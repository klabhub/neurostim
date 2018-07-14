classdef (Abstract) eyeMovement  < neurostim.behavior    % This is an abstract class that sets up some functionality used for
    % all eye movement related behavior. 
    
    properties
        
    end
    
     methods (Access=public)  % Derived classes can overrule these if needed
        % Constructor
        function o = eyeMovement(c,name)
           o = o@neurostim.behavior(c,name);   
           o.addProperty('X',0,'validate',@isnumeric); % X,Y,Z - the position of a target for the behaviour (e.g. fixation point)
           o.addProperty('Y',0,'validate',@isnumeric);
           o.addProperty('Z',0,'validate',@isnumeric);
           o.addProperty('tolerance',1,'validate',@isnumeric);           
           o.addProperty('invert',false,'validate',@isnumeric); %Invert the meaning of "in the window'
           o.addProperty('radius',5,'validate',@isnumeric); 
           
           
           if ~isfield(c,'eye')
               warning(c,'No eye data in CIC. This behavior control is unlikely to work');
           end

        end
        
        % Overrule the getEvent function to generate events that carry eye
        % position information.
        function e = getEvent(o)
            e.X = o.cic.eye.x;
            e.Y = o.cic.eye.y;
        end
     end
          
    % This class does not define any new states. State functions
    % methods        
    % end
    
    methods (Access=protected)
        % Helper function to determine whether the eye is in a circular window
        function value= isInWindow(o,e)
            dx = e.X-o.X; 
            tol =o.tolerance.
            if dx < tol
               value = sqrt(dx^2+(e.Y-o.Y)^2)<=tol;
            end
           if o.invert
               value = ~value;
           end
        end
        
       
    end
end