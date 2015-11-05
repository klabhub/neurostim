classdef behavior < neurostim.plugin
    % Simple behavioral class which adds properties, event listeners and function wrappers
    % for all behavioral subclasses.
    % Properties:
    % on - true when conditions met, false when not.
    % beforeframe, afterframe), case insensitive.
    
    events
        GIVEREWARD
    end
    
    properties
        sampleEvent =   {'afterFrame'}; %Event(s) upon which we will obtain measurements of the behaviour (e.g. eye position)
        validateEvent = {'afterFrame'}; %Event(s) upon which we will check whether the behavior satisfies the criteria.
        success = false;
        endsTrial = true;               %Does violating behaviour end trial?
        rewardOn = true;
        rewardPlugins = [];
        prevOn = false;
    end
    
    properties (Access=public,SetObservable=true,GetObservable=true,AbortSet)
        on@logical = false;
        done@logical=false;
        endTime;
        startTime;
    end
    
    methods
        function o=behavior(name)
            o = o@neurostim.plugin(name);
            o.addPostSet('done',[]);
            o.addPostSet('on',[]);
            o.addProperty('response',[]);
            o.addProperty('continuous',false,[],@islogical);
            o.addProperty('duration',1000,[],@isnumeric);
            o.addProperty('from',0,[],@isnumeric);
            o.addProperty('X',0,[],@isnumeric);
            o.addProperty('Y',0,[],@isnumeric);
            o.addProperty('Z',0,[],@isnumeric);
            o.addProperty('tolerance',1,[],@isnumeric);
            o.addPostSet('startTime',[]);
            
            o.listenToEvent('BEFORETRIAL');
            o.listenToEvent(unique(upper([o.validateEvent o.sampleEvent])));
        end
        
        function beforeTrial(o,c,evt)
            % reset all flags
            o.on = false;
            o.done = false;
            o.startTime = Inf;
            o.prevOn = false;
            o.endTime = Inf;
            o.success = false;
            
            if o.rewardOn && isempty(o.rewardPlugins)
                % collect reward plugin pointers in a cell array
                o.rewardPlugins = pluginsByClass(c,'neurostim.plugins.reward');
            end
        end
        
        
        function beforeFrame(o,c,evt)
            
            if any(strcmpi('beforeframe',o.sampleEvent))
                sampleBehavior(o);
            end
            
            if any(strcmpi('beforeframe',o.validateEvent))
                processBehavior(o,c);
            end
        end
        
        function afterFrame(o,c,evt)
            
            if any(strcmpi('afterframe',o.sampleEvent))
                sampleBehavior(o);
            end
            
            if any(strcmpi('afterframe',o.validateEvent))
                processBehavior(o,c);
            end
        end
        
        function afterTrial(o,c,evt)
            
            if any(strcmpi('afterTrial',o.sampleEvent))
                sampleBehavior(o);
            end
            
            if any(strcmpi('afterTrial',o.validateEvent))
                processBehavior(o,c);
            end
        end
        
        function afterExperiment(o,c,evt)
            
            if any(strcmpi('afterExperiment',o.sampleEvent))
                sampleBehavior(o);
            end
            
            if any(strcmpi('afterExperiment',o.validateEvent))
                processBehavior(o,c);
            end
        end
        
        function o = sampleBehavior(o,c)
            % wrapper for sampleBehavior function, to be overloaded in
            % subclasses. This should store some value(s) of the
            % requested behaviour (i.e. eye position, mouse position) 
            % to be later checked by validateBehavior(o).
        end
        
        function on = validateBehavior(o)
            % wrapper for checkBehavior function, to be overloaded in
            % subclasses. Should return true if behavior is satisfied and false if not.
        end
        
        function processBehavior(o,c)
            % processes all behavioural responses.
            if ~o.done && c.frame>1 && ~ischar(o.from) && ~isempty(o.from) && c.trialTime >=o.from
                
                %Check whether the behavioural criteria are currently being met
                o.on = validateBehavior(o);   %returns true if so.
                
                %If the behaviour extends over an interval of time
                if o.continuous 
                    
                    %If the FROM deadline is reached without commencement of behavior
                    if ~o.on && ~o.prevOn
                        %Violation! Should have started by now.
                        o.success = false;
                        handleOutcome(o,o.success,o.endsTrial);
                        return;
                    end
                    
                    %If behaviour is on for the first time, log the the start time
                    if o.on && ~o.prevOn  
                        o.startTime = c.trialTime;
                        o.prevOn = true;
                        return;
                    end
                    
                    %If behaviour commenced, but has been interrupted
                    if ~o.on && o.prevOn
                        %Violation!
                        o.success = false;
                        o.done = true;
                        handleOutcome(o,o.success,o.endsTrial);
                        return;
                    end
                    
                    %If behaviour completed
                    if ~o.done && o.on && ((c.trialTime-o.startTime)>=o.duration || o.endTime~=Inf)   % if duration has been met and behaviour is still on
                        %Hooray!
                        o.success = true;
                        o.done = true;
                        o.endTime = c.trialTime;
                        handleOutcome(o,o.success,false);
                        return;
                    end
                else
                    % if behaviour is discrete
                    o.done = o.on;
                    if o.done
                        handleOutcome(o,o.response,o.endsTrial);
                    end
                end
            end
        end
        
        
        function handleOutcome(o,answer, endTrial)
            
            %Schedule all rewards, positive or negative
            if o.rewardOn
                for a=1:numel(o.rewardPlugins)
                    rewPlg = o.rewardPlugins{a};
                    rewPlg.rewardAnswer = answer;
                    notify(rewPlg,'GIVEREWARD');
                end
            end
            
            %If requested, set the flag to end the trial
            if endTrial
                o.cic.nextTrial;
            end
        end
    end   
end