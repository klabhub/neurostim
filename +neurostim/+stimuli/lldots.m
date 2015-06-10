classdef lldots < neurostim.stimulus
    properties
    end
    
    methods (Access = public)
        function o = lldots(name)
            o = o@neurostim.stimulus(name);
            o.listenToEvent('BEFOREFRAME');
            o.addProperty('size',5);
            o.addProperty('radius',50);
            o.addProperty('speed',25);
            o.addProperty('nrDots',100);
            o.addProperty('coherence',0.2);
            o.addProperty('direction',0);
        end
        
        function beforeFrame(o,c,evt)
            
            xy = round(o.radius*[cos(o.speed*c.frame) ;sin(o.speed*c.frame)]);
            white = WhiteIndex(o.cic.window);
            Screen('DrawDots', o.cic.window,xy,o.size,white,o.cic.center);
            xy = round(o.radius*[cos(-o.speed*c.frame) ;sin(-o.speed*c.frame)]);
            
            if isprop(o.cic,'eye')
                ref= [o.cic.eye.x o.cic.eye.y];
            else
                ref= o.cic.center;
            end
            Screen('DrawDots', o.cic.window,xy,o.size,white,ref);
            
        end
    end
end