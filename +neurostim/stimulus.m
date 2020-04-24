classdef stimulus < neurostim.plugin
    % Base class for stimuli in PTB.
    %
    % Adjustable variables:
    %   X,Y,Z - position of stimulus
    %   on - time the stimulus should come 'on' (ms) from start of trial
    %   duration - length of time the stimulus should be 'on' (ms)
    %   color - color of the stimulus
    %   scale.x,scale.y,scale.z - scale of the stimulus along various axes
    %   angle - angle of the stimulus
    %   rx, ry, rz - rotation of the stimulus
    %   rsvp - RSVP conditions of the stimulus (see addRSVP() for more input
    %       details)
    %
    % To monitor onset/offset timing of a stimulus, see stimuli.diodeFlasher
    %
    
    properties
        % Function to call on onset. Used to communicate event to external hardware. See egiDemo
        % This function takes a stimulus object and the flipTime (i.e. the
        % time when the stimulus started showing on the screen) as its
        % input
        onsetFunction = [];
        offsetFunction = [];
    end
    
    properties (SetAccess =?neurostim.stimuli.diodeFlasher)
        diodeFlasher = []; 
    end
    
    properties (Dependent)
        off;
        onFrame;
        offFrame;
        time; % Time since start of stimulus.
        frame; % frame since start of stimulus
    end
    
    properties (SetAccess = protected, GetAccess = public)
        flags = struct('on',true);
        stimstart = false;
        stimstop = false;
        rsvp;
        
    end
    % These are local/locked parameters used to speed up access to the
    % values of a neurostim.parameter. Any member variables whose name starts
    % with loc_ retrieve their value from the associated parameter object
    % just after the beforeTrial user code finishes. These values are used
    % in the base stimulus class code. Only neurostim.parameters that can change within
    % a trial are updated before every frame. These parameters are flagged by
    % the changesInTrial flag. All of this happens behind the scenes,
    % without user intervention.
    %
    % By default every parameter that is a neurostim function has
    % changesInTrial set to true.
    % In new stimulus classes, designers can mark a property as
    % 'changesInTrial' in the call to addProperty (for instance if that is
    % a variable that is updated in the beforeFrame/afterFrame code). If
    % the designer forgets, Neurostim will do it (and issue a warning).
    % To set one of the propertieds of a parent class , use
    % setChangesInTrial(stimulus,'X').
    %
    %
    % Most stimulus classes will not need this functionality, but if
    % performance (frame drops) becomes an issue, a user just needs to
    % define loc_XXX members in their stimulus class, given them the same
    % access rights as these properties here, and then use the loc_XXX
    % parameters in the beforeFrame and afterFrame user code to get a boost
    % in performance.
    %
    % neurostim.plugin needs GetAccess and SetAccess because the code that updates the
    % localized variables runs in the plugin parent class.
    % GetAccess should also be given to the class in which these lock
    % parameters are defined {?yourstimulusclass} so that they can be used in the
    % beforeFrame/afterFrame code. We would like to NOT give SetAccess to the class (or derived classes);
    % because assignmnt should always be done to the neurostim.parameter (to ensure
    % logging and persistence across trials). But I cannot think of a way
    % to achieve that in Matlab (stimulus derives from plugin, plugin
    % requires access, so stimlulus will get it too). Setting the Hidden
    % property at least hides these dangerous variables from users who do
    % not need to be aware of them.
    properties (SetAccess= {?neurostim.plugin}, GetAccess={?neurostim.plugin,?neurostim.stimulus},Hidden)
        loc_X
        loc_Y
        loc_Z
        loc_on
        loc_duration
        loc_color
        loc_scale
        loc_angle
        loc_rx
        loc_ry
        loc_rz
        loc_rsvpIsi
        loc_disabled                                
    end
    
    properties (Access=private)
        logOnset=false;
        logOffset=false;
    end
    
    
    
    methods
        
        function v = get.time(o)
            v = o.cic.frames2ms(o.frame);
        end
        
        function v = get.frame(o)
            if o.stimstart
                v = o.cic.frame -o.onFrame;
            else
                v = -inf;
            end
        end
        
        function v= get.off(o)
            v = o.on+o.duration;
        end
        
        function v=get.onFrame(o)
            v = o.cic.ms2frames(o.on,true)+1; % rounded==true
        end
        
        function v=get.offFrame(o)
            if isfinite(o.off)
                v= o.cic.ms2frames(o.on+o.duration,true);
            else
                v=Inf;
            end
        end
        
    end
    
    
    
    methods
        
        function s = stimulus(c,name)
            s = s@neurostim.plugin(c,name);
            
            %% user-settable properties
            s.addProperty('X',0,'validate',@isnumeric);
            s.addProperty('Y',0,'validate',@isnumeric);
            s.addProperty('Z',0,'validate',@isnumeric);
            s.addProperty('on',0,'validate',@isnumeric);
            s.addProperty('duration',Inf,'validate',@isnumeric);
            s.addProperty('color',[1/3 1/3 50],'validate',@isnumeric);
            s.addProperty('scale',[1 1 1]);
            s.addProperty('angle',0,'validate',@isnumeric);
            s.addProperty('rx',0,'validate',@isnumeric);
            s.addProperty('ry',0,'validate',@isnumeric);
            s.addProperty('rz',1,'validate',@isnumeric);
            s.addProperty('rsvpIsi',false,'validate',@islogical); % Logs onset (1) and offset (0) of the RSVP "ISI" . But only if log is set to true in addRSVP.
            s.addProperty('disabled',false);
            
            
            
            %% internally-set properties
            s.addProperty('startTime',Inf);   % first time the stimulus appears on screen
            s.addProperty('stopTime',Inf);   % first time the stimulus does NOT appear after being run
            
            s.rsvp.active= false;
            s.rsvp.design =neurostim.design('dummy');
            s.rsvp.duration = 0;
            s.rsvp.isi =0;
            
            s.feedStyle = '[0 0.75 0]'; % Stimuli show feed messages in light green.
        end
        
    end
    
    methods (Access = public)
        
        function addRSVP(s,design,varargin)
            %           addRSVP(s,design,varargin)
            %
            %           Rapid Serial Visual Presentation
            %           design is a factoral design (See design.m) specifying the parameter(s) to be
            %           manipulated in the stream.
            %
            %           optionalArgs = {'param1',value,'param2',value,...}
            %
            %           Optional parameters [default]:
            %
            %           'duration'  [100]   - duration of each stimulus in the sequence (msec)
            %           'isi'       [0]     - inter-stimulus interval (msec)
            %           'log'       [false] - Log isi start and stop. For rapid changes this can require a lot of memory.
            
            p=inputParser;
            p.addRequired('design',@(x) (isa(x,'neurostim.design')));
            p.addParameter('duration',100,@(x) isnumeric(x) & x > 0);
            p.addParameter('isi',0,@(x) isnumeric(x) & x >= 0);
            p.addParameter('log',false,@islogical);
            p.parse(design,varargin{:});
            flds = fieldnames(p.Results);
            for i=1:numel(flds)
                s.rsvp.(flds{i}) = p.Results.(flds{i});
            end
            
            %Elaborate the factorial design into (sub)condition lists for RSVP
            s.rsvp.design.shuffle;
            s.rsvp.log = p.Results.log;
            s.rsvp.active = true;
        end
        
    end
    
    
    methods (Access=private)
        
        function s = updateRSVP(s)
            % Called from baseBeforeFrame only when the stimulus is on.
            %How many frames for item + blank (ISI)?
            nFramesPerItem = s.cic.ms2frames(s.rsvp.duration+s.rsvp.isi);
            %How many frames since the RSVP stream started?
            rsvpFrame = s.cic.frame-s.onFrame;
            %Which item frame are we in?
            itemFrame = mod(rsvpFrame, nFramesPerItem);
            %If at the start of a new element, move the design to the
            % next "trial"
            if itemFrame==0
                ok = beforeTrial(s.rsvp.design);
                if ~ok
                    % Ran out of "trials"
                    s.rsvp.design.shuffle; % Reshuffle the list
                end
                % Get current specs and apply
                specs = s.rsvp.design.specs;
                for sp=1:size(specs,1)
                    s.(specs{sp,2}) = specs{sp,3};
                end
            end
            
            %Blank now if it's time to do so.
            startIsiFrame = s.cic.ms2frames(s.rsvp.duration);
            s.flags.on = itemFrame < startIsiFrame;  % Blank during rsvp isi
            if s.rsvp.log
                if itemFrame == 0
                    s.rsvpIsi = false;
                elseif itemFrame==startIsiFrame
                    s.rsvpIsi = true;
                end
            end
        end                        
    end % private methods
    
    %% Methods that the user cannot change.
    % These are called by CIC for all stimuli to provide
    % consistent functionality. Note that @stimulus.baseBeforeXXX is always called
    % before @derivedClasss.beforeXXX and baseAfterXXX always before afterXXX. This gives
    % the derived class an oppurtunity to respond to changes that this
    % base functionality makes.
    methods (Access = public)
        
        function baseBeforeExperiment(s)
            % Check whether this stimulus should be displayed on
            % the color overlay in VPIXX-M16 mode.  Done here to
            % avoid the overhead of calling this every draw.
            if any(strcmpi(s.cic.screen.type,{'VPIXX-M16','SOFTWARE-OVERLAY'})) && s.overlay
                s.window = s.cic.overlayWindow;
            else
                s.window = s.cic.mainWindow;
            end
            if s.rsvp.active
                %Check that stimulus durations and ISIs are multiples of the frame interval (defined as within 5% of a frame)
                [dur,rem1] = s.cic.ms2frames(s.rsvp.duration,true);
                [isi,rem2] = s.cic.ms2frames(s.rsvp.isi,true);
                if any(abs([rem1,rem2])>0.05)
                    s.writeToFeed('Requested RSVP duration or ISI is impossible. (non-multiple of frame interval)');
                else
                    %Set to multiple of frame interval
                    s.rsvp.duration = dur*1000/s.cic.screen.frameRate;
                    s.rsvp.isi = isi*1000/s.cic.screen.frameRate;
                end
            end                        
            beforeExperiment(s);
        end
        
        function baseBeforeTrial(s)
            %                     if ~isempty(s.rsvp) TODO different rsvps in different
            %                     conditions
            %                         s.addRSVP(s.rsvp{:})
            %                     end
            if s.rsvp.active
                s.rsvp.design.shuffle; % Reshuffle each trial
            end
            
            %Reset variables here?
            s.startTime = Inf;
            s.stopTime = Inf;
            s.stimstart=false;
            
            beforeTrial(s);
        end
        
        function baseBeforeFrame(s)
            
            if s.loc_disabled; return;end
            
            % Because this function is called for every stimulus, every
            % frame, try to optimize as much as possible by avoiding
            % duplicate access to member properties and by using the localized
            % member variables for dynprops (see loc_X definition and the
            % plugin.localizeParms function).
            locWindow =s.window;
            
            %Should the stimulus be drawn on this frame?
            % This partially duplicates get.onFrame get.offFrame
            % code to minimize computations (and especially dynprop
            % evaluations which can be '@' functions and slow)
            sOffFrame = inf;
            cFrame = s.cic.frame;
            if isinf(s.loc_on)
                s.flags.on =false; %Dont bother checking the rest
            else
                sOnFrame = round(s.loc_on.*s.cic.screen.frameRate/1000)+1;
                %sOnFrame = s.cic.ms2frames(sOn,true)+1; % rounded==true
                if cFrame < sOnFrame % Not on yet.
                    s.flags.on = false;
                else % Is on already or turning on. Checck that we have not
                    % reached full duration yet.
                    sOffFrame = round((s.loc_on+s.loc_duration)*s.cic.screen.frameRate/1000);
                    %sOffFrame = s.cic.ms2frames(sOn+s.duration,true);
                    s.flags.on = cFrame <sOffFrame;
                end
            end
            
            %% RSVP mode
            %   Update parameter values if necesssary
            if s.rsvp.active && s.flags.on
                s=updateRSVP(s);
            end
            
            %%
            
            %If this is the first frame on which the stimulus will NOT be drawn, schedule logging after the pending flip
            if cFrame==sOffFrame
                s.cic.addFlipCallback(s);
                s.logOffset = true;
            end
            
            %If the stimulus should be drawn on this frame:
            if s.flags.on
                %Apply stimulus transform
                if  any([s.loc_X s.loc_Y s.loc_Z]~=0)
                    Screen('glTranslate',locWindow,s.loc_X,s.loc_Y,s.loc_Z);
                end
                if any(s.loc_scale~=1)
                    Screen('glScale',locWindow,s.loc_scale(1),s.loc_scale(2),s.loc_scale(3));
                end
                if  s.loc_angle ~=0
                    Screen('glRotate',locWindow,s.loc_angle,s.loc_rx,s.loc_ry,s.loc_rz);
                end
                
                %If this is the first frame that the stimulus will be drawn, register that it has started.
                if ~s.stimstart
                    s.stimstart = true;
                    s.cic.addFlipCallback(s);
                    s.logOnset = true;
                end
                
                %Pass control to the child class
                beforeFrame(s);
            end
            Screen('glLoadIdentity', locWindow);
                        
            if ~isempty(s.diodeFlasher)
                setStimulusState(s.diodeFlasher,s.flags.on); % Tell the diodeFlasher that the stimulus is on now.                
            end
            
        end
        
        function baseAfterFrame(s)
            ok = ~s.loc_disabled && s.flags.on;
            if ok
                afterFrame(s)
            end
        end
        
        function baseAfterTrial(s)
            if isempty(s.stopTime) || s.offFrame>=s.cic.frame
                s.stopTime=s.cic.trialStopTime-s.cic.firstFrame;
            end
            afterTrial(s);
        end
        
        function baseAfterExperiment(s)
            %NOP
            afterExperiment(s);
        end
        
        function beforeExperiment(~)
            %NOP
        end
        
        function beforeTrial(~)
            %NOP
        end
        
        function beforeFrame(~)
            %NOP
        end
        
        function afterFrame(~)
            %NOP
        end
        
        function afterTrial(~)
            %NOP
        end
        
        function afterExperiment(~)
            %NOP
        end
        
    end % public methods
    
    methods (Access = {?neurostim.cic})
        function afterFlip(s,flipTime,ptbTime)
            % flipTime = time in trial (relative to firstframe)
            % ptbTime =  time in experiment.
            % Both refer to the stimulus onset time estimated by the
            % Screen('Flip') function (either synchronous or asynchronous).
            if s.logOnset
                %DEBUG only: s.writeToFeed([s.name ' on:' num2str(s.cic.frame) '(' num2str(flipTime) ',' num2str(ptbTime) ')'])
                s.startTime = flipTime;
                s.logOnset = false;
                if ~isempty(s.onsetFunction)
                    s.onsetFunction(s,ptbTime);
                end
            elseif s.logOffset
                %DEBUG only: s.writeToFeed([s.name ' off:' num2str(s.cic.frame) '(' num2str(flipTime) ',' num2str(ptbTime) ')'])
                s.stopTime = flipTime;
                s.logOffset = false;
                if ~isempty(s.offsetFunction)
                    s.offsetFunction(s,ptbTime);
                end
            end
        end
    end
    
end % classdef