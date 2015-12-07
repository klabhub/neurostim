classdef eyetracker < neurostim.plugin

properties (Access=public)
    x@double;
    y@double;
    z@double;
    pupilSize@double;
    useMouse@logical=false;
    keepExperimentSetup@logical=true;
end

methods
    function o= eyetracker
        o = o@neurostim.plugin('eye'); % Always eye such that it can be accessed through cic.eye
        o.listenToEvent('AFTERFRAME');
        o.addProperty('eyeClockTime',[]);
        o.addProperty('hardwareModel',[]);
        o.addProperty('sampleRate',1000,[],@isnumeric);
        o.addProperty('backgroundColor',[]);
        o.addProperty('foregroundColor',[]);
        o.addProperty('clbTargetColor',[]);
        o.addProperty('clbTargetSize',[]);
        o.addProperty('eyeToTrack','left');
    end
    
    function trackedEye(o)
        if ischar(o.eyeToTrack)
            switch lower(o.eyeToTrack)
                case {'left','l'}
                    o.eyeToTrack = 0;
                case {'right','r'}
                    o.eyeToTrack = 1;
                case {'binocular','b','binoc'}
                    o.eyeToTrack = 2;
            end
        end
    end
    
    function [x,y] = mouseConnection(o,c)
        if o.useMouse
            %use the inbuilt mouse function
           [x,y] = c.getMouse;
        end
    end
    
    function afterFrame(o,c,evt)
        if o.useMouse
            [x,y,buttons] = c.getMouse;
            if buttons(1)
                o.x=x;
                o.y=y;
            end
        end
    end
    
end
end