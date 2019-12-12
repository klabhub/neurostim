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
%
% Keyboard:
%   Pressing 'w' simulates a 200 ms eye blink
    
    
    properties (Access=public)
        useMouse =false;
        keepExperimentSetup =true;
        eye='LEFT'; %LEFT,RIGHT, or BOTH
        tmr; %@timer
    end
    
    properties
        x=NaN; % Should have default values, otherwise bhavior checking can fail.
        y=NaN;
        z=NaN;
        pupilSize;
        valid= true;  % valid=false signals a temporary absence of data (due to a blink for instance)
    end
    
    methods
        function o= eyetracker(c)
            o = o@neurostim.plugin(c,'eye'); % Always eye such that it can be accessed through cic.eye
            
            o.addProperty('eyeClockTime',[]);
            o.addProperty('hardwareModel','');
            o.addProperty('softwareVersion','');
            o.addProperty('sampleRate',1000,'validate',@isnumeric);
            o.addProperty('backgroundColor',[]);
            o.addProperty('foregroundColor',[]);
            o.addProperty('clbTargetColor',[1,0,0]);
            o.addProperty('clbTargetSize',0.25);
            o.addProperty('continuous',false);
            
            o.addKey('w','Toggle Blink');
            o.tmr = timer('name','eyetracker.blink','startDelay',200/1000,'ExecutionMode','singleShot','TimerFcn',{@o.openEye});
        end
        
        
        
        function afterFrame(o)
            if o.useMouse
                [currentX,currentY,buttons] = o.cic.getMouse;
                if buttons(1) || o.continuous
                    o.x=currentX;
                    o.y=currentY;
                end
            end
        end
        
        
         function keyboard(o,key)
            switch upper(key)
                case 'W'
                    % Simulate a blink
                    o.valid = false;                    
                    if strcmpi(o.tmr.Running,'Off')
                        start(o.tmr);                    
                    end                   
            end
         end
         function openEye(o,varargin)
             o.valid = true;
             writeToFeed(o,'Blink Ends')
         end
    end
    
end