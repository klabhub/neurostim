classdef convPoly < neurostim.stimulus
    % Draws an equilateral convex polygon with variable sides.
    % Equilateral convex polygon (e.g. triangle, square, pentagon, hexagon
    %etc.). Can also create a circle if "nSides" is set to a large number.
    %
    % Adjustable variables:
    %   radius - in physical size.
    %   nSides - number of sides.
    %   filled - true or false.
    %   linewidth - only for unfilled polygon, in pixels.
    properties
    end
    
    methods (Access = public)
        function o = convPoly(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('radius',3,[],@isnumeric);
            o.addProperty('nSides',5,[],@isnumeric);
            o.addProperty('filled',true,[],@islogical);
            o.addProperty('linewidth',10,[],@isnumeric); %Used only for unfilled polygon.
            o.listenToEvent('BEFOREFRAME');
        end
        
        function beforeFrame(o,c,evt)
            %Compute vertices
            th = linspace(0,2*pi,o.nSides+1);
            [vx,vy] = pol2cart(th,o.radius);
            
            %Draw
            if o.filled
                Screen('FillPoly',o.cic.window, o.color,[vx',vy'],1);
            else
                Screen('FramePoly',o.cic.window, o.color,[vx',vy'],o.linewidth);
            end
        end
    end
end