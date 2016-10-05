function staircaseDemo(varargin)
% STAIRCASEDEMO demo of adaptive threshold estimation.

% 2016-10-05 - Shaun L. Cloherty <s.cloherty@ieee.org>

import neurostim.*
commandwindow;

%
% rig configuration
%
c = myRig();
c.screen.color.background = zeros(1,3); % black

%
% stimuli
%

% fixation target
f = stimuli.fixation(c,'fixpoint');
f.shape = 'CIRC';
f.size = 0.25;
f.color = [1 0 0]; % red
% f.on = 0;
% f.duration = Inf;

% a random limited lifetime dot pattern
d = stimuli.rdp(c,'dots');
d.duration = 1000;
d.nrDots = 200;
d.noiseMode = 1; % distribution
d.noiseDist = 0; % gaussian
d.lifetime = 2;
d.maxRadius = 5;

d.addProperty('k',120,'AbortSet',false); % see staircase on k below

d.noiseWidth = '@bwdth.max-dots.k'; % note, k

d.size = 2;
d.color = ones(1,3); % white

% we estimate motion noise threshold using a simple weighted
% up/down staircase (i.e., a Kaernbach staircase, see Kaernbach,
% Percept Psychophys 49:227-229, 1991).
%
% weights are set to converge on the 75% correct point... I think
s = plugins.nDown1UpStaircase(c,'bwdth','dots','k', ...
  '@choice.success & choice.correct', ...
  'n',1,'min',0,'max',120,'delta',10,'weights',1.0./[1.0,3.0]);

%
% behaviour(s)
%
k = plugins.nafcResponse(c,'choice');
k.on = '@dots.on';
k.deadline = '@dots.stopTime + 2000';  % 2s timeout
k.keys = {'a','z'}; % 'a' = up, 'z' = down
k.keyLabels = {'up', 'down'};
k.correctKey = '@double(dots.direction < 0) + 1';   %Function returns the index of the correct response (i.e., key 1 or 2)

%
% feedback
%
if true
  % add the sound plugin... needed by the soundFeedback plugin
  plugins.sound(c);

  % add sounds for correct/incorrect feedback...
  fb = plugins.soundFeedback(c,'soundFeedback');
  fb.add('waveform','CORRECT.wav','when','AFTERFRAME','criterion','@choice.success & choice.correct');
  fb.add('waveform','INCORRECT.wav','when','AFTERFRAME','criterion','@choice.success & ~choice.correct');
end

%
% presentation options...
%
c.trialDuration = '@choice.stopTime';

% factorial design
fac = factorial('direction',1);
fac.fac1.dots.direction = [-90, 90];

% specify a block of trials
blk = block('block',fac);
blk.nrRepeats = 40;

% now run the experiment...
c.order('bwdth','dots','choice','sound');
c.subject = 'demo';
c.paradigm = 'staircaseDemo';
c.run(blk);
