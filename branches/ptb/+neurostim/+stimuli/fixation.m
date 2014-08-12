classdef fixation < neurostim.stimulus
    properties
        
    end
    methods (Access = public)
        function o = fixation(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('size',[5,10,15,20,25,30,35,40,45,50]) ;     %Size property...Call o.size(multiple of 5) for the size desired.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
                                                                       % Ex: o.size(6) = 30                                                              
            o.addProperty('shape','CIRC') ;   
            o.addProperty('angle', [10,20,30,40,50,60,70,80,90,100]);  % Same as size, except multiples of 10
   
            o.on = 0;
            o.listenToEvent({'BEFOREFRAME','AFTERFRAME'});
            o.X = 0; % X coordinate for top left of screen
            o.Y=  0; % Y coordinate for top left of screen  
            o.addProperty('CC',[650,512.5]); %CC= Center Coordinates of o.window
           
        end
        
        function afterFrame(o,c,evt)
           % o.X= o.X +100*(rand-0.5);
        end
        function beforeFrame(o,c,evt)
            
            rct = CenterRect([o.X, o.Y, o.X+o.size(2).*(10), o.Y+o.size(2).*(10)], o.cic.position); %Center a Rectangle on the screen
            
            switch upper(o.shape)
                                   
                case 'RECT'                
                    Screen('FillRect', o.cic.window, [o.color o.luminance],rct);
                    
                case 'CIRC'
                    Screen('glLoadIdentity',o.cic.window);      
                    Screen('glPoint',o.cic.window,[o.color o.luminance],o.CC(1),o.CC(2),o.size(2));
                    Screen('glLoadIdentity',o.cic.window);
                    
                case 'CONCIRC'
                    Screen('glLoadIdentity', o.cic.window);
                    Screen('glPoint',o.cic.window,[o.color o.luminance],o.CC(1),o.CC(2),o.size(4));
                    Screen('glPoint',o.cic.window,[0 1 0], o.CC(1), o.CC(2), o.size(2));
                    Screen('glLoadIdentity', o.cic.window);
                              
                case 'TRIA'  %Creates an upward facing triangle, rotated to the right by 90 deg
                   Screen('glLoadIdentity', o.cic.window);
                   Screen('glTranslate', o.cic.window, o.cic.position(3)/2, o.cic.position(4)/2);
                   Screen('glRotate', o.cic.window, o.angle(9), 0, 0, 1) ;   %Make this general
                  
                   Screen('glTranslate', o.cic.window, -o.cic.position(3)/2, -o.cic.position(4)/2);
                   isConvex = 1;
                   Screen('FillPoly',o.cic.window,[o.color o.luminance],[o.CC(1),o.CC(2)-o.size(3); o.CC(1)-o.size(5),o.CC(2)+o.size(3); o.CC(1)+o.size(5),o.CC(2)+o.size(3);],isConvex);
                   Screen('glLoadIdentity', o.cic.window);                    
                 
                case 'OVAL'                
                   Screen('FillOval', o.cic.window, [o.color o.luminance], rct);
                                                             
                case 'STAR'                 
                   Screen('FramePoly',o.cic.window,[o.color o.luminance],[o.CC(1)-o.size(5),o.CC(2)+o.size(3); o.CC(1)-o.size(1),o.CC(2)-o.size(6); o.CC(1)+o.size(2),o.CC(2)+o.size(3); o.CC(1)-o.size(6),o.CC(2)-o.size(3); o.CC(1)+o.size(3),o.CC(2)-o.size(3);], [3]);  %This should create a star
                      
                             
            end
            %Screen('DrawDots', o.cic.window,[o.X o.Y],o.size,[o.color o.luminance],o.cic.center);
        end
        
        %Do we have to flip the screen after completion??
        
    end
end