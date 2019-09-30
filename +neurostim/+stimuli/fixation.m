classdef fixation < neurostim.stimulus
    % Class for drawing a fixation point in the PTB.
    %
    % Adjustable variables:
    %   size - with relation to the 'physical' size of the window.
    %   size2 - second required size, i.e. width of oval, inner star/donut size.
    %   color2 - color of inner donut.
    %   shape - one of CIRC, RECT, TRIA, DONUT, OVAL, STAR
    
    properties
    end
    

    methods (Access = public)
        function o = fixation(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('size',15,'validate',@isnumeric);
            o.addProperty('size2',5,'validate',@isnumeric);
            o.addProperty('color2',[0 0 0],'validate',@isnumeric);
            o.addProperty('shape','CIRC','validate',@(x)(ismember(upper(x),{'CIRC','RECT','TRIA','DONUT','OVAL','STAR','FRAME'}))) ;               
            
            o.on = 0;
        end
        
        
        function beforeFrame(o)
            locSize = o.size; % Local copy, to prevent repeated expensive "getting" of NS param          
            switch upper(o.shape)  
                 case 'FRAME' % Rectangle 
                    locSize2 = o.size2;
                    % This draws a frame using lines. The FrameRect command
                    % (below) did not work on our vPixx monitor. Don't
                    % understand why, but this works .
                    Screen('DrawLine', o.window,o.color, -(locSize/2),-(locSize2/2),-(locSize/2),+(locSize2/2));
                    Screen('DrawLine', o.window,o.color, -(locSize/2),+(locSize2/2),+(locSize/2),+(locSize2/2));
                    Screen('DrawLine', o.window,o.color, +(locSize/2),+(locSize2/2),+(locSize/2),-(locSize2/2));
                    Screen('DrawLine', o.window,o.color, +(locSize/2),-(locSize2/2),-(locSize/2),-(locSize2/2));
                    %Screen('FrameRect', o.window, o.color,[-(locSize/2) -(locSize2/2) (locSize/2) (locSize2/2)]);                                 
                case 'RECT' % Rectangle 
                    locSize2 = o.size2;
                    Screen('FillRect', o.window, o.color,[-(locSize/2) -(locSize2/2) (locSize/2) (locSize2/2)]);                    
                case 'CIRC' % Circle
                    Screen('FillOval', o.window,o.color,[-(locSize/2) -(locSize/2) (locSize/2) (locSize/2)]); % With antialiasing.                    
                case 'DONUT' % DONUT
                    locSize2 = o.size2;
                    Screen('FillOval', o.window,o.color, [-(locSize/2) -(locSize/2) (locSize/2) (locSize/2)]);  
                    Screen('FillOval', o.window,o.color2, [-(locSize2/2) -(locSize2/2) (locSize2/2) (locSize2/2)]);                                
                case 'TRIA'  %Oriented triangle                 
                    % This rotation does not work: (it rotates the o.Y
                    % too...)
                    %Screen('glRotate', o.window, o.angle+90, 0, 0, 1) ;  %0.angle = 0 ->points rightward
                    x = [-0.5*locSize 0 0.5*locSize];
                    y = [-0.5*locSize +0.5*locSize -0.5*locSize];
                   Screen('FillPoly',o.window,o.color,[x' y'],1);                           
                case 'OVAL' % oval
                    locSize2 = o.size2;
                    x = [-(locSize/2) (locSize/2)];
                    y = [-(locSize2/2) (locSize2/2)];
                    Screen('FillOval', o.window, o.color, [x(1) y(1) x(2) y(2)]);
%                     Screen('glLoadIdentity',o.cic.window);
                case 'STAR' % Five-pointed star, oriented with point upward.
                    anglesDeg = linspace(90,360+90,11);
                    radius2 = .5*(3-sqrt(5))*locSize;
                    radiustot = [repmat([locSize radius2],1,5) locSize];
                    x = cosd(anglesDeg).*radiustot;
                    y = sind(anglesDeg).*radiustot;
                    Screen('FillPoly',o.window, o.color, [x;y]', 0);

            end
        end
        
        
        
    end
end