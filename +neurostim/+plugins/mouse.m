classdef mouse < neurostim.plugin
  % Generic mouse class.
  %
  % Properties:
  %
  %   x,y,z - coordinates of the mouse
  %   buttons - state of the buttons
  
  % 2019-03-25 - Shaun L. Cloherty <s.cloherty@ieee.org>
        
  properties
    x= NaN; 
    y= NaN;
    z= NaN;
  
    buttons;
    
    valid= true;  % valid=false signals a temporary absence of data
  end
    
  properties (Dependent)
    button1;
    button2;
  end
  
  methods
    function o = mouse(c)
      o = o@neurostim.plugin(c,'mouse'); % always 'mouse', accessed through cic.mouse
            
      o.addProperty('hardwareModel','');
      o.addProperty('softwareVersion','');
      
      o.addProperty('logXY',false,'validate',@islogical);
      o.addProperty('xy',[],'validate',@isnumeric);
    end
        
    function afterFrame(o)
      [thisX,thisY,bttons] = o.cic.getMouse; % position in physical screen units

      o.x = thisX;
      o.y = thisY;
      
      o.buttons = bttons;
      
      if o.logXY
        o.xy = [thisX, thisY];
      end
    end  
  end
    
  methods % get methods
    function v = get.button1(o)
      v = o.buttons(1);
    end
    
    function v = get.button2(o)
      v = o.buttons(2);
    end
  end
  
end % classdef
