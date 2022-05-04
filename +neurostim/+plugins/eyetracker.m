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
%   eye - one of 'left' or 'right'.
%   binocular - if set to true, requests binocular eye tracking (may not be supported by all child classes).
%   useMouse - if set to true, uses the mouse coordinates as eye coordinates.
%
% Keyboard:
%   Pressing 'w' simulates a 200 ms eye blink
%
% Notes on binocular eye tracking:
%   Where the eye tracker hardware (and the child plugin) supports it, setting
%   the .binocular property to true will configure the eye tracker to track
%   both eyes. However, at present, neurostim eyetracker plugins expose
%   position for only one eye, via the .x and .y properties, at runtime.
%   Which eye is used to populate these properties, and is therefore
%   available for eye movement behaviours or gaze contingent stimuli, is
%   determined by the .eye property, which must be either 'left' or 'right'. 

    properties (Access=public)
        useMouse = false;
        mouseButton = 1; % By default check the left click (button =1), but user can set to 2 or 3.
        keepExperimentSetup = true;

        eye = 'LEFT'; % LEFT or RIGHT
        binocular = false; % Set to true to request binocular eye tracking (see notes above)

        tmr; % @timer (for blink simulation)
        
        doTrackerSetupEachBlock = false % Return to tracker setup before the first trial of every block.
        doTrackerSetup = true;  % Do it before the next trial. Initialised to true to do setup on first trial.
        doDriftCorrect = false;  % Do it before the next trial
    end
    
    properties
        x=NaN; % Should have default values, otherwise bhavior checking can fail.
        y=NaN;
        z=NaN;
        pupilSize;
        valid= true;  % valid=false signals a temporary absence of data (due to a blink for instance)
    end
    
    properties (SetAccess={?neurostim.plugin}, GetAccess={?neurostim.plugin}, Hidden)
        loc_clbMatrix;
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
        
        function beforeBlock(o)
            if o.doTrackerSetupEachBlock
                %Return to tracker setup before the first trial of every block.
                o.doTrackerSetup = true; %Will be done in next beforeTrial()
            end
        end
        
        function afterFrame(o)
            if o.useMouse
                [currentX,currentY,buttons] = o.cic.getMouse;
                if buttons(o.mouseButton) || o.continuous
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
            cm = o.loc_clbMatrix;
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
            cm = o.loc_clbMatrix;
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
