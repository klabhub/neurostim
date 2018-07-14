classdef (Abstract) behavior <  neurostim.plugin
    
    properties (SetAccess=public,GetAccess=public)
        failEndsTrial       = true;          % Does reaching the fail state end the trial?
        successEndsTrial    = false;         % Does reaching the success state end the trial?
        verbose             = true;
    end
    
    properties (SetAccess=protected,GetAccess=public)
        currentState; % Function handle that represents the current state.
        beforeExperimentState; % Must be non-empty
        beforeTrialState;  % If empty,the currentState is used
        
    end
    properties (Dependent)
        stateName@char;
        isOn@logical;
        stopTime@double; % time when fail or success state was reached.
    end
    
    methods %get/set
        
        function v = get.isOn(o)
            t= o.cic.trialTime;
            v= t>=o.on & t < o.off;
        end
        
        function v = get.stateName(o)
            pattern = '@\(varargin\)o\.(?<name>[\w\d]+)\(varargin{:}\)'; % This is what a state function looks like when using func2str : @(varargin)o.freeViewing(varargin{:})
            if isempty(o.currentState)
                v= '';
            else
                match = regexp(func2str(o.currentState),pattern,'names');
                if isempty(match)
                    error('State name extraction failed');
                else
                    v= upper(match.name);
                end
            end
        end

        function v = get.stopTime(o)
             if o.prms.state.cntr >1
                [states,~,t] = get(o.prms.state,'trial',o.cic.trial,'withDataOnly',true);
                stay = ismember(states,{'FAIL','SUCCESS'});
                v  = t(stay);
                if isempty(v) % This state did not occur yet this trial
                    v= NaN;
                end
            else
                v= NaN;
            end
        end

    end
    
        methods (Access=public)  
    
        % Users should add functionality by defining new states, or
        % if a different response modailty (touchbar, keypress, eye) is
        % needed, by overloading the getEvent function.
        % When overloading the regular plugin functions beforeXXX/afterXXX,
        % make sure to also call the functions defined here.
                    
        function beforeExperiment(o)
            assert(~isempty(o.beforeExperimentState),['Behavior ' o.name '''s beforeExperimentState has not been defined']);
        end
        
        
        function beforeTrial(o)
            if ~isempty(o.beforeTrialState)
                transition(o,o.beforeTrialState);
            end            
        end
        
        function beforeFrame(o)
            if o.isOn
                e= getEvent(o);% Get current events
                if e.isRegular
                    % Only regular events are sent out by this dispatcher,
                    % ENTRY/EXIT events are generated and dispatched by
                    % transition, and NOOP events are ignored.
                    % Derived classes can use NOOP events to indicate they
                    % should not be distributed to states (i.e. a no-op
                    % instruction).
                    o.currentState(o.cic.trialTime,e);  % Each state is a member function- just pass the event
                end
            end
        end
        
                
    
        
        % Constructor. In the non-abstract derived clases, the user must
        % set currentState to an existing state.
        function o = behavior(c,name)
            o = o@neurostim.plugin(c,name);
            o.addProperty('on',0,'validate',@isnumeric);
            o.addProperty('off',Inf,'validate',@isnumeric);
            o.addProperty('from',0,'validate',@isnumeric);
            o.addProperty('to',Inf,'validate',@isnumeric);
            o.addProperty('state','','validate',@ischar);
            o.feedStyle = 'blue';
        end
        
        % This function must return a neurostim.event, typically of the
        % REGULAR type, although derived classes can use the NOOP type to 
        % indicate that the event should not be sent to the states.
        function e = getEvent(~)
            % The base-class does not generate any specific events.
            e = neurostim.event(neurostim.event.NOOP);
            % For testing purposes this could be commented out
            % [e.X,e.Y,e.key] = GetMouse;                        
        end
        
        end
    
        methods (Sealed)
        % To avoid the temptation to overload these member functions, they 
        % sealed,. 
        function transition(o,state)       
            if ~isempty(o.currentState)
                o.currentState(0, neurostim.event(neurostim.event.EXIT)); % Send the EXIT signal           
            end
            o.currentState = state; % Change the state
            o.state = o.stateName; % Log time/state transition            
            o.currentState([], neurostim.event(neurostim.event.ENTRY)); % Send the ENTRY signal
            if o.verbose
                o.writeToFeed(['Transition to ' o.state]);
            end
        end
    
        end
    
    %% States
    methods
        function fail(o,~,e)           
            if e.isEntry && o.failEndsTrial
                o.cic.endTrial();
            end
        end
        
        function success(o,~,e)            
            if e.isEntry && o.successEndsTrial
                o.cic.endTrial();
            end
        end
        
    end
    
    %% Helper functions
    methods
        
        function v= stateDuration(o,t,s)
            %Return how long the state s has been active at time t.
            if o.prms.state.cntr >1
                [v] = get(o.prms.state,'trial',o.trial,'withDataOnly',true);
            else
                v= 0;
            end
        end
        
        % Return the starttimes of a specific state (s) in the current
        % trial. In a behavior where the same state can be visited multiple
        % times, this can be a vector of times - the caller will have to
        % handle that aspect. (e.g. take the max for the last)
        function v = startTime(o,s)
            if o.prms.state.cntr >1
                [states,~,t] = get(o.prms.state,'trial',o.cic.trial,'withDataOnly',true);
                stay = ismember(states,upper(s));
                v  = t(stay);
                if isempty(v) % This state did not occur yet this trial
                    v= NaN;
                end
            else
                v= NaN;
            end
            
        end
    end
    
    
end