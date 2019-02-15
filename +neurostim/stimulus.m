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
    %   diode.on,diode.color,diode.location,diode.size - a square box of
    %       specified color in the corner of the screen specified ('nw','sw', etc.),
    %       for use with a photodiode recording.
    %   mccChannel - a linked MCC Channel to output alongside a stimulus.
    %
    %
    
    properties
        % Function to call on onset. Used to communicate event to external hardware. See egiDemo        
        % This function takes a stimulus object and the flipTime (i.e. the
        % time when the stimulus started showing on the screen) as its
        % input
        onsetFunction=[]; 
    end
    
    properties (Dependent)
        off;
        onFrame;
        offFrame;
        time; % Time since start of stimulus.
        frame; % frame since start of stimulus
        
    end
    
    properties (SetAccess=protected, GetAccess=public)
        flags = struct('on',true);
        stimstart = false;
        stimstop = false;
        rsvp;
        diodePosition;
        
    end
    
    properties (Access=private)
        logOnset@logical;
        logOffset@logical;
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
        function s= stimulus(c,name)
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
            
            s.addProperty('diode',struct('on',false,'color',[],'location','sw','size',0.05));
            s.addProperty('mccChannel',[],'validate',@isnumeric);
            s.addProperty('userData',[]);
            
            s.addProperty('alwaysOn',false,'validate',@islogical);
            
            %% internally-set properties
            s.addProperty('startTime',Inf);   % first time the stimulus appears on screen
            s.addProperty('stopTime',Inf);   % first time the stimulus does NOT appear after being run
            
            s.rsvp.active= false;
            s.rsvp.flow =neurostim.flow;
            s.rsvp.duration = 0;
            s.rsvp.isi =0;
            
         
            
            s.feedStyle = '[0 0.75 0]'; % Stimuli show feed messages in light green.
        end
    end
    
    methods (Access= public)
        
        
        
        function addRSVP(s,X,varargin)
            %           addRSVP(s,design,varargin)
            %
            %           Rapid Serial Visual Presentation
            % INPUT 
            % X  =  a factoral design (See design.m) or a flow
            %       (See neurostim.flow) specifying the parameter(s) to be
            %       manipulated in the stream.
            %  Optional parameters [default]:
            %   'duration'  [100]   - duration of each stimulus in the sequence (msec)
            %   'isi'       [0]     - inter-stimulus interval (msec)
            %   'log'       [false] - Log isi start and stop. For rapid changes this can require a lot of memory.
            %
            %   'nrRepeats' [100] -  The number of items to
            %               prepare. This should be big enough for a single
            %               trial (although new ones will be generated if
            %                 needed).
            %   'randomization'  [RANDOMWITHOUTREPLACEMENT]  - see neurostim.flow for options            
            %   'weights'        [1] - weight of each of the conditions in the design/flow.
            %                                   see neurostim.flow for
            %                                   explanation
            p=inputParser;
            p.addParameter('duration',100,@(x) isnumeric(x) & x > 0);
            p.addParameter('isi',0,@(x) isnumeric(x) & x >= 0);
            p.addParameter('log',false,@islogical);
            p.addParameter('randomization','RANDOMWITHOUTREPLACEMENT',@(x)(ischar(x) && ismember(upper(x),{'SEQUENTIAL','RANDOMWITHREPLACEMENT','RANDOMWITHOUTREPLACEMENT','ORDERED','LATINSQUARES'})));
            p.addParameter('weights',1);
            p.addParameter('nrRepeats',100);      
            p.parse(varargin{:});
            
            s.rsvp.duration = p.Results.duration;
            s.rsvp.isi = p.Results.isi;
            s.rsvp.log = p.Results.log;
            
            if isa(X,'neurostim.design')
                % Wrap it with a flow
                s.rsvp.flow = neurostim.flow(s.cic,'randomization',p.Results.randomization,'weights',p.Results.weights,'nrRepeats',p.Results.nrRepeats);
                s.rsvp.flow.addTrials(X);
             else % it is a flow
                s.rsvp.flow =X;
                % Only set those parms that were explicitly set. (to avoid
                % changing something the user set in the flow that was
                % passed)
                flds = {'randomization','weights','nrRepeats'};
                for f=1:numel(flds)
                    if ~ismember(flds{f},p.UsingDefaults)
                        s.rsvp.flow.(flds{f}) = p.Results.(flds{f});
                    end
                end
            end
            
               
            %Initialize the flow tree for RSVP
            s.rsvp.flow.shuffle(true); % 
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
                beforeRSVP(s.rsvp.flow);
                % Get current specs and apply
