classdef convPoly < neurostim.stimulus
    properties
    end
    
    methods (Access = public)
        function o = convPoly(name)
            o = o@neurostim.stimulus(name);
            o.addProperty('radius',3);
            o.addProperty('nSides',5);
            o.listenToEvent('BEFOREFRAME');
        end
        
        function beforeFrame(o,c,evt)
            %Insert drawing commands here.
            th = linspace(0,2*pi,o.nSides+1);
            [vx,vy] = pol2cart(th,o.radius);
            Screen('FillPoly',o.cic.window, [o.color o.luminance],[vx',vy'],1); 
        end
    end
end