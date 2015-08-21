classdef convPoly < neurostim.stimulus
    %Equilateral convex polygon (e.g. triangle, square, pentagon, hexagon
    %etc.). Can also create a circle if "nSides" is set to a large number.
    properties
    end
    
    methods (Access = public)
        function o = convPoly(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('radius',3);
            o.addProperty('nSides',5);
            o.addProperty('filled',true);
            o.addProperty('linewidth',10); %Used only for unfilled polygon.
            o.listenToEvent('BEFOREFRAME');
        end
        
        function beforeFrame(o,c,evt)
            %Compute vertices
            th = linspace(0,2*pi,o.nSides+1);
            [vx,vy] = pol2cart(th,o.radius);
            
            %Draw
            if o.filled
                Screen('FillPoly',o.cic.window, [o.color o.luminance],[vx',vy'],1);
            else
                Screen('FramePoly',o.cic.window, [o.color o.luminance],[vx',vy'],o.linewidth);
            end
        end
    end
end