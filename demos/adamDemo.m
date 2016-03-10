function adamDemo

import neurostim.*
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
%Screen('Preference','TextRenderer',1);

%% ========= Specify rig configuration  =========
c = adamsConfig;%bkConfig;

%Use DEBUG features
plugins.debug(c);

%Use the experimenter GUI window
neurostim.plugins.gui(c);
gui.toleranceColor = [1 1 0];
c.screen.color.text = [1 1 1];

%Use/simulate Eylink eye tracker
e = neurostim.plugins.eyetracker(c);
e.useMouse = true;

%Add the Blackrock acquisition system
% neurostim.plugins.blackrock(c);

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation(c,'fix');
f.shape = 'CIRC';
f.size = 0.5;
f.color = [1 1 1];
f.on=0;
f.duration = Inf;


%Random dot pattern
d = stimuli.rdp(c,'dots');
d.on = '@f1.startTime';
d.duration = 1000;
d.color = [0.3 0.3 0.3];
d.size = 6;
d.nrDots = 200;
d.maxRadius = 8;
d.lifetime = Inf;
d.noiseMode = 1;
d.X = '@fix.X';
d.Y = '@fix.Y';
d.diode.on = true;


%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on = '@dots.on + dots.duration';
k.deadline = '@ choice.on + 3000';
k.keys = {'a' 'z'};
k.keyLabels = {'up', 'down'};
k.correctKey = '@double(dots.direction < 0) + 1';  %Function returns 1 or 2


%Maintain gaze on the fixation point
g = plugins.fixate(c,'f1');
g.from = '@f1.startTime';
g.to = '@dots.endTime';
g.X = '@fix.X';
g.Y = '@fix.Y';
g.tolerance = 3;


%% Specify rewards and feedback

%Give juice at the end of the trial for completing all fixations
r = plugins.liquid(c,'juice');
r.add('duration',100,'when','afterTrial','criterion','@f1.success');

% Play a correct/incorrect sound for the 2AFC task
%     Use the sound plugin
plugins.sound(c);


%     Add correct/incorrect feedback
s= plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','CORRECT.wav','when','afterFrame','criterion','@ choice.success & choice.correct');
s.add('waveform','INCORRECT.wav','when','afterFrame','criterion','@ choice.success & ~choice.correct');


%% Experimental design
c.trialDuration = '@ choice.endTime';

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
