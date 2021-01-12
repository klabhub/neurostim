classdef (Abstract) noiseclut < neurostim.stimuli.clutImage
    % TODO: clean up this help text, and unify across all child classes.
    % see noiseGridDemo.m for examples of usage in experiment script, and noisegrid.m for example of an implmented child stimulus.
    % Abstract stimulus class to present arbitrary noise images (e.g. for white-noise analysis).
    % Luminance noise values are drawn from Matlab's built-in probaility distributions or returned by a user-defined function.
    % Argument specification is based on that of the jitter() plugin (though custom function specification is slightly different... TODO: unify this and jitter())
    %
    % The imaging approach is similar to a CLUT, where the image that is
    % drawn is represented as a 2D matrix of indices into an array LUT of random
    % variables for luminance. The LUT values are updated (sampled) from frame to frame.
    % This allows an arbitrary mapping of a small number of random variables onto
    % a potentially larger image of texels/pixels. The last entry in the LUT is the background luminance.
    % This allows you to make arbitrary noise stimuli, such as Cartesian grids, polar grids,
    % polygons, non-contiguous patches, etc.
    %
    % By default, luminance values are NOT logged because of potential memory load.
    % However, the state of the RNG on each frame is logged, allowing offline reconstruction.
    % There is some over-head there. Logging can also be switched off entirely.
    %
    %
    %   Settable properties:
    %
    %   sampleFun       -   a handle to a custom CLUT function used to populate the CLUT values.
    %                       sampleFun() must accept this plugin as its sole argument, f(o), and return an array of luminance/xyl values for one or more color channels (size = [1, o.nRandels] or [3, o.nRandels]) for each of the
    %                       random variables (that are mapped internally to pixels in the ID image).
    %   parms           -   parameters for the N-parameter pdf, as an N-length cell array (see RANDOM)
    %   bounds          -   2-element vector specifying lower and upper bounds to truncate the distribution (default = [], i.e., unbounded). Bounds cannot be Inf.
    %
    %                       ** Note that the CLUT distribution function is called once before the start of each trial to determine the CLUT size.**
    %
    %   width           -   width on screen (screen units)
    %   height           -   height on screen (screen units)
    %   logType         -   What should be logged? All luminance values, RNG state (for offline reconstruction), or nothing?
    %   alphaMask       -   Matrix of alpha values to apply a transparency mask. Size = o.size
    %   signal          -   [not yet supported - use alphaMask for now] A matrix of values that is added to the noise (e.g. for detection task)
    %
    %
    % A note on CLUT format:
    %
    %   If Neurostim is running in the XYL color mode, the CLUT will be 3 x
    %   nRandels in size, with all entries in the first two rows (CIEx and CIEy) equal to
    %   o.color(1) and o.color(2) respectively.
    %
    %   To use different colours, you would need to use the custom
    %   distribution option and population the 3 x nRandels CLUT yourself.
    %
    %
    %  TODO:
    %       (1) Allow a signal to be embedded (this has to happen in the shader used in gllutimage.m)
    %       (2) Add co-variance matrix, sz = [o.nRandels,o.nRandels], for presenting correlated noise.
    %       (3) Provide a reconstruction tool for offline analysis
    %       (4) This approach to rng is inefficient: it would be better to have a separate RNG stream for this stimulus. CIC would need to act as RNG server?
    
    properties (Access = private)
        initialised = false;
        frameInterval_f;
        callbackCtr;  %Increments every time the callback functions are called, to ensure that we can reconstruct the stimulus offline
    end
    
    properties (GetAccess = public, SetAccess = private)
        nRandels;
        callback;   %Handle of function for returning luminance values on each frame, or cell array of function handles (one per color/alpha channel)
    end
    
    properties (GetAccess = public, SetAccess = protected)
        wireFrame;                  % nVertices x 2 matrix for the wireframe "grid", useful for plotting and presenting
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
        function o = noiseclut(c,name)
            
            o = o@neurostim.stimuli.clutImage(c,name);
            
            %% User-definable
            %---Sampling distribution
            %sampleFun, parms, and bounds can all be single values, or cell arrays (to specify sampling for multiple color/luminance/alpha channels)
            validator = @(validateFun,x) (~iscell(x) && validateFun(x)) | (iscell(x) && all(cellfun(@(y) validateFun(y),x)));
            o.addProperty('sampleFun','uniform','validate',@(x) validator(@(arg) ischar(arg) | isa(arg,'function_handle'),x));
            o.addProperty('parms',[0 1],'validate',@(x) validator(@iscell,x));
            o.addProperty('bounds',[], 'validate',@(x) validator(@(arg) isempty(arg) || (numel(arg)==2 && ~any(isinf(arg)) && diff(arg) > 0),x));
            
            %---Timing
            o.addProperty('frameInterval',o.cic.frames2ms(3));                  %How long should each frame be shown for? default = 3 frames.
            
            %---Logging options
            %WARNING: ONLY SET propOfRandelsToLog to 1 IF nRandels IS VERY SMALL! OTHERWISE, THE MEMORY LOAD REQUIRED COULD LEAD TO FRAMEDROPS.
            o.addProperty('propOfRandelsToLog',0.1,'validate',@(x) (numel(x)==1)&(x>=0)&(x<=1)); %CLUT values are logged at the end of each trial, and only the first 10% by default.
            
            %---Offline tools
            o.addProperty('offlineMode',false);                     %True to simulate trials without opening PTB window.
            
            %---Drawing tools for debugging. (not yet implemented)
            o.addProperty('showWireFrame',false,'validate',@(x) islogical(x));
            o.addProperty('showCenters',false,'validate',@(x) islogical(x));
            o.addProperty('showPerimeter',false,'validate',@(x) islogical(x));
            
            %% Internal use for clut and mapping
            %---Spatial info
            o.addProperty('randelX',[],'validate',@(x) validateattributes(x,{'numeric'},{'real'}));
            o.addProperty('randelY',[],'validate',@(x) validateattributes(x,{'numeric'},{'real'}));
            
            %---logging of CLUT values
            o.addProperty('rngState',[]);       %Logged at the start of each trial.
            o.addProperty('callbackCounter',0); %Logged at the end of each trial
            o.addProperty('clutVals',[]);       %If requested, just log all luminance values.
            
            %We need our own RNG stream, to ensure its protected for stimulus reconstruction offline
            addRNGstream(o);
            
        end
        
        function beforeFrame(o)
            %Can be overloaded in child class, as long as drawIt() is called.
            o.drawIt();
        end
        
        function drawIt(o)
            
            %Update the raster luminance values
            curFr = o.frame;
            frInt = o.frameInterval_f;
            o.isNewFrame = (isinf(frInt) && curFr==0) || (~isinf(frInt)&&~mod(curFr,frInt));
            if o.isNewFrame
                o.update();
            end
            
            %Show the randel image
            o.draw();
            
            %Superimpose the wireFrame, if requested
            % (TO DO)   if o.showWireFrame
            %               o.drawWireFrame();
            %           end
            
            %Superimpose the randel centers, if requested
            %  (TO DO)  if o.showCenters
            %               o.drawCenters();
            %           end
        end
        
        function afterTrial(o)
            o.logInfo();
            o.cleanUp();
            o.initialised = false;
        end
        
        function afterExperiment(o)
            %Experiment has been cancelled. Make sure we log last trial
            if ~isempty(o.clut)
                %o.cleanUp() hasn't been called. Probably because "esc" was pressed
                o.logInfo();
                o.cleanUp();
            end
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
            framesWereDropped = ~iscell(frDr.data);
            if framesWereDropped
                stay = ~isnan(frDr.data(:,1)); %frameDrop initialises to NaN
                frDr = structfun(@(x) x(stay,:),frDr,'unif',false);
                
                %Convert duration of frame drop from ms to frames (this assumes frames were synced?)
                frDr.data(:,2) = o.cic.ms2frames(1000*frDr.data(:,2));
            end
            
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
                
                if ~isempty(thisFrDrData)
                    
                    %Discard drops that happened before or after
                    kill = thisFrDrData(:,1)<stimStart.frame(i) | thisFrDrData(:,1)>stimStop.frame(i);
                    thisFrDrData(kill,:) = [];
                    
                    %Now re-number the frame drops relative to our first frame
                    thisFrDrData(:,1) = thisFrDrData(:,1) - stimStart.frame(i)+1;
                    
                    %Now add in the repeats caused by dropped frames
                    framesPerFrame = ones(size(cbByFrame));
                    framesPerFrame(thisFrDrData(:,1)) = thisFrDrData(:,2)+1;
                    cbByFrame = repelem(cbByFrame,framesPerFrame);
                end
                
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
        
        function initialise(o,im)
            
            %The image (im) is specified as a bitmap of arbitrary IDs for random variables.
            %IDs must be integers from 1 to N, or 0 to use background luminance.
            
            %Make sure the requested duration is a multiple of the display frame interval
            tol = 0.1; %5% mismatch between requested frame duration and what is possible
            frInt = o.cic.ms2frames(o.frameInterval,false);
            o.frameInterval_f = round(frInt);
            if ~isinf(frInt) && abs(frInt-o.frameInterval_f) > tol
                o.writeToFeed(['Noise frameInterval not a multiple of the display frame interval. It has been rounded to ', num2str(o.cic.frames2ms(o.frameInterval_f)) ,'ms']);
            end
            
            %Allow the CLUT parent class to build textures and clut
            o.setImage(im);
            o.nRandels = o.nClutColors;
            
            %Set up CLUT callbacks, used to population the noise clut with luminance values
            o.setupCallbacks();
            
            if ~o.offlineMode
                o.prep();   %This line makes the openGL textures
            end
            
            o.initialised = true;
            
        end
        
        function setupCallbacks(o)
            
            %Build the callback functions that will be used to populate the clut.
            
            %First have to clean up the formatting of the variables.
            %sampleFun,bounds, and parms are all processed internally as cell
            %arrays. Parms, additionally, is a cell array of cells, because each entry needs to capture a variable number of args to random()
            %If only a single channel has been parameterized, probably need to cellify
            locSampleFun = o.sampleFun;
            locBounds = o.bounds;
            locParms = o.parms;
            if ~iscell(locSampleFun)
                locSampleFun = {locSampleFun};
            end
            
            if isempty(locBounds)
                locBounds = cell(1,numel(locSampleFun));
            elseif ~iscell(locBounds)
                locBounds = {locBounds};
            end
            
            %o.parms is converted to a cell array of cells
            cellifyParm = @(x) num2cell(x(:)');
            if isempty(locParms)
                locParms = cell(1,numel(locSampleFun));
            elseif ~iscell(locParms)
                locParms = {cellifyParm(locParms)};
            end
            
            %Already a cell/cell array. Make sure that each entry is a cell.
            if numel(locParms)>1
                needsCellifying = cellfun(@(x) ~iscell(x),locParms);
                locParms(needsCellifying) = cellfun(cellifyParm, locParms(needsCellifying),'unif',false);
            end
            
            %Create the callback function(s) (this line populates o.callback and o.probObj)
            cellfun(@(s,p,b,i) setupThisCallback(o,s,p,b,i),locSampleFun,locParms,locBounds,num2cell(1:numel(locSampleFun)));
            
            %Assign the cleaned up variables.
            o.sampleFun = locSampleFun;
            o.bounds = locBounds;
            o.parms = locParms;
            
            %Store the RNG state.
            o.rngState = o.rng.State;
            
            %Correspondingly, reset the callbackCounter. We set it to
            %-1, so that after the beforeTrial() dry run (on the next
            %line), it will be zero, and then 1 on the first frame in which
            %the stimulus will actually be drawn (when update is called).
            %-1 will help us remember offline that the dry run happens and
            %to take it into acocunt.
            o.callbackCtr = -1;
            
            %The parent class requires us to have populated o.clut, so do
            %that now. We need to anyway, because if user-defined, we need
            %to know how many channels are being supplied.
            %(The user must thus be aware that their function is called as
            %a dry-run once before the trial starts.)
            locClut = runCallbacks(o);
            
            % If cic is in XYL mode, and the CLUT only has one channel, assume luminance.
            % So prepend a callback that sets the xy channels to o.color.
            if strcmpi(o.colorMode,'XYL') && size(locClut,1)==1
                col = o.color(:);
                xyLpartialClut = repmat(col(1:2),1,o.nRandels);         %2 x nRandels matrix of xy values
                o.callback = horzcat({@(o) xyLpartialClut}, o.callback);
                locClut = vertcat(xyLpartialClut,locClut); %Also done manually once here, to prevent needing to call to callbacks again
            end
            
            %All done. Set it.
            o.clut = locClut;
        end
        
        function setupThisCallback(o,sampleFun,parms,bounds,callbackID)
            %Set up a callback function, used to population the noise clut with luminance values
            if isa(sampleFun,'function_handle')
                %User-defined function. Function must receive the noise plugin as its sole argument and return
                %luminance/color values [o.nChans x o.nRandels] for the CLUT.
                cb = sampleFun;
                
            elseif ischar(sampleFun)
                if any(strcmpi(sampleFun,{'1ofN','oneofN','randsample'}))
                    %Picking a value from a pre-defined list with equal probability, with replacement
                    cb = @(o) [parms{randi(numel(parms),1,o.nRandels)}];
                    
                elseif any(strcmpi(sampleFun,makedist))
                    %Using Matlab's built-in probability distributions
                    
                    %Create a probability distribution object
                    pd = makedist(sampleFun,parms{:});
                    
                    %Truncate the distribution, if requested
                    if ~isempty(bounds)
                        pd = truncate(pd,bounds(1),bounds(2));
                    end
                    
                    %Store function handle and object
                    %TODO: we are creating and logging more and more probObjects. Might run into a problem with large number of trials? Better to re-create the objects offline
                    cb = @(o) random(pd,1,o.nRandels);
                else
                    error(horzcat('Unknown distribution name ', sampleFun));
                end
                
            else
                error(['Unknown distribution type. See help for ', mfilename]);
            end
            
            %Add this one the list
            o.callback{callbackID} = cb;
        end
        
        function o = update(o)
            
            %Update the values in the clut
            o.clut = runCallbacks(o);
            
            %Allow parent to update its mapping texture (there should really be a setClut() in parent
            updateCLUTtex(o);
        end
        
        function locClut = runCallbacks(o)
            %Switch to using my RNG as the global stream)
            globStream = RandStream.setGlobalStream(o.rng);
            
            %Evaluate the callback functions (each of which returns a m x nRandels set of gun/alpha values) and set the clut.
            locClut = cellfun(@(x) x(o),o.callback,'unif',false);
            locClut = vertcat(locClut{:});
            
            %Keep track of how many times we have called these functions,
            %to make sure we can reconstruct the stimuli offline
            o.callbackCtr = o.callbackCtr+1;
            
            %Restore previous global stream
            RandStream.setGlobalStream(globStream);
        end
        
        function setIDxy(o,xy)
            %Store a single normalised [x,y] coordinate to each random variable (e.g. patch centroid).
            if ~o.initialised
                error('You can only set the coordinates after placing the image with o.initialise(im)');
            end
            
            %Check format
            if ~isequal(size(xy),[o.nRandels,2])
                error('The XY matrix must be a two-column matrix of x and Y coordinates with the number of rows equal to the number of unique IDs in the image, i.e., [o.nRandels, 2]');
            end
            if ~all(xy>=0 & xy <=1)
                error('The XY mapping coordinates for IDs must be in normalised units (0 to 1)');
            end
            
            %All good.
            o.randelXY = xy;
        end
        
        function drawWireFrame(o)
            %PLACEHOLDER
            warning('Sorry... showWireFrame is not implemented yet');
            %             Screen('FramePoly', o.window,[1,0,0], o.wireFrame, 3);
        end
        function drawCenters(o)
            %PLACEHOLDER
            warning('Sorry...  showCenters is not implemented yet');
            %             Screen('FramePoly', o.window,[1,0,0], o.wireFrame, 3);
        end
        function drawPerimeter(o)
            %PLACEHOLDER
            warning('Sorry...  showCenters is not implemented yet');
            %             Screen('FramePoly', o.window,[1,0,0], o.wireFrame, 3);
        end
        %         function [x,y] = id2xy(o,id)
        %
        %         end
        
    end % protected methods
    
    methods (Access = private)
        
        function logInfo(o)
            %Store some details to help reconstruct the stimulus offline
            %How many times the callbacks were called.
            o.callbackCounter = o.callbackCtr;
            
            %The actual CLUT values used in the last frame (usually, only a subset)
            o.clutVals = o.clut(:,1:o.nRandelsToLog);
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
    
end % classdef
