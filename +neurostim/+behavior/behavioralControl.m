classdef (Abstract) behavioralControl <  neurostim.plugin
    
    properties (SetAccess=public,GetAccess=public)
        failEndsTrial       = true;             %Does violating behaviour end trial?
        successEndsTrial    = false;         % Does completing the behavior successfully end the trial?     
        everyFrame@logical =true;
        
    end
    
    properties (SetAccess=protected,GetAccess=public)
         currentState; % Function handle that represents the current state. 
         initialState; % Each trial starts in this state 
    end
    
    
    %% Standard plugin member functions
    methods (Sealed)
        % Users should add functionality by defining new states, or
        % if a different response modailty (touchbar, keypress, eye) is
        % needed, by overloading the getEvent function. The regular plugin
        % functions are sealed. 
        function beforeExperiment(o)
        end
        
        
        function beforeTrial(o)
            o.currentState = o.initialState;
            
        end
        
        function beforeFrame(o)
            if o.everyFrame    
                e= getEvent(o);     % Get current events
                o.currentState(e);  % Each state is a member function- just pass the event
            end
        end
        
        function afterFrame(o)
        end
        
        function afterTrial(o)
        end
        function afterExperiment(o)
        end
        
        
        function transition(o,state)
            o.currentState = state;
        end
    end
    
    %% 
    methods (Access=public)  % Derived classes can overrule these if needed
       
        % Constructor. In the non-abstract derived clases, the user must
        % set currentState to an existing state.
        function o = behavior(c,name)
            o = o@neurostim.plugin(c,name);     
            o.feedStyle = 'blue';
        end
           
        function e = getEvent(o)
            [e.x,e.y,e.buttons] = GetMouse;   
            e.t = o.cic.trialTime;
        end
      
    end
    
    %% States
    methods
        function fail(o,e)
            if o.failEndsTrial
                o.cic.endTrial();
            end
        end
        
        function success(o,e)
            if o.successEndsTrial
                o.cic.endTrial();
            end
        end
    end
    
    methods
        % Helper function to determine whether we've reached the timeout
        function value = isTimeout(o,e)
            value = e.t >o.timeout;
        end
        
    end
    
end