function gazeContingent
% Demonstrate gaze contingent displays
%
 % BK - 2015.
import neurostim.*

c= myRig;
c.trialDuration = 5000;

% Fake an eye tracker that updates continuously with the mouse.
c.eye.useMouse =true;
c.eye.continuous = true;

% Red fixation point that follows the eye.
f = stimuli.fixation(c,'reddot');       
f.color             = [1 0 0];
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 0.1;
f.on                = 0;                % On from the start of the trial
f.X                 = '@eye.x';  % This is all that is needed for gaze-cotingency.
f.Y                 = '@eye.y';

% A dots stimulus that follows the red dot (with an offset).
s = stimuli.shadlendots(c,'dots');
s.apertureD = 15;
s.color = [1 1 1];
s.coherence = 0.8;
s.speed = 5;
s.maxDotsPerFrame =100;
s.direction = 0;
s.dotSize= 5;
s.Y='@reddot.Y+5';
s.X='@reddot.X+5';

% Setup some dummy conditions
d =design('dummy');
d.conditions(1).reddot.size = 0.1; % Define a single "condition"
blk = block('dummy',d);
blk.nrRepeats = 10;
c.run(blk);
end