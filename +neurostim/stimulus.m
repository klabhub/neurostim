classdef stimulus < neurostim.plugin
%     events
%         BEFOREFRAME;
%         AFTERFRAME;    
%         BEFORETRIAL;
%         AFTERTRIAL;    
%         BEFOREEXPERIMENT;
%         AFTEREXPERIMENT;        
%     end
    
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
    
    properties (Access=private)
        stimstart = false;
        stimstop = false;
        prevOn@logical = false;
        stimNum = 1;
        rsvpStimProp;
        rsvpParms;
        rsvpList;
    end
    
    methods
        
        function v= get.off(o)
            v = o.on+o.duration;
        end
        function v=get.onFrame(s)
            if numel(s.on)>1
                if s.stimNum< numel(s.on)
                v = round(s.on{s.stimNum}*s.cic.screen.framerate/1000);
                elseif s.stimNum==numel(s.on)
                    v=round(s.on{end}*s.cic.screen.framerate/1000);
                else
                    v=0;
                end
            else
                v = round(s.on*s.cic.screen.framerate/1000);
            end
        end
        function v=get.offFrame(s)
            if numel(s.duration)>1
                if s.stimNum< numel(s.duration)
                    v = s.onFrame+round(s.duration{s.stimNum}*s.cic.screen.framerate/1000);
                elseif s.stimNum==numel(s.duration)
                    v=s.onFrame+round(s.duration{end}*s.cic.screen.framerate/1000);
                end
            else
                v=s.onFrame+round(s.duration*s.cic.screen.framerate/1000);
            end
        end
    end
    
    
    methods
        function s= stimulus(name)
            s = s@neurostim.plugin(name);
            s.addProperty('X',0,[],@isnumeric);
            s.addProperty('Y',0,[],@isnumeric);
            s.addProperty('Z',0,[],@isnumeric);  
            s.addProperty('on',0,[],@(x) isnumeric(x) || iscell(x));  
            s.addProperty('duration',Inf,[],@(x) isnumeric(x) || iscell(x));  
            s.addProperty('color',[1/3 1/3],[],@isnumeric);
            s.addProperty('luminance',50,[],@isnumeric);
            s.addProperty('alpha',1,[],@(x)x<=1&&x>=0);
            s.addProperty('scale',struct('x',1,'y',1,'z',1));
            s.addProperty('angle',0,[],@isnumeric);
            s.addProperty('rx',0,[],@isnumeric);
            s.addProperty('ry',0,[],@isnumeric);
            s.addProperty('rz',1,[],@isnumeric);
            s.addProperty('startTime',Inf);   % first time the stimulus appears on screen
            s.addProperty('endTime',0);   % first time the stimulus does not appear after being run
            s.addProperty('rsvp',{},[],@(x)iscell(x)||isempty(x));
            s.addProperty('subCond',[]);
            s.listenToEvent({'BEFORETRIAL','AFTERTRIAL'});
        
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
               % (stimulus endTime check)
           end
    end
        
    %% Methods that the user cannot change. 
    % These are called from by CIC for all stimuli to provide 
    % consistent functionality. Note that @stimulus.baseBeforeXXX is always called
    % before @derivedClasss.beforeXXX and baseAfterXXX always before afterXXX. This gives
    % the derived class an oppurtunity to respond to changes that this 
    % base functionality makes.
    methods (Access=public) 
        
        function addRSVP(s,rsvpFactorial,optionalArgs)
