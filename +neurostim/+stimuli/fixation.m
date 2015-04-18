classdef fixation < neurostim.stimulus
    properties
        
    end
    methods (Access = public)
        function o = fixation(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('size',5);
            o.addProperty('size2',5);
            o.addProperty('color2',[0 0]);
            o.addProperty('luminance2',0);
            o.addProperty('shape','CIRC','',@(x)(ismember(upper(x),{'CIRC','RECT','TRIA','DONUT','OVAL','STAR'}))) ;   
            o.addProperty('angle', 0);              
            o.listenToEvent({'BEFOREFRAME'});
            o.X = 0; 
            o.Y=  0; 
            o.on = 0;
        end
        
        function beforeFrame(o,c,evt)
            switch upper(o.shape)                                   
                case 'RECT' % Rectangle                
                    rct = CenterRect([o.X, o.Y, o.X+o.size, o.Y+o.size], o.cic.position); %Center a Rectangle on the screen
                    Screen('FillRect', o.cic.window, [o.color o.luminance],rct);                    
                case 'CIRC' % Circle
                    Screen('DrawDots', o.cic.window,[o.X o.Y],o.size,[o.color o.luminance],o.cic.center);                    
                case 'DONUT' % DONUT
                    Screen('DrawDots', o.cic.window,[o.X o.Y],o.size,[o.color o.luminance],o.cic.center);  
                    Screen('DrawDots', o.cic.window,[o.X o.Y],o.size2,[o.color2 o.luminance2],o.cic.center);                                
                case 'TRIA'  %Oriented triangle
                    Screen('glLoadIdentity', o.cic.window);
                    Screen('glTranslate', o.cic.window,o.cic.center(1),o.cic.center(2));                   
                    % This rotation does not work: (it rotates the o.Y
                    % too...)
                    %Screen('glRotate', o.cic.window, o.angle+90, 0, 0, 1) ;  %0.angle = 0 ->points rightward
                    isConvex = 1;
                    x = o.X + [-0.5*o.size 0 0.5*o.size];
                    y = o.Y + [-0.5*o.size +0.5*o.size -0.5*o.size];
                   Screen('FillPoly',o.cic.window,[o.color o.luminance],[x' y'],isConvex);
                   Screen('glLoadIdentity', o.cic.window);                                     
                case 'OVAL'                                  
                case 'STAR'                                       
                             
            end
        end
        
        
    end
end