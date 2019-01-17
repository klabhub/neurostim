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
    case 'MU00101417X'
        % Shaun's MacBook Pro
        if false
          c = rig(c,'eyelink',false,'mcc',false,'xpixels',300,'ypixels',300,'screenWidth',24,'frameRate',60,'screenNumber',max(Screen('screens')),'keyboardNumber',max(GetKeyboardIndices()));
        else
          % magic software overlay... EXPERIMENTAL!!
          c = rig(c,'eyelink',false,'mcc',false,'xpixels',600,'ypixels',300,'screenWidth',24,'screenHeight',24,'frameRate',60,'screenNumber',max(Screen('screens')),'keyboardNumber',max(GetKeyboardIndices()));
          c.screen.type  = 'SOFTWARE-OVERLAY'; % <-- note: xpixels will actually be half that passed to rig(), screenWidth/screenHeight (above) should reflect that
          
          consoleClut = [ ...
            0.8,  0.0,  0.5;  % cursor       1
            0.0,  1.0,  1.0;  % eye posn     2
            1.0,  1.0,  1.0;  % windows      3
            0.75, 0.75, 0.75; % grid         4
            bgColor;          % diode        5
          ];
        
          subjectClut = repmat(bgColor,size(consoleClut,1),1);
          subjectClut(5,:) = [1.0, 1.0, 1.0]; % diode (white)   5
        
          % setup combined overlay CLUT
          c.screen.overlayClut = cat(1,subjectClut,consoleClut);
          
          c.screen.color.text = 3; % white (console display only)
          
          % show eye position on the overlay
          f = stimuli.fixation(c,'ofix');
          f.shape = 'CIRC';
          f.size = 0.5;
          f.X = '@eye.x';
          f.Y = '@eye.y';
          f.overlay = true;
          f.color = 2; % eye posn
          
          % draw the grid on the overlay...
          g = marmolab.stimuli.grid(c,'grid');
          g.minor = 1;
          g.major = 5;
          g.size = 0.1;
          g.overlay = true;
          g.color = 4; % 4 = grid, 3 = window (white)

          g.diode.color = 5; % white (subject's display only)
          g.diode.on = true;          
        end
        
        smallWindow = false;
        
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
        
    case 'CMBN-Presentation-Airbook.local'
        %Airbook
        scrNr =0;
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',60,'screenNumber',scrNr);
        smallWindow = false;
        c.useConsoleColor = true;
        
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
    case '2014C'
        % Presentation computer
        c = rig(c,'eyelink',false,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',133,'screenHeight',75, 'frameRate',60,'screenNumber',1);
        Screen('Preference', 'SkipSyncTests', 2);
    case 'PTB-P'
        Screen('Preference', 'SkipSyncTests', 0);
        c = rig(c,'eyelink',pin.Results.eyelink,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',52,'frameRate',120,'screenNumber',1);
        c.screen.colorMode = 'RGB';            
        c.screen.type  = 'GENERIC';
        smallWindow = false;
        c.timing.vsyncMode =0;
        c.timing.frameSlack = 0.1;
        c.eye.sampleRate  = 250;
        c.useConsoleColor = true;
    case 'PTB-P-UBUNTU'
        c = rig(c,'keyboardNumber',[],'eyelink',pin.Results.eyelink,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',52,'frameRate',120,'screenNumber',1);
        
        c.screen.colorMode = 'RGB';            
        smallWindow = false;      
        c.eye.sampleRate  = 250;
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
    case 'ns2'
        % marmolab rig #1
        c = rig(c,'mcc',false,'xpixels',1920*2,'ypixels',1080,'screenWidth',40,'screenHeight',22.5,'frameRate',60,'screenNumber',max(Screen('screens'))); %,'keyboardNumber',max(GetKeyboardIndices()));
        c.screen.type = 'SOFTWARE-OVERLAY';
        
        consoleClut = [ ...
            0.8,  1.0,  0.5;  % cursor   1
            0.0,  1.0,  1.0;  % eye posn 2
            1.0,  1.0,  1.0;  % window   3
            0.75, 0.75, 0.75; % grid     4
            bgColor;          % diode    5
        ];
        
        subjectClut = repmat(bgColor,5,1);
        subjectClut(5,:) = [1.0, 1.0, 1.0]; % diode (white) 5
            
        c.screen.overlayClut = cat(1,subjectClut,consoleClut);
        
        % show eye position on the console display
        e = stimuli.fixation(c,'eyepos');
        e.shape = 'CIRC';
        e.size = 0.5;
        e.X = '@eye.x';
        e.Y = '@eye.y';
        e.overlay = true;
        e.color = 2; % eye posn
    
        % draw the grid on the console display
        g = marmolab.stimuli.grid(c,'grid');
        g.minor = 1;
        g.major = 5;
        g.size = 0.05;
        g.overlay = true;
        g.color = 4; % 4 = grid, 3 = window (white)
        
        % show the diode on the subject's display (only)
        g.diode.size = 0.025; % fraction of xscreen (pixels)
        g.diode.on = true;
        g.diode.color = 5; % white (subject's display only)
        
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
