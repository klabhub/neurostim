classdef behavior < neurostim.plugin & neurostim.plugins.reward
    % Simple behavioral class which adds properties, event listeners and function wrappers
    % for all behavioral subclasses.
    % Properties:
    % on - true when conditions met, false when not.
    % beforeframe, afterframe), case insensitive.
    % reward - struct containing type, duration, etc.
    
    events
        GETREWARD;
    end
    
    properties
    acquireEvent = {'afterFrame'};    % checks behaviour, for acquiring data
    validateEvent = {'afterTrial'}; % checks whether this behaviour is 'correct'
    startTime = Inf;
    endsTrial = true;  %does violating behaviour end trial?
    rewardOn = true;
    end
    
    properties (Access=public,SetObservable=true,GetObservable=true,AbortSet)
       from=1000;
       on@logical = false;
       done@logical=false;
    end
    
    
    methods
        function o=behavior(name)
            o = o@neurostim.plugin(name);
            o.addPostSet('done',[]);
            o.addPostSet('on',[]);
            o.addProperty('continuous',false);
            o.addProperty('duration',1000);
            o.addPostSet('from',[]);
            o.addProperty('X',0);
            o.addProperty('Y',0);
            o.addProperty('Z',0);
            o.addProperty('tolerance',1.5);
            
            if any(strcmpi('afterframe',o.validateEvent))
                o.listenToEvent('AFTERFRAME');
            end
            
            if any(strcmpi('aftertrial',o.validateEvent))
                o.listenToEvent('AFTERTRIAL');
            end
            
            if any(strcmpi('beforeframe',o.validateEvent))
                o.listenToEvent('BEFOREFRAME');
            end
            
            if any(strcmpi('afterexperiment',o.validateEvent))
                o.listenToEvent('AFTEREXPERIMENT');
            end
        end
        
        
        function beforeFrame(o,c,evt)
            processBehavior(o,c);
        end
        
        function afterFrame(o,c,evt)
            processBehavior(o,c);
        end
        
        function afterTrial(o,c,evt)
            processBehavior(o,c);
        end
        
        function afterExperiment(o,c,evt)
            processBehavior(o,c);
        end
        
        function acquireBehavior(o)
            % wrapper for acquireBehavior function
        end
        
        function validateBehavior(o)
           % wrapper for checkBehavior function, to be overloaded in
           % subclasses. Should return true if behavior is satisfied and false if not.
            
        end
            
        function processBehavior(o,c)
            % processes all behavioural responses.
            if GetSecs*1000-c.trialStartTime(end) >=o.from
                o.on = checkBehavior(o);   %returns o.on = true if true.
                if o.continuous % if the behaviour needs to be continuous (i.e. has a duration)
                    if o.on && o.startTime == Inf   % if behaviour is on for the first time
                        o.startTime = GetSecs*1000;     % set start time.
                    end
                    if ~o.on && o.startTime ~=Inf       % if behaviour is not on, but was on previously
                        o.startTime = Inf;      % reset start time and done flag
                        o.done = false;
                        if o.rewardOn       % if we want to trigger rewards
                            [o.rewardData.answer] = deal(false);
                            notify(c,'GETREWARD');
                        end
                        if o.endsTrial    % if we want failure to end trial
                            c.nextTrial;  % quit trial
                            return;
                        end
                    end
                    if o.on && (GetSecs*1000)-o.startTime>=o.duration   % if duration has been met and behaviour is still on
                        o.done = true;  % set done flag
                        if o.rewardOn   % if we want to trigger rewards
                            [o.rewardData.answer] = deal(true);
                            notify(c,'GETREWARD');
                        end
                    end
                else    % if behaviour is discrete
                    o.done = o.on;
                end
            end
            
        end
    end
    
    
    
    
    
end