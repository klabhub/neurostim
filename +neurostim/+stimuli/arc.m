classdef arc < neurostim.stimulus
% Draws a filled or framed arc inscribed within the rect. ‘color’ is the clut index (scalar
% or [r g b a] triplet) that you want to poke into each pixel; default produces
% black with the standard CLUT for this window’s pixelSize. Angles are 
% measured clockwise from vertical.
    
    properties
    end
    
    methods (Access = public)
        function o = arc(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('filled',false,'validate',@islogical);
            o.addProperty('linewidth',10,'validate',@isnumeric); %Used only for unfilled polygon.
            o.addProperty('startAngle',0,'validate',@isinteger); %[deg] 
            o.addProperty('arcAngle',60,'validate',@isinteger); %[deg]
            o.addProperty('outerRad',10,'validate',@isnumeric);
        end
        
        function beforeTrial(o)
        end
        
        
        function beforeFrame(o)
          
            rect = [-o.outerRad -o.outerRad o.outerRad o.outerRad]';%left bottom right top
            
            %Draw
            if o.filled
                Screen('FillArc',o.window, o.color,rect,o.startAngle, o.arcAngle);
            else
                Screen('FrameArc',o.window, o.color,rect,o.startAngle, o.arcAngle, o.linewidth, o.linewidth);
            end
            
        end
    end
end