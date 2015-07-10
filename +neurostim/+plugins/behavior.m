classdef behavior < neurostim.plugin
    % Simple behavioral class which adds properties, event listeners and function wrappers
    % for all behavioral subclasses.
    % Properties:
    % on - true when conditions met, false when not.
    % checkEvent - cell array of strings containing events (e.g.
    % beforeframe, afterframe), case insensitive.
    % reward - struct containing type, duration, when.
    properties
    checkEvent = {'afterFrame'};
    reward = struct('type','SOUND','dur',100,'when','IMMEDIATE')
    startTime = Inf;
    endsTrial = true;  %does violating behaviour end trial?
    end
    
    properties (SetObservable,AbortSet)
       from=1000; 
       on@logical = false;
       done@logical=false;
    end
    
    methods 
        function set.from(o,value)
            if isempty(value)
                o.from = Inf;
            else
                o.from = value;
            end
        end
        
    end
    
    methods
        function o=behavior
            o = o@neurostim.plugin('behavior');
            o.addPostSet('done',[]);
            o.addPostSet('on',[]);
            o.addProperty('continuous',false);
            o.addProperty('duration',1000);
            o.addPostSet('from',[]);
            o.addProperty('X',0);
            o.addProperty('Y',0);
            o.addProperty('Z',0);
            o.addProperty('tolerance',1.5);
            
            if any(strcmpi('afterframe',o.checkEvent))
                o.listenToEvent('AFTERFRAME');
            end
            
            if any(strcmpi('aftertrial',o.checkEvent))
                o.listenToEvent('AFTERTRIAL');
            end
            
            if any(strcmpi('beforeframe',o.checkEvent))
                o.listenToEvent('BEFOREFRAME');
            end
            
            if any(strcmpi('afterexperiment',o.checkEvent))
                o.listenToEvent('AFTEREXPERIMENT');
            end
        end
        
        function beforeFrame(o,c,evt)
            processBehavior(o,c);
            if o.done && strcmpi('immediate',o.reward.when)
                % call reward function
            end
        end
        
        function afterFrame(o,c,evt)
            processBehavior(o,c);
            if o.done && strcmpi('immediate',o.reward.when)
                % call reward function
            end
        end
        
        function afterTrial(o,c,evt)
            processBehavior(o,c);
            
            if o.done && any(strcmpi({'immediate','afterTrial'},o.reward.when))
                % call reward function
            end
        end
        
        function afterExperiment(o,c,evt)
            processBehavior(o,c);
        end
        
        
        
        function on = checkBehavior(o)
           % wrapper for checkBehavior function, to be overloaded in
           % subclasses. Should return o.on = true if behavior is satisfied.
            
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
                        if o.done
                            o.done = false;
                        end
                        if o.endsTrial
                            c.nextTrial;  % quit trial
                            return;
                        end
                    end
                    if o.on && (GetSecs*1000)-o.startTime>=o.duration && ~o.done   % if duration has been met and behaviour is still on
                        o.done = true;  % set done flag
                        % notify behaviour complete?
                    end
                else    % if behaviour is discrete
                    o.done = o.on;
                end
            end
            
        end
    end
    
    
    
    
    
end