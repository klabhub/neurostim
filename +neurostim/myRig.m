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
        c = rig(c,'eyelink',false,'mcc',false,'xpixels',2560,'ypixels',1600,'screenWidth',28.6,'frameRate',60,'screenNumber',max(Screen('screens')),'keyboardNumber',max(GetKeyboardIndices()));
        smallWindow = true;
        
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
        c = rig(c,'xpixels',1920,'ypixels',1200,'screenWidth',42,'frameRate',60,'screenNumber',0);
        smallWindow = true;
        
    case 'CMBN-Presentation-Airbook.local'
        %Airbook
        scrNr =0;
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',60,'screenNumber',scrNr);
        smallWindow = false;
        
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
        
        
    case 'XPS2013'
        scrNr=0;
        rect = Screen('rect',scrNr);
        Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',34.5,'frameRate',60,'screenNumber',scrNr);
        smallWindow = true ;
    case 'SURFACE2017'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        smallWindow = true;
        c.dirs.output= 'c:/temp';
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
    case 'PTB-P-UBUNTU'
        c = rig(c,'keyboardNumber',[],'eyelink',pin.Results.eyelink,'outputdir','c:/temp/','mcc',false,'xpixels',1920,'ypixels',1080,'screenWidth',52,'frameRate',120,'screenNumber',1);
        
        c.screen.colorMode = 'RGB';            
        smallWindow = false;      
        c.eye.sampleRate  = 250;
    case 'PC2017A'
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c = rig(c,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',42,'frameRate',max(fr,60),'screenNumber',scrNr);
        Screen('Preference', 'SkipSyncTests', 2);
        smallWindow = true;
    case 'ROOT-PC'
        c = rig(c,'xpixels',1280,'ypixels',1024,'screenWidth',40,'frameRate',85,'screenNumber',max(Screen('screens')));

        smallWindow = false;
    case 'ns2'
        % marmolab rig #1 (Ubuntu 16.04), GTX980Ti, dual BenQ XT2411z (1920x1080 @ 100Hz?)
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        
        % BenQ XL2411z viewable area is 531.36 x 298.89 mm
        scrWdth = 53.1; % deg. (approx., at 57cm viewing distance)
        scrHght = 29.8;
        
        % viewpoint eye tracker setup... note: space between 'DATA:' and the path is critical!
        vpCmds = {'setPath DATA: C:\Users\shaunc\Documents','calibration_RealRect 0.3 0.3 0.7 0.7'};
        
        if true
            % generic monitor           
            c = rig(c,'viewpoint',true,'mcc',false,'xpixels',rect(3)/2,'ypixels',rect(4),'screenWidth',scrWdth,'screenHeight',scrHght,'frameRate',fr,'screenNumber',scrNr,'viewpointCommands',vpCmds);
            
            c.eye.sampleRate = 220;
            c.eye.ipAddress = '192.168.1.2';
        else
            % experimental SOFTWARE-OVERLAY
            c = rig(c,'viewpoint',false,'mcc',false,'xpixels',rect(3),'ypixels',rect(4),'screenWidth',scrWdth,'screenHeight',scrHght,'frameRate',fr,'screenNumber',scrNr);
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
            g = stimuli.grid(c,'grid');
            g.minor = 1;
            g.major = 5;
            g.size = 0.05;
            g.overlay = true;
            g.color = 4; % 4 = grid, 3 = window (white)
        
            % show the diode on the subject's display (only)
            g.diode.size = 0.025; % fraction of xscreen (pixels)
            g.diode.on = true;
            g.diode.color = 5; % white (subject's display only)
        end
        
        smallWindow = false;
    otherwise
        warning('This computer is not recognised. Using default settings.');
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
