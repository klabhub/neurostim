classdef arc < neurostim.stimulus
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
    %
    % The 'color' can be modulated sinusoidally using the following
    % parameters:  color =  o.color*(1+amplitude*sind(phase+360*time*frequency/1000)
    %  frequency = sinusoidal flicker frequency in Hz  [0].
    %  phase - phase of the flicker in degrees. [0]
    % amplitude - amplitude of the flicker.  [Default is 0: no flicker]
    % 
    % Calculating the new color from the paramets on each frame is a time
    % consuming operation (reading the parameters mainly). So if you know
    % that the parameters do not change with in a trial, you can pre-compute the
    % sinusoid before the trial by setting preCalc to true. [Default is
    % false]
    %
    properties
        %colorPerFrame;
        %nrFramesPreCalc;
    end
    
    methods (Access = public)
        function o = arc(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('filled',false,'validate',@islogical);
            o.addProperty('linewidth',10,'validate',@isnumeric); %Used only for unfilled polygon.
            o.addProperty('startAngle',0,'validate',@isinteger); %[deg] from horizontal, CCW
            o.addProperty('arcAngle',60,'validate',@isinteger); %[deg]
            o.addProperty('innerRad',0,'validate',@isnumeric);
            o.addProperty('outerRad',10,'validate',@isnumeric);
            
            %o.addProperty('preCalc',false);
        end
        
        function beforeTrial(o)
        end
        
        
        function beforeFrame(o)
 
%             %% implementation 1: polygon
%             nSides = 360;
%             th = 2*pi/360*linspace(0 + o.startAngle,360 + o.startAngle,nSides+1);
%             %th = th(2:end);
%             if o.innerRad == 0
%                 vx_inner = 0; vy_inner = 0;
%             else
%                 [vx_inner, vy_inner] = pol2cart(th(1:o.arcAngle),o.innerRad);
%             end
%             [vx_outer, vy_outer] = pol2cart(th(1:o.arcAngle),o.outerRad);
%             
%             vx = [vx_inner fliplr(vx_outer) vx_inner(1)];
%             vy = [vy_inner fliplr(vy_outer) vy_inner(1)];
%           
%             %Draw
%             if o.filled
%                 Screen('FillPoly',o.window, o.color,[vx(:),vy(:)],0);
%             else
%                 Screen('FramePoly',o.window, o.color,[vx(:),vy(:)],o.linewidth);
%             end
            
            %% implementation 2: arc
            rect = [];
            o.color = [1 1 0];
            o.filled = true;
            %Draw
            if o.filled
                Screen('FillArc',o.window, o.color,rect,o.startAngle, o.arcAngle);
            else
                Screen('DrawArc',o.window, o.color,rect,o.startAngle, o.arcAngle);
            end
            
        end
    end
end