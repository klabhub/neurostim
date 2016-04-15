function adamDemo

import neurostim.*
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);

%% ========= Specify rig configuration  =========
c = adamsConfig;%bkConfig;

%Use DEBUG features
plugins.debug(c);

%Use the experimenter GUI window
% neurostim.plugins.gui(c);
% c.gui.toleranceColor = [1 1 0];

%Use/simulate Eylink eye tracker
e = neurostim.plugins.eyelink(c);
% e = neurostim.plugins.eyetracker(c);
% e.useMouse = true;

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
d.size = 4;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;
d.X = '@fix.X';
d.Y = '@fix.Y';
d.diode.on = true;


%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on = '@dots.on + dots.duration';
k.deadline = '@choice.on + 3000';
k.keys = {'a' 'z'};         %Press 'a' for "upward" motion, 'z' for "downward"
k.keyLabels = {'up', 'down'};
k.correctKey = '@double(dots.direction < 0) + 1';  %Function returns 1 or 2


%Maintain gaze on the fixation point until the dots disappear
g = plugins.fixate(c,'f1');
g.from = '@f1.startTime';
g.to = '@dots.stopTime';
g.X = '@fix.X';
g.Y = '@fix.Y';
g.tolerance = 3;


%% Specify rewards and feedback

%Give juice at the end of the trial for completing all fixations
r = plugins.liquid(c,'juice');
r.add('duration',100,'when','afterTrial','criterion','@f1.success');
% neurostim.plugins.mcc(c);

% Play a correct/incorrect sound for the 2AFC task
%     Use the sound plugin
% plugins.sound(c);
% 
%     Add correct/incorrect feedback
% s= plugins.soundFeedback(c,'soundFeedback');
% s.add('waveform','CORRECT.wav','when','afterFrame','criterion','@ choice.success & choice.correct');
% s.add('waveform','INCORRECT.wav','when','afterFrame','criterion','@ choice.success & ~choice.correct');


%% Experimental design
c.trialDuration = '@ choice.stopTime';

%Specify experimental conditions
myFac=factorial('myFactorial',2);
myFac.fac1.fix.X={0};
myFac.fac2.dots.direction={-90 90};

%Specify a block of trials
myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;

%% Run the experiment.
c.cursor = 'arrow';
c.order('sound','fix','dots','f1','choice','liquid','soundFeedback','Eyelink','gui');
c.subject = '999';
c.run(myBlock);
