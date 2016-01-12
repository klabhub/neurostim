function adamDemo

import neurostim.*
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference','TextRenderer',1);
%% ========= Specify rig configuration  =========
c = adamsConfig;

%Use DEBUG features
c.add(plugins.debug);

%Use the experimenter GUI window
% c.add(neurostim.plugins.gui);

%Use/simulate Eylink eye tracker
e = neurostim.plugins.eyelink;
e.useMouse = true;
c.add(e);

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation('fix');
f.shape = 'CIRC';
f.size = 0.5;
f.color = [1 1 50];
f.on=0;
f.duration = Inf;
c.add(f);

%Random dot pattern
d = stimuli.rdp('dots');
d.on = '@(f1) f1.startTime';
d.duration = 1000;
d.color = [0.3 0.3 100];
d.size = 6;
d.nrDots = 200;
d.maxRadius = 8;
d.lifetime = Inf;
d.noiseMode = 1;
d.X = '@(fix) fix.X';
d.Y = '@(fix) fix.Y';
c.add(d);

%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse('choice');
k.on = '@(dots) dots.on + dots.duration';
k.deadline = '@(choice) choice.on + 3000';
k.keys = {'a' 'z'};
k.keyLabels = {'up', 'down'};
k.correctKey = '@(dots) double(dots.direction < 0) + 1';  %Function returns 1 or 2
c.add(k);

%Maintain gaze on the fixation point
g = plugins.fixate('f1');
g.from = '@(f1) f1.startTime';
g.to = '@(dots) dots.endTime';
g.X = '@(fix) fix.X';
g.Y = '@(fix) fix.Y';
g.tolerance = 3;
c.add(g);

%% Specify rewards and feedback

%Give juice at the end of the trial for completing all fixations
% r = plugins.liquid('juice');
% r.add('duration',100,'when','afterTrial','criterion','@(f1) f1.success');
% c.add(r);

% Play a correct/incorrect sound for the 2AFC task
%     Use the sound plugin
s = plugins.sound;
c.add(s);

%     Add correct/incorrect feedback
s = plugins.soundFeedback('soundFeedback');
c.add(s);
s.add('waveform','CORRECT','when','afterFrame','criterion','@(choice) choice.done & choice.correct');
s.add('waveform','INCORRECT','when','afterFrame','criterion','@(choice) choice.done & ~choice.correct');


%% Experimental design
c.trialDuration = '@(choice) choice.endTime';

%Specify experimental conditions
myFac=factorial('myFactorial',2);
myFac.fac1.fix.X={-10 0 10};
myFac.fac2.dots.direction={-90 90};

%Specify a block of trials
myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;

%% Run the experiment.
c.cursor = 'arrow';
c.order('sound','fix','dots','f1','choice','liquid','soundFeedback','gui');
c.run(myBlock);
