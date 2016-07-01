function c = myRig(varargin)

%Convenience function to set up a CIC object with appropriate settings for the current rig/computer.
%Feel free to add your PC/rig to the list
pin = inputParser;
pin.addParameter('smallWindow',false);   %Set to true to use a half-screen window
pin.parse(varargin{:});
smallWindow = pin.Results.smallWindow;

import neurostim.*

%Create a Command and Intelligence Center object - the central controller for Neurostim.
c = cic;
c.cursor = 'arrow';
computerName = getenv('COMPUTERNAME');
if isempty(computerName)
    [~,computerName] =system('hostname');
    computerName = deblank(computerName);
end
c.dirs.output = tempdir; % Output files will be stored here.

switch computerName
    case 'MU00043185'
        
        %Office PC
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',1680,'ypixels',1050,'screenWidth',42,'frameRate',60,'screenNumber',max(Screen('screens')));
        smallWindow = true;
        
    case 'MU00042884'
        
        %Neurostim A (Display++)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1920-1,'ypixels',1080-1,'screenWidth',72,'frameRate',120,'screenNumber',1,'output','C:\Neurostim Data Store','eyelinkCommands',{'calibration_area_proportion=0.3 0.3','validation_area_proportion=0.3 0.3'});
        
    case 'MU00080600'
        
        %Neurostim B (CRT)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1600-1,'ypixels',1200-1,'screenWidth',40,'frameRate',85,'screenNumber',0,'output','C:\Neurostim Data Store');
        
    case 'MOBOT'
        
        %Home
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',1920,'ypixels',1200,'screenWidth',42,'frameRate',60,'screenNumber',0);
        smallWindow = true;
        
    case 'CMBN-Presentation-Airbook.local'
        %Airbook
        scrNr =0;
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',60,'screenNumber',scrNr);
        smallWindow = false;
        
    case 'KLAB-U'
        scrNr = 1;
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',38.3,'frameRate',60,'screenNumber',scrNr);
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=30;
        Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.
        smallWindow = false;
        
    case 'XPS2013'
        scrNr=0;
        rect = Screen('rect',scrNr);
        Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',34.5,'frameRate',60,'screenNumber',scrNr);
        c.screen.colorMode = 'RGB';
        smallWindow = false;
        
    case 'PTB-P'
        scrNr =1;
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',38.3,'frameRate',60,'screenNumber',scrNr);
        c.screen.colorMode = 'RGB';
        c.screen.frameRate=60;
        Screen('Preference', 'SkipSyncTests', 0); % Not in production mode; this is just to run without requiring accurate timing.
        smallWindow = false;
    otherwise
        warning('This computer is not recognised. Using default settings.');
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
pin.addParameter('output',[]);
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
if ~isempty(pin.Results.output)
    if exist(pin.Results.output,'dir')
        c.dirs.output  = pin.Results.output;
    else
        error(horzcat('Output folder ', pin.Results.output, ' does not exist.'));
    end
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
