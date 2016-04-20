function gazeContingent

import neurostim.*

c= bkConfig;
c.trialDuration = 5000;

% Fake an eye tracker that updates continuously with the mouse.
e = plugins.eyetracker(c);
e.useMouse =true;
e.continuous = true;

% Create a dots stimulus with X/Y properties that are functions of the 
% eye trackers x/y properties.
s = stimuli.shadlendots(c,'dots');
s.apertureD = 15;
s.color = [1 1 1];
s.coherence = 0.8;
s.speed = 5;
s.maxDotsPerFrame =100;
s.direction = 0;
s.dotSize= 5;
s.Y='@eye.y';
s.X='@eye.x';

% Setup some dummy conditions
fac =factorial('dummy',1);
fac.fac1.dots.X=0;
blk = block('dummy',fac);
blk.nrRepeats = 10;
c.run(blk);
end