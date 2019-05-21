function vpixxDemo(varargin)
% Demonstrate use of VPixx daq plugin.

import neurostim.*
commandwindow;

% rig configuration
c = myRig(varargin{:});

% add the mcc plugin
m =  plugins.mcc(c);

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
d.X = '@fix.X';                 
d.Y = '@fix.Y';                 
d.on = plugins.jitter(c,{250,500},'distribution','uniform'); % Turn on at random times
d.duration = 1000;
d.color = [1 1 1]; % white
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;

% add on onsetFcn to set DAQ bit 9 on the mcc HIGH when the dots appear
d.onsetFunction = @(o,t) o.cic.mcc.digitalOut(8+1,true);

% add on offsetFcn to clear DAQ bit 9 on the mcc when the dots disappear
d.offsetFunction = @(o,t) o.cic.mcc.digitalOut(8+1,false);

% experiment design
c.trialDuration = 2000;
% c.iti = 2000;

% specify experimental conditions
fac = design('myFactorial');
fac.fac1.fix.X = {-10, 0, 10}; % three positions
fac.fac2.dots.direction = {-90, 90}; % two dot directions

fac.conditions(:,:).dots.duration = plugins.jitter(c,{500,1500},'distribution','uniform');

% specify a block of trials
blk = block('myBlock',fac);
blk.nrRepeats = 1e3;

% Run the experiment
c.subject = 'easyD';
c.run(blk);
