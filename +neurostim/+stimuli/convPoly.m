classdef convPoly < neurostim.stimulus
    % Draws an equilateral convex polygon with variable sides.
    % Equilateral convex polygon (e.g. triangle, square, pentagon, hexagon
    % etc.). Can also create a circle if "nSides" is set to a large number.
    % Alternatively, can supply a set of arbitrary vertices to pass to
    % PTB's FillPoly/FramePoly
    %
    % Adjustable variables:
    %   radius - in physical size.
    %   nSides - number of sides.
    %   filled - true or false.
    %   linewidth - only for unfilled polygon, in pixels.
    properties
    end
    
    methods (Access = public)
        function o = convPoly(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('radius',3,'validate',@isnumeric);
            o.addProperty('nSides',5,'validate',@isnumeric);
            o.addProperty('filled',true,'validate',@islogical);
            o.addProperty('linewidth',10,'validate',@isnumeric); %Used only for unfilled polygon.
            o.addProperty('vx',0,'validate',@isnumeric);        %
            o.addProperty('vy',0,'validate',@isnumeric);
        end
        
        function beforeFrame(o)
            
            if isempty(o.vx) 
                %Compute vertices
                th = linspace(0,2*pi,o.nSides+1);
                [o.vx,o.vy] = pol2cart(th,o.radius);
            end
              
            %Draw
            if o.filled
                Screen('FillPoly',o.window, o.color,[o.vx(:),o.vy(:)],1);
            else
                Screen('FramePoly',o.window, o.color,[o.vx(:),o.vy(:)],o.linewidth);
            end
        end
    end
end