classdef stimulus < neurostim.plugin
    % Base class for stimuli in PTB.
    %
    % Adjustable variables:
    %   X,Y,Z - position of stimulus
    %   on - time the stimulus should come 'on' (ms) from start of trial
    %   duration - length of time the stimulus should be 'on' (ms)
    %   color - color of the stimulus
    %   alpha - alpha blend of the stimulus.
    %   scale.x,scale.y,scale.z - scale of the stimulus along various axes
    %   angle - angle of the stimulus
    %   rx, ry, rz - rotation of the stimulus
    %   rsvp - RSVP conditions of the stimulus (see addRSVP() for more input
    %       details)
    %   rngSeed - seed of the RNG.
    %   diode.on,diode.color,diode.location,diode.size - a square box of
    %       specified color in the corner of the screen specified ('nw','sw', etc.),
    %   for use with a photodiode recording.
    %   mccChannel - a linked MCC Channel to output alongside a stimulus.
    %
    %
    %TODO: Should we have a small class for storing durations in both
    %frames and msec in a dependent way? used for "on", 
    
    properties (SetAccess = public,GetAccess=public)
        quest@struct;
    end
    properties (SetAccess=private,GetAccess=public)
        beforeFrameListenerHandle =[];
        afterFrameListenerHandle =[];
    end
    properties
        flags = struct('on',true);
    end
    properties (Dependent)
        off;
        onFrame;
        offFrame;
        time; % Time since start of stimulus.
        frame; % frame since start of stimulus
    end
    
    properties (Access=protected)
        stimstart = false;
        stimstop = false;
        logOffset@logical;
        rsvp;
        diodePosition;
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
            s.addProperty('alpha',1,'validate',@(x)x<=1&&x>=0);
            s.addProperty('scale',struct('x',1,'y',1,'z',1));
            s.addProperty('angle',0,'validate',@isnumeric);
            s.addProperty('rx',0,'validate',@isnumeric);
            s.addProperty('ry',0,'validate',@isnumeric);
            s.addProperty('rz',1,'validate',@isnumeric);
            
            s.addProperty('rngSeed',[],'validate',@isnumeric);
            s.listenToEvent({'BEFORETRIAL','AFTERTRIAL','BEFOREEXPERIMENT'});
            s.addProperty('diode',struct('on',false,'color',[],'location','sw','size',0.05));
            s.addProperty('mccChannel',[],'validate',@isnumeric);
            s.addProperty('userData',[]);
            
            %% internally-set properties
            s.addProperty('startTime',Inf,'SetAccess','protected');   % first time the stimulus appears on screen
            s.addProperty('stopTime',Inf,'SetAccess','protected');   % first time the stimulus does NOT appear after being run
      
            s.rsvp.active= false;
            s.rsvp.design =neurostim.factorial('dummy',1);
            s.rsvp.duration = 0;
            s.rsvp.isi =0;
            
            s.rngSeed=GetSecs;
            rng(s.rngSeed);
        end
        
        % Setup threshold estimation for one of the parameters. The user
        % has to call answer(s,true/false) to update the adaptive estimation
        % procedure. One estimator will be created for each condition so
        % this function should only be called after calls to addFactorial
        % and addCondition.
        function setupThresholdEstimation(s,prop,method,varargin)
            
            if s.cic.nrConditions ==0
                error('Experimental design should be completed before calling threshold');
            end
            % Measure threshold for a certain parm.
            % Interpret the input. Defaults are set as recommended for
            % QUEST. See Quest and Quest Create
            p = inputParser;
            p.addParameter('guess',-1);   % Log Contrast for QUEST
            p.addParameter('guessSD',2);  %
            p.addParameter('threshold',0.82); %Target threshold
            p.addParameter('beta',3.5); % Steepness of assumed Weibull
            p.addParameter('delta',0.01); % Fraction of blind presses
            p.addParameter('gamma',0.5); % Fraction of trials that will generate response when for intensity = -inf.
            p.addParameter('grain',0.01); % Discretization of the range
            p.addParameter('range',5); % Range centered on guess.
            p.addParameter('plotIt',false);
            p.addParameter('normalizePdf',1);
            p.parse(varargin{:});
            switch upper(method)
                case 'QUEST'
                    if p.Results.guess>0
                        warning('Contrast above 1? I dont think that will work');
                    end
                    q =QuestCreate(p.Results.guess,p.Results.guessSD,p.Results.threshold,p.Results.beta,p.Results.delta,p.Results.gamma,p.Results.grain,p.Results.range,p.Results.plotIt);
                    s.quest =struct('q', repmat(q,[1 s.cic.nrConditions]),'prop',prop);
                otherwise
                    error('NIY');
            end
            % Install a PreGet event listener to update the dynamic
            % property for this parameter just before it is returned to the
            % caller.
            h= findprop(s,prop);
            if isempty(h)
                error(['There is no  ' prop ' parameter in ' s.name '. Please add it before defining a threshold estimation procedure']);
            end
            h.GetObservable = true;
            h.SetObservable = false;
            s.addlistener(prop,'PreGet',@(src,evt)updateAdaptive(s,src,evt));
        end
        
        % Clients should call this to inform the adaptive method whether
        % the answer (in response to the current intensity) was correct or
        % not.
        function answer(s,correct)
            if ~islogical(correct)
                %     error('The answer can only be correct or incorrect');
            end
            s.quest.q(s.cic.condition) =QuestUpdate(s.quest.q(s.cic.condition),s.(s.quest.prop),correct); % Add the new datum .
        end
        
        % This is called before returning the current value for the
        % adaptive method. Basically the function retrieves teh current
        % proposed intensity from the adaptive method and places it in the
        % dynamic property.
        function updateAdaptive(s,src,~)
            c = s.cic.condition;
            if ~isnan(c)
                s.(src.Name) = QuestQuantile(s.quest.q(s.cic.condition));
                %disp (['Qest:' num2str(s.(src.Name)) ])
            end
        end
        
        function [m,sd]= threshold(s)
            % Return the estimated thresholds for all conditions
            if isempty(s.quest)
                m= [] ;
            else
                m =QuestMean(s.quest.q);
                sd = QuestSd(s.quest.q);
            end
        end      
    end
    
    methods (Access= public)
        function beforeTrial(s,c,evt)
            % to be overloaded in subclasses; necessary for baseBeforeTrial
            % (RSVP re-check)
        end
        
        function afterTrial(s,c,evt)
            % to be overloaded in subclasses; needed for baseAfterTrial
            % (stimulus stopTime check)
        end
        
        function beforeExperiment(s,c,evt)
            % to be overloaded in subclasses; needed for baseBeforeExperiment
            % (stimulus stopTime check)
        end
        
        
        function addRSVP(s,design,varargin)
            %           addRSVP(s,design,varargin)
            %
            %           Rapid Serial Visual Presentation
            %           design is a factoral design (See factorial.m) specifying the parameter(s) to be
            %           manipulated in the stream.
            %
            %           optionalArgs = {'param1',value,'param2',value,...}
            %
            %           Optional parameters [default]:
            %
            %           'duration'  [100]   - duration of each stimulus in the sequence (msec)
            %           'isi'       [0]     - inter-stimulus interval (msec)
            
            p=inputParser;
            p.addRequired('design',@(x) (isa(x,'neurostim.factorial')));
            p.addParameter('duration',100,@(x) isnumeric(x) & x > 0);
            p.addParameter('isi',0,@(x) isnumeric(x) & x >= 0);           
            p.parse(design,varargin{:});
            flds = fieldnames(p.Results);
            for i=1:numel(flds)
                s.rsvp.(flds{i}) = p.Results.(flds{i});
            end
            
            %Elaborate the factorial design into (sub)condition lists for RSVP
            setupExperiment(s.rsvp.design);
            s.rsvp.active = true;    
        end        
    end
    

    methods (Access=private)
        
        function s = updateRSVP(s,c)
            
            %How many frames for item + blank (ISI)?
            nFramesPerItem = c.ms2frames(s.rsvp.duration+s.rsvp.isi);
            
            %How many frames since the RSVP stream started?
            rsvpFrame = c.frame-s.onFrame;
            
            %Which item in the sequence are we up to?
            itemNum = floor(rsvpFrame./nFramesPerItem);
            
            %Which item frame are we in?
            itemFrame = mod(rsvpFrame, nFramesPerItem);
            
            %If at the start of a new element, update param values
            if itemFrame==0
                curCondInd = mod(itemNum,s.rsvp.design.nrConditions)+1;
                specs = s.rsvp.design.conditions(s.rsvp.design.list(curCondInd));
                for g=1:3:numel(specs)
                    s.(specs{g+1}) = specs{g+2};
                end
            end
            
            %Blank now if it's time to do so.
            s.flags.on = itemFrame < c.ms2frames(s.rsvp.duration);  % Blank during rsvp isi
            
            %If this item is the last condition in the factorial, reshuffle conditions
            if itemNum==s.rsvp.design.nrConditions-1
                s.rsvp.design.reshuffle;
            end
        end
        
        function setupDiode(s)
            pixelsize=s.diode.size*s.cic.screen.xpixels;
            if isempty(s.diode.color)
                s.diode.color=WhiteIndex(s.cic.window);
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
        
        function baseEvents(s,c,evt)
            switch evt.EventName
                case 'BASEBEFOREFRAME'
                    
                    glScreenSetup(c,c.window);
                    
                    %Apply stimulus transform
                    if  any([s.X s.Y s.Z]~=0)
                        Screen('glTranslate',c.window,s.X,s.Y,s.Z);
                    end
                    if any([s.scale.x s.scale.y] ~=1)
                        Screen('glScale',c.window,s.scale.x,s.scale.y);
                    end
                    if  s.angle ~=0
                        Screen('glRotate',c.window,s.angle,s.rx,s.ry,s.rz);
                    end 
                    
                    %Should the stimulus be drawn on this frame?
                    s.flags.on = c.frame>=s.onFrame && c.frame <s.offFrame;
                    
                    %% RSVP mode
                    %   Update parameter values if necesssary
                    if s.rsvp.active && s.flags.on
                        s=updateRSVP(s,c);
                    end
                    
                    %%
                    % get the stimulus end time
                    if s.logOffset
                        s.stopTime=c.flipTime;
                        s.logOffset=false;
                    end
                    
                    %If this is the first frame on which the stimulus will NOT be drawn, schedule logging after the pending flip
                    if c.frame==s.offFrame
                        s.logOffset=true;
                    end
                   
                    %If the stimulus should be drawn on this frame:
                    if s.flags.on
                        %If this is the first frame that the stimulus will be drawn, register that it has started.
                        if ~s.stimstart
                            s.stimstart = true;
                            c.getFlipTime=true; % tell CIC to store the next flip time, to log startTime in next frame
                        end
                        
                        %If the previous frame was the first frame, log the time that the flip aactually happened.
                        if c.frame==s.onFrame+1
                            s.startTime = c.flipTime;
                        end
                        
                        %Pass control to the child class and any other listeners
                        notify(s,'BEFOREFRAME');
                        
                    elseif s.stimstart && (c.frame==s.offFrame)% if the stimulus will not be shown,
                        % get the next screen flip for stopTime
                        c.getFlipTime=true;
                    end
                    Screen('glLoadIdentity', c.window);
                    if s.diode.on && s.flags.on
                        Screen('FillRect',c.window,s.diode.color,s.diodePosition);
                    end
                case 'BASEAFTERFRAME'
                    if s.flags.on
                        notify(s,'AFTERFRAME');
                    end
                case 'BASEBEFORETRIAL'
                    %                     if ~isempty(s.rsvp) TODO different rsvps in different
                    %                     conditions
                    %                         s.addRSVP(s.rsvp{:})
                    %                     end
                    if s.rsvp.active
                        s.rsvp.design.reshuffle; % Reshuffle each trial
                    end
                    
                    %Reset variables here?
                    s.startTime = Inf;
                    s.stopTime = Inf;
                    s.stimstart=false;
                    
                    notify(s,'BEFORETRIAL');
                    
                case 'BASEAFTERTRIAL'
                    if isempty(s.stopTime) || s.offFrame>=c.frame
                        s.stopTime=c.trialStopTime-c.trialStartTime;
                        s.logOffset=false;
                    end
                    notify(s,'AFTERTRIAL');
                    
                case 'BASEBEFOREEXPERIMENT'
                    if s.rsvp.active
                        %Check that stimulus durations and ISIs are multiples of the frame interval (defined as within 5% of a frame)
                        [dur,rem1] = c.ms2frames(s.rsvp.duration,true);
                        [isi,rem2] = c.ms2frames(s.rsvp.isi,true);
                        if any(abs([rem1,rem2])>0.05)
                            s.writeToFeed('Requested RSVP duration or ISI is impossible. (non-multiple of frame interval)');
                        else
                            %Set to multiple of frame interval
                            s.rsvp.duration = dur*1000/c.screen.frameRate;
                            s.rsvp.isi = isi*1000/c.screen.frameRate;
                        end
                    end
                    if s.diode.on
                        setupDiode(s);
                    end
                    if ~isempty(s.mccChannel) && any(strcmp(s.cic.plugins,'mcc'))
                        s.cic.mcc.map(s,'DIGITAL',s.mccChannel,s.on,'FIRSTFRAME')
                    end
                    notify(s,'BEFOREEXPERIMENT');
                    
                case 'BASEAFTEREXPERIMENT'
                    notify(s,'AFTEREXPERIMENT');     
            end
        end
    end
end