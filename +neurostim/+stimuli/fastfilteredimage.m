classdef fastfilteredimage < neurostim.stimuli.splittasksacrossframes
    %Filter images/noise using an ampltidue mask in Fourier space.
    %
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
        pvtMeanLum@single;
        pvtContrast@single;
        rect;        
        tex;
        ticStart;
        normStatsDone = false;
    end
    
    properties (GetAccess = public, SetAccess = private)
        nRandels;
    end
    
    properties (GetAccess = public, SetAccess = protected)
        
    end
    
    properties (Dependent, Access = protected)
        nRandelsToLog;
    end
    
    methods
        function v = get.nRandelsToLog(o)
            %If nRandels is 10 or less, log them all, otherwise, log X% of them
            v = max(min(o.nRandels,10),round(o.propOfRandelsToLog*o.nRandels));
        end
    end
    
    methods (Access = public)
        function o = fastfilteredimage(c,name)
            
            o = o@neurostim.stimuli.splittasksacrossframes(c,name);
            
            %% User-definable
            o.addProperty('image',@randImage);          %A string path to an image file, an image matrix, or a function handle that returns an image
            o.addProperty('imageDomain','SPACE','validate',@(x) any(strcmpi(x,{'SPACE','FREQUENCY'})));
            o.addProperty('imageIsStatic',false);       %if true, image is computed once in beforeTrial() and never again. Otherwise, every frame
            o.addProperty('mask',@(o) gaussLowPassMask(o,24));
            o.addProperty('maskIsStatic',true);
            o.addProperty('meanLum',0.25);                   %Mean luminance of the final image
            o.addProperty('contrast',0.5);                  %Contrast of the final image, defined as RMS contrast, std(L)/mean(L)
            o.addProperty('size',[1024 1024]);
            o.addProperty('width',10);
            o.addProperty('height',10);
            o.addProperty('statsConstant',false); %Set to true if mean lum and SD is constant across trials, saves on re-computing each frame.
            
            %---Logging options
            %WARNING: ONLY SET propOfRandelsToLog to 1 IF nRandels IS VERY SMALL! OTHERWISE, THE MEMORY LOAD REQUIRED COULD LEAD TO FRAMEDROPS.
            o.addProperty('propOfRandelsToLog',0.1,'validate',@(x) (numel(x)==1)&(x>=0)&(x<=1)); %CLUT values are logged at the end of each trial, and only the first 10% by default.
            
            %---Offline tools
            o.addProperty('offlineMode',false);                     %True to simulate trials without opening PTB window.
            
            %% Internal use for mapping
            %---Spatial info
            o.addProperty('randelX',[],'validate',@(x) validateattributes(x,{'numeric'},{'real'}));
            o.addProperty('randelY',[],'validate',@(x) validateattributes(x,{'numeric'},{'real'}));
            
            %---logging of CLUT values
            o.addProperty('rngState',[]);       %Logged at the start of each trial.
            o.addProperty('nBigFrames',0); %Logged at the end of each trial
            o.addProperty('randelVals',[]);       %If requested, just log all luminance values.
            
            %We need our own RNG stream, to ensure its protected for stimulus reconstruction offline
            o.rng = requestRNGstream(c);
            
            o.gpuDevice = gpuDevice;
            reset(o.gpuDevice);
        end
        
        function setupTasks(o)
            
            %Create a list of the tasks to be done to create the filtered image.
            tsks = {@initGPUarrays,@getImage,@getMask,@fftImage,@filterImage,@intensity2lum,@gatherToCPU,@single2double,@makeTexture};
            
            %Make the array of tasks, indicating that they are splittable across frames
            for i=1:numel(tsks)
                o.addTask(tsks{i},'splittable',0);
            end
            
            %Separate tasks into ones we can do now, and ones that need to be done beforeFrame()
            %Which of these can we do now?
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
            
            %Check that the random number generator is 'threefry'
            %TODO
            
            o.pvtMeanLum = single(o.meanLum);
            o.pvtContrast = single(o.contrast);
        end
        
        function beforeBigFrame(o)
            
        end
        
        function initGPUarrays(o,~)
            
            %Create CPU and GPU arrays
            sz=o.size;
            o.sngImage_space = zeros(sz,'single');
            o.dblImage_space = zeros(sz,'double');
            [o.gpuMask_freq,o.gpuFiltImage_freq]=deal(zeros(sz,'single','gpuArray'));
            
            o.gpuImage_space = zeros(sz,'single','gpuArray');
            o.gpuMask_freq = zeros(sz,'single','gpuArray');
            
            o.rect = [-o.width/2,-o.height/2,o.width/2,o.height/2];
            o.nRandels = prod(o.size);
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
            o.sngImage_space = gather(o.gpuImage_space); %2ms
        end
        
        function single2double(o,~)
            o.dblImage_space = double(o.sngImage_space); %3ms
        end
        
        function makeTexture(o,~)
            if ~isempty(o.tex)
                Screen('Close', o.tex);
            end
            o.tex = Screen('MakeTexture',o.window,o.dblImage_space,[],[],2); %2 means 32-bit texture, 0 to 1 RGB range
        end
        
        function draw(o)
            Screen('DrawTexture',o.window,o.tex,[],o.rect,[],1);
        end
        
        function afterTrial(o)
            Screen('Close', o.tex);
            o.tex = [];
            
            afterTrial@neurostim.stimuli.splittasksacrossframes(o);
            o.logInfo();
        end        
        
        function im = randImage(o)
            
            %Switch to using my RNG as the global stream
            globStream = RandStream.setGlobalStream(o.rng);
            
            %Random image
            im = neurostim.stimuli.fastfilteredimage.randComplexPhase(o.size);
            
            %Restore previous global stream
            RandStream.setGlobalStream(globStream);
            
        end
        
        function maskIm = gaussLowPassMask(o,sd)
            %Gaussian mask filter, centered on 0
            sz = o.size;
            if diff(sz)~=0
                error('gaussLowPassMask currently only supports square images');
            end
            maskIm = gpuArray(ifftshift(fspecial('gaussian',sz(1),sd)));
        end
        
        function [clutVals,ixImage] = reconstructStimulus(o,varargin)
            %Reconstruct the noiseclut stimulus offline. Returns the
            %stimulus as a cell array of clut arrays (clutVals), one for each trial,
            %and a corresponding cell array (ixImage) storing the color-by-numbers images.
            %To convert to a bitmap image, just use ixImage to index into the
            %clut array from the same frame.
            %
            %Each entry in clutVals is a [o.nChans x o.nRandels x nFrames] array of
            %color values.
            
            p=inputParser;
            p.addParameter('trial',1:o.cic.trial);
            p.addParameter('replay',false);
            p.addParameter('replayFrameDur',50);
            p.addParameter('debug',false);
            p.parse(varargin{:});
            p = p.Results;
            
            %Callback parameters
            sFun = get(o.prms.sampleFun,'trial',p.trial,'atTrialTime',Inf);
            prms = get(o.prms.parms,'trial',p.trial,'atTrialTime',Inf);
            bnds = get(o.prms.bounds,'trial',p.trial,'atTrialTime',Inf,'matrixIfPossible',false);
            rngSt = get(o.prms.rngState,'trial',p.trial,'atTrialTime',Inf);
            cbCtr = get(o.prms.callbackCounter,'trial',p.trial,'atTrialTime',Inf);
            
            %Other parameters that we need to recapitulate
            ixImage =  get(o.prms.ixImage,'trial',p.trial,'atTrialTime',Inf); %The color-by-numbers image
            loggedClut = get(o.prms.clutVals,'trial',p.trial,'atTrialTime',Inf);
            
            %ixImage and loggedClut will be cell arrays if their sizes
            %changed from trial to trial, so unify that here
            cellify = @(x) cellfun(@(y) squeeze(y),mat2cell(x,ones(1,size(x,1))),'unif',false);
            if ~iscell(ixImage)
                ixImage = cellify(ixImage);
            end
            if ~iscell(loggedClut)
                loggedClut = cellify(loggedClut);
            end
            
            %How many randels were there?
            nRndls = cellfun(@(x) max(x(:)),ixImage);
            
            %Everything is in hand. Reconstruct.
            clutVals = cell(1,numel(p.trial));
            warned = false;
            if p.replay, figure; end
            nTrials = numel(p.trial);
            for i=1:nTrials
                
                %Restore these parameters, to ensure callbacks are built correctly.
                o.sampleFun = sFun{i};
                o.parms     = prms{i};
                o.bounds    = bnds{i};
                o.nRandels  = nRndls(i);
                
                %We need to be careful if the user defined their own
                %callback function, gaining control, rather than letting us
                %call Matlab's built-in functions. If so, it's really
                %out of our hands. Warn user that we cannot guarantee
                %anything. That said, everything should work fine as long
                %as their function does not depend on any other property
                %values that changed throughout the experiment.
                if any(cellfun(@(x) isa(x,'function_handle'),o.sampleFun))
                    if ~warned
                        warning('This stimulus used a user-defined function to set the luminance/color of the randels. The reconstruction might fail if your custom function calls upon any Neurostim parameters other than o.nRandels and o.ixImage). We really have no way to know what you did!');
                        warned = true;
                    end
                    o.ixImage = ixImage{i}; %We'll at least restore this... maybe they used it.
                end
                
                %Restore the state of the RNG
                o.rng.State = rngSt(i,:);
                
                %Re-build the callback functions
                setupCallbacks(o);
                
                %Run the frames for this trial
                for j=1:cbCtr(i)
                    clutVals{i}(:,:,j) = runCallbacks(o);
                end
                
                %Validate the reconstruction against the stored CLUT values
                nLogged = o.nRandelsToLog;
                if ~isequal(clutVals{i}(:,1:nLogged,end),loggedClut{i}(:,1:nLogged))
                    error('Stimulus reconstruction failed. Values do not match the logged values.');
                end
                
                %Use a figure window to show the reconstructed images
                if p.replay
                    neurostim.stimuli.noiseclut.offlineReplay(clutVals{i},ixImage{i},cbCtr(i),i,p.replayFrameDur,o.colorMode)
                end
            end
            
            
            %Up til here, we have reconstructed the unique images that were
            %shown, in the right order, but not taken into account the
            %update rate, nor dropped frames logged in CIC.
            %
            %So, our task here is to use repelem() to duplicate each image
            %the right number of times to restore the actual time-line.
            updateInterval = o.cic.ms2frames(get(o.prms.frameInterval,'trial',p.trial,'atTrialTime',Inf));
            
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
            
            for i=1:numel(p.trial)
                
                %Initially assume no drops. i.e. all repeats were due to intended frame interval
                %and all repeats were shown (nothing guarantees that...
                %could be mid-way through an interval when the stimulus/trial ends.
                cbByFrame = repelem(1:cbCtr(i),updateInterval(i)*ones(1,cbCtr(i)));
                
                %Get the frame drop data for this trial
                these = frDr.trial==p.trial(i);
                thisFrDrData = frDr.data(these,:);
                
                %Discard drops that happened before or after
                kill = thisFrDrData(:,1)<stimStart.frame(i) | thisFrDrData(:,1)>stimStop.frame(i);
                thisFrDrData(kill,:) = [];
                
                %Now re-number the frame drops relative to our first frame
                thisFrDrData(:,1) = thisFrDrData(:,1) - stimStart.frame(i)+1;
                
                %Now add in the repeats caused by dropped frames
                framesPerFrame = ones(size(cbByFrame));
                framesPerFrame(thisFrDrData(:,1)) = thisFrDrData(:,2)+1;
                cbByFrame = repelem(cbByFrame,framesPerFrame);
                
                %**** BAND-AID
                if stimDur_Fr(i) > numel(cbByFrame)
                    %Last frame of trial (screen clearing) must have been dropped! That one's not logged.
                    cbByFrame(end:stimDur_Fr(i)) = cbByFrame(end); %Our last frame must have been shown for longer
                end
                %*****
                
                %Chop off any frames that were never shown due to end of stimulus
                cbByFrame = cbByFrame(1:stimDur_Fr(i));
                
                %Timeline reconstructed, so use it to convert the length of clutVals to time
                clutVals{i} = clutVals{i}(:,:,cbByFrame);
            end
        end
        
        function im = annulusMask(o,varargin)
            %Annulus mask in Fourier domain. Use fftshift(im) to visualise it with zero in the center.
            p=inputParser;
            p.addParameter('maxSF',8.3); %Proportion of Nyquist.
            p.addParameter('minSF',3.5);
            p.addParameter('SFbandwidth',1.2);
            p.addParameter('blurSD',0.5);
            p.addParameter('orientation',0); %orientation of major axis for deformed annulus
            p.addParameter('plot',false);
            p.parse(varargin{:});
            p=p.Results;
            
            if diff(o.size)~=0
                error('annulusMask currently only supports square images.');
            end
            
            nPix = o.size(1);
            
            %Set up pixel space
            nPixPerNS = nPix/o.width;                %Display pixel resolution
            
            %Set up Fourier domain, in normalised coordinates
            nyq = 1./sqrt(2); %Nyquist on oblique
            
            %X_deg = (0:nPix-1)*nPixPerDeg/nPix;             %Frequencies along FFT axis, without FFT shift
            fx_ns = (-nPix/2:nPix/2-1)*(nPixPerNS/nPix);   %Frequencies along FFT axis, with FFT shift
            maxSF_ns = max(fx_ns);
            
            sfNorm2sfNS = @(sf) sf*maxSF_ns;
            
            %Convert params to prop of nyq and then degrees
            %             p.maxSF = sfNorm2sfNS(p.maxSF*nyq);
            %             p.minSF = sfNorm2sfNS(p.minSF*nyq);
            %             p.SFbandwidth = sfNorm2sfNS(p.SFbandwidth*nyq);
            %             blurSD = sfNorm2sfNS(p.blurSD*nyq);
            nyq = sfNorm2sfNS(nyq);
            centerSF = mean([p.maxSF,p.minSF]);
            
            %X = linspace(-1,1,nPix);
            [fSFh,fSFv]=meshgrid(fx_ns);
            
            % %% New method
            [fTheta,fR]=cart2pol(fSFh,fSFv);
            
            %Center frequency
            theta2centSF = @(th) ((cos(2*th+p.orientation+pi)+1)/2).*(p.maxSF-p.minSF)+p.minSF;
            
            distToCenterSF = @(th,r) abs(r-theta2centSF(th));
            rAdj = @(th,r) max(distToCenterSF(th,r)-p.SFbandwidth/2,0);
            tableTopGauss = @(th,r,sd) normpdf(rAdj(th,r),0,sd);
            mask_freq = tableTopGauss(fTheta,fR,p.blurSD)';
            
            if p.plot
                
                %Mask in frequency domain
                figure; h = [];
                imagesc(fx_ns,fx_ns,mask_freq); axis image; colormap('gray');hold on; h(end+1) = gca;
                [circX,circY]=pol2cart(linspace(-pi,pi,1000),1);
                plot(nyq*circX,nyq*circY,'r'); plot(centerSF*circX,centerSF*circY,'y');
                
                %Mask in space
                figure
                mask_space = fftshift(ifft2(ifftshift(mask_freq), 'symmetric'));
                imagesc(mask_space); axis image; colormap('gray'); hold on                
            end
            
            im = ifftshift(mask_freq);            
            im = im./max(im(:));
            %im(im<eps) = 0;
            im=gpuArray(im);
        end
    end % public methods
    
    
    methods (Access = protected)
                
        function tic(o)
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
            sd = sqrt(sum(dev(:))/o.nRandels);
        end
        
        function gpuIm = rescale(o,newMean,newSD)
            %Efficient rescaling of an image, defined by its mean and SD
            %(so probably only meaningful for approximately Gaussian
            %intensity distributions.)
            if (o.statsConstant && ~o.normStatsDone) || ~o.statsConstant
                [curMean,curSTD] = meanstd(o); %2ms
                if o.statsConstant
                    o.gpuFiltImageRawMean = curMean;
                    o.gpuFiltImageRawSTD = curSTD;
                    o.normStatsDone = true; %Prevent re-entry to meanstd()
                end
            else
                %Use values stored on CPU
                curMean = o.gpuFiltImageRawMean;
                curSTD = o.gpuFiltImageRawSTD;
            end
            
            gpuIm = max(min((o.gpuImage_space-curMean)./curSTD.*newSD+newMean,1),0);
        end
        
        
        
    end % protected methods
    
    methods (Access = private)
        
        function logInfo(o)
            %Store some details to help reconstruct the stimulus offline
            %How many times the callbacks were called.
            o.nBigFrames = o.bigFrame;
            
            %The actual CLUT values used in the last frame (usually, only a subset)
            %o.randelVals = o.clut(:,1:o.nRandelsToLog);
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
        function im = randComplexPhase(sz)
            %Gaussian white noise.
            im = exp(1j*2*pi*rand(sz,'single','gpuArray')); %This gives random phases
        end
        
        
        
    end
end
% classdef
