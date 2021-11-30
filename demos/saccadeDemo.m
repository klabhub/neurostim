function saccadeDemo
% Show how to implement a simple task where the subject has to fixate one
% point and then saccade to a second. 
%
%   This demo shows how to use:
%       - Behavioral control
%
%   The task:
%
%       (1) "Fixate" on the fixation point to start the trial by clicking on it with the mouse
%       (2) Fixate the new target once it appears.
%
%   *********** Press "Esc" twice to exit a running experiment ************

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.addPropsToInform('saccade.stateName'); % Show this value on the command prompt after each trial (i.e. whether the answer was correct and whether fixation was successful).

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

t = duplicate(f,'target');      % make a duplicate, called target.
t.X = NaN;                      % Will be varied in the factorial design, below.
t.on = '@fix.on + fix.duration';  % Use a function to turn on when target turns off


%% ========== Add required behaviours =========

g = behaviors.saccade(c,'saccade');
g.X = '@fix.X';
g.Y = '@fix.Y';
g.from = 2000;       % If fixation has not started at this time, move to the next trial
g.to = '@fix.stopTime'; 
g.saccadeDuration = 2000;
g.targetDuration = 1000;
g.targetX = '@target.X';
g.targetY = '@target.Y';
g.tolerance = 3;
g.failEndsTrial = true;
g.successEndsTrial  = true;


%% ========== Specify feedback/rewards ========= 
% Play a correct/incorrect sound for the 2AFC task
plugins.sound(c);           %Use the sound plugin

% Add correct/incorrect feedback
%s= plugins.soundFeedback(c,'soundFeedback');
%s.add('waveform','correct.wav','when','afterTrial','criterion','@saccade.isSuccess');
%s.add('waveform','incorrect.wav','when','afterTrial','criterion','@ ~choice.isSuccess');

%% Experimental design
c.trialDuration = inf;                        % Trials are infinite, but the saccade behavior ends the trial on success or fail.

%Specify experimental conditions
myDesign=design('dummy');                      %Type "help neurostim/design" for more options.
myDesign.fac1.target.X = [10 -10];
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;
%% Run it
c.run(myBlock);
    
