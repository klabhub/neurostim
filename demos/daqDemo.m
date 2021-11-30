function daqDemo(varargin)
% Demonstrate use of the mcc daq plugin.
%
% Optional arguments:
%
%   'bit' - digital output bit (1-8) to be toggled (Default: 1)

% 2019-05-21 - Shaun L. Cloherty <s.cloherty@ieee.org>

p = inputParser;
p.KeepUnmatched = true;
p.addParameter('bit',1,@(x) validateattributes(x,{'numeric'},{'nonempty','scalar','>=',1,'<=',8}));

p.parse(varargin{:});
args = p.Results;

import neurostim.*
commandwindow;

% rig configuration
c = myRig(varargin{:});

% add the mcc plugin
m =  plugins.mcc(c);

% add stimuli

% fixation target
f = stimuli.fixation(c,'fix');
f.shape = 'CIRC';
f.size = 0.25;
f.color = [1 0 0]; % red
f.on = 0;
f.duration = Inf;

% random dot pattern
d = stimuli.rdp(c,'dots');
d.on = plugins.jitter(c,{250,500},'distribution','uniform'); % Turn on at random times
d.duration = 1000;
d.color = [1 1 1]; % white
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;

% add on onsetFcn to set DAQ bit HIGH when the dots appear
d.onsetFunction = @(o,t) o.cic.mcc.digitalOut(8+args.bit,true);

% add on offsetFcn to clear DAQ bit when the dots disappear
d.offsetFunction = @(o,t) o.cic.mcc.digitalOut(8+args.bit,false);

% experiment design
c.trialDuration = '@dots.duration + 2*dots.on';

% specify experimental conditions
fac = design('myFactorial');
fac.fac1.dots.direction = {-90, 90}; % upward or downward motion

fac.conditions(:).dots.duration = plugins.jitter(c,{500,1000},'distribution','uniform');

% specify a block of trials
blk = block('myBlock',fac);
blk.nrRepeats = 1e3;

% Run the experiment
c.subject = 'easyD';
c.run(blk);
