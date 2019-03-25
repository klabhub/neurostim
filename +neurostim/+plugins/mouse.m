classdef mouse < neurostim.plugin
  % Generic mouse class.
  %
  % Properties:
  %
  %   x,y,z - coordinates of the mouse
  %   buttons - state of the buttons
  
  % 2019-03-25 - Shaun L. Cloherty <s.cloherty@ieee.org>
        
  properties
    x@double = NaN; 
    y@double = NaN;
    z@double = NaN;
  
    buttons@logical;
    
    valid@logical = true;  % valid=false signals a temporary absence of data (due to a blink for instance)
  end
    
  methods
    function o = mouse(c)
      o = o@neurostim.plugin(c,'mouse'); % always 'mouse', accessed through cic.mouse
            
      o.addProperty('hardwareModel','');
      o.addProperty('softwareVersion','');

      o.addProperty('tolerance',3); % used to set default tolerance on behaviours
    end
        
    function afterFrame(o)
      [x,y,buttons] = o.cic.getMouse; % position in physical screen units

      o.x = x;
      o.y = y;
      
      o.buttons = buttons;
    end  
  end
    
end
