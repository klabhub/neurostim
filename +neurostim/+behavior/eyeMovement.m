classdef (Abstract) eyeMovement  < neurostim.behavior.behavioralControl
    % This is an abstract class that sets up some functionality used for
    % all eye movement related behavior. 
    
    properties
        
    end
    
     methods (Access=public)  % Derived classes can overrule these if needed
        % Constructor
        function o = eyeMovement(c,name)
            o = o@neurostim.plugins.behavior(c,name);   
            o.addProperty('x',0);
            o.addProperty('y',0);
            o.addProperty('tolX',0);
            o.addProperty('tolY',0);            
        end
        
        % Overrule the getEvent function to generate events that carry eye
        % position information.
        function e = getEvent(o)
            [e.x,e.y,e.buttons] = GetMouse;            
        end
     end
          
    % This class does not define any new states. State functions
    % methods        
    % end
    
    methods (Access=protected)
        % Helper function to determine whether the eye is in the window
        function value= isInWindow(o,e)
              value= all(abs(e.x-o.x)<o.tolX) && all(abs(e.y-o.y)<o.tolY);
        end
    end
end