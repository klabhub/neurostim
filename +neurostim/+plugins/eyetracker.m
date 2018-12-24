classdef eyetracker < neurostim.plugin
% Generic eyetracker base class.
%
% Properties:
%
%   x,y,z - eye position coordinates
%   eyeClockTime - eye tracker time (for synchronization)
%
%   hardwareModel - description of eye tracker in use.
%   sampleRate - rate of samples to be taken.
%   backgroundColor - background colour for eyetracker functions.
%   foregoundColor - foreground colour for eyetracker functions.
%   clbTargetColor - calibration target color.
%   clbTargetSize - calibration target size.
%   eyeToTrack - one of 'left','right','binocular' or 0,1,2.

    properties (Access=public)
        eye@char='LEFT'; %LEFT,RIGHT, or BOTH  
    end
    
    properties
        x@double=NaN; % Should have default values, otherwise behavior checking can fail.
        y@double=NaN;
        z@double=NaN;
        
        pupilSize@double;
        valid@logical = true;
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
            
            o.addProperty('clbMatrix',[],'sticky',true); % manual calibration matrix (optional)

            o.addProperty('tolerance',3); % Used to set default tolerance on behaviors.eyeMovement
        end
        
        function afterFrame(o)
          [currentX,currentY,buttons] = o.cic.getMouse;
          if buttons(1) || o.continuous
            [currentX,currentY] = o.raw2ns(currentX,currentY);
                    
            o.x=currentX;
            o.y=currentY;
          end
        end
        
        function [x,y] = raw2ns(o,x,y,cm)
          if nargin < 4
            cm = o.clbMatrix;
          end
          
          if isempty(cm)
            return % pass through
          end
          
          xy = [x,y,ones(size(x))]*cm;
          
          x = xy(:,1);
          y = xy(:,2);
        end
        
        function [x,y] = ns2raw(o,x,y,cm)
          if nargin < 4
            cm = o.clbMatrix;
          end
          
          if isempty(cm)
            return % pass through
          end
                    
          xy = [x,y,ones(size(x))]*inv(cm);
          
          x = xy(:,1);
          y = xy(:,2);
        end
    end    
end
