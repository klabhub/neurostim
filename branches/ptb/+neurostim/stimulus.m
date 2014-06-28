classdef stimulus < neurostim.plugin
    events
        BEFOREFRAME;
        AFTERFRAME;    
        BEFORETRIAL;
        AFTERTRIAL;    
        BEFOREEXPERIMENT;
        AFTEREXPERIMENT;

        
    end
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
    end
    
    methods
        function v= get.off(o)
            v = o.on+o.duration;
        end
    end
    methods
        function s= stimulus(name)
            s = s@neurostim.plugin(name);
            s.addProperty('X',0);
            s.addProperty('Y',0);
            s.addProperty('Z',0);  
            s.addProperty('on',0);  
            s.addProperty('duration',Inf);  
            s.addProperty('stimstart',false)
            s.addProperty('stimstop',false); 
            s.addProperty('color',[1/3 1/3]);
            s.addProperty('luminance',50);
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
            p.addParamValue('guess',-1);   % Log Contrast for QUEST
            p.addParamValue('guessSD',2);  % 
            p.addParamValue('threshold',0.82); %Target threshold
            p.addParamValue('beta',3.5); % Steepness of assumed Weibull
            p.addParamValue('delta',0.01); % Fraction of blind presses
            p.addParamValue('gamma',0.5); % Fraction of trials that will generate response when for intensity = -inf.
            p.addParamValue('grain',0.01); % Discretization of the range
            p.addParamValue('range',5); % Range centered on guess.
            p.addParamValue('plotIt',false);
            p.addParamValue('normalizePdf',1);
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
       
        
        function baseEvents(s,c,evt)
            switch evt.EventName
                case 'BASEBEFOREFRAME'
                    s.flags.on = c.frame >=s.on && c.frame < s.on+s.duration;
                    if s.flags.on 
                        notify(s,'BEFOREFRAME');
                        s.stimstart = true;
                    else %Stim off
                        
                    end
                case 'BASEAFTERFRAME'
                    if s.flags.on 
                        notify(s,'AFTERFRAME');
                    end
                case 'BASEBEFORETRIAL'
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
    
        
    %% Methods that the user cannot change. 
    % These are called from by the controller for all stimuli to provide 
    % consistent functionality. Note that @stimulus.baseBeforeXXX is always called
    % before @derivedClasss.beforeXXX and baseAfterXXX always before afterXXX. This gives
    % the derived class an oppurtunity to respond to changes that this 
    % base functionality makes.
    methods (Sealed)
        
        
    end
end