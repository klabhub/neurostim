function c = adamsConfig(varargin)

import neurostim.*

c = cic;
c.screen.xpixels=1680 ;
c.screen.ypixels=1050;
c.screen.xorigin=0;
c.screen.yorigin=0;

c.screen.width= 50;
c.screen.height = 31.25;
c.screen.color.background = [0 0 0];
c.screen.colorMode = 'RGB';
c.iti = 500;
c.trialDuration = 500;
c.mirrorPixels=[0 0 1680 1050];
c.screen.frameRate=60;
c.dirs.output = 'c:\temp\';
end
