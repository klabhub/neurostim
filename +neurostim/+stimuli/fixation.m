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
            o.addProperty('shape','CIRC','validate',@(x)(ismember(upper(x),{'CIRC','RECT','TRIA','DONUT','OVAL','STAR'}))) ;               
            o.listenToEvent('BEFOREFRAME');
            o.on = 0;
        end
        
        
        function beforeFrame(o)
            switch upper(o.shape)                                   
                case 'RECT' % Rectangle                
                    Screen('FillRect', o.window, o.color,[-(o.size/2) -(o.size2/2) (o.size/2) (o.size2/2)]);                    
                case 'CIRC' % Circle
                    Screen('FillOval', o.window,o.color,[-(o.size/2) -(o.size/2) (o.size/2) (o.size/2)]); % With antialiasing.                    
                case 'DONUT' % DONUT
                    Screen('FillOval', o.window,o.color, [-(o.size/2) -(o.size/2) (o.size/2) (o.size/2)]);  
                    Screen('FillOval', o.window,o.color2, [-(o.size2/2) -(o.size2/2) (o.size2/2) (o.size2/2)]);                                
                case 'TRIA'  %Oriented triangle                 
                    % This rotation does not work: (it rotates the o.Y
                    % too...)
                    %Screen('glRotate', o.window, o.angle+90, 0, 0, 1) ;  %0.angle = 0 ->points rightward
                    x = [-0.5*o.size 0 0.5*o.size];
                    y = [-0.5*o.size +0.5*o.size -0.5*o.size];
                   Screen('FillPoly',o.window,o.color,[x' y'],1);                           
                case 'OVAL' % oval
                    x = [-(o.size/2) (o.size/2)];
                    y = [-(o.size2/2) (o.size2/2)];
                    Screen('FillOval', o.window, o.color, [x(1) y(1) x(2) y(2)]);
%                     Screen('glLoadIdentity',o.cic.window);
                case 'STAR' % Five-pointed star, oriented with point upward.
                    anglesDeg = linspace(90,360+90,11);
                    radius2 = .5*(3-sqrt(5))*o.size;
                    radiustot = [repmat([o.size radius2],1,5) o.size];
                    x = cosd(anglesDeg).*radiustot;
                    y = sind(anglesDeg).*radiustot;
                    Screen('FillPoly',o.cic.window, o.color, [x;y]', 0);

            end
        end
        
        
        
    end
end