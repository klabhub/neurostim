classdef fastfilteredimage < neurostim.stimuli.splittasksacrossframes
    %Filter images/noise using an amplitude mask in Fourier space.
    %Calculations are done on the GPU so that it is extremely fast,
    %allowing new noise/mask values to be applied every frame (or close to it) without frame
    %drops. Uses the splittask adaptive approach to distribute the task
    %load across the update interval frames and minimize frame drops.
    %
    %NOTE: image is not shown on the screen until o.bigFrameInterval
    %milliseconds after o.on (because first image is still being computed)
    %External functions that return an image or mask with random elements
    %must use o.rng in the calls to rand, randn,or randi (no other random
    %functions are supported on the GPU!)
    properties (Constant)
        MAXTEXELSTOLOG = 20;
    end
    
    properties (Access = private)
        gpuDevice;
        sngImage_space;
        dblImage_space;
        gpuImage_space@gpuArray;
        gpuImage_freq@gpuArray;
        gpuFiltImage_freq@gpuArray;
        gpuMask_freq@gpuArray;
        gpuFiltImageRawMean@gpuArray;
        gpuFiltImageRawSTD@gpuArray;
        filtImageRawSTD;
        pvtNumImagesComputed;
        pvtMeanLum@single;
        pvtContrast@single;
        pvtSize;
        rect;        
        tex;
        ticStart;
        normStatsDone = false;
    end
    
    properties (GetAccess = public, SetAccess = private)
        nTexels;
        dataHashVersion;
    end
    
    properties (GetAccess = public, SetAccess = protected)
        
    end
    
    properties (Dependent, Access = protected)
        pvtNTexelsToLog
    end
    
    methods
        function v = get.pvtNTexelsToLog(o)
            switch upper(o.logMode)
                case 'ALL'
                    v = o.nTexels;
                case 'HASH'
                    v = 0;
                case 'NTEXELS'
                    v = o.nTexelsToLog;
            end
        end
    end
    
    methods (Access = public)
        function o = fastfilteredimage(c,name)
            
            o = o@neurostim.stimuli.splittasksacrossframes(c,name);
            o.writeToFeed('Warning: this is a new stimulus and has gone through only limited testing. Check images/timing/reconstruction with PTB image grabs and/or photodiode.');
                        
            %% User-definable
            o.addProperty('image',@randComplexPhaseImage);          %A string path to an image file, an image matrix, or a function handle that returns an image
            o.addProperty('imageDomain','FREQUENCY','validate',@(x) any(strcmpi(x,{'SPACE','FREQUENCY'})));
            o.addProperty('imageIsStatic',false);       %if true, image is computed once in beforeTrial() and never again. Otherwise, every frame
            o.addProperty('mask',@(o) gaussLowPassMask(o,24));
            o.addProperty('maskIsStatic',true);
            o.addProperty('meanLum',0.25);                   %Mean luminance of the final image
            o.addProperty('contrast',0.5);                  %Contrast of the final image, defined as RMS contrast, std(L)/mean(L)
            o.addProperty('size',[1024 1024],'validate',@(x) size(x,1)==1 && numel(x)==2);
            o.addProperty('width',10);
            o.addProperty('height',10);
            o.addProperty('statsConstant',false); %Set to true if mean lum and SD is constant across trials, saves on re-computing each frame.
            
            %---Logging options            
            o.addProperty('logMode','HASH', 'validate',@(x) ismember(upper(x),{'ALL','HASH','NTEXELS'}));
            o.addProperty('nTexelsToLog',[],'validate',@(x) (numel(x)==1)&(x>=0)); %CLUT values are logged at the end of each trial, and only the first 10% by default.
            
            %---Offline tools
            o.addProperty('offlineMode',false);                     %True to simulate trials without opening PTB window.
            
            %% Internal use for mapping            
            %---logging of image luminance values
            o.addProperty('rngState',[]);               %Logged at the start of each trial.
            o.addProperty('nImagesComputed',0);         %Logged at the end of each trial
            o.addProperty('lastImageComputed',[]);      %Partial or complete log of luminance values, or a hash
            
            %Get the GPU device and reset it to clear any memory/tasks (not certain that this is needed)
            o.gpuDevice = gpuDevice;
            reset(o.gpuDevice);
            
            %We need our own GPU RNG stream, to ensure its protected for stimulus reconstruction offline
            addRNGstream(o,[],true); %true means GPU-based RNG
            
            %Store version of the DataHash tool (from File Exchange)
            o.dataHashVersion = neurostim.utils.DataHash;
        end
        
        function setupTasks(o)
            if o.disabled
                %Nothing to do this trial
                return;
            end
            
            %Create a list of the tasks to be done to create the filtered image.
            tsks = {@initialise,@getImage,@getMask,@fftImage,@filterImage,@intensity2lum,@gatherToCPU,@finalise,@makeTexture};
            
            %Make the array of tasks, indicating that they are unsplittable across frames
            for i=1:numel(tsks)
                o.addTask(tsks{i},'splittable',0);
            end
            
            %Separate tasks into ones we can do now, and ones that need to be done beforeFrame()
            isStatic = o.imageIsStatic & o.maskIsStatic;
            fftNeeded = strcmpi(o.imageDomain,'SPACE');
            doNow = [true,o.imageIsStatic,o.maskIsStatic,isStatic&fftNeeded,isStatic,isStatic,isStatic,isStatic,isStatic];
            doLater = ~doNow;
            doLater(4) = false; %FFT not yet implemented
            
            %Set up each task
            for i=1:numel(o.tasks)
                %When should it be done?
                if doNow(i)
                    o.tasks(i).when = 'beforeTrial';
                elseif doLater(i)
                    o.tasks(i).when = 'beforeFrame';
                else
                    o.tasks(i).enabled = 0;
                end
            end
        end
        
        function beforeBigFrame(o)
            
        end
        
        function initialise(o,~)
            
            %Make local copies for faster access (no online changes to
            %these properties are allowed anyway)
            o.pvtMeanLum = single(o.meanLum);
            o.pvtContrast = single(o.contrast);
            o.pvtSize = o.size;
            
            %Create CPU and GPU arrays
            o.sngImage_space = zeros(o.pvtSize,'single');
            o.dblImage_space = zeros(o.pvtSize,'double');
            [o.gpuMask_freq,o.gpuFiltImage_freq]=deal(zeros(o.pvtSize,'single','gpuArray'));
            
            o.gpuImage_space = zeros(o.pvtSize,'single','gpuArray');
            o.gpuMask_freq = zeros(o.pvtSize,'single','gpuArray');
            
            o.rect = [-o.width/2,-o.height/2,o.width/2,o.height/2];
            o.nTexels = prod(o.pvtSize);
            
            %Make sure we are logging texels appropriately.
            if isempty(o.nTexelsToLog)
                o.nTexelsToLog = min(0.1*o.nTexels,o.MAXTEXELSTOLOG); %Log 10% by default, up to limit
            end
            
            %Make sure we aren't logging too much data.
            if (o.pvtNTexelsToLog > o.MAXTEXELSTOLOG) && o.cic.trial==1                
                warning(horzcat('**** You are logging ', num2str(o.pvtNTexelsToLog), ' image values every trial. This could cause memory problems and slow-down. Consider changing logMode.'));
            end
            
            %Store the RNG state.
            o.rngState = o.rng.State;
            
            %Reset counter
            o.pvtNumImagesComputed = 0;
        end
        
        function getImage(o,~)
            
            %Load or construct the raw image
            if isa(o.image,'function_handle')
                im = o.image(o);
            else
                %It's just an image matrix.
                im = o.image;
            end
            
            if strcmpi(o.imageDomain,'FREQUENCY')
                o.gpuImage_freq = im;
            else
                o.gpuImage_space = im;
            end
        end
        
        function getMask(o,~)
            %Load or construct the raw image
            if isa(o.mask,'function_handle')
                o.gpuMask_freq = o.mask(o);
            else
                %It's just an image matrix.
                o.gpuMask_freq = o.mask;
            end
        end
        
        function fftImage(o,~)
            %Not yet implemented
        end
        
        function filterImage(o,~)
            %Mask.*Image
            o.gpuFiltImage_freq  = o.gpuImage_freq.*o.gpuMask_freq;
            
            %IFFT2
            o.gpuImage_space = real(ifft2(o.gpuFiltImage_freq));
        end
        
        function intensity2lum(o,~)
            %Normalise and apply mean luminance, RMS contrast
            newMean = o.pvtMeanLum;
            newSD = newMean*o.pvtContrast;
            o.gpuImage_space = rescale(o,newMean,newSD);
        end
        
        function gatherToCPU(o,~)
            %Return filtered image to the CPU and convert to double for MakeTexture
            o.sngImage_space = gather(o.gpuImage_space);
        end
        
        function finalise(o,~)
            %This is a separate task because double() was surprisingly slow with large images
            o.dblImage_space = double(o.sngImage_space);
            
            %Increment the counter (done here because it is dblImage_space
            %that is ultimately logged (last image only) for stimulus reconstruction
            o.pvtNumImagesComputed = o.pvtNumImagesComputed + 1;
        end
        
        function makeTexture(o,~)
            %The filtered image is ready, so put it into out texture
            if ~isempty(o.tex)
                Screen('Close', o.tex);
            end
            o.tex = Screen('MakeTexture',o.window,o.dblImage_space,[],[],2); %2 means 32-bit texture, 0 to 1 RGB range
        end
        
        function draw(o)
            Screen('DrawTexture',o.window,o.tex,[],o.rect,[],1);
        end
        
        function afterTrial(o)
            if ~isempty(o.tex)
                %Our stimulus must have been shown, so do post-trial tasks
                Screen('Close', o.tex);
                o.tex = [];
                o.logInfo();
            end
            afterTrial@neurostim.stimuli.splittasksacrossframes(o);
        end        
        
        function maskIm = gaussLowPassMask(o,sd)
            %Gaussian mask filter, centered on 0
            if diff(o.size)~=0
                error('gaussLowPassMask currently only supports square images');
            end
            maskIm = gpuArray(ifftshift(fspecial('gaussian',o.size(1),sd)));
        end
        
        function [im,imIx] = reconstructStimulus(o,varargin)
            %Reconstruct the filtered images offline.
            %Also requires a GPU and Parallel Computing Toolbox.
            %
            %Input arguments:
            %
            %'trial' [default = all trials] = list of trial numbers to reconstruct
            %
            %Output arguments
            %
            %'im' =     cell array containing all the unique images shown,
            %           of size [1 nTrials], where nTrials is determined by
            %           the trial numbers requested. Each cell in the array
            %           contains a [o.size(1) o.size(2) nUniqueFrames(tr)]
            %           matrix of luminance values. These are the unique
            %           images, not the frame sequence - it does not
            %           include image repetition due to o.bigFrameInterval
            %           or dropped frames. To reconstruct the full stream,
            %           including those repeats, use the second output
            %           argument:
            %
            %'imIx' =   cell array, same size as im. Each entry is a vector
            %           of image indices (into the last dimension of
            %           im{tr}) of size [1,nFrames(tr)] - the full image
            %           sequence.
            %
            %e.g.       To reconstruct the full image stream on trial 3:
            %
            %           [im,imIx] = reconstructStimulus(c.filtIm,'trial',[2 3 5]);
            %           imSequence = im{3}(:,:,imIx{3});
            
            p=inputParser;
            p.addParameter('trial',[]);
            p.parse(varargin{:});
            p = p.Results;
            
            %Return all trials by default
            if isempty(p.trial)
                p.trial = 1:o.cic.trial;
            end
            
            %NS parameters                        
            nsPrms = {'image','imageDomain','imageIsStatic','mask','maskIsStatic','meanLum', ...
                      'contrast','nImagesComputed','size','statsConstant','rngState','lastImageComputed'};                    
            getFun = @(thisPrm) get(o.prms.(thisPrm),'trial',p.trial,'atTrialTime',Inf);
            cellify = @(x) cellfun(@(y) squeeze(y),mat2cell(x,ones(1,size(x,1))),'unif',false);
            constantPrms = {};
            for i=1:numel(nsPrms)
                %Get the per-trial values
                vals = getFun(nsPrms{i});
                
                %If not already in an nTrials x 1 cell array, make it so
                if ~iscell(vals)
                    vals = cellify(vals);
                end
                
                %If all trials have the same value, only store it once (prevent OOM errors)
                if all(cellfun(@(x) isequal(x,vals{1}),vals)) && ~strcmpi(nsPrms{i}, 'nImagesComputed')
                    vals = vals(1);
                    constantPrms = horzcat(constantPrms,nsPrms(i));
                end
                
                byTrial.(nsPrms{i})= vals;
                
                %Turn off logging for this param (so replay isn't logged)
                stopLog(o.prms.(nsPrms{i}));
            end
            
            %Replay the stimulus by restoring initial state of NS
            %parameters, then running tasks as before, excluding the ones
            %that use openGL, PTB etc.
            needsRewind = ~ismember(nsPrms,{'rngState','nImagesComputed','lastImageComputed'}); %these ones were not set by user
            recapPrms = nsPrms(needsRewind);
            
            %Prepare the task objects
            deleteTask(o,{'makeTexture'});
            
            %Some of the byTrial entries are singletons (if constant), so can't always use t (below) to index.
            t2ix = @(prmName,t) ~ismember(prmName,constantPrms)*(t-1)+1; 
            
            for t=1:numel(p.trial)                       
                
                %Rewind the plugin, using the per-trial values or the lone value if constant
                for i=1:numel(recapPrms)
                    prmName = recapPrms{i};
                    o.(prmName) = byTrial.(prmName){t2ix(prmName,t)};
                end
                
                %Restore the state of the RNG
                o.rng.State = byTrial.rngState{t};
                
                %Reconstruct the images by re-running the beforeTrial and beforeFrame tasks
                arrayfun(@(tsk) do(tsk),o.beforeTrialTasks); 
                nFrames = byTrial.nImagesComputed{t};
                im{t} = nan(horzcat(byTrial.size{t2ix('size',t)},nFrames+1)); %plus 1 because from time zero until first big frame, our stimulus was not yet visible. So we'll leave a NaNs image in position 1.               
                for f=1:nFrames
                    arrayfun(@(tsk) do(tsk),o.beforeFrameTasks);
                    im{t}(:,:,f+1)=o.dblImage_space;
                end
                
                %Make sure the reconstruction matches, last frame checked only
                lastRecoIm = im{t}(:,:,end);
                switch upper(o.logMode)
                    case 'HASH'         
                        recoHash = neurostim.stimuli.fastfilteredimage.im2hash(lastRecoIm);
                        isMatch = isequal(recoHash,byTrial.lastImageComputed{t});
                    case {'ALL','NTEXELS'}
                        isMatch = isequal(lastRecoIm(1:o.pvtNTexelsToLog),byTrial.lastImageComputed{t}(:)');
                end
                if ~isMatch
                    error('Reconstructed stimulus does not match the logged values.');
                end
            end
                       
            %Up til here, we have reconstructed the unique images that were
            %shown, in the right order, but not taken into account the
            %update rate, nor dropped frames logged in CIC.
            %
            %So, our task here is to use repelem() to duplicate each image
            %index the right number of times to restore the actual time-line.
            
            %We need to take into account frame-drops. So gather info here
            frDr = get(o.cic.prms.frameDrop,'trial',p.trial,'struct',true);
            stay = ~isnan(frDr.data(:,1)); %frameDrop initialises to NaN
            frDr = structfun(@(x) x(stay,:),frDr,'unif',false);
            
            %Convert duration of frame drop from ms to frames (this assumes frames were synced?)
            frDr.data(:,2) = o.cic.ms2frames(1000*frDr.data(:,2));
            
            %Need to align the frame-drop data to the onset of this stimulus
            %On what c.frame did the stimulus appear, and how long was it shown?
            stimStart = get(o.prms.startTime,'trial',p.trial,'struct',true);
            stimStop = get(o.prms.stopTime,'trial',p.trial,'struct',true);
            %stimStop remains Inf if we stop an experiment prematurely via
            %"escape". Fix that here.
            [~,~,trialStopTime] = get(o.cic.prms.trialStopTime,'trial',p.trial);
            ix = isinf(stimStop.trialTime);
            stimStop.trialTime(ix) = trialStopTime(ix);
            
            %Calculate stimulus duration in display frames
            stimDur_Fr = o.cic.ms2frames(stimStop.trialTime-stimStart.trialTime);
            
            for t=1:numel(p.trial)
                
                %Initially assume no drops. i.e. all repeats were due to
                %intended frame interval and all repeats were shown
                %(nothing guarantees that... could be mid-way through an
                %interval when the stimulus/trial ends. Gets fixed below.)
                imIxByFrame = horzcat(ones(1,o.nLittleFrames), repelem(1:byTrial.nImagesComputed{t},o.nLittleFrames*ones(1,byTrial.nImagesComputed{t}))+1); %Concat and Plus-1 for same reason as above: Nan image in pos 1
                
                %Get the frame drop data for this trial
                these = frDr.trial==p.trial(t);
                thisFrDrData = frDr.data(these,:);
                
                %Discard drops that happened before or after
                kill = thisFrDrData(:,1)<stimStart.frame(t) | thisFrDrData(:,1)>stimStop.frame(t);
                thisFrDrData(kill,:) = [];
                
                %Now re-number the frame drops relative to our first frame
                thisFrDrData(:,1) = thisFrDrData(:,1) - stimStart.frame(t)+1;
                
                %Now add in the repeats caused by dropped frames
                framesPerFrame = ones(size(imIxByFrame));
                framesPerFrame(thisFrDrData(:,1)) = thisFrDrData(:,2)+1;
                imIxByFrame = repelem(imIxByFrame,framesPerFrame);
                
                %**** BAND-AID
                if stimDur_Fr(t) > numel(imIxByFrame)
                    %Last frame of trial (screen clearing) must have been dropped! That one's not logged.
                    imIxByFrame(end:stimDur_Fr(t)) = imIxByFrame(end); %Our last frame must have been shown for longer
                end
                %*****
                
                %Chop off any frames that were never shown due to end of stimulus
                imIxByFrame = imIxByFrame(1:stimDur_Fr(t));
                
                %Store it
                imIx{t} = imIxByFrame;
            end
        end
        
        function afterExperiment(o)
            %Clear the memory in local variables
            dumpArrays(o);
            afterExperiment@neurostim.stimuli.splittasksacrossframes(o);
        end
        
        function dumpArrays(o)
            %Clear the memory in local variables
            props = {'sngImage_space', 'dblImage_space','gpuImage_space','gpuImage_freq', 'gpuFiltImage_freq', 'gpuMask_freq', 'gpuFiltImageRawMean', 'gpuFiltImageRawSTD'};
            for i=1:numel(props)
                if isa(o.(props{i}),'gpuArray')
                    o.(props{i}) = gpuArray;
                else
                    o.(props{i}) = [];
                end
            end
        end
        
        function im = deformedAnnulusMask(o,varargin)
            %Annulus mask in Fourier domain, with radius ? cos(orientation).
            p=inputParser;
            p.addParameter('maxSF',8.3); %cycles/screen width unit (NS)
            p.addParameter('minSF',3.5);
            p.addParameter('SFbandwidth',1.2);
            p.addParameter('blurSD',0.5);
            p.addParameter('orientation',0); %orientation of major axis for deformed annulus
            p.addParameter('plot',false);
            p.parse(varargin{:});
            p=p.Results;
            
%             if diff(o.size)~=0
%                 error('annulusMask currently only supports square images.');
%             end
            
            %Set up pixel space
            sz = o.size;
            nPixPerNS = sz(2)/o.width;                %Display pixel resolution
            
            %X_deg = (0:nPix-1)*nPixPerDeg/nPix;             %Frequencies along FFT axis, without FFT shift
            fx_ns = (-sz(2)/2:sz(2)/2-1)*(nPixPerNS/sz(2));   %Frequencies along FFT axis, with FFT shift
            fy_ns = (-sz(1)/2:sz(1)/2-1)*(nPixPerNS/sz(1));   %Frequencies along FFT axis, with FFT shift
            
            %What is the maximum SF
            maxSF_ns = min([max(fx_ns),max(fy_ns)]);            
            
            %Calculate nyquist limit
            nyq = 1./sqrt(2); %Nyquist on oblique            
            sfNorm2sfNS = @(sf) sf*maxSF_ns;           
            nyq = sfNorm2sfNS(nyq);
            
            %What is the center SF in the annulus?
            centerSF = mean([p.maxSF,p.minSF]);
            
            [fSFh,fSFv]=meshgrid(fx_ns,fy_ns);
            
            % %% New method
            [fTheta,fR]=cart2pol(fSFh,fSFv);
            
            %Center frequency
            theta2centSF = @(th) ((cos(2*(th+p.orientation))+1)/2).*(p.maxSF-p.minSF)+p.minSF;
            
            distToCenterSF = @(th,r) abs(r-theta2centSF(th));
            rAdj = @(th,r) max(distToCenterSF(th,r)-p.SFbandwidth/2,0);
            tableTopGauss = @(th,r,sd) normpdf(rAdj(th,r),0,sd);
            mask_freq = tableTopGauss(fTheta,fR,p.blurSD);
            
            if p.plot
                
                %Mask in frequency domain
                figure; h = [];
                imagesc(fy_ns,fx_ns,mask_freq); axis image; colormap('gray');hold on; h(end+1) = gca;
                [circX,circY]=pol2cart(linspace(-pi,pi,1000),1);
                plot(nyq*circX,nyq*circY,'r'); plot(centerSF*circX,centerSF*circY,'y');
                title('Amplitude mask in Fourier domain (hSF, vSF)');
                
                %Mask in space
                figure
                mask_space = fftshift(ifft2(ifftshift(mask_freq), 'symmetric'));
                imagesc(mask_space); axis image; colormap('gray'); hold on;
                title('Amplitude mask as convolution kernel in image space');
            end
            
            im = ifftshift(mask_freq);            
            im = im./max(im(:));
            %im(im<eps) = 0;
            im=gpuArray(im);
        end
    end % public methods
    
    
    methods (Access = protected)
                
        function tic(o,waitForGPUFinish)
            if nargin > 1 && waitForGPUFinish
                wait(o.gpuDevice);
            end
            o.ticStart=GetSecs;
        end
        
        function toc(o,waitForGPUFinish)
            if nargin > 1 && waitForGPUFinish
                wait(o.gpuDevice);
            end
            disp(horzcat('Elapsed = ',num2str(1000*(GetSecs-o.ticStart)),' ms'));
        end
        
        function [meanVal,sd] = meanstd(o)
            %Efficient calculation of mean and std on gpu image
            meanVal = mean2(o.gpuImage_space);
            dev = (o.gpuImage_space-meanVal).^2;
            sd = sqrt(sum(dev(:))/o.nTexels);
        end
        
        function gpuIm = rescale(o,newMean,newSD)
            %Efficient rescaling of an image, defined by its mean and SD
            %(so probably only meaningful for approximately Gaussian
            %intensity distributions.)
            if (o.statsConstant && ~o.normStatsDone) || ~o.statsConstant
                [curMean,curSTD] = meanstd(o); 
                if o.statsConstant
                    o.gpuFiltImageRawMean = curMean;
                    o.gpuFiltImageRawSTD = curSTD;
                    o.normStatsDone = true; %Prevent re-entry to meanstd()
                end
            else
                %Use stored values
                curMean = o.gpuFiltImageRawMean;
                curSTD = o.gpuFiltImageRawSTD;
            end
            
            gpuIm = max(min((o.gpuImage_space-curMean)./curSTD.*newSD+newMean,1),0);
        end
                
        function im = randComplexPhaseImage(o)
            %Gaussian white noise.
            im = exp(1j*2*pi*rand(o.rng,o.pvtSize,'single')); %This gives random phases
        end
        
    end % protected methods
    
    methods (Access = private)
                
        function logInfo(o)
            %Store some details to help reconstruct the stimulus offline
            %How many times was the task list executed?
            o.nImagesComputed = o.pvtNumImagesComputed;
            
            %The actual luminance values used in the last frame (usually, only a hash or subset)
            switch upper(o.logMode)
                case 'HASH'
                    o.lastImageComputed = neurostim.stimuli.fastfilteredimage.im2hash(o.dblImage_space);
                case {'ALL'}
                    o.lastImageComputed = o.dblImage_space;
                case 'NTEXELS'
                    o.lastImageComputed = o.dblImage_space(1:o.nTexelsToLog);
            end
        end
    end
    
    methods (Static, Access = private)
        
        function offlineReplay(clutVals,ixImage,cbCtr,trialNum,frameDur,colorMode)
            %Show the reconstructed stimulus in a figure window.
            warning('Replay is rudimentary and should not be taken too seriously. It won''t show you any transparency, and it uses no timing info.');
            replayErrorMsg = 'Replay is currently only supported for luminance or RGB images, no alpha, no XYL color mode.';
            if strcmpi(colorMode,'XYL'), error(replayErrorMsg); end
            for j=1:cbCtr
                %Use the image to index into the clut
                cl = clutVals(:,:,j);
                cl = horzcat(zeros(size(cl,1),1),cl);%Set transparent parts to black
                im = cl(:,ixImage+1);
                if ~ismember(size(cl,1),[1 3]), error(replayErrorMsg); end
                
                %Restore the image size
                im = squeeze(reshape(im,size(im,1),size(ixImage,1),size(ixImage,2)));
                
                %Convert to suitable RGB format
                if ismatrix(im)
                    %Luminance only
                    im = repmat(im,1,1,3); %replicate to RGB
                elseif ndims(im)==3
                    %RGB color
                    im = permute(im,[2 3 1]);
                end
                
                %Show it
                imshow(uint8(im*256),'initialMagnification','fit'); title(['Trial ', num2str(trialNum)]);
                pause(frameDur/1000);
            end
        end
    end
    
    methods (Static)        
        function h = im2hash(im)
            %Convert image into a checksum/hash.
            h = neurostim.utils.DataHash(im,'array','hex','md5');
        end
    end
end
% classdef
