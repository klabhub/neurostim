classdef behavior < neurostim.plugin
    % Generic behavior class (inc. function wrappers) for subclasses.
    %
    % Simple behavioral class which adds properties, event listeners and function wrappers
    % for all behavioral subclasses.
    
    
    properties (Access=public)
        failEndsTrial = true;             %Does violating behaviour end trial?
        successEndsTrial = false;         % Does completing the behavior successfully end the trial?
        required = true;                  % Is success on this behavior required for overall success in a trial?
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
        success
    end
    
    methods
        function set.sampleEvent(o,val)
            o.sampleEvent = neurostim.plugins.behavior.checkEventArgs(val);
        end
        function set.validateEvent(o,val)
            o.validateEvent = neurostim.plugins.behavior.checkEventArgs(val);
        end
        
        function v = get.success(o)
            v = o.state;
        end
        
        
        function set.success(o,itsASuccess)
            o.state = itsASuccess;
            
            o.stopTime = o.cic.trialTime;
            o.done = true;
            if (itsASuccess)
                % Success :-)
                if o.successEndsTrial
                    o.cic.endTrial;
                end
            else
                % Failure :-(
                if o.failEndsTrial
                    o.cic.endTrial;
                end
            end
            
            if ~itsASuccess
                o.writeToFeed(o.outcome);
            end
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
            o.addProperty('startTime',Inf);         %The time at which the behaviour was initiated (i.e. in progress).
            o.addProperty('stopTime',Inf);          %The time at which a result was achieved (good or bad).
            o.addProperty('state',false);           % Logs changes in success. Dont assign to this, use .success instead.
            o.addProperty('outcome',[]);            %A string indicating the outcome upon termination (e.g., 'COMPLETE','FAILEDTOSTART')
            
            o.feedStyle = 'blue';
        end
        
        function beforeTrial(o)
            % reset all flags
            reset(o);
        end
        
        function afterFrame(o)
            if o.enabled
                update(o,o.cic,'AFTERFRAME');
            end
        end
        
        function afterTrial(o)
            if o.enabled
                update(o,o.cic,'AFTERTRIAL');
            end
            if ~o.done && o.started
                %The trial ended before the behaviour could be completed. Treat this as a completion.
                o.outcome  = 'COMPLETE';
                o.success = true;
            end
        end
        
        function reset(o)
            %Reset all flags and variables to initial state. Useful for
            %looping/repeating the behaviour within a trial
            o.inProgress = false;
            o.done = false;
            o.startTime = Inf;
            o.stopTime = Inf;
            o.started = false;
            o.state  = false;
            o.outcome = [];
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
        
        function sample(o,c) %#ok<INUSD>
            % wrapper for sampleBehavior function, to be overloaded in
            % subclasses. This should store some value(s) of the
            % requested behaviour (i.e. eye position, mouse position)
            % to be later checked by validate(o).
        end
        
        function on = validate(o) %#ok<STOUT,MANU>
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
                    o.outcome = 'COMPLETE';
                    o.success = true;
                    return;
                end
                
                %if the FROM deadline is reached without commencement of behavior
                if ~o.started && (c.trialTime >=o.from)
                    %Violation! Should have started by now.
                    o.outcome = 'FAILEDTOSTART';
                    o.success = false;
                    return;
                end
                
                %if behaviour commenced, but has been interrupted
                if ~o.inProgress && o.started
                    %Violation!
                    o.outcome = 'PREMATUREEND';
                    o.success = false;
                    return;
                end
            else
                % if behaviour is discrete (one-shot)
                if o.inProgress
                    % A one-shot behavior that is in progress should
                    % set its success variable to true or false. This can end the trial
                    % or stay "inProgress"
                elseif c.trialTime >= o.deadline
                    o.outcome = 'FAILEDTOSTART';
                    o.success = false;
                end
            end
            
        end
    end
    
    methods (Static)
        function val = checkEventArgs(val)
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