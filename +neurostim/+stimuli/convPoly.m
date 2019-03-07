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
    %
    % The 'color' can be modulated sinusoidally using the following
    % parameters:  color =  o.color*(1+amplitude*sind(phase+360*time*frequency/1000)
    %  frequency = sinusoidal flicker frequency in Hz  [0].
    %  phase - phase of the flicker in degrees. [0]
    % amplitude - amplitude of the flicker.  [Default is 0: no flicker]
    %
    properties
    end
    
    methods (Access = public)
        function o = convPoly(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('radius',3,'validate',@isnumeric);
            o.addProperty('nSides',5,'validate',@isnumeric);
            o.addProperty('filled',true,'validate',@islogical);
            o.addProperty('linewidth',10,'validate',@isnumeric); %Used only for unfilled polygon.
            o.addProperty('frequency',0,'validate',@isnumeric); % Hz
            o.addProperty('phase',0,'validate',@isnumeric); % degrees
            o.addProperty('amplitude',0,'validate',@isnumeric); %o.color is the mean, 
        end
        
        function beforeFrame(o)
            %Compute vertices
            th = linspace(0,2*pi,o.nSides+1);
            [vx,vy] = pol2cart(th,o.radius);
            
            if o.amplitude>0
                % Use sinusoidal flicker
                thisColor  = o.color * (1+o.amplitude*sind(o.phase + 360*o.time*(o.frequency/1000)));
            else
                thisColor = o.color;
            end
               
            %Draw
            if o.filled
                Screen('FillPoly',o.window, thisColor,[vx(:),vy(:)],1);
            else
                Screen('FramePoly',o.window, thisColor,[vx(:),vy(:)],o.linewidth);
            end
        end
    end
end