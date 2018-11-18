function egiDemo
%Two-alternative forced choice (2AFC) motion task.
%
%This demo shows how to use:
%       - Visual stimuli
%       - Fixation control using (virtual or real) eye tracking.
%       - Gaze-contingent stimulus presentation.
%       - Subject feedback/reward.
%       - Specification of experiemntal design (factorials, blocks, trial randomization)
%
%The task:
%
%       - "Fixate" on the fixation point to start the trial by moving the mouse and clicking on it
%       - Is the motion upward (press "a") or downward (press "z")? Respond only once motion disappears.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========
%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%Make sure there is an eye tracker (or at least a virtual one)
if isempty(c.pluginsByClass('eyetracker'))
    e = neurostim.plugins.eyetracker(c);      %Eye tracker plugin not yet added, so use the virtual one. Mouse is used to control gaze position (click)
    e.useMouse = true;
end

%% ============== Add Recording ==================
 plugins.egi(c);           % Use the egi plugin

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
d.on = '@f1.startTime.Fixating+500';     %Motion appears 500ms after the subject begins fixating (see behavior section below). 
d.duration = 1000;
d.color = [1 1 1];
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;

%% ========== Add required behaviours =========

%Subject's 2AFC response
k = behaviors.keyResponse(c,'choice');
k.from= '@dots.on + dots.duration';
k.maximumRT = 2000;                   %Maximum allowable RT is 2000ms
k.keys = {'a' 'z'};                                 %Press 'a' for "upward" motion, 'z' for "downward"
k.correctFun = '@double(dots.direction < 0) + 1';   %Function returns the index of the correct response (i.e., key 1 or 2)

%Maintain gaze on the fixation point until the dots disappear
g = behaviors.fixate(c,'f1');
g.from = Inf; % 
g.to = '@dots.stopTime';
g.X = '@fix.X';
g.Y = '@fix.Y';
g.tolerance = 3;


%% Experimental design
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.

%Specify experimental conditions
myFac=design('myFactorial');           %Using a 3 x 2 factorial design.  Type "help neurostim/factorial" for more options.
myFac.fac1.fix.X={-10 0 10};                %Three different fixation positions along horizontal meridian
myFac.fac2.dots.direction={-90 90};         %Two dot directions
myFac.conditions(:).fix.Y = plugins.jitter(c,{0,4},'distribution','normal','bounds',[-5 5]);   %Vary Y-coord randomly from trial to trial (truncated Gaussian)

%Specify a block of trials
myBlock=block('myBlock',myFac);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1;

%% Run the experiment.
c.subject = '0';
c.run(myBlock);
    
