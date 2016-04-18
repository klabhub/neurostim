function [c,opts] = adamsConfig(varargin)

import neurostim.*

fullScreen = false;
computerName = getenv('COMPUTERNAME');
c = cic;
c.cursor = 'arrow';

switch computerName
    case 'MU00043185'
        %Office PC
        c.screen.xpixels  = 1680;
        c.screen.ypixels  = 1050;
        c.screen.frameRate=60;
        c.screen.width= 42;
        c.screen.number = max(Screen('screens'));
        opts.eyeTracker = false;
    case 'MU00042884'

        %Neurostim A (Display++)
        c.screen.xpixels  = 1920-1; %Currently -1 because getting weird frame drops if full-screen mode
        c.screen.ypixels  = 1080-1; %Currently -1 because getting weird frame drops if full-screen mode
        c.screen.frameRate=120;
        c.screen.width= 72;
        c.screen.number = 1;
        opts.eyeTracker = true;
        fullScreen = true;

    case 'MU00080600'
        %Neurostim B (CRT)
        subjDisp = false;
        opts.eyeTracker = true;        
        if subjDisp
            c.screen.xpixels  = 1600-1; %Currently -1 because getting weird frame drops if full-screen mode
            c.screen.ypixels  = 1200-1; %Currently -1 because getting weird frame drops if full-screen mode
            c.screen.frameRate=85;
            c.screen.width= 40;
            c.screen.number = 0;
            fullScreen = true;
        else
            c.screen.xpixels  = 600; %Currently -1 because getting weird frame drops if full-screen mode
            c.screen.ypixels  = 450; %Currently -1 because getting weird frame drops if full-screen mode
            c.screen.frameRate=60;
            c.screen.width= 40;
            c.screen.number = 1;
            opts.eyeTracker = true;
            fullScreen = true;
        end
    case 'MOBOT'
        %Home
        c.screen.xpixels  = 1920/4;
        c.screen.ypixels  = 1200/4;
        c.screen.frameRate=60;
        c.screen.width= 42;
        c.screen.number = 0;
        opts.eyeTracker = false;
    otherwise
        c.screen.width  = 42;
        c.screen.number = max(Screen('screens'));
        c.screen.frameRate = Screen('FrameRate',0);
        if c.screen.frameRate==0
            c.screen.frameRate =60;
        end
        rect = Screen('rect',c.screen.number);
        c.screen.xpixels  = rect(3);
        c.screen.ypixels  = rect(4);
        opts.eyeTracker = false;
end

if ~fullScreen
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

