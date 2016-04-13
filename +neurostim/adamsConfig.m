function c = adamsConfig(varargin)

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
        
    case 'MU00042884'
        %Neurostim A (Display++)
        c.screen.xpixels  = 1920-1; %Currently -1 because getting weird frame drops if full-screen mode
        c.screen.ypixels  = 1080-1; %Currently -1 because getting weird frame drops if full-screen mode
        c.screen.frameRate=120;
        c.screen.width= 72;
        c.screen.number = 1;
    case 'MOBOT'
        %Home
        c.screen.xpixels  = 1920;
        c.screen.ypixels  = 1200;
        c.screen.frameRate=60;
        c.screen.width= 42;
        c.screen.number = 0;
        
    otherwise
        c.screen.frameRate = Screen('FrameRate',0);
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
c.dirs.output = 'c:\temp\';

