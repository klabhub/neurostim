function adamDemo

import neurostim.*
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference','TextRenderer',1);

%% ========= Specify rig configuration  =========
c = adamsConfig;
c.add(plugins.debug);
c.trialDuration = Inf;

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
s = stimuli.rdp('dots');
s.on = '@(f1) f1.startTime';
s.duration = 4000;
s.color = [0.3 0.3 100];
s.size = 6;
s.nrDots = 200;
s.maxRadius = 8;
s.lifetime = Inf;
s.noiseMode = 1;
s.X = '@(fix) fix.X';
s.Y = '@(fix) fix.Y';
c.add(s);

%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse('choice');
k.on = '@(dots) dots.on+dots.duration';
k.deadline = '@(choice) choice.on + 5000';
k.keys = {'a' 'z'};
k.keyLabels = {'up', 'down'};
k.correctKey = '@(dots) double(dots.direction < 0) + 1';  %Function returns 1 or 2
c.add(k);

e = neurostim.plugins.eyelink;
e.useMouse = true;
c.add(e);

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

%Play a correct/incorrect sound for the 2AFC task
    %Use the sound plugin
% s = plugins.sound('sound');

    %Add correct/incorrect feedback
% s.add('waveform','CORRECT','when','afterFrame','criterion','@(choice) choice.done & choice.correct');
% s.add('waveform','INCORRECT','when','afterFrame','criterion','@(choice) choice.done & ~choice.correct');
% c.add(s);

%% Experimental design

%Specify experimental conditions
myFac=factorial('myFactorial',2);
myFac.fac1.fix.X={-10 10};
myFac.fac2.dots.direction={-90 90};

%Specify a block of trials
myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;

%% Run the experiment.
c.add(neurostim.plugins.gui);
c.order('fix','target','dots','octagon','choice','gui');
c.run(myBlock);
