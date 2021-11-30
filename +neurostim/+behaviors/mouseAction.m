classdef (Abstract) mouseAction  < neurostim.behavior 
  % An abstract class to simplify creation of mouse related behaviours.

  % 2019-03-11 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  methods (Access = public)
    % constructor
    function o = mouseAction(c,name)
      o = o@neurostim.behavior(c,name);
      o.addProperty('X',0,'validate',@isnumeric); % X,Y - the position of a target for the behaviour
      o.addProperty('Y',0,'validate',@isnumeric);
      
      o.addProperty('tolerance',1.0,'validate',@isnumeric);  % window radius (typically around X,Y)

      o.addProperty('invert',false,'validate',@isnumeric); % invert the meaning of "in the window"
    end
        
    % override the getEvent method to generate events that carry mouse
    % position and button state information.
    function e = getEvent(o)
      e = neurostim.event;
  
      e.X = o.cic.mouse.x;
      e.Y = o.cic.mouse.y;
      
      e.isBitHigh = o.cic.mouse.buttons; % TODO: not sure how to handle button events
      
      e.valid = o.cic.mouse.valid;
    end
  end
    
  methods (Access = protected)
    % Helper function to determine whether the mouse is in a circular
    % window around (o.X,o.Y).
    %
    % A different position can be checked by specifying the optional third
    % input argument. A different tolerance can be checked by specifying
    % the optional forth input argument.
    function value = isInWindow(o,e,XY,tol)
      if ~e.valid
        value = true; % benefit of the doubt?
        return;
      end
            
      nin = nargin;
      if nin < 3 || isempty(XY)
        XY = [o.X o.Y];
      end
      if nin < 4 || isempty(tol)
        tol = o.tolerance;
      end
            
      nrPos = size(XY,1);
      distance = sqrt(sum((repmat([e.X e.Y],[nrPos 1])-XY).^2,2));
      value = any(distance < tol);

      if o.invert
        value = ~value;
      end
    end
    
    % Helper function to determine whether a mouse button has been clicked.
    %
    % One or more specific buttons can be tested by specifying the optional
    % third input argument.
    function value = isButtonClicked(o,e,id)
      if ~e.valid
        value = false; % false -ve's are preferable to false +ve's?
        return;
      end
      
      if nargin < 3
        id = true(size(e.isBitHigh));
      end
      
      value = any(e.isBitHigh(id));
    end
  
  end % methods

end % classdef