function gazeContingent
% Demonstrate gaze contingent displays
%
 % BK - 2015.
import neurostim.*

% We fake an eye tracker that updates continuously with the mouse, but if
% you have an eyelink, you can set the input to myRig to true to use its
% eye position signals instead


c= myRig('eyelink',false); 
c.trialDuration = 5000;
c.screen.colorMode = 'RGB';
c.eye.continuous = true;
c.addPropsToInform('eye.x','eye.y');

%Make sure there is an eye tracker (or at least a virtual one)
if isempty(c.pluginsByClass('eyetracker'))
    e = neurostim.plugins.eyetracker(c);      %Eye tracker plugin not yet added, so use the virtual one. Mouse is used to control gaze position (click)
    e.useMouse = true;
end


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

% Setup Eyelink
if  ~isempty(c.pluginsByClass('eyelink'))
    % Match eye calibration colors to the experiment    
    c.eye.clbTargetColor  = f.color;
    c.eye.clbTargetSize = 1;
end


% Setup some dummy conditions
d =design('dummy');
d.conditions(1).reddot.size = 0.1; % Define a single "condition"
blk = block('dummy',d);
blk.nrRepeats = 10;
c.run(blk);
end