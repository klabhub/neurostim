function c = adamsConfig(varargin)
import neurostim.*

c = cic;
c.screen.pixels = [0 0 1680 1050];

c.screen.physical = [50 50/c.screen.pixels(3)*c.screen.pixels(4)];
c.screen.color.background = [0 0 0];
c.screen.colorMode = 'xyl';
c.iti = 1000;
c.trialDuration = 3000;
c.mirrorPixels = [c.screen.pixels(3),0,2*c.screen.pixels(3),c.screen.pixels(4)];

