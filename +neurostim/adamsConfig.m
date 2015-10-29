function c = adamsConfig(varargin)
import neurostim.*

c = cic;
c.screen.pixels = [0 0 1680 1050];
c.screen.physical = [50 50/c.screen.pixels(3)*c.screen.pixels(4)];
c.trialDuration = Inf;
c.screen.color.background = [0 0 0];
c.screen.colorMode = 'xyl';
c.mirrorPixels = [1920 0 3600 1080];
c.iti = 500;
end