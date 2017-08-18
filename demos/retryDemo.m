function c=behaviorDemo
%Two-alternative forced choice (2AFC) motion task:
%       
%       "Is the motion up or down?"
%
%   This demo shows how to use:
%       - Subject feedback/reward for correct/incorrect behaviors and
%       different options to retry failed trials
%
%   The task:
%
%       (1) Respond by pressing "a" for upward motion or "z" for downward motion (once motion disappears).
%
%   *********** Press "Esc" twice to exit a running experiment ************

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%% ============== Add stimuli ==================
%Random dot pattern
d = stimuli.rdp(c,'dots');      %Add a random dot pattern.
d.X = 0;
d.Y = 0;
d.on = 0;
d.duration = 1000;
d.color = [1 1 1];
d.size = 2;
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




%% ========== Specify feedback/rewards ========= 
% Play a correct/incorrect sound for the 2AFC task
plugins.sound(c);           %Use the sound plugin

% Add correct/incorrect feedback
s= plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','correct.wav','when','afterTrial','criterion','@choice.correct');
s.add('waveform','incorrect.wav','when','afterTrial','criterion','@ ~choice.correct');

%% Experimental design
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.dots.direction=[-90 90];         %Two dot directions

% By default, an incorrect answer is simply ignored (i.e. the condition is not repeatd).
% This corresponds to myDesign.retry ='IGNORE';
% To repeat a condition immediately if the answer is wrong (e.g. during trainig) , specify
% myDesign.retry = 'IMMEDIATE' 
% You can also repeate the condition at a later random point in the block, using the 'RANDOM' mode.
myDesign.retry = 'IMMEDIATE';
myDesign.maxRetry = 3;

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1;




%% Run the experiment.
c.subject = '0';
c.run(myBlock);
    
