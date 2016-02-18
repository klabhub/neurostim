classdef eyetracker < neurostim.plugin
% Generic eyetracker class for PTB.
%
% Properties:
%   To be set by subclass: x,y,z - coordinates of eye position
%                          eyeClockTime - for synchronization
%
%   sampleRate - rate of samples to be taken.
%   backgroundColor - background colour for eyetracker functions.
%   foregroundColor - foreground colour for eyetracker functions.
%   clbTargetColor - calibration target color.
%   clbTargetSize - calibration target size.
%   eyeToTrack - one of 'left','right','binocular' or 0,1,2.
%   useMouse - if set to true, uses the mouse coordinates as eye coordinates.
properties (Access=public)
    useMouse@logical=false;
    keepExperimentSetup@logical=true;
end

properties 
    x@double;
    y@double;
    z@double;
    pupilSize@double;
end

methods
    function o= eyetracker
        o = o@neurostim.plugin('eye'); % Always eye such that it can be accessed through cic.eye
        o.listenToEvent('AFTERFRAME');
        o.addProperty('eyeClockTime',[],[],[],'private');
        o.addProperty('hardwareModel',[]);
        o.addProperty('sampleRate',1000,[],@isnumeric);
        o.addProperty('backgroundColor',[]);
        o.addProperty('foregroundColor',[]);
        o.addProperty('clbTargetColor',[]);
        o.addProperty('clbTargetSize',[]);
        o.addProperty('eyeToTrack','left');
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

methods (Access=protected)
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
    
end
end