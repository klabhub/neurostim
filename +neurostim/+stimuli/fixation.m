classdef fixation < neurostim.stimulus
    properties
        
    end
    methods (Access = public)
        function o = fixation(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('size',10) ;
            o.addProperty('shape','CIRC') ;
            o.addProperty('angle', 90);
            o.on = 0;
            o.listenToEvent({'BEFOREFRAME','AFTERFRAME'});
            o.X = 0;
            o.Y=  0;
            
        end
        
        function afterFrame(o,c,evt)
           % o.X= o.X +100*(rand-0.5);
        end
        function beforeFrame(o,c,evt)
            switch upper(o.shape)
                case 'RECT'
                    rct = CenterRect([0 0 100 100], o.cic.position);
                    Screen('FillRect', o.cic.window, [o.color o.luminance],rct);
                    
                case 'CIRC'
                    Screen('glLoadIdentity',o.cic.window);
                    Screen('glTranslate',o.cic.window,o.cic.position(3)/2,o.cic.position(4)/2);
                    Screen('glPoint',o.cic.window,[o.color o.luminance],o.X,o.Y,o.size);
                    Screen('glLoadIdentity',o.cic.window);
                    
                case 'CONCIRC'
                    Screen('glLoadIdentity', o.cic.window);
                    Screen('glTranslate', o.cic.window, o.cic.position(3)/2, o.cic.position(4)/2);
                    Screen('glPoint',o.cic.window,[o.color o.luminance],o.X,o.Y,o.size);
                    Screen('glPoint',o.cic.window,[0, 1, 0], o.X, o.Y, 5);
                    Screen('glLoadIdentity', o.cic.window);
                    
                case 'TRIA'
                    isConvex = 1;
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[50,0; 0,50; 100,50;],isConvex);
                        
                case 'TRIAR'
                    Screen('glLoadIdentity', o.cic.window);
                    Screen('glRotate', o.cic.window, o.angle, 50, 50);
                    isConvex = 1;
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[50,0; 0,50; 100,50;],isConvex);
                    Screen('glLoadIdentity', o.cic.window);
                                
                case 'TRIAD'
                    Screen('glLoadIdentity', o.cic.window);
                    Screen('glRotate', o.cic.window, o.angle, 50, 50);
                    Screen('glRotate', o.cic.window, o.angle, 50, 50);
                    isConvex = 1;
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[50,0; 0,50; 100,50;],isConvex);
                    Screen('glLoadIdentity', o.cic.window);
                                
                case 'TRIAL'
                    Screen('glLoadIdentity', o.cic.window);
                    Screen('glRotate', o.cic.window, o.angle, 50, 50);
                    Screen('glRotate', o.cic.window, o.angle, 50, 50);
                    Screen('glRotate', o.cic.window, o.angle, 50, 50);
                    isConvex = 1;
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[50,0; 0,50; 100,50;],isConvex);
                    Screen('glLoadIdentity', o.cic.window);                
                                                                      
                case 'OVAL'     
                    rct = CenterRect([0 0 100 100], o.cic.position);
                    Screen('FillOval', o.cic.window, [o.color o.luminance], rct);
                             
                                
                case 'STAR' 
                    rct = CenterRect([0 0 100 100], o.cic.position);
                    isConvex = 0; %The polygon is concave                    
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[0,100; 0,35; 50,0; 100,35; 100,100;],isConvex);  %This should create a star
                                  
                
                    
                    
                    
            end
            %Screen('DrawDots', o.cic.window,[o.X o.Y],o.size,[o.color o.luminance],o.cic.center);
        end
        
        %Do we have to flip the screen after completion??
        
    end
end