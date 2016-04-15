function adamDemo
%Two-alternative forced choice (2AFC) motion task.
%
%This demo shows how to use:
%       - Visual stimuli
%       - Fixation control using (virtual or real) eye tracking.
%       - Gaze-contingent stimulus presentation.
%       - Subject feedback/reward.
%
%Your task:
%
%       - "Fixate" on the fixation point to start the trial by moving the mouse and clicking on it (if you can't see the mouse, something might be wrong!)
%       - Is the motion upward (press "a") or downward (press "z")? Respond only once motion disappears.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a CIC object. Here the cic is returned with some default settings intitialised for Adam's rigs.
[c,opts] = adamsConfig;

%Track gaze position
if opts.eyeTracker
    e = neurostim.plugins.eyelink(c);         %Use real eye tracker. Must be connected.
else
    e = neurostim.plugins.eyetracker(c);      %If no eye tracker, use a virtual one. Mouse is used to control gaze position (click)
    e.useMouse = true;
end

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation(c,'fix');    %Add a fixation stimulus object (named "fix") to the cic. It is born with default values for all parameters.
f.shape = 'CIRC';               %The seemingly local variable "f" is actually a handle to the stimulus in CIC, so can alter the internal stimulus by modifying "f".               
f.size = 0.25;
f.color = [1 0 0];
f.on=0;                         %What time should the stimulus come on? (all times are in ms)
f.duration = Inf;               %How long should it be displayed?

%Random dot pattern
d = stimuli.rdp(c,'dots');      %Add a random dot pattern.
d.X = '@fix.X';                 %Parameters can be set to arbitrary, dynamic functions using this string format. To refer to other stimuli/plugins, use their name (here "fix" is the fixation point).
d.Y = '@fix.Y';                 %Here, wherever the fixation point goes, so too will the dots, even if it changes in real-time.       
d.on = '@f1.startTime+500';     %Motion appears 500ms after the subject begins fixating (see behavior section below). 
d.duration = 1000;
d.color = [0.3 0.3 0.3];
d.size = 4;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;

%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on = '@dots.on + dots.duration';
k.deadline = '@choice.on + 2000';                   %Maximum allowable RT is 2000ms
k.keys = {'a' 'z'};                                 %Press 'a' for "upward" motion, 'z' for "downward"
k.keyLabels = {'up', 'down'};
k.correctKey = '@double(dots.direction < 0) + 1';   %Function returns the index of the correct response (i.e., key 1 or 2)

%Maintain gaze on the fixation point until the dots disappear
g = plugins.fixate(c,'f1');
g.from = '@f1.startTime';
g.to = '@dots.stopTime';
g.X = '@fix.X';
g.Y = '@fix.Y';
g.tolerance = 3;


%% ========== Specify feedback/rewards ========= 
% Play a correct/incorrect sound for the 2AFC task
plugins.sound(c);           %Use the sound plugin

% Add correct/incorrect feedback
s= plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','CORRECT.wav','when','afterFrame','criterion','@choice.success & choice.correct');
s.add('waveform','INCORRECT.wav','when','afterFrame','criterion','@choice.success & ~choice.correct');

%% Experimental design
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.

%Specify experimental conditions
myFac=factorial('myFactorial',2);           %Using a 3 x 2 factorial design.  Type "help neurostim/factorial" for more options.
myFac.fac1.fix.X={-10 0 10};                       %Three different fixation positions along horizontal meridian
myFac.fac2.dots.direction={-90 90};         %Two dot directions

%Specify a block of trials
myBlock=block('myBlock',myFac);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run the experiment.
c.cursor = 'arrow';
c.order('sound','fix','dots','f1','choice','liquid','soundFeedback','Eyelink','gui');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'trump';
c.run(myBlock);
    
