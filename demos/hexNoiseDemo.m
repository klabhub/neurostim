function c = hexNoiseDemo(sz)

% 2018-06-05 - Shaun L. Cloherty <s.cloherty@ieee.org>

import neurostim.*
commandwindow;

% get rig configuration
c = myRig; % returns s neurostim @cic object

%
% add stimuli...
%

% white noise on a hexagonal grid
n = neurostim.stimuli.hexNoise(c,'noise');
n.width = c.screen.width; % width and height on screen
n.height = c.screen.height;

n.distribution = 'normal'; % luminance distribution
n.parms = {127, 40}; % {mean, sd}
n.bounds = [0, 255]; % [min, max]

n.frameInterval = 300.0; % milliseconds

if nargin >= 1
  n.hexSz = sz;
end

% fixation target
f = stimuli.fixation(c,'fix');
f.size = 0.5;
f.color = [1.0 0.0 0.0];

% experimental design
c.trialDuration = 3.0*1e3; % milliseconds 

% specify experimental conditions
myDesign = design('myFac');
myDesign.fac1.fix.X = [-10, 0, 10];  

% specify a block of trials
myBlock = block('myBlock',myDesign);
myBlock.nrRepeats = 10;

% Run the experiment.
c.order('noise');
c.subject = 'easyD';
c.run(myBlock);

