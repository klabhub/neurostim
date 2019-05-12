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
        useMouse@logical=false;
        keepExperimentSetup@logical=true;
        eye@char='LEFT'; %LEFT,RIGHT, or BOTH
        tmr@timer;
    end
    
    properties
        x@double=NaN; % Should have default values, otherwise behavior checking can fail.
        y@double=NaN;
        z@double=NaN;
        pupilSize@double;
        valid@logical = true;  % valid=false signals a temporary absence of data (due to a blink for instance)
    end
    
    methods
        function o = eyetracker(c)
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

            o.addProperty('clbMatrix',[],'sticky',true); % local calibration matrix (optional)
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
        
        % Helper functions to transform eye sample data to/from neurostim's
        % physical coords.
        %
        % Any eye tracker can achieve the rescaling to screen pixels that
        % they require (e.g., from camera pixels in the case of the Eyelink
        % raw/pupil data, or from normalized coords in the case of the
        % Arrington eye tracker) by defining the appropriate o.clbMatrix.
        %
        % Other transformations (offset/translation, scaling or even
        % rotation) are also possible if required/desired, for example to
        % implement local calibration or automatic on-the-fly adjustment
        % of eye calibration.
        %
        % These functions can also be used when loading eye data for
        % analysis, ensuring that the transformations applied on- and
        % off-line are identical.
        
        function [nx,ny] = raw2ns(o,x,y,cm)
          if nargin < 4
            cm = o.clbMatrix;
          end
          
          if ~isempty(cm)
            % apply local calibration/transformation matrix
            xy = [x,y,ones(size(x))]*cm;
          
            x = xy(:,1);
            y = xy(:,2);
          end
          
          [nx,ny] = o.cic.pixel2Physical(x,y);
        end
        
        function [x,y] = ns2raw(o,nx,ny,cm)
          if nargin < 4
            cm = o.clbMatrix;
          end
          
          [x,y] = o.cic.physical2Pixel(nx,ny);
          
          if ~isempty(cm)
            % invert local calibration/transformation matrix
            xy = [x,y,ones(size(x))]/cm;
          
            x = xy(:,1);
            y = xy(:,2);
          end
        end
        
    end
    
end
