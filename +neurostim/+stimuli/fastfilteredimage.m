classdef fastfilteredimage < neurostim.stimulus
    %Filter images/noise using an ampltidue mask in Fourier space.
    %
    properties (Access = private)
        sngImage_space;
        dblImage_space;
        gpuImage_space;
        gpuImage_freq;
        gpuFiltImage_freq;
        gpuMask_freq;
        gpuFiltImageRawMean;
        gpuFiltImageRawSTD;
        rect;
        frameInterval_f;
        bigFrameCtr;  %Increments every time a new rand() image is created to ensure that we can reconstruct the stimulus offline
        tex;
        ticStart;
    end
    
    properties (GetAccess = public, SetAccess = private)
        nRandels;        
    end
    
    properties (GetAccess = public, SetAccess = protected)
       
    end
    
    properties
        isNewFrame = false  %Flag that gets set to true on each frame that the noise is updated. Useful for syncing other stimuli/plugins.
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
            
            o = o@neurostim.stimulus(c,name);
            
            %% User-definable
            defaultImage = imread('cameraman.tif');
            o.addProperty('image',defaultImage);          %A string path to an image file, an image matrix, or a function handle that returns an image
            o.addProperty('imageDomain','SPACE','validate',@(x) any(strcmpi(x,{'SPACE','FREQUENCY'})));
            o.addProperty('imageIsStatic',false);       %if true, image is computed once in beforeTrial() and never again. Otherwise, every frame
            o.addProperty('mask',eye(5));
            o.addProperty('maskIsStatic',true);
            o.addProperty('meanLum',0.25);                   %Mean luminance of the final image
            o.addProperty('contrast',0.5);                  %Contrast of the final image, defined as RMS contrast, std(L)/mean(L)
            o.addProperty('size',size(defaultImage));
            o.addProperty('width',10);
            o.addProperty('height',10);
            
            %---Timing
            o.addProperty('frameInterval',o.cic.frames2ms(3));                  %How long should each frame be shown for? default = 3 frames.
            
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
            
        end
        
        function beforeExperiment(o)
            %Check the RNG type. Needs to be 'threefry'
        end
        
        
        function beforeTrial(o)
            
            %Create CPU and GPU arrays
            sz=o.size;
            o.sngImage_space = zeros(sz,'single');
            o.dblImage_space = zeros(sz,'double');
            [o.gpuMask_freq,o.gpuFiltImage_freq]=deal(zeros(sz,'single','gpuArray'));
            
            if o.imageIsStatic && strcmpi(o.imageDomain,'SPACE')                
                o.gpuImage_space = gpuArray(single(o.image));
            else
                o.gpuImage_space = zeros(sz,'single','gpuArray');
            end
                        
            if o.maskIsStatic
                o.gpuMask_freq = gpuArray(single(o.mask));
            else
                o.gpuMask_freq = zeros(sz,'single','gpuArray');
            end
            
            o.rect = [-o.width/2,-o.height/2,o.width/2,o.height/2];
            
            o.bigFrameCtr = 0;
            
                        %Make sure the requested duration is a multiple of the display frame interval
            tol = 0.1; %5% mismatch between requested frame duration and what is possible
            frInt = o.cic.ms2frames(o.frameInterval,false);
            o.frameInterval_f = round(frInt);
            if ~isinf(frInt) && abs(frInt-o.frameInterval_f) > tol
                o.writeToFeed(['Noise frameInterval not a multiple of the display frame interval. It has been rounded to ', num2str(o.cic.frames2ms(o.frameInterval_f)) ,'ms']);
            end
            

            o.nRandels = prod(o.size);
        end
        
        function beforeFrame(o)
            
            %Update the raster luminance values
            curFr = o.frame;
            frInt = o.frameInterval_f;
            o.isNewFrame = (isinf(frInt) && curFr==0) || (~isinf(frInt)&&~mod(curFr,frInt));
            if o.isNewFrame
                %Calculate a new image
                o.update();
            
                %Clera the existing texture
                if curFr>0
                    Screen('Close', o.tex);
                end
                
                o.tic();
                o.tex = Screen('MakeTexture',o.window,o.dblImage_space,[],[],2); %2 means 32-bit texture, 0 to 1 RGB range
                o.toc();
            end
                                   
            Screen('DrawTexture',o.window,o.tex,[],o.rect,[],1);
        end
        
        function afterTrial(o)
            o.logInfo();
        end
        
        function afterExperiment(o)
            %Experiment has been cancelled. Make sure we log last trial
%             if ~isempty(o.clut)
%                 %o.cleanUp() hasn't been called. Probably because "esc" was pressed
%                 o.logInfo();
%                 o.cleanUp();
%             end
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
    end % public methods
    
    
    methods (Access = protected)            
        
        function o = update(o)
            
            %Keep track of how many times we've updated
            o.bigFrameCtr = o.bigFrameCtr+1;
                        
            %Switch to using my RNG as the global stream
            globStream = RandStream.setGlobalStream(o.rng);
            
            sz = o.size;
            
            %Random image
            o.gpuImage_freq = neurostim.stimuli.fastfilteredimage.randComplexPhase(sz);

            %Mask.*Image
            o.gpuFiltImage_freq  = o.gpuImage_freq.*o.gpuMask_freq;
            
            %IFFT2
            o.gpuImage_space = real(ifft2(o.gpuFiltImage_freq));

            %Normalise and apply mean luminance, RMS contrast
            newMean = o.meanLum;
            newSD = newMean*o.contrast;
            if o.bigFrameCtr==1 &&  o.cic.trial==1
                [o.gpuFiltImageRawMean,o.gpuFiltImageRawSTD] = meanstd(o); %2ms
            end            
            o.gpuImage_space = rescale(o,newMean,newSD);

            %Return filtered image to the CPU and convert to double for MakeTexture
            o.sngImage_space = gather(o.gpuImage_space); %2ms                     
            o.dblImage_space = double(o.sngImage_space); %3ms
                
            %Restore previous global stream
            RandStream.setGlobalStream(globStream);
            
        end
        
        function tic(o)
            if o.bigFrameCtr==100
                o.ticStart=GetSecs;
            end
        end
        
        function toc(o)
            if o.bigFrameCtr==100
                1000*(GetSecs-o.ticStart)
            end
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
            gpuIm = (o.gpuImage_space-o.gpuFiltImageRawMean)./o.gpuFiltImageRawSTD.*newSD+newMean;
        end
        

        
    end % protected methods
    
    methods (Access = private)
        
        function logInfo(o)
            %Store some details to help reconstruct the stimulus offline
            %How many times the callbacks were called.
            o.nBigFrames = o.bigFrameCtr;
            
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
end % classdef
