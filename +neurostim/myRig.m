function c = myRig(varargin)

%Convenience function to set up a CIC object with appropriate settings for the current rig/computer.
%Feel free to add your PC/rig to the list
pin = inputParser;
pin.addParameter('smallWindow',false);   %Set to true to use a half-screen window
pin.addParameter('bgColor',[0.25,0.25,0.25]);
pin.addParameter('eyelink',false);
pin.addParameter('debug',false);
pin.parse(varargin{:});
smallWindow = pin.Results.smallWindow;
bgColor = pin.Results.bgColor;
[here,~] = fileparts(mfilename('fullpath'));

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

switch upper(computerName)
    case {'MU00101417X','NS2','NS3'}
        % Shaun's MacBook Pro, Marmolab Rig #1 (NS2) and the Psychophysics rig (NS3)
        c = marmolab.rigcfg();
        
    case 'MU00043185'
        %Office PC
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',1680,'ypixels',1050,'screenWidth',42,'frameRate',60,'screenNumber',max(Screen('screens')));
        smallWindow = false;
        
    case 'MU00042884'
        %Neurostim A (Display++)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1920-1,'ypixels',1080-1,'screenWidth',72,'screenDist',42,'frameRate',120,'screenNumber',0,'eyelinkCommands',{'calibration_area_proportion=0.3 0.3','validation_area_proportion=0.3 0.3'},'outputDir','C:\Neurostim Data Store');
        c.eye.eye = 'RIGHT';
    case 'MU00080600'
        %Neurostim B (CRT)
        c = rig(c,'eyelink',true,'mcc',true,'xpixels',1600-1,'ypixels',1200-1,'screenWidth',40,'frameRate',85,'screenNumber',0,'eyelinkCommands',{'calibration_area_proportion=0.6 0.6','validation_area_proportion=0.6 0.6'});
        
    case 'MOBOT'
        %Home
        c = rig(c,'xorigin',950,'yorigin',550,'xpixels',1920,'ypixels',1200,'screenWidth',42,'frameRate',60,'screenNumber',0);
        smallWindow = true;
        
           
    case 'KLAB-U'
        %if pin.Results.debug
        scrNr = 2;
        rect = Screen('rect',scrNr);
        hz=Screen('NominalFrameRate', scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',40,'frameRate',hz,'screenNumber',scrNr);
        smallWindow = false;
        Screen('Preference', 'SkipSyncTests', 2);
        %         else
        %             scrNr = 1;
        %             rect = Screen('rect',scrNr);
        %             c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',60,'frameRate',60,'screenNumber',scrNr);
        %             smallWindow = false;
        %              Screen('Preference', 'SkipSyncTests', 0);
        %         end
        c.useConsoleColor = true;
        
    case 'NEUROSTIMM'
        scrNr=0;
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',34.5,'frameRate',60,'screenNumber',scrNr);
        InitializePsychSound(1)
        devs = PsychPortAudio('GetDevices');
        c.hardware.sound.device = devs(strcmpi({devs.DeviceName},'Microsoft Sound Mapper - Output')).DeviceIndex; % Automatic sound hardware detection fails on this machine. Specify device 1
        %if pin.Results.debug
        smallWindow = true ;
        %else
        %    smallWindow = false;
        %end
        c.useConsoleColor = true;
        Screen('Preference', 'ConserveVRAM', 4096); %kPsychUseBeampositionQueryWorkaround
    case 'SURFACE2017'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        smallWindow = true;
        c.dirs.output= 'c:/temp';
        c.useConsoleColor = true;
    case '2014B'
        scrNr = 2;
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',38.3,'frameRate',60,'screenNumber',scrNr);
        c.screen.colorMode = 'RGB';
        Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.
        smallWindow = false;
        c.useConsoleColor = true;
        c.hardware.keyEcho  = true;
    case '2014C'
        % Presentation computer
        c = rig(c,'eyelink',false,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',133,'screenHeight',75, 'frameRate',60,'screenNumber',1);
        Screen('Preference', 'SkipSyncTests', 2);
    case 'NEUROSTIMP'
        c.screen.color.background = [0.25 0.25 0.25];
        c.iti                     = 500;
        c.trialDuration           = 500;
        c.saveEveryBlock          = true;
        c.saveEveryN              = inf;
        c.hardware.textEcho       = true;
        
        %% Define plugins based on user selections passed to this function
        c.subjectNr               = 0;
        c.runNr                   = 0;
        if pin.Results.debug
            c.dirs.output = 'c:/temp/';
            c.cursor = 'arrow';
        else
            c.dirs.output = 'z:/klab/';
            c.cursor = 'arrow';
        end
        
        c.dirs.calibration = here;
      
        c.screen.number     = 2;
        c.screen.frameRate  = 120;
        % Geometry
        c.screen.xpixels    = 1920;
        c.screen.ypixels    = 1080;
        c.screen.xorigin    = [];
        c.screen.yorigin    = [];
        c.screen.width      = 52;
        c.screen.height     = c.screen.width*c.screen.ypixels/c.screen.xpixels;
        % Color calibration
        c.screen.colorMode  = 'RGB';        
        c.screen.type       = 'GENERIC';
        %
        c.useConsoleColor   = true;
        c.useFeedCache      = true;
        c.hardware.keyEcho = true;
        c.hardware.sound.latencyClass = 2; % Take control - gives 10ms latency in PTB-P
        
        % Timing parameters
        % Make sure synctests are done
        Screen('Preference', 'SkipSyncTests', 0);
        % These do not help (and seem to make thing worse)
        %Screen('Preference', 'VBLTimestampingMode',3); % Beamposition queries work ok on PTB-P, so force their usage for Flip timing
        %Screen('Preference', 'ConserveVRAM', 4096); %kPsychUseBeampositionQueryWorkaround
        c.timing.vsyncMode = 1; % 0 waits for the flip and makes timing most accurate.
        c.timing.frameSlack = NaN;% NaN; % Not used in vsyncmode 0. A likely drop is one that is 25% late.        
        % We define a standard overlay clut with R, G,B, W the first 4
        % entries (and 0=black)
        c.screen.overlayClut = [1 0 0; ... % .color =1 will be max saturated red
            0 1 0; ...  % .color =2 will be max saturated green
            0 0 1; ...
            1 1 1;...
            ];    %.
  case 'NEUROSTIMP-UBUNTU'
       
        c.screen.color.background = [0.25 0.25 0.25];
        c.iti                     = 500;
        c.trialDuration           = 500;
        c.saveEveryBlock          = true;
        c.saveEveryN              = inf;
        c.hardware.textEcho       = true;
        
      %  c.kbInfo.experimenter    = 10;
      %  c.kbInfo.subject         = 10;
        c.kbInfo.default        = 10;
        
        %% Define plugins based on user selections passed to this function
        c.subjectNr               = 0;
        c.runNr                   = 0;
        if pin.Results.debug
            c.dirs.output = '/home/ktech/temp/';
            c.cursor = 'arrow';
        else
            c.dirs.output = '/home/ktech/klab/';
            c.cursor = 'arrow';
        end
        
        c.dirs.calibration = here;
      
        c.screen.number     = 1;
        c.screen.frameRate  = 120;
        % Geometry
        c.screen.xpixels    = 1920;
        c.screen.ypixels    = 1080;
        c.screen.xorigin    = [];
        c.screen.yorigin    = [];
        c.screen.width      = 52;
        c.screen.height     = c.screen.width*c.screen.ypixels/c.screen.xpixels;
        % Color calibration
        c.screen.colorMode  = 'RGB';        
        c.screen.type       = 'GENERIC';
        %
        c.useConsoleColor   = true;
        c.useFeedCache      = true;
        c.hardware.keyEcho = true;
        c.hardware.sound.latencyClass = 2; % Ta ke control - gives 10ms latency in PTB-P
        
        % Timing parameters
        % Make sure synctests are done
        Screen('Preference', 'SkipSyncTests', 0);
        % These do not help (and seem to make thing worse)
        %Screen('Preference', 'VBLTimestampingMode',3); % Beamposition queries work ok on PTB-P, so force their usage for Flip timing
        %Screen('Preference', 'ConserveVRAM', 4096); %kPsychUseBeampositionQueryWorkaround
        c.timing.vsyncMode = 0; % 0 waits for the flip and makes timing most accurate.
        c.timing.frameSlack = NaN;% NaN; % Not used in vsyncmode 0. A likely drop is one that is 25% late.
       
        % We define a standard overlay clut with R, G,B, W the first 4
        % entries (and 0=black)
        c.screen.overlayClut = [1 0 0; ... % .color =1 will be max saturated red
            0 1 0; ...  % .color =2 will be max saturated green
            0 0 1; ...
            1 1 1;...
            ];    %.
    case 'PC2017A'
        scrNr = 1;%max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        c.useConsoleColor = true;
        %Screen('Preference', 'SkipSyncTests', 2);
        smallWindow = true;
        c.hardware.keyEcho = true;
        
    case 'NEUROSTIMA2018'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        c.useConsoleColor = true;
        Screen('Preference', 'SkipSyncTests', 2);
        smallWindow = true;
    case 'PC-2018D'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        c.useConsoleColor = true;
        Screen('Preference', 'SkipSyncTests', 0);
        smallWindow = false;
    case 'ROOT-PC'
        c = rig(c,'xpixels',1280,'ypixels',1024,'screenWidth',40,'frameRate',85,'screenNumber',max(Screen('screens')));
        smallWindow = false;
    otherwise
        warning('a:b','This computer (%s) is not recognised. Using default settings.\nHint: edit neurostim.myRig to prevent this warning.',computerName);
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'eyelink',pin.Results.eyelink,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        smallWindow = true;
end

if smallWindow
    c.screen.xpixels = c.screen.xpixels/2;
    c.screen.ypixels = c.screen.ypixels/2;
end

c.screen.color.background = bgColor;
c.iti = 500;
c.trialDuration = 500;
