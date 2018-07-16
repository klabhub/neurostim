function fixateThenChooseDemo
% Show how to implement a simple task where the subject has to fixate one
% point and then saccade to a dot to indicate a direction of motion.
%
%   This demo shows how to use:
%       - Behavioral control
%
%   The task:
%
%       (1) "Fixate" on the fixation point to start the trial by clicking on it with the mouse
%       (2) Assess the direction of motion in the dots stimulus
%       (3) Fixate one of the dots that appear to indicate the perceived
%                 direcion of motion
%
%   *********** Press "Esc" twice to exit a running experiment ************

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

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation(c,'fix');    %Add a fixation stimulus object (named "fix") to the cic. It is born with default values for all parameters.
f.shape = 'CIRC';               %The seemingly local variable "f" is actually a handle to the stimulus in CIC, so can alter the internal stimulus by modifying "f".               
f.size = 0.25;
f.color = [1 0 0];
f.on=0;                         %What time should the stimulus come on? (all times are in ms)
f.duration = 3000;              %How long should it be displayed?

u = duplicate(f,'up');          % Dot for upward choices.
u.Y = 5;                    
u.X = 0;
u.on = '@dots.stopTime';          %Turns on when the dots go off

dwn = duplicate(u,'down');          % Dot for downward choices.
dwn.Y = -5;


%Random dot pattern
d = stimuli.rdp(c,'dots');      %Add a random dot pattern.
d.X = '@fix.X';                 %Parameters can be set to arbitrary, dynamic functions using this string format. To refer to other stimuli/plugins, use their name (here "fix" is the fixation point).
d.Y = '@fix.Y';                 %Here, wherever the fixation point goes, so too will the dots, even if it changes in real-time.       
d.on = '@fixThenChoose.startTime.FIXATING+500';     %Motion appears 500ms after the subject begins fixating (see behavior section below). 
d.duration = 1000;
d.color = [1 1 1];
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 0;
d.coherence = 0.8;
d.coordSystem = 0; % Polar


%% ========== Add required behaviours =========

g = behaviors.fixateThenChoose(c,'fixThenChoose');
g.X = 0; % Initial fixation
g.Y = 0;
g.from = 2000;       % If fixation has not started at this time, move to the next trial
g.to = '@dots.stopTime'; 
g.choiceDuration   = 500;  % keep fixating the answer dot for this long
g.saccadeDuration  = 1000; % Time allowed to go from the fixation ot the choice, after .to
g.radius = 5;
g.angles = [-90 90];  % These two angles are choice targets
g.correctFun = '@find(dots.direction==fixThenChoose.angles)'; % Return the ix of the correct angle
g.tolerance = 3;
g.failEndsTrial = true;
g.successEndsTrial  = true;


%% ========== Specify feedback/rewards ========= 
% Play a correct/incorrect sound for the 2AFC task
plugins.sound(c);           %Use the sound plugin

% Add correct/incorrect feedback
s= plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','correct.wav','when','afterTrial','criterion','@fixThenChoose.isSuccess');
s.add('waveform','incorrect.wav','when','afterTrial','criterion','@~fixThenChoose.isSuccess');

%% Experimental design
c.trialDuration = inf;                        % Trials are infinite, but the saccade behavior ends the trial on success or fail.

%Specify experimental conditions
myDesign=design('dummy');                       %Type "help neurostim/design" for more options.
myDesign.fac1.dots.direction = [-90 90];        % Up /Down
myDesign.retry = 'IMMEDIATE';
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run it
c.run(myBlock);
    
