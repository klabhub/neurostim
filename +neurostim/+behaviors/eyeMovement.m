classdef (Abstract) eyeMovement  < neurostim.behavior    % This is an abstract class that sets up some functionality used for
    % This is an abstract base class with some helper functions that simplifies
    % defining derived classes. 
    %
    % This class does not define any actual states. That's why it is Abstract
    % see behaviors.fixate for a derived class that does define staes.
    % 
    % BK - July 2018
    
     methods (Access=public)  % Derived classes can overrule these if needed
        % Constructor
        function o = eyeMovement(c,name)
           o = o@neurostim.behavior(c,name);   
           o.addProperty('X',0,'validate',@isnumeric); % X,Y,Z - the position of a target for the behaviour (e.g. fixation point)
           o.addProperty('Y',0,'validate',@isnumeric);
           o.addProperty('Z',0,'validate',@isnumeric);
           if hasPlugin(c,'eye')
               defaultTolerance = c.eye.tolerance;
           else
                defaultTolerance = 3;
           end
           o.addProperty('tolerance',defaultTolerance,'validate',@isnumeric);  % tolerance is the window size         
           o.addProperty('invert',false,'validate',@isnumeric); %Invert the meaning of "in the window'
           if ~hasPlugin(c,'eye')
               warning('No eye data in CIC. This behavior control is unlikely to work');
           end
        end
        
        % Overrule the getEvent function to generate events that carry eye
        % position information.
        function e = getEvent(o)
            e = neurostim.event;  % Create an object of event type
            e.X = o.cic.eye.x;  % Fill it with relevant data from the eye tracker.
            e.Y = o.cic.eye.y;
            e.valid = o.cic.eye.valid; % To detect blinks
        end
     end
          
    
    methods (Access=protected)
        % Helper function to determine whether the eye is in a circular window
        % around o.X, o.Y. A different position can be checked the same way
        % by specifying the optional third input argument.
        function value= isInWindow(o,e,XY)
            if ~e.valid
                value = true; % Benefit of the doubt
                return;
            end
            nin=nargin;
            if nin < 3
                XY = [o.X o.Y];                
            end
            
            nrXPos = size(XY,1); 
            distance = sqrt(sum((repmat([e.X e.Y],[nrXPos 1])-XY).^2,2));            
            value= any(distance< o.tolerance);
            if o.invert
               value = ~value;
            end
        end        
    end
end