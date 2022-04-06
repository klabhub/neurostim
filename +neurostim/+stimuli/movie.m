classdef movie < neurostim.stimulus
    % Stimulus class to present movies as textures (without using
    % GStreamer, which does not play nice with the Matlab JVM).
    %
    % This class uses the VideoReader to read the movie files and convert
    % to OpenGL textures in the interrial interval. For a 1 MB movie (20
    % seconds at 30 fps), this takes about 4 seconds -= so a long ITI
    % should be expected. With some additional bookkeeping this could be
    % pushed to the beforeExperiment phase (to load multiple movies to
    % texture memory at the start of the experiment)
    %
    % 
    % Settable properties:
    %   id      - id(s) of the texture(s) to show on
    %             the next frame
    %   width   - width on screen (screen units)
    %   hight   - height on screen (screen units)
    %   X
    %   Y
    %   orientation - in degrees.
    %   filename  - full path to the movie file. This must be one of the
    %   formats that VideoReader can interpret.
    %   path - If filename is not a full path, specify a path separately
    %   here.
    % 
    %   framerate - the framerate at which to play the Movie (defaults to the rate in the file)
    %   filterMode - Texture filterModes - 1 = bilinear, the default.  For higher quality, increase the number (up to 5). See Screen('DrawTexture?') for details.  
    %   loop - Loop the movie within a trial.
    %
    % Read only properties   
    %   nrFrames = nmber of frames in the movie
    %   xPixels , yPixels native number of pixels in the movie file.
    % 
    %  BK - May 2019
    
    properties (Access = private)
        % Each frame will be associated with a texture
        tex = [];       % Vector fo texture pointers 
        rect =[];       % Rect to apply the texture
        currentlyLoadedFile = '';  % Full path to currently loaded file.
    end
    
     properties (GetAccess = public, SetAccess = private)
        fracFrameCntr;      % Current fractional frame cntr.
    end
    
    methods (Access = public)
        function o = movie(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('width',[],'validate',@isnumeric);
            o.addProperty('height',[],'validate',@isnumeric);
            o.addProperty('xPixels',[],'validate',@isnumeric, 'sticky',true);
            o.addProperty('yPixels',[],'validate',@isnumeric, 'sticky',true);
            o.addProperty('nrFrames',[],'validate',@isnumeric, 'sticky',true);
            o.addProperty('filename','','validate',@ischar);
            o.addProperty('path','','validate',@(x) (ischar(x) && exist(x,'dir')));
            o.addProperty('filterMode',1,'validate',@(x) ismember(x,[0:5]));
            o.addProperty('framerate',[],'validate',@isnumeric, 'sticky',true);
            o.addProperty('orientation',0,'validate',@isnumeric);
            o.addProperty('loop',false,'validate',@islogical);
             %record #frames of every trial
            o.addProperty('nrFramesRecord', [], 'validate',@isnumeric);
        end
        
        function afterTrial(o)
            o.nrFramesRecord = o.frame; %smaller
%             o.nrFramesRecord = o.cic.frame; %larger
        end
             
        function afterExperiment(o)
            % clean up the textures
            Screen('Close',o.tex);
            o.tex = [];
        end
        
        function beforeTrial(o)
            % Check what the current filename is, load it if necessary
            if isempty(o.path)
                file = o.filename;
            else
                file = fullfile(o.path,o.filename);
            end
            if strcmpi(o.currentlyLoadedFile,file)
                % No need to reload
            else
                % Cleanup textures from the previous movie
                Screen('Close',o.tex);
                if ~exist(file,'file')
                    error(['Movie file : ' file ' could not be found']);
                end
                try
                    % tic
                    % Use the VideoReader object to read each of the frames
                    % and put it in texture memory.
                    obj = VideoReader(file);
                    o.xPixels = obj.Width;
                    o.yPixels = obj.Height;                    
                    if isempty(o.framerate)
                        o.framerate = obj.FrameRate;
                    end
                    % create the textures
                    i=0;
                    while hasFrame(obj)
                        i=i+1;
                        o.tex(i) = Screen('MakeTexture',o.window,readFrame(obj));
                    end
                    o.nrFrames =i;
                    % toc
                catch me
                    me.message
                    error(['Could not load the movie : ' file]);
                end
                o.currentlyLoadedFile =file;
            end
            
            % Determine the currently requested size of the movie
            if isempty(o.width)
                % Do not scale
                o.width = o.cic.screen.width*o.xPixels/o.cic.screen.xpixels;
            end
            if isempty(o.height)
                % Do not scale
                o.height = o.cic.screen.height*o.yPixels/o.cic.screen.ypixels;
            end
            o.rect = 0.5*[-o.width o.height o.width -o.height];
            o.fracFrameCntr=  1;% Reset the fractional frame cntr
            
        end
        
        function beforeFrame(o)
            if isempty(o.tex); return; end % Nothing to do
            % Increase the fractional frame cntr by some amount determined
            % by the desired framerate and the actual (targeted) framerate
            % of the application.
            o.fracFrameCntr = o.fracFrameCntr+o.framerate/o.cic.screen.frameRate;
            if o.loop
                thisFrame = mod(floor(o.fracFrameCntr)-1,o.nrFrames)+1;
            else
                thisFrame = floor(o.fracFrameCntr);
            end
            
            if thisFrame <= o.nrFrames
                % These are not currently used/varied but could be added if neeed.
                globalAlpha=1;modulateColor=[];textureShader=[];specialFlags=[];auxParameters=[];
                Screen('DrawTextures',o.window,o.tex(thisFrame),[],o.rect,o.orientation,o.filterMode,globalAlpha,modulateColor,textureShader,specialFlags,auxParameters);
            end
        end
        
         function [frames_ori, frameIdx_final, timeVec, frames_final] = reconstructStimulus(o, varargin)
            %Reconstruct the movie stimulus offline of a specified trial.
            % INPUTS:
            % trial: trial number
            % moviePath: path to the original movie file. if empty, use the
            % one in c.movie.filename
            % replay: whether to show movie [default: false]
            % replayFPS: frame rate of the replay movie [default: 60Hz]
            %
            % OUTPUTS;
            % frames_ori: original movie 4D stack (y - x - color- frame)
            % frameIdx_final: frame index for restoring frames_final =
            % frame(:,:,:,frameIdx_final)
            % timeVec: time vector corresponding to frames_final
            % OPTIONAL OUTPUTS:
            % frames_final: a 4D stack of images of all the screen
            % refleshes
            % created from neurostim/stimli/noiseclut.reconstructStimulus
            
            % TODO: save every N frames of the movie or cic.frame of every
            % trials with addProperty()
            
            p=inputParser;
            p.addParameter('replay',false);
            p.addParameter('trial',1);
            p.addParameter('moviePath',[]);
            p.addParameter('replayFPS',60);%Display++ is 120Hz
            p.parse(varargin{:});
            p = p.Results;
            
            % width = get(c.movie.prms.width,'trial',p.trial, 'atTrialTime', Inf);
            % height = get(c.movie.prms.height,'trial',p.trial, 'atTrialTime', Inf);
            % nrFrames = get(o.prms.nrFrames,'trial',p.trial, 'atTrialTime', Inf);
            %p.moviePath = get(o.prms.path,'trial',p.trial, 'atTrialTime', Inf);
            filename = get(o.prms.filename,'trial',p.trial, 'atTrialTime', Inf);
            % orientation = get(o.prms.orientation,'trial',p.trial, 'atTrialTime', Inf);
            loop = get(o.prms.loop,'trial',p.trial, 'atTrialTime', Inf);
            frameRate = get(o.prms.framerate,'trial',p.trial, 'atTrialTime', Inf);
            refleshRate = o.cic.screen.frameRate; %screen reflesh rate
            xPixels = get(o.prms.xPixels,'trial',p.trial, 'atTrialTime', Inf);
            yPixels = get(o.prms.yPixels,'trial',p.trial, 'atTrialTime', Inf);
            nrFramesRecord = get(o.prms.nrFramesRecord,'trial',p.trial, 'atTrialTime', Inf);
            
            
            %Everything is in hand. Reconstruct.
            %clutVals = cell(1,numel(p.trial));
            warned = false;
            if p.replay, figure; end
            
            %% beforeTrial
            if isempty(p.moviePath)
                file = filename;
            else
                [~,filename_p,filename_s] = fileparts(filename);
                filename = [filename_p filename_s];
                file = fullfile(p.moviePath,filename);
            end
            
            obj = VideoReader(file);
            frames_ori = uint8([]);%zeros(obj.Height, obj.Width, 3);
            
            i=0;
            disp('loading movie');
            while hasFrame(obj)
                i=i+1;
                frames_ori(:,:,:,i) = readFrame(obj);
            end
            nrFrames =i;
            disp('done loading movie');
            
            clear obj ;
            %% beforeFrame
            %% temporally down sampling
            frameIdx_ds = [];%<this defines length of frameIdx_final
            frameCntr = 1;
            thisFrame = 0;
            iFrame = 1;
            while (thisFrame < size(frames_ori,4))
                frameCntr = frameCntr+frameRate...
                    /refleshRate;
                if loop
                    thisFrame = mod(floor(frameCntr)-1,nrFrames)+1;
                else
                    thisFrame = floor(frameCntr);
                end
                frameIdx_ds(iFrame) = thisFrame;
                iFrame = iFrame + 1;
            end
            
            
            %Use a figure window to show the reconstructed images
            if p.replay
                implay(frames_ori(:,:,:,frameIdx_ds), p.replayFPS);
            end
            
            
            %Up til here, we have reconstructed the unique images that were
            %shown, in the right order, but not taken into account the
            %update rate, nor dropped frames logged in CIC.
            %
            %So, our task here is to use repelem() to duplicate each image
            %the right number of times to restore the actual time-line.
            updateInterval = 1; %update at every screen reflesh
            
            %We need to take into account frame-drops. So gather info here
            frDr = get(o.cic.prms.frameDrop,'trial',p.trial,'struct',true);
            if size(frDr.block,1) < size(frDr.block,2)
                frDr.block = frDr.block';%rmfield(frDr, 'block');
            end
            framesWereDropped = ~iscell(frDr.data);
            if framesWereDropped
                stay = ~isnan(frDr.data(:,1)); %frameDrop initialises to NaN
                frDr = structfun(@(x) x(stay,:),frDr,'unif',false);
                
                %Convert duration of frame drop from ms to frames
                % (this assumes frames were synced?)
                % duration smaller than one frame is converted to one frame
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
            %the line below is originally implemented in noiseclut.m:
            stimDur_Fr = nrFramesRecord;
            %stimDur_Fr = c.cic.ms2frames(stimStop.trialTime-stimStart.trialTime); <why
             
            %Initially assume no drops. i.e. all repeats were due to intended frame...
            %interval and all repeats were shown (nothing guarantees that...
            %could be mid-way through an interval when the stimulus/trial ends.
            cbCtr = length(frameIdx_ds);
            cbByFrame = repelem(1:cbCtr,updateInterval...
                *ones(1,cbCtr));
            
            %Get the frame drop data for this trial
            these = frDr.trial==p.trial;
            thisFrDrData = frDr.data(these,:);
            
            if ~isempty(thisFrDrData)
                
                %Discard drops that happened before or after
                kill = thisFrDrData(:,1)<stimStart.frame ...
                    | thisFrDrData(:,1)>stimStop.frame;
                thisFrDrData(kill,:) = [];
                
                %Now re-number the frame drops relative to our first frame
                thisFrDrData(:,1) = thisFrDrData(:,1) - stimStart.frame+1;
                
                %Now add in the repeats caused by dropped frames
                framesPerFrame = ones(size(cbByFrame));
                framesPerFrame(thisFrDrData(:,1)) = thisFrDrData(:,2)+1;
                
                cbByFrame = repelem(cbByFrame,framesPerFrame);
            end
            
            %**** BAND-AID
            if stimDur_Fr > numel(cbByFrame)
                %Last frame of trial (screen clearing) must have been dropped! That one's not logged.
                cbByFrame(end:stimDur_Fr) = cbByFrame(end); %Our last frame must have been shown for longer
            end
            %*****
            
            %Chop off any frames that were never shown due to end of stimulus
            cbByFrame = cbByFrame(1:stimDur_Fr);
            
            %Timeline reconstructed, so use it to convert the length of clutVals to time
            frameIdx_final = frameIdx_ds(cbByFrame);
            if nargout>3
                frames_final = frames_ori(:,:,:,frameIdx_final);
            end
            
            timeVec = stimStart.trialTime:1e3/refleshRate:stimStop.trialTime;
            timeVec = timeVec(1:end-1);%at stimStop.trialTime, frame is NOT presented
            %timeVec = linspace(stimStart.trialTime, stimStop.trialTime, stimDur_Fr);
            %timeVec = c.cic.frames2ms(1:size(frames_final,4));
            
            disp(['#images in the movie:' num2str(size(frames_ori,4))]);
            disp(['#supposed frames wo dropped frames:' num2str(length(frameIdx_ds))]);
            disp(['#dropped frames:' num2str(size(thisFrDrData,1))]);
            disp(['#reconstructed frames:' num2str(length(frameIdx_final))]); %=stimDur_Fr
            disp(['#frames recorded:' num2str(nrFramesRecord)]);
            
        end
        
    end % public methods
    
    
end
