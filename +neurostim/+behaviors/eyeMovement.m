 classdef (Abstract) eyeMovement  < neurostim.behavior    % This is an abstract class that sets up some functionality used for
    % This is an abstract base class with some helper functions that simplifies
    % defining derived classes.
    %
    % This class does not define any actual states. That's why it is Abstract
    % see behaviors.fixate for a derived class that does define staes.
    %
    %
    % % By setting o.allowBlinks to true, blinks can be allowed during the
    % trial. In that case, states do not change during a blink. Note that
    % simply closing ones eyes would also be considered a "blink" allowing
    % the subject to stay in a state forever. For this reason state
    % transitions based on time should normally precede transitions based
    % on blinks. (See derived classes for examples). If it very important
    % to allow blinks and avoid this limitation, a new blink state would
    % have to be created (presumably one that would allow a return only to
    % the state from whence it came). Most tasks will have
    % allowBlinks=false and ask subjects to blink in the ITI.
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
            o.addProperty('allowBlinks',false,'validate',@islogical);
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
            e.valid = o.cic.eye.valid; % valid==false means a blink
        end
    end
    
    
    methods (Access = protected)
        % Helper function to determine whether the eye is in a circular window
        % around o.X, o.Y. A different position can be checked the same way
        % by specifying the optional third input argument. A different
        % tolerance can be checked by specifying the optional forth input
        % argument.
        % OUTPUT
        % value =  wheter in the window or not.
        % allowedBlink  = currenty in a blink and blinks are allowed.
        function [value,allowedBlink] = isInWindow(o,e,XY,tol)
            if ~e.valid
                 allowedBlink = o.allowBlinks;
                 value= false;
            else
                allowedBlink = false;
                nin = nargin;
                if nin < 3 || isempty(XY)
                    XY = [o.X o.Y];
                end
                if nin < 4 || isempty(tol)
                    tol = o.tolerance;
                end
                
                nrXPos = size(XY,1);
                distance = sqrt(sum((repmat([e.X e.Y],[nrXPos 1])-XY).^2,2));
                value = any(distance < tol);

                if o.invert
                    value = ~value;
                end                
            end
        end       
    end
end