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
    
    properties (SetAccess = public,GetAccess=public)
        quest@struct;
        subConditions;
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
    end
    
    properties (Access=protected)
        stimstart = false;
        stimstop = false;
        prevOn@logical;
        rsvp;

        diodePosition;
    end
    
    methods
        
        function v= get.off(o)
            v = o.on+o.duration;
        end
        function v=get.onFrame(s)
            on=s.on;
            if on==0
                v=1;
            else
                v = s.cic.ms2frames(on)+1;
            end
        end
        
        function v=get.offFrame(s)

            if s.off==Inf
                v=Inf;
            else
                v=s.onFrame+s.cic.ms2frames(s.duration);
            end
        end
    end
    
    
    methods
        function s= stimulus(c,name)
            s = s@neurostim.plugin(c,name);
            %% user-settable properties
            s.addProperty('X',0,[],@isnumeric);
            s.addProperty('Y',0,[],@isnumeric);
            s.addProperty('Z',0,[],@isnumeric);  
            s.addProperty('on',0,[],@isnumeric);  
            s.addProperty('duration',Inf,[],@isnumeric);  
            s.addProperty('color',[1/3 1/3 50],[],@isnumeric);
            s.addProperty('alpha',1,[],@(x)x<=1&&x>=0);
            s.addProperty('scale',struct('x',1,'y',1,'z',1));
            s.addProperty('angle',0,[],@isnumeric);
            s.addProperty('rx',0,[],@isnumeric);
            s.addProperty('ry',0,[],@isnumeric);
            s.addProperty('rz',1,[],@isnumeric);
        %    s.addProperty('rsvp',{},[],@(x)iscell(x)||isempty(x));
            s.addProperty('rngSeed',[],[],@isnumeric);
            s.listenToEvent({'BEFORETRIAL','AFTERTRIAL','BEFOREEXPERIMENT'});
            s.addProperty('diode',struct('on',false,'color',[],'location','sw','size',0.05));
            s.addProperty('mccChannel',[],[],@isnumeric);
            
            %% internally-set properties
            s.addProperty('startTime',Inf,[],[],{'neurostim.stimulus'},'public');   % first time the stimulus appears on screen
            s.addProperty('stopTime',Inf,[],[],{'neurostim.stimulus'},'public');   % first time the stimulus does not appear after being run
            s.addProperty('isi',[],[],@isnumeric,{'neurostim.stimulus'});
        %    s.addProperty('subCond',[],[],[],{'neurostim.stimulus'},{'neurostim.plugin'});
            
        
        
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
%           maniupulated in the stream.
%
%           optionalArgs = {'param1',value,'param2',value,...}
%         
%           Optional parameters [default]:
%
%           'duration'  [100]   - duration of each stimulus in the sequence
%           'isi'       [0]     - inter-stimulus interval
          
            p=inputParser;
            p.addRequired('design',@(x) (isa(x,'neurostim.factorial')));            
            p.addParameter('duration',100,@(x) isnumeric(x) & x > 0);
            p.addParameter('isi',0,@(x) isnumeric(x) & x >= 0);
            
            p.parse(design,varargin{:});
            flds = fieldnames(p.Results);
            for i=1:numel(flds)
                s.rsvp.(flds{i}) = p.Results.(flds{i});
            end            
            setupExperiment(s.rsvp.design);
            s.rsvp.active = true;           
            
        end
           
           
           
    end
        
    %% Methods that the user cannot change. 
    % These are called from by CIC for all stimuli to provide 
    % consistent functionality. Note that @stimulus.baseBeforeXXX is always called
    % before @derivedClasss.beforeXXX and baseAfterXXX always before afterXXX. This gives
    % the derived class an oppurtunity to respond to changes that this 
    % base functionality makes.
    methods (Access=private) 
                       
        
        
        function setupDiode(s)
            pixelsize=s.diode.size*s.cic.screen.xpixels;
            if isempty(s.diode.color)
                s.diode.color=WhiteIndex(s.cic.onscreenWindow);
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
    
    methods (Access=public)
        
        function baseEvents(s,c,evt)
            switch evt.EventName
                case 'BASEBEFOREFRAME'
                    
                    glScreenSetup(c,c.window);
                    %Apply stimulus transform
                    Screen('glTranslate',c.window,s.X,s.Y,s.Z);
                    Screen('glScale',c.window,s.scale.x,s.scale.y);
                    Screen('glRotate',c.window,s.angle,s.rx,s.ry,s.rz);
                    
                    
                    s.flags.on = c.frame>=s.onFrame && c.frame <s.offFrame;

                    
                    %% RSVP
                    if s.rsvp.active 
                        rsvpFrame = c.frame/c.ms2frames(s.rsvp.duration+s.rsvp.isi);
                        item = floor(rsvpFrame); % This element of the rsvp list should be shown now (base-0)
                        frac = rsvpFrame-item;   % We are this far into the current rsvp item.                                              
                        if rsvpFrame==item % Last element
                            % Wrap
                            s.rsvp.design.reshuffle;
                        end
                        if frac==0 % Start of a new element
                            specs = s.rsvp.design.conditions(s.rsvp.design.list(mod(item,s.rsvp.design.nrConditions)+1));
                            for g=1:3:numel(specs)
                             s.(specs{g+1}) = specs{g+2};
                            end
                        end
                        s.flags.on = s.flags.on && frac < s.rsvp.duration/(s.rsvp.isi+s.rsvp.duration);  % Blank during rsvp isi
                    end
                    
                    % get the stimulus end time
                    if s.prevOn
                        s.stopTime=c.flipTime;
                        s.prevOn=false;
                    end
                    
                    
                    %%
                    if c.frame==s.offFrame                        
                        s.prevOn=true;
                    end
                    
                    if s.flags.on 
                        if c.frame==s.onFrame+1 % get stimulus on time
                            s.startTime = c.flipTime;
                        end
                        notify(s,'BEFOREFRAME');
                        if s.stimstart ~= true
                            s.stimstart = true;
                        end
                        if c.frame==s.onFrame
                            c.getFlipTime=true; % get the next flip time for startTime
                        end
                    elseif s.stimstart && (c.frame==s.offFrame)% if the stimulus will not be shown, 
                        % get the next screen flip for stopTime
                        c.getFlipTime=true;
                        s.stimstart=false;
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
                    
                    notify(s,'BEFORETRIAL');

                case 'BASEAFTERTRIAL'
                    if isempty(s.stopTime) || s.offFrame>=c.frame
                        s.stopTime=c.trialStopTime-c.trialStartTime;
                        s.prevOn=false;
                    end
                    notify(s,'AFTERTRIAL');

                case 'BASEBEFOREEXPERIMENT'
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