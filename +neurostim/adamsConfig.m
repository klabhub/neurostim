function [c,opts] = adamsConfig(varargin)

import neurostim.*

halfSizeWin = false;
computerName = getenv('COMPUTERNAME');
c = cic;

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
    case 'MOBOT'
        %Home
        c.screen.xpixels  = 1920/4;
        c.screen.ypixels  = 1200/4;
        c.screen.frameRate=60;
        c.screen.width= 42;
        c.screen.number = 0;
        opts.eyeTracker = false;
    otherwise
        c.screen.xpixels  = 400;
        c.screen.ypixels  = 300;
        c.screen.width    = 42;
        c.screen.frameRate = Screen('FrameRate',0);
        if c.screen.frameRate==0
            c.screen.frameRate =60;
        end
        c.screen.number = max(Screen('screens'));
        opts.eyeTracker = false;
end

if halfSizeWin
    c.screen.xpixels = c.screen.xpixels/2;
    c.screen.ypixels = c.screen.ypixels/2;
end

c.screen.xorigin = [];
c.screen.yorigin = [];

c.screen.height = c.screen.width*c.screen.ypixels/c.screen.xpixels;
c.screen.color.background = [0.5 0.5 0.5];
c.screen.colorMode = 'RGB';
c.iti = 500;
c.trialDuration = 500;

