classdef fixation < neurostim.stimulus
    properties
    end
    

    methods (Access = public)
        function o = fixation(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('size',15);
            o.addProperty('size2',5);
            o.addProperty('color2',[0 0]);
            o.addProperty('luminance2',0);
            o.addProperty('shape','CIRC','',@(x)(ismember(upper(x),{'CIRC','RECT','TRIA','DONUT','OVAL','STAR'}))) ;               
            o.listenToEvent({'BEFOREFRAME','BEFOREEXPERIMENT'});
            o.on = 0;
        end
        
        function beforeExperiment(o,c,evt)
            if (c.screen.physical(1) ~= c.screen.pixels(3)) && sum(strcmp('size',c.(o.name).log.parms))==1
                o.size = o.size*c.screen.physical(1)/c.screen.pixels(3);
            end
        end

        
        function beforeFrame(o,c,evt)
            switch upper(o.shape)                                   
                case 'RECT' % Rectangle                
                    Screen('FillRect', o.cic.window, [o.color o.luminance],[-(o.size/2) -(o.size2/2) (o.size/2) (o.size2/2)]);                    
                case 'CIRC' % Circle
                    Screen('FillOval', o.cic.window,[o.color o.luminance],[-(o.size/2) -(o.size/2) (o.size/2) (o.size/2)]); % With antialiasing.                    
                case 'DONUT' % DONUT
                    Screen('FillOval', o.cic.window,[o.color o.luminance], [-(o.size/2) -(o.size/2) (o.size/2) (o.size/2)]);  
                    Screen('FillOval', o.cic.window,[o.color2 o.luminance2], [-(o.size2/2) -(o.size2/2) (o.size2/2) (o.size2/2)]);                                
                case 'TRIA'  %Oriented triangle                 
                    % This rotation does not work: (it rotates the o.Y
                    % too...)
                    %Screen('glRotate', o.cic.window, o.angle+90, 0, 0, 1) ;  %0.angle = 0 ->points rightward
                    x = [-0.5*o.size 0 0.5*o.size];
                    y = [-0.5*o.size +0.5*o.size -0.5*o.size];
                   Screen('FillPoly',o.cic.window,[o.color o.luminance],[x' y'],1);                           
                case 'OVAL' % oval
                    x = [-(o.size/2) (o.size/2)];
                    y = [-(o.size2/2) (o.size2/2)];
                    Screen('FillOval', o.cic.window, [o.color o.luminance], [x(1) y(1) x(2) y(2)]);
%                     Screen('glLoadIdentity',o.cic.window);
                case 'STAR' % Five-pointed star, oriented with point upward.
                    anglesDeg = linspace(90,360+90,11);
                    radius2 = .5*(3-sqrt(5))*o.size;
                    radiustot = [repmat([o.size radius2],1,5) o.size];
                    x = cosd(anglesDeg).*radiustot;
                    y = sind(anglesDeg).*radiustot;
                    Screen('FillPoly',o.cic.window, [o.color o.luminance], [x;y]', 0);

            end
        end
        
        
        
    end
end