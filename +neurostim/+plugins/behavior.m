classdef behavior < neurostim.plugin
    % Generic behavior class (inc. function wrappers) for subclasses.
    % 
    % Simple behavioral class which adds properties, event listeners and function wrappers
    % for all behavioral subclasses.
    
    
    properties (Access=public)
        failEndsTrial = true;             %Does violating behaviour end trial?
        successEndsTrial = false;         % Does completing the behavior successfully end the trial?  
        sampleEvent = 'AFTERFRAME';       %On which event(s) should the behavioral data be sampled? (string or cell of strings)
        validateEvent = 'AFTERFRAME';     %On which event(s) should the behavioral data be validated? (i.e. is subject doing the right thing?)
    end
    
    properties (SetAccess=protected)
        started@logical=false;             %Set to true when behavior first begins (e.g. onset of fixation)
        done@logical=false;                %Set to true when the behavior is complete/terminated, for good or bad.
        inProgress@logical=false;          %True if the subject is currently satisfying the requirement
    end
    
    
    properties (Dependent)
        enabled
    end
    
    methods
        function set.sampleEvent(o,val)
            o.sampleEvent = checkEventArgs(o,val);
        end
        function set.validateEvent(o,val)
            o.validateEvent = checkEventArgs(o,val);
        end       
        function v= get.enabled(o)
            if o.done
                v = false;
            else
                %This part is reltively slow, hence the if approach here
                t = o.cic.trialTime;
                v = t >= o.on && t <= o.off;
            end
        end
    end
    
    methods
        function o=behavior(c,name)
            o = o@neurostim.plugin(c,name);
            
            %User settable
            o.addProperty('on',0,'validate',@isnumeric);                %The time the plugin should become active
            o.addProperty('off',Inf,'validate',@isnumeric);             %The time the plugin should become inactive
            o.addProperty('continuous',false,'validate',@islogical);    %Behaviour continues over an interval of time (as opposed to one-shot behavior).
            o.addProperty('from',Inf,'validate',@isnumeric);            %The time by which the behaviour *must* have commenced (for continuous)
            o.addProperty('to',Inf,'validate',@isnumeric);              %The time to which the behaviour *must* continue to be satisfied (for continuous).
            o.addProperty('deadline',Inf,'validate',@isnumeric);        %The time by which the behaviour *must* be satisfied (for one-shot).
            
            %Internal use only       
            o.addProperty('startTime',Inf);      %The time at which the behaviour was initiated (i.e. in progress).
            o.addProperty('stopTime',Inf);        %The time at which a result was achieved (good or bad).
            o.addProperty('success',false);     %Set to true if the behavior was completed correctly
            o.addProperty('outcome',false);     %A string indicating the outcome upon termination (e.g., 'COMPLETE','FAILEDTOSTART')
            
            
        end
        
        function beforeTrial(o)
            % reset all flags
            o.inProgress = false;
            o.done = false;
            o.startTime = Inf;
            o.stopTime = Inf;
            o.started = false;
            o.success = false;
        end
        
        function afterFrame(o)
            if o.enabled
                update(o,o.cic,'AFTERFRAME');
            end
        end
        
        function afterTrial(o)
            update(o,o.cic,'AFTERTRIAL');
            if ~o.done && o.started
                %The trial ended before the behaviour could be completed. Treat this as a completion.
                result(o,true,'COMPLETE',false);
                o.stopTime = o.cic.trialTime;
            end
        end 
    end
    
    methods (Access=protected)
        function update(o,c,curEvent)

            %Collect relevant data from a device (e.g. keyboard, eye tracker, touchbar)
            if any(strcmp(o.sampleEvent, curEvent))
                sample(o,c);
            end
            
            %Check whether the subject is meeting the requirements
            if any(strcmp(o.validateEvent, curEvent))
                baseValidate(o,c);
            end
            
        end
        
        function sample(o,c)
            % wrapper for sampleBehavior function, to be overloaded in
            % subclasses. This should store some value(s) of the
            % requested behaviour (i.e. eye position, mouse position)
            % to be later checked by validate(o).
        end
        
        function on = validate(o)
            % wrapper for checkBehavior function, to be overloaded in
            % subclasses. Should return true if behavior is currently satisfied and false if not.
        end
        
        function baseValidate(o,c)
            
            %Check whether the behavioural criteria are currently being met
            o.inProgress = validate(o);   %returns true if so.
            
            
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
                    %Hooray!
                    o.result(true,'COMPLETE',o.successEndsTrial);
                    return;
                end
                
                %if the FROM deadline is reached without commencement of behavior
                if ~o.started && (c.trialTime >=o.from)
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
                    o.started = true;
                    o.result(true,'COMPLETE',o.successEndsTrial);
                elseif c.trialTime >= o.deadline
                    o.result(false,'FAILEDTOSTART',o.failEndsTrial);
                end
            end
            
        end
        
        function result(o,success,outcome,endTrial)
            
            %Register that an outcome has been reached
            o.stopTime = o.cic.trialTime;
            o.done = true;
            
            %Set a flag indicating success or failure.
            o.success = success;
            
            %Log the outcome as a string (event)
            o.outcome = outcome;
            
            %If requested, set the flag to end the trial
            if endTrial
                o.cic.endTrial;
            end
            
            if ~o.success
                o.writeToFeed(o.outcome);
            end
        end
        
        function val = checkEventArgs(o,val)
            %Make sure that the request is an actual event
            allGood = true;
            
            %If not already a cell, make it so
            if ~iscell(val)
                val = {val};
            end
            
            %Check that only strings have been entered and convert to uppercase
            if all(cellfun(@ischar,val))
                val = cellfun(@upper,val,'uniformoutput',false);
            else
                allGood = false;
            end
            
            %Make sure that the request is an actual event (or empty)
            if ~all(ismember(val,{'AFTERTRIAL','AFTERFRAME',''}))
                allGood = false;
            end
            
            if ~allGood
                error('Behavior sampleEvent/validateEvent must be one or more (cell) of ''AFTERFRAME'', ''AFTERTRIAL''');
            end
        end
    end   
end