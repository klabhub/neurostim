function behaviorDemo
%Two-alternative forced choice (2AFC) motion task:
%       
%       "Is the motion up or down?"
%
%   This demo shows how to use:
%       - Visual stimuli
%       - Specification of experimental design (factorial design, blocks, trial randomization)
%       - Fixation control using eye tracking (uses the mouse if no eye tracker attached).
%       - Gaze-contingent stimulus presentation.
%       - Subject feedback/reward for correct/incorrect behaviors.
%       - Different options to retry failed trials (see myDesign.retry
%       below).  Here we retry any trial in which the eye 
%       moves out of the fixation window. 
%
%   The task:
%
%       (1) "Fixate" on the fixation point to start the trial by clicking on it with the mouse
%       (2) Respond by pressing "a" for upward motion or "z" for downward motion (once motion disappears).
%
%   *********** Press "Esc" twice to exit a running experiment ************

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.addPropsToInform('choice.correct','f1.stateName'); % Show this value on the command prompt after each trial (i.e. whether the answer was correct and whether fixation was successful).
c.subject = 'easyD';

%Make sure there is an eye tracker (or at least a virtual one)
if isempty(c.pluginsByClass('eyetracker'))
    e = neurostim.plugins.eyetracker(c);      %Eye tracker plugin not yet added, so use the virtual one. Mouse is used to control gaze position (click)
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
d.on = '@f1.startTime.fixating+500';     %Motion appears 500ms after the subject begins fixating (see behavior section below). 
d.duration = 1000;
d.color = [1 1 1];
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 0;
d.coherence = 0.6;

%% ========== Add required behaviours =========

%Subject's 2AFC response
% Use this is you want to receive a single key press 
k = behaviors.keyResponse(c,'choice');
% or this if you want to allow subjects to change their mind:
%k = behaviors.multiKeyResponse(c,'choice');
k.from = '@dots.startTime + dots.duration';
k.maximumRT= Inf;                   %Allow inf time for a response
k.keys = {'a' 'z'};                                 %Press 'a' for "upward" motion, 'z' for "downward"
k.correctFun = '@double(dots.direction < 0) + 1';   %Function returns the index of the correct response (i.e., key 1 or 2)
k.required = false; %   This means that even if this behavior is not successful (i.e. the wrong answer is given), the trial will not be repeated.

%Maintain gaze on the fixation point until the dots disappear
g = behaviors.fixate(c,'f1');
g.from = 5000; % If fixation has not started at this time, move to the next trial
g.to = '@dots.stopTime';
g.X = '@fix.X';
g.Y = '@fix.Y';
g.tolerance = 3;
g.required = true; % This is a required behavior. Any trial in which fixation is not maintained throughout will be retried. (See myDesign.retry below)

%% ========== Specify feedback/rewards ========= 
% Play a correct/incorrect sound for the 2AFC task
plugins.sound(c);           %Use the sound plugin

% Add correct/incorrect feedback
s= plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','correct.wav','when','afterTrial','criterion','@choice.correct');
s.add('waveform','incorrect.wav','when','afterTrial','criterion','@ ~choice.correct');

%% Experimental design
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.
k.failEndsTrial = false;
k.successEndsTrial  = false;

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.fix.X=   [-10 0 10];             %Three different fixation positions along horizontal meridian
myDesign.fac2.dots.direction=[-90 90];         %Two dot directions
% Jitter the Y position in all conditions of the 2-factor design (you have
% to explicitly specify two ':' to represent the two factors, a single (:) is interpreted as a single factor and will fail.)
myDesign.conditions(:,:).fix.Y =  plugins.jitter(c,{0,4},'distribution','normal','bounds',[-5 5]);   %Vary Y-coord randomly from trial to trial (truncated Gaussian)

% Now we use this design to create an experiment.
% By default, an incorrect answer is simply ignored (i.e. the condition is not repeated).
% This corresponds to retry ='IGNORE';
% To repeat a condition immediately if the behavioral requiremnts are not met (e.g. during trainig) , specify
% You can also repeate the condition at a later random point in the block, using the 'RANDOMINBLOCK' mode.
% Note that because we made the choice not required, a trial with the wrong
% answer will not be retried, only trials with a fixation break.

%% Run the experiment.
c.run(myDesign,'retry','IMMEDIATE','maxRetry',20,'nrRepeats',10);
    
