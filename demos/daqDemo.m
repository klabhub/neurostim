function vpixxDemo(varargin)
% Demonstrate use of VPixx daq plugin.

import neurostim.*
commandwindow;

% rig configuration
c = myRig(varargin{:});

% add the datapixx plugin
d =  plugins.datapixx(c); % add the datapixx plugin

% add stimuli

% fixation target
f=stimuli.fixation(c,'fix');
f.shape = 'CIRC';
f.size = 0.25;
f.color = [1 0 0]; % red
f.on = 0;
f.duration = Inf;

% random dot pattern
d = stimuli.rdp(c,'dots');
d.X = 0;                 
d.Y = 0;                 
d.on = plugins.jitter(c,{500,250},'distribution','normal','bounds',[0 400]); % Turn on at random times
d.duration = 1000;
d.color = [1 1 1]; % white
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;

% add on onsetFcn to set DAQ bit 0 on the viewpixx HIGH when the dots appear
d.onsetFunction = @neurostim.plugins.datapixx.digitalOut(0,true);

% add on offsetFcn to clear DAQ bit 0 on the viewpixx when the dots disappear
d.onsetFunction = @neurostim.plugins.datapixx.digitalOut(0,false);

% experiment design
c.trialDuration = 1500;


% specify experimental conditions
fac = design('myFactorial');
fac.fac1.fix.X = {-10, 0, 10}; % three positions
fac.fac2.dots.direction = {-90, 90}; % two dot directions

fac.conditions(:,:).dots.duration = plugins.jitter(c,{500,1500},'distribution','unif');

% specify a block of trials
blk = block('myBlock',fac);
blk.nrRepeats=1;

% Run the experiment.
c.run(blk);
