function adamDemo

import neurostim.*
commandwindow;
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference','TextRenderer',1);

%% ========= Specify rig configuration  =========
c = adamsConfig;

%Use DEBUG features
plugins.debug(c);

%Use the experimenter GUI window
neurostim.plugins.gui(c);

%Use/simulate Eylink eye tracker
e = neurostim.plugins.eyelink(c);
e.useMouse = true;

%Add the Blackrock acquisition system
% neurostim.plugins.blackrock(c);

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation(c,'fix');
f.shape = 'CIRC';
f.size = 0.5;
f.color = [1 1 50];
f.on=0;
f.duration = Inf;


%Random dot pattern
d = stimuli.rdp(c,'dots');
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
d.diode.on = true;


%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on = '@(dots) dots.on + dots.duration';
k.deadline = '@(choice) choice.on + 3000';
k.keys = {'a' 'z'};
k.keyLabels = {'up', 'down'};
k.correctKey = '@(dots) double(dots.direction < 0) + 1';  %Function returns 1 or 2


%Maintain gaze on the fixation point
g = plugins.fixate(c,'f1');
g.from = '@(f1) f1.startTime';
g.to = '@(dots) dots.endTime';
g.X = '@(fix) fix.X';
g.Y = '@(fix) fix.Y';
g.tolerance = 3;


%% Specify rewards and feedback

%Give juice at the end of the trial for completing all fixations
r = plugins.liquid(c,'juice');
r.add('duration',100,'when','afterTrial','criterion','@(f1) f1.success');

% Play a correct/incorrect sound for the 2AFC task
%     Use the sound plugin
plugins.sound(c);


%     Add correct/incorrect feedback
plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','CORRECT','when','afterFrame','criterion','@(choice) choice.success & choice.correct');
s.add('waveform','INCORRECT','when','afterFrame','criterion','@(choice) choice.success & ~choice.correct');


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