%           addRSVP(s,rsvpFactorial,[optionalArgs])
%
%           Rapid Serial Visual Presentation
%           rsvpFactorial is a cell specifying the parameter(s) to be maniupulated in the stream
%           The format of rsvpFactorial is the same as for c.addFactorial.
%
%           optionalArgs = {'param1',value,'param2',value,...}
%         
%           Optional parameters [default]:
%
%           'duration'  [100]   - duration of each stimulus in the sequence
%           'isi'       [0]     - inter-stimulus interval
%           'randomization' ['RANDOMWITHREPLACEMENT'] - ordering of stimuli

            p=inputParser;
            p.addRequired('rsvpFactorial',@(x) iscell(x));
            p.addParameter('duration',100,@(x) isnumeric(x) & x > 0);
            p.addParameter('isi',0,@(x) isnumeric(x) & x >= 0);
            p.addParameter('randomization','RANDOMWITHOUTREPLACEMENT',@(x) any(strcmpi(x,{'RANDOMWITHOUTREPLACEMENT', 'RANDOMWITHREPLACEMENT','SEQUENTIAL'})));
            p.parse(rsvpFactorial,optionalArgs{:});
            duration = p.Results.duration;
            isi = p.Results.isi;
            randomization = p.Results.randomization;
            
            % extract all informations
            s.rsvpStimProp = rsvpFactorial{1};
            s.rsvpParms = rsvpFactorial{2};
            
            if s.duration <s.cic.trialDuration %if stimulus duration is not infinite
                if numel(s.on)>1
                    stimEndDur=s.on{end}+s.duration;
                else
                    stimEndDur = s.duration;
                end
            else stimEndDur=s.cic.trialDuration; % otherwise, set to trial duration
            end
            % set the stimulus on and duration times
            if numel(s.on)==1
                s.on = num2cell(s.on:(duration+isi):stimEndDur);
            else
                s.on = num2cell(s.on{1}:(duration+isi):stimEndDur);
            end
            s.duration = duration;
            % calculate on which frames the parameters should be set
            frames = round(cell2mat(s.on)*s.cic.screen.framerate/1000);
            
            s.subConditions = 1:numel(s.rsvpParms);
            

            nrRepeats = ceil(numel(frames)/numel(s.subConditions));

            switch upper(randomization)
                case 'SEQUENTIAL' % repeats sequentially
                    s.rsvpList = repmat(s.subConditions,[1,nrRepeats]);
                case 'RANDOMWITHREPLACEMENT' % repeats randomly (with replacement)
                    s.rsvpList = datasample(s.subConditions,(numel(s.subConditions)*nrRepeats));
                case 'RANDOMWITHOUTREPLACEMENT' % repeats randomly (without replacement)
                    s.rsvpList = repmat(s.subConditions,[1 nrRepeats]);
                    s.rsvpList = s.rsvpList(randperm(numel(s.rsvpList)));
            end
        end
        
        
        function baseEvents(s,c,evt)
            switch evt.EventName
                case 'BASEBEFOREFRAME'
                    
                    glScreenSetup(c);
                    
                    %Apply stimulus transform
                    Screen('glTranslate',c.window,s.X,s.Y,s.Z);
                    Screen('glScale',c.window,s.scale.x,s.scale.y);
                    Screen('glRotate',c.window,s.angle,s.rx,s.ry,s.rz);
                    
                    if c.frame==1
                        s.stimNum=1;
                        if ~isempty(s.rsvp)
                            s.subCond = s.rsvpList(s.stimNum);
                            s.(s.rsvpStimProp) = s.rsvpParms{s.subCond};
                        end
                    end
                    

                    % get the stimulus end time
                    if c.frame==s.offFrame+2
                        s.endTime=c.flipTime;
                        
                        s.stimNum = s.stimNum+1;
                        if ~isempty(s.rsvp)
                            if s.stimNum<=numel(s.rsvpList)
                                s.subCond = s.rsvpList(s.stimNum);
                                s.(s.rsvpStimProp) = s.rsvpParms{s.subCond};
                            else
                                s.stimNum=1;
                            end
                        end
                    end


                    s.flags.on = c.frame >s.onFrame && c.frame < s.offFrame;
                    if s.flags.on 
                        if c.frame==s.onFrame+2 % get stimulus on time
                            s.startTime = c.flipTime;
                        end
                        notify(s,'BEFOREFRAME');
                        if s.stimstart ~= true
                        s.stimstart = true;
                        c.getFlipTime=true; % get the next flip time for startTime
                        end
                    elseif s.stimstart && (c.frame==s.offFrame+1)% if the stimulus will not be shown, 
                        % get the next screen flip for endTime
                        c.getFlipTime=true;
                        s.stimstart=false;
                    end
                    Screen('glLoadIdentity', c.window);
                case 'BASEAFTERFRAME'
                    if s.flags.on 
                        notify(s,'AFTERFRAME');
                    end
                case 'BASEBEFORETRIAL'
                    if ~isempty(s.rsvp)
                        s.addRSVP(s.rsvp{:})
                    end

                    notify(s,'BEFORETRIAL');

                case 'BASEAFTERTRIAL'
                    if s.endTime<c.trialStartTime(c.trial)
                        s.endTime=c.trialEndTime(c.trial);
                    end
                    notify(s,'AFTERTRIAL');

                case 'BASEBEFOREEXPERIMENT'
                    notify(s,'BEFOREEXPERIMENT');

                case 'BASEAFTEREXPERIMENT'    
                    notify(s,'AFTEREXPERIMENT');

            end
        end        
    end
end