classdef clearScreen < neurostim.stimulus

    
    properties
    end
    
    methods (Access = public)
        function o = clearScreen(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('width',52,'validate',@isnumeric);
            o.addProperty('height',52,'validate',@isnumeric);
        end

        function beforeFrame(o)
            borders = [-o.width/2 -o.height/2 o.width/2 o.height/2]; % left, top, right, bottom borders of a rectangular area to fill      
            %Draw
            Screen('FillRect',o.window,o.color,borders);
        end
        
                      
    end
        
end