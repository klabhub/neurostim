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
           o.addProperty('tolerance',1,'validate',@isnumeric);  % tolerance is the window size         
           o.addProperty('invert',false,'validate',@isnumeric); %Invert the meaning of "in the window'
           if ~hasPlugin(c,'eye')
               warning(c,'No eye data in CIC. This behavior control is unlikely to work');
           end
        end
        
        % Overrule the getEvent function to generate events that carry eye
        % position information.
        function e = getEvent(o)
            e = neurostim.event;  % Create an object of event type
            e.X = o.cic.eye.x;  % Fill it with relevant data from the eye tracker.
            e.Y = o.cic.eye.y;
        end
     end
          
    
    methods (Access=protected)
        % Helper function to determine whether the eye is in a circular window
        % around o.X, o.Y. A different position can be checked the same way
        % by specifying the optional third and fourth input argument.
        function value= isInWindow(o,e,X,Y)
            nin=nargin;
            if nin < 4
                Y = o.Y;
                if nin < 3
                    X = o.X;
                end
            end
            nrXPos = numel(X);  % X and Y could have multiple targets( they have to match in numels)
            distance = sqrt(sum((repmat([e.X e.Y],[nrXPos 1])-[X(:)' Y(:)']).^2,2));            
            value= any(distance< o.tolerance);
            if o.invert
               value = ~value;
            end
        end        
    end
end