%                 specs = s.rsvp.design.specs;
%                 for sp=1:size(specs,1)
%                     s.(specs{sp,2}) = specs{sp,3};
%                 end
                nextRSVP(s.rsvp.flow); % Ger ready for next
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
        
        function setupDiode(s)
            pixelsize=s.diode.size*s.cic.screen.xpixels;
            if isempty(s.diode.color)
                s.diode.color=WhiteIndex(s.window);
            end
            switch lower(s.diode.location)
                case 'ne'
                    s.diodePosition=[s.cic.screen.xpixels-pixelsize 0 s.cic.screen.xpixels pixelsize];
                case 'se'
                    s.diodePosition=[s.cic.screen.xpixels-pixelsize s.cic.screen.ypixels-pixelsize s.cic.screen.xpixels s.cic.screen.ypixels];
                case 'sw'
                    s.diodePosition=[0 s.cic.screen.ypixels-pixelsize pixelsize s.cic.screen.ypixels];
                case 'nw'
                    s.diodePosition=[0 0 pixelsize pixelsize];
                otherwise
                    error(['Diode Location ' s.diode.location ' not supported.'])
            end
        end
        
    end
    
    %% Methods that the user cannot change.
    % These are called by CIC for all stimuli to provide
    % consistent functionality. Note that @stimulus.baseBeforeXXX is always called
    % before @derivedClasss.beforeXXX and baseAfterXXX always before afterXXX. This gives
    % the derived class an oppurtunity to respond to changes that this
    % base functionality makes.
    methods (Access=public)
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
            
            if s.diode.on
                setupDiode(s);
            end
            if ~isempty(s.mccChannel) && any(strcmp(s.cic.plugins,'mcc'))
                s.cic.mcc.map(s,'DIGITAL',s.mccChannel,s.on,'FIRSTFRAME')
            end
            beforeExperiment(s);
        end
        
        
        function baseBeforeTrial(s)
            %                     if ~isempty(s.rsvp) TODO different rsvps in different
            %                     conditions
            %                         s.addRSVP(s.rsvp{:})
            %                     end
            if s.rsvp.active
                s.rsvp.flow.shuffle(true); % Reshuffle each trial
            end
            
            %Reset variables here?
            s.startTime = Inf;
            s.stopTime = Inf;
            s.stimstart=false;
            
            beforeTrial(s);
            
        end
        function baseBeforeFrame(s)
            if s.disabled; return;end
            % Because this function is called for every stimulus, every
            % frame, try to optimize as much as possible by avoiding
            % duplicate access to member properties and dynprops in
            % particular
            locWindow =s.window;
            
            %Should the stimulus be drawn on this frame?
            % This partially duplicates get.onFrame get.offFrame
            % code to minimize computations (and especially dynprop
            % evaluations which can be '@' functions and slow)           
            sOffFrame = inf;                
            cFrame = s.cic.frame;
            if s.alwaysOn
                s.flags.on =true;
            else   
                sOn = +s.on;          
                if isinf(sOn)
                    s.flags.on =false; %Dont bother checking the rest
                else
                    sOnFrame = round(sOn.*s.cic.screen.frameRate/1000)+1;
                    %sOnFrame = s.cic.ms2frames(sOn,true)+1; % rounded==true
                    if cFrame < sOnFrame % Not on yet.
                        s.flags.on = false;
                    else % Is on already or turning on. Checck that we have not
                        % reached full duration yet.
                        sOffFrame = round((sOn+s.duration)*s.cic.screen.frameRate/1000);
                        %sOffFrame = s.cic.ms2frames(sOn+s.duration,true);
                        s.flags.on = cFrame <sOffFrame;
                    end
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
                sX =+s.X;sY=+s.Y;sZ=+s.Z; % USe + operator to force the use of values if s.X is an adaptive parameter.
                if  any([sX sY sZ]~=0)
                    Screen('glTranslate',locWindow,sX,sY,sZ);
                end
                sScale = +s.scale;
                if any(sScale~=1)
                    Screen('glScale',locWindow,sScale(1),sScale(2),sScale(3));
                end
                sAngle= +s.angle;
                if  sAngle ~=0
                    Screen('glRotate',locWindow,sAngle,+s.rx,+s.ry,+s.rz);
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
            
            % diode size/position is in pixels and we don't really want it
            % changing even if we change the physical screen size (e.g., 
            % when changing viewing distance) or being distorted by the
            % transforms above...
            if s.diode.on  && s.flags.on 
                Screen('FillRect',locWindow,+s.diode.color,+s.diodePosition);                
            end
            
        end

        function baseAfterFrame(s)
            
            ok = ~s.disabled && s.flags.on;
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
        
        
    end
    
    methods (Access = {?neurostim.cic})
        function afterFlip(s,flipTime,ptbTime)
            if s.logOnset
                s.startTime = flipTime;
                s.logOnset = false;
                if ~isempty(s.onsetFunction)
                    s.onsetFunction(s,ptbTime);
                end
            elseif s.logOffset
                s.stopTime = flipTime;
                s.logOffset = false;
            end
        end
    end
end