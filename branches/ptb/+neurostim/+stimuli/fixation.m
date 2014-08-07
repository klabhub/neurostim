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
                    Screen('glPoint',o.cic.window,[o.color o.luminance],o.X,o.Y,o.size);
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
                  
                    isConvex = 1;
                   
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[660,512.5; 625,525; 625,500;],isConvex);
               
                   
                                
                case 'TRIAD'
                    isConvex = 1;
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[642.5,525; 625,500; 660,500],isConvex);
                   
                                
                case 'TRIAL'
                    isConvex = 1;
                    Screen('FillPoly',o.cic.window,[o.color o.luminance],[625,512.5; 660,500; 660,525],isConvex);
                              
                                                                      
                case 'OVAL'     
                    rct = CenterRect([0 0 100 100], o.cic.position);
                    Screen('FillOval', o.cic.window, [o.color o.luminance], rct);
                             
                                
                case 'STAR' 
                                   
                    Screen('FramePoly',o.cic.window,[o.color o.luminance],[625,525; 642.5,490; 660,525; 620,505; 665,505;]);  %This should create a star
                
                %{    
                case 'TRIA2'
                    posXs = [screenXpixels * 0.25 screenXpixels * 0.5 screenXpixels * 0.75];
                    posYs = ones(1, numRects) .* (screenYpixels / 2);
                    posX = posXs(i);
                    posY = posYs(i);
                    
                    while ~kbCheck
                        
                        Screen('glPushMatrix', o.cic.window)
                        Screen('glTranslate', o.cic.window, posX, posY)
                        Screen('glRotate', o.cic.window, o.angle, 0, 0);
                        Screen('glTranslate', o.cic.window, -posX, -posY)
                         isConvex = 1;
                        Screen('FillPoly',o.cic.window,[o.color o.luminance],[650,500; 625,525; 675,525;],isConvex);
                        Screen('glPopMatrix', o.cic.window)
                        
                    end 
                    
                    %}
                    
                    
            end
            %Screen('DrawDots', o.cic.window,[o.X o.Y],o.size,[o.color o.luminance],o.cic.center);
        end
        
        %Do we have to flip the screen after completion??
        
    end
end