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
        RSVPStimProp;
        RSVPParms;
        RSVPList;
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
            s.addProperty('endTime',Inf);   % first time the stimulus does not appear after being run
            s.addProperty('RSVP',{},[],@(x)iscell(x)||isempty(x));
            s.addProperty('currSubCond',[]);
            s.listenToEvent({'BEFORETRIAL'});
        
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
            % to be overloaded in subclasses; necessary for BaseBeforeTrial
            % 
        end
    end
        
    %% Methods that the user cannot change. 
    % These are called from by CIC for all stimuli to provide 
    % consistent functionality. Note that @stimulus.baseBeforeXXX is always called
    % before @derivedClasss.beforeXXX and baseAfterXXX always before afterXXX. This gives
    % the derived class an oppurtunity to respond to changes that this 
    % base functionality makes.
    methods (Sealed) 
        
        function addRSVP(s,isi,duration,varargin)
            % addRSVP(s,isi,duration,RSVP [,repetitions] [,randomization])
            % add a Rapid Serial Visual Presentation
            % Inputs:
            % name - name of the RSVP
            % ISI - inter-stimulus-interval (ms)
            % duration - RSVP stimulus duration (ms)
            % RSVP contains:
            % stimulusProperty - property of the stimulus to change each RSVP
            % parameters - cell array of parameters
            % 
            % Optional Inputs:
            % repetitions - number of repetitions (default: until stimulus end-duration)
            % randomization - type of randomization (default: sequential)
               RSVPSpecs = varargin{1,1};
               % extract all information
               s.RSVPStimProp = RSVPSpecs{1};
               s.RSVPParms = RSVPSpecs{2};
               
               if numel(RSVPSpecs)>3
                   randomization = RSVPSpecs{4};
               else
                   randomization = 'SEQUENTIAL';
               end
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
               

               
               s.subConditions = 1:numel(s.RSVPParms);
               
               if numel(RSVPSpecs)>2
                   nrRepeats=RSVPSpecs{3};
               else nrRepeats = ceil(numel(frames)/numel(s.subConditions));
               end
               
               if nrRepeats>1 %if parameters need expansion
                   switch upper(randomization)
                       case 'SEQUENTIAL'
                           s.RSVPList = repmat(s.subConditions,[1,nrRepeats]);
                       case 'RANDOMWITHREPLACEMENT'
                           s.RSVPList = datasample(s.subConditions,(numel(s.subConditions)*nrRepeats));
                       case 'RANDOMWITHOUTREPLACEMENT'
                           s.RSVPList = repmat(s.subConditions,[1 nrRepeats]);
                           s.RSVPList = s.RSVPList(randperm(numel(s.RSVPList)));
                   end
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
                        if ~isempty(s.RSVP)
                            s.currSubCond = s.RSVPList(s.stimNum);
                        s.(s.RSVPStimProp) = s.RSVPParms{s.currSubCond};
                        end
                    end
                    

                    % get the stimulus end time
                    if c.frame==s.offFrame+2
                        s.endTime=c.flipTime;
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
                        s.stimNum = s.stimNum+1;
                        if ~isempty(s.RSVP)
                            if s.stimNum<=numel(s.RSVPList)
                                s.currSubCond = s.RSVPList(s.stimNum);
                                s.(s.RSVPStimProp) = s.RSVPParms{s.currSubCond};
                            else
                                s.stimNum=1;
                            end
                        end
                    end
                    Screen('glLoadIdentity', c.window);
                case 'BASEAFTERFRAME'
                    if s.flags.on 
                        notify(s,'AFTERFRAME');
                    end
                case 'BASEBEFORETRIAL'
                    if ~isempty(s.RSVP)
                        s.addRSVP(s.RSVP{1},s.RSVP{2},s.RSVP{3},s.RSVP{4:end})
                    end
                    
                    notify(s,'BEFORETRIAL');

                case 'BASEAFTERTRIAL'
                    notify(s,'AFTERTRIAL');

                case 'BASEBEFOREEXPERIMENT'
                    notify(s,'BEFOREEXPERIMENT');

                case 'BASEAFTEREXPERIMENT'    
                    notify(s,'AFTEREXPERIMENT');
                    

            end
        end        
    end
end