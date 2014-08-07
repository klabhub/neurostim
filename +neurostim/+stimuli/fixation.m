classdef fixation < neurostim.stimulus
    properties
        
    end
    methods (Access = public)
        function o = fixation(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('sizelarge',20) ;
            o.addProperty('sizesmall',5) ;
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
                    Screen('glPoint',o.cic.window,[o.color o.luminance],o.X,o.Y,o.sizelarge);
                    Screen('glLoadIdentity',o.cic.window);
                    
                case 'CONCIRC'
                    Screen('glLoadIdentity', o.cic.window);
                    Screen('glTranslate', o.cic.window, o.cic.position(3)/2, o.cic.position(4)/2);
                    Screen('glPoint',o.cic.window,[o.color o.luminance],o.X,o.Y,o.sizelarge);
                    Screen('glPoint',o.cic.window,[0, 1, 0], o.X, o.Y, o.sizesmall);
                    Screen('glLoadIdentity', o.cic.window);
                    
                case 'TRIA'
                   isConvex = 1;
                   Screen('FillPoly',o.cic.window,[o.color o.luminance],[650,500; 625,525; 675,525;],isConvex);
                        
                case 'TRIAR'
                   Screen('glPushMatrix', o.cic.window);
                   Screen('glTranslate', o.cic.window, o.cic.position(3)/2, o.cic.position(4)/2);
                   Screen('glRotate', o.cic.window, o.angle, 0, 0, 1) ;
                   isConvex = 1;
                   Screen('glTranslate', o.cic.window, -o.cic.position(3)/2, -o.cic.position(4)/2);
                   Screen('FillPoly',o.cic.window,[o.color o.luminance],[650,500; 625,525; 675,525;],isConvex);
                   Screen('glPopmatrix', o.cic.window);
               
                   
                                
                case 'TRIAD'
                   Screen('glPushMatrix', o.cic.window);
                   Screen('glTranslate', o.cic.window, o.cic.position(3)/2, o.cic.position(4)/2);
                   Screen('glRotate', o.cic.window, o.angle, 0, 0, 1) ;
                   Screen('glRotate', o.cic.window, o.angle, 0, 0, 1) ;
                   isConvex = 1;
                   Screen('glTranslate', o.cic.window, -o.cic.position(3)/2, -o.cic.position(4)/2);
                   Screen('FillPoly',o.cic.window,[o.color o.luminance],[650,500; 625,525; 675,525;],isConvex);
                   Screen('glPopmatrix', o.cic.window);
                   
                                
                case 'TRIAL'       
                   Screen('glPushMatrix', o.cic.window);
                   Screen('glTranslate', o.cic.window, o.cic.position(3)/2, o.cic.position(4)/2);
                   Screen('glRotate', o.cic.window, o.angle, 0, 0, 1) ;
                   Screen('glRotate', o.cic.window, o.angle, 0, 0, 1) ;
                   Screen('glRotate', o.cic.window, o.angle, 0, 0, 1) ;
                   isConvex = 1;
                   Screen('glTranslate', o.cic.window, -o.cic.position(3)/2, -o.cic.position(4)/2);
                   Screen('FillPoly',o.cic.window,[o.color o.luminance],[650,500; 625,525; 675,525;],isConvex);
                   Screen('glPopmatrix', o.cic.window);
                                                                      
                case 'OVAL'     
                   rct = CenterRect([0 0 100 100], o.cic.position);
                   Screen('FillOval', o.cic.window, [o.color o.luminance], rct);
                             
                                
                case 'STAR'                 
                   Screen('FramePoly',o.cic.window,[o.color o.luminance],[625,525; 642.5,490; 660,525; 620,505; 665,505;], [3]);  %This should create a star
                      
                    
                    
            end
            %Screen('DrawDots', o.cic.window,[o.X o.Y],o.size,[o.color o.luminance],o.cic.center);
        end
        
        %Do we have to flip the screen after completion??
        
    end
end