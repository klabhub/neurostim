classdef eyetracker < neurostim.plugin

properties 
    x@double;
    y@double;
    z@double;
    size@double;
    useMouse@logical=false;
end
methods
    function o= eyetracker
        o = o@neurostim.plugin('eye'); % Always eye such that it can be accessed through cic.eye
        o.listenToEvent ('AFTERFRAME');
    end
    
    
    function events(o,src,evt)
        if o.useMouse && strcmpi(evt.EventName,'AFTERFRAME')
           [mouseX,mouseY] = GetMouse(o.cic.window);
            o.x=mouseX;
            o.y=mouseY; 
        end
    end
    
end
end