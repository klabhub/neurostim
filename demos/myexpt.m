classdef myexpt < neurostim.plugin
    
    methods
        function o = myexpt
            o = o@neurostim.plugin('myexpt');
            o.listenToEvent({'AFTERFRAME'});
            o.listenToKeyStroke({'z','p'},{'nxt trial','y =60'});
        end
        
        
        
        function afterFrame(o,c,evt)            
            if iseven(floor(c.frame/30))
                c.gabor.orientation = 30;
            else
                c.gabor.orientation = -30;
            end
            
        end
        
        % Keyboard handling, separate from the stimuli in use. (but with
        % access to the stimuli)
        function keyboard(o,key,time)
            switch upper(key)
                case 'Z'
                    %write
                    o.cic.fix.color = []
                case 'P'
                    o.cic.fix.Y = 60;                                        
            end
            
        end
    end
end