classdef fixation < neurostim.stimulus
    properties
        
    end
    methods (Access = public)
        function o = fixation(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('size',10) ;
            o.addProperty('shape','CIRC') ;
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
                    
            end
            %Screen('DrawDots', o.cic.window,[o.X o.Y],o.size,[o.color o.luminance],o.cic.center);
        end
        
        
        
    end
end