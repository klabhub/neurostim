function c = adamsConfig(varargin)

import neurostim.*

smallWindow = false;    %Use a half-screen window
computerName = getenv('COMPUTERNAME');
c = cic;
c.cursor = 'arrow';

switch computerName
    case 'MU00043185'
        
        %Office PC
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',1680,'ypixels',1050,'screenWidth',42,'frameRate',60,'screenNumber',max(Screen('screens')));
        smallWindow = true;
        
    case 'MU00042884'
        
        %Neurostim A (Display++)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1920-1,'ypixels',1080-1,'screenWidth',72,'frameRate',120,'screenNumber',1,'eyelinkCommands',{'calibration_area_proportion=0.3 0.3','validation_area_proportion=0.3 0.3'});

    case 'MU00080600'
        
        %Neurostim B (CRT)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1600-1,'ypixels',1200-1,'screenWidth',40,'frameRate',85,'screenNumber',0);

    case 'MOBOT'
        
        %Home
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',1920,'ypixels',1200,'screenWidth',42,'frameRate',60,'screenNumber',0);
        smallWindow = true;

    case ''
        if ismac
            %BK mac
            scrNr =0;
            fr = 60;
            rect = Screen('rect',scrNr);
            c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
          smallWindow = false; 
        
        end
    otherwise
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        smallWindow = true;
end

if smallWindow
    c.screen.xpixels = c.screen.xpixels/2;
    c.screen.ypixels = c.screen.ypixels/2;
end

c.screen.xorigin = [];
c.screen.yorigin = [];
c.screen.height = c.screen.width*c.screen.ypixels/c.screen.xpixels;
c.screen.color.background = [0.25 0.25 0.25];
c.screen.colorMode = 'RGB';
c.iti = 500;
c.trialDuration = 500;

function c = rig(c,varargin)
            
pin = inputParser;
pin.addParameter('xpixels',[]);
pin.addParameter('ypixels',[]);
pin.addParameter('screenWidth',[]);
pin.addParameter('frameRate',[]);
pin.addParameter('screenNumber',[]);
pin.addParameter('eyelink',[]);
pin.addParameter('eyelinkCommands',[]);
pin.addParameter('mcc',[]);
pin.parse(varargin{:});

if ~isempty(pin.Results.xpixels)
    c.screen.xpixels  = pin.Results.xpixels;
end
if ~isempty(pin.Results.ypixels)
    c.screen.ypixels  = pin.Results.ypixels;
end
if ~isempty(pin.Results.frameRate)
    c.screen.frameRate  = pin.Results.frameRate;
end
if ~isempty(pin.Results.screenWidth)
    c.screen.width  = pin.Results.screenWidth;
end
if ~isempty(pin.Results.screenNumber)
    c.screen.number  = pin.Results.screenNumber;
end
if pin.Results.eyelink
    neurostim.plugins.eyelink(c);
    if ~isempty(pin.Results.eyelinkCommands)
        for i=1:numel(pin.Results.eyelinkCommands)
            c.eye.command(pin.Results.eyelinkCommands{i});
        end
    end
else
    e = neurostim.plugins.eyetracker(c);      %If no eye tracker, use a virtual one. Mouse is used to control gaze position (click)
    e.useMouse = true;
end
if pin.Results.mcc
    neurostim.plugins.mcc(c);
end
