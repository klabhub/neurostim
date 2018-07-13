classdef behaviorStateMachine < handle
    
    properties
        currentState; % Function handle that represents the current state.
    end
    
    
    
    %% 
    methods
        function o=behaviorStateMachine()
            
        end
        
        function e = getEvent(o)
            [e.x,e.y,e.buttons] = GetMouse;            
        end
        
        function handleEvent(o)
            e= getEvent(o);
            o.currentState(e);           
        end
        
        function transition(o,state)
            o.currentState = state;
        end
    end
    
    %% States
    methods
        function endTrial(o,e)
            
        end
    end
   
end