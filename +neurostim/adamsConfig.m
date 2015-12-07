function c = adamsConfig(varargin)

import neurostim.*

c = cic;
c.screen.pixels=[0 0 1680 1050];
c.screen.physical = [50 31.25];
c.screen.color.background = [0 0 0];
c.screen.colorMode = 'xyl';
c.iti = 50;
c.trialDuration = 500;
c.mirrorPixels=[0 0 1680 1050];
c.screen.frameRate=60;
end
