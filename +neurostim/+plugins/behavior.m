classdef behavior < neurostim.plugin
    % Generic behavior class (inc. function wrappers) for subclasses.
    % 
    % Simple behavioral class which adds properties, event listeners and function wrappers
    % for all behavioral subclasses.
    
    
    properties (Access=public)
                failEndsTrial = true;               %Does violating behaviour end trial?
    end
    
    properties (SetAccess=protected)
        started = false;

    end
    
    properties (SetObservable=true,GetObservable=true,AbortSet)
        inProgress@logical = false;
        done@logical=false;
    end
    
    properties (Dependent)
        enabled;
    end
    
    methods
        function v= get.enabled(o)
            v = (o.cic.trialTime >= o.on) && (o.cic.trialTime <= (o.on + o.duration));
        end
    end
    
    methods
        function o=behavior(name)
            o = o@neurostim.plugin(name);
            
            %User settable
            o.addProperty('on',0,[],@isnumeric);                %The time the plugin should begin sampling behavior
            o.addProperty('duration',Inf,[],@isnumeric);        %The time the plugin should stop sampling behavior
            o.addProperty('continuous',false,[],@islogical);    %Behaviour continues over an interval of time (as opposed to one-shot behavior).
            o.addProperty('from',Inf,[],@isnumeric);            %The time from which the behaviour *must* be satisfied (for continuous)
            o.addProperty('to',Inf,[],@isnumeric);              %The time to which the behaviour *must* be satisfied (for continuous).
            o.addProperty('deadline',Inf,[],@isnumeric);        %The time by which the behaviour *must* be satisfied (for one-shot).
            
            %Internal
            o.addProperty('startTime',Inf);                     %The time at which the behaviour was initiated (i.e. in progress).
            o.addProperty('endTime',Inf);                       %The time at which a result was achieved (good or bad).
            o.addPostSet('done',[]);                            %True when a result (of any kind) has been achieved.
            o.addPostSet('inProgress',[]);                      %True if the subject is currently satisfying the requirement
            o.addProperty('success',false);                     %Whether the behavioral criterion was achieved.
            o.addProperty('outcome','',[],@ischar);             %For logging different types of outcome 

            o.listenToEvent({'BEFORETRIAL','AFTERTRIAL','AFTERFRAME'});
        end
        
        function beforeTrial(o,c,evt)
            % reset all flags
            o.inProgress = false;
            o.done = false;
            o.startTime = Inf;
            o.endTime = Inf;
            o.started = false;
            o.success = false;
        end
        
        function afterFrame(o,c,evt)
            
            if o.enabled && ~o.done
                
                %Collect relevant data from a device (e.g. keyboard, eye tracker, touchbar)
                sampleBehavior(o);

                %Check whether the subject is meeting the requirements
                checkBehavior(o,c);
            end
        end
        
        function afterTrial(o,c,evt)
            if ~o.done && o.started
                %The trial ended before the behaviour could be completed. Treat this as a completion.
                o.result(true,'COMPLETE',false);
                o.endTime = c.trialTime;
            end
        end
        
    end
    
    methods (Access=protected)
       
        function o = sampleBehavior(o,c)
            % wrapper for sampleBehavior function, to be overloaded in
            % subclasses. This should store some value(s) of the
            % requested behaviour (i.e. eye position, mouse position) 
            % to be later checked by validateBehavior(o).
        end
        
        function on = validateBehavior(o)
            % wrapper for checkBehavior function, to be overloaded in
            % subclasses. Should return true if behavior is currently satisfied and false if not.
        end
        
        function checkBehavior(o,c)
                        
            %Check whether the behavioural criteria are currently being met
            o.inProgress = validateBehavior(o);   %returns true if so.
            
            %If the behaviour extends over an interval of time
            if o.continuous
                
                %If behaviour is on for the first time, log the the start time
                if o.inProgress && ~o.started
                    o.startTime = c.trialTime;
                    o.started = true;
                    return;
                end
                
                %If behaviour completed
                if o.inProgress && (c.trialTime>=o.to)
                    %Hooray!n
                    o.result(true,'COMPLETE',false);
                    return;
                end
                
                %if the FROM deadline is reached without commencement of behavior
                if (c.trialTime >=o.from) && ~o.started
                    %Violation! Should have started by now.
                    o.result(false,'FAILEDTOSTART',o.failEndsTrial);
                    return;
                end
                
                %if behaviour commenced, but has been interrupted
                if ~o.inProgress && o.started
                    %Violation!
                    o.result(false,'PREMATUREEND',o.failEndsTrial);
                    return;
                end
            else
                % if behaviour is discrete (one-shot)
                if o.inProgress
                    o.result(true,'COMPLETE',false);
                elseif c.trialTime >= o.deadline
                    o.result(false,'FAILEDTOSTART',o.failEndsTrial);
                end
            end
            
        end
        
        function result(o,success,outcome,endTrial)
            
            %Register that an outcome has been reached
            o.endTime = o.cic.trialTime;
            o.done = true;
            
            %Set a flag indicating success or failure.
            o.success = success;
            
            %Log the outcome as a string (event)
            o.outcome = outcome;
            
            %If requested, set the flag to end the trial
            if endTrial
                o.cic.nextTrial;
            end
            
            if ~o.success
                o.writeToFeed(o.outcome);
            end
        end
        
        
    end   
end