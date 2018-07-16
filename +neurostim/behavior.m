classdef (Abstract) behavior <  neurostim.plugin
    % This abstract class implements a finite state machine to
    % define behaviors. Derived classes are needed to implement specific
    % behavioral sequences. See for example behaviors.fixate or
    % behaviors.keyResponse.
    %
    % This base class only implements two states:
    % FAIL - the final state of the machine indicating that the behavioral
    %           constraints defined by the machine were not met.
    % SUCCESS - the final state of the machine indicating tha that the
    % behavioral constraints defined by the machine were met. 
    % 
    % Derived classes should define their states such that the machine ends
    % in either the FAIL or SUCCESS endstate.
    % To learn how to do this, look at the behaviors.fixate class which
    % implements one complete state machine for steady fixation in a trial.
    % Then look at behaviors.saccade and behaviors.fixateThenChoose to see 
    % how behaviors can build on each other. In all cases, if you find
    % yourself adding many if/then constructs to see where you are in the
    % flow of the behavior, then you're probably doing something wrong and
    % should think about adding a state instead. 
    % Another example of inheritance is the keyResponse (single key
    % press per trial) and multiKeyResponse (multiple presses that allow a
    % subject to change their mind during the trial). This could be
    % achieved by adding various flags and if/thens in the keyResponse
    % behavior, but adding states (as in multikeyResponse) leads to cleaner
    % and less error prone code. 
    %
    % For more background information on the advantages of finite state machines
    % see 
    % https://en.wikipedia.org/wiki/UML_state_machine 
    % https://barrgroup.com/Embedded-Systems/How-To/State-Machines-Event-Driven-Systems
    %
    % Parameters:
    % failEndsTrial  - a trial ends when the FAIL state is reached [true]
    % successEndsTrial - a trial ends when the SUCCESS state is reached  [false]
    % verbose - Write output about each state change to the command line [true]
    % stateName - the name of the current state of the machine.
    % isOn -  Logical to indicate whether the machine is currently active.
    % stopTime - the trial time when the machine reached either the FAIL or
    %                   SUCCESS state in the current trial
    % required - If this is true, then this behaviors end state is used to
    % determine the success of an entire trail (which may have other
    % behaviors too) [true]
    % 
    % Functions to be used in experiment designs:
    % 
    % startTime(o,state) - returns the time in the current trial when the
    % specified state started. 
    % duration(o,state,t) - returns how long the machine has been in state s at time t
    %                       of the current trial (or the current time if t is not provide).
    %
    % 
    % 
    % TODO:
    %   hack str2fun so that it can accept f1.startTime.fixation instead of
    %   startTime(cic.f1,''fixation'') as is currently necessary because
    %   str2fun cannot handle the .startTime.fixation. 
    %
    % BK  - July 2018
    properties (SetAccess=public,GetAccess=public)
        failEndsTrial       = true;          % Does reaching the fail state end the trial?
        successEndsTrial    = false;         % Does reaching the success state end the trial?
        verbose             = true;
        required            = true;
        
    end
    
    properties (SetAccess=protected,GetAccess=public)
        currentState; % Function handle that represents the current state.
        beforeTrialState;  % Must be non-empty
        iStartTime;  % containers.Map object to store state startTimes for quick access
        
        
    end
    properties (Dependent)
        stateName@char;
        isOn@logical;
        stopTime@double; % time when fail or success state was reached.
        isSuccess;
        duration;
    end
    
    methods %get/set
        function v = get.isSuccess(o)
            v= strcmpi(o.stateName,'SUCCESS');            
        end
        
        function v = get.isOn(o)
            t= o.cic.trialTime;
            v= t>=o.on & t < o.off;
        end
        
        
        function v=get.duration(o)
            % Duration of the current state
            v= o.cic.trialTime -startTime(o,o.stateName);
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
            v = min(startTime(o,'FAIL'),startTime(o,'SUCCESS')); % At least one will be NaN             
        end
        
        
    end
    
    
        methods (Access=public)  
    
        % Users should add functionality by defining new states, or
        % if a different response modailty (touchbar, keypress, eye) is
        % needed, by overloading the getEvent function.
        % When overloading the regular plugin functions beforeXXX/afterXXX,
        % make sure to also call the functions defined here.
                    
        function beforeExperiment(o)
            assert(~isempty(o.beforeTrialState),['Behavior ' o.name '''s beforeTrialState has not been defined']);
        end
        
        
        function beforeTrial(o)
            % Reset the internal record of state start times
            o.iStartTime = containers.Map('keyType','char','ValueType','double');
            transition(o,o.beforeTrialState,neurostim.event(neurostim.event.NOOP));
        end
        
        function afterTrial(o)
            % Send an afterTrial  event
            o.currentState(o.cic.trialTime,neurostim.event(neurostim.event.AFTERTRIAL))
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
            o.addProperty('event',neurostim.event(neurostim.event.NOOP)); 
            o.feedStyle = 'blue';
            o.iStartTime = containers.Map('keyType','char','ValueType','double');          
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
        function transition(o,state,e) 
            % state = the state to transition into
            % e = the event that triggered this transition. This event is
            % sent to the old and new state as an entry/exit signal to
            % allow teardown/setup code to use the information in the
            % event.            
            
            o.event = e; % Log the event driving the transition.
            
            
            %Tear down old state
            if ~isempty(o.currentState)
                e.type = neurostim.event.EXIT; % Change the type
                o.currentState(0,e); % Send the EXIT signal           
            end
            
            
            % Setup new state
            e.type = neurostim.event.ENTRY;
            state([],e); % Send the ENTRY signal to the new state.
            
            % Switch to new state and log the new name
            o.currentState = state; % Change the state
            oStateName = o.stateName;
            o.state = oStateName; % Log time/state transition            
            o.iStartTime(oStateName) = o.cic.trialTime;
            
            if o.verbose
                o.writeToFeed(['Transition to ' o.state]);
            end
        end
    
        
        
        
        end
    
    %% States
    % These two generic states should be the endpoint for every derived
    % class. success or fail.  
    methods
        function fail(o,~,e)       
            % This state responds to the entry signal to end the trial (if
            % requested)
            if e.isEntry && o.failEndsTrial
                o.cic.endTrial();
            end
        end
        
        function success(o,~,e)            
            % This state responds to the entry signal to end the trial (if
            % requested)            
            if e.isEntry && o.successEndsTrial
                o.cic.endTrial();
            end
        end
        
    end
    
    %% Helper functions
    methods
      
        
     
    function v = startTime(o,s)
        s = upper(s);
        if isKey(o.iStartTime,s)
            % This state's startTime was logged 
            v = o.iStartTime(s);        
        else
            v= NaN;
        end
    end
     end
    
    
end