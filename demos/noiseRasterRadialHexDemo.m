function noiseRasterRadialHexDemo(n)

% 2018-06-05 - Shaun L. Cloherty <s.cloherty@ieee.org>

import neurostim.*
commandwindow;

% get rig configuration
c = myRig; % returns s neurostim @cic object

%
% add stimuli...
%

% white noise on a hexagonal grid
h = neurostim.stimuli.noiserasterradialhex(c,'noise');
h.X = '@fix.X';
h.innerRad = 1.5;
h.outerRad = 10.0;
h.nTiles = 15;

h.distribution = 'normal'; % luminance distribution
h.parms = {127, 40}; % {mean, sd}
h.bounds = [0, 255]; % [min, max]

h.frameInterval = 300.0; % milliseconds

if nargin >= 1
  h.nTiles = n;
end

% h.debug = true;

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
c.order('fix','noise');
c.subject = 'easyD';
c.run(myBlock);

