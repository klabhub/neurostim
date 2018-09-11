function c=  stgDemo
% Demo to show (and test) stimulation functionality of the Multi Channel
% Systems, STG device series. These provide high-resolution (in time,
% current, and voltage) and complete control of electrical stimulation.
% 
% BK -  June 2016

import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig('debug',true);
c.screen.colorMode = 'RGB'; % Allow specification of RGB luminance as color
c.screen.color.text = [1 0 0];  % Red text 
c.screen.color.background = [0.5 0.5 0.5]; % A high luminance background that looks "white" (same luminance for each gun)
c.dirs.output = 'c:/temp/';

c.screen.type = 'GENERIC';
c.trialDuration = 4000;
c.iti           = 150;
c.paradigm      = 'stgStimDemo';
c.subjectNr      =  0;

% Convpoly to create the target patch
ptch = stimuli.convPoly(c,'patch');
ptch.radius       = 5;
ptch.X            = 0;
ptch.Y            = 0;
ptch.nSides       = 100;
ptch.filled       = true;
ptch.color        = [1 1 0];
ptch.on           = 0;

stm = stimuli.stg(c,'stg');
%stm.fake = true;   % Set to false if you're connected to a machine with NIC running
%stm.enabled = true;          


%% Stimulation defined per trial
% In this mode, stimulation can be turned on at a specific time in a trial (stg.on)
% and it will last for a specified, fixed duration  (stg.duration).
% Stimulation starts fresh with each trial, regardless of the duration parameter (in
% other words the duration should be less than the trial duration so that it can finish).
% A stimulus that has not finished when the new trial starts is set to zero (not ramped down). 
% Note that the rampUp and rampDown are included in the duration.

% Specify shared parameters-  in principle these apply to each of the channels (because
% they are specified as scalars), but by specifing the .channel we limit
% stimulation to that channel alone. Setting .channel = [1 2] would apply
% the same stimulation to both channels. 
stm.channel = [1 2]; % Only the channels specified here will be used.
stm.on = 500; % Stimulation will be triggered 500 ms after trial onset
stm.currentMode = false; % If you're hooked up to an oscilloscope you want voltage mode. 
stm.rampUp = 500; % Ramp up/down in 500 ms
stm.rampDown = 500;
stm.duration =  2000; %ms If the trial is shorter than this, the stimulation will be cutoff.
stm.persistent = false;
stm.syncOutChannel = 2; % SyncOut Channel 2 will have a TTL out.
stm.phase = 0;   % This will only be used for tACS mode
stm.amplitude = 1500; % mV % This will be used for both the noise function and the tACS mode

% Define a noise function with output that depends on the amplitude/mean
% set per trial
 noise  = @(x,o)(o.amplitude*rand(size(x))+o.mean);
% Design : half of trials get noise stimulation , the other half get 40Hz
% tACS. The patch changes color with stimulation type
d =design('DUMMY'); 
d.fac1.stg.channel = [1, 2];
d.fac1.stg.fun = {noise,'tACS'};  
d.fac1.stg.frequency = [NaN 40];
d.fac1.stg.mean    = [-750 0];
d.fac1.patch.color  = {[1 1 0], [1 0 0 ]};
% 
d.randomization = 'SEQUENTIAL';
blck=block('dummyBlock',d); 
blck.nrRepeats  = 2;
c.trialDuration = 2500; 
c.iti= 250;
c.addPropsToInform('stg.amplitude','stg.frequency','stg.duration','stg.fun')
c.run(blck); 
% 

return
%% Stimulation extends across trials.
% Here we setup a blocked design in which stimulation runs throughout one
% block of trials (including ITI) and then another block has only sham
% stimulation at the start.

d =design('DUMMY'); 
d.fac1.stg.fun = 'tACS';  
d.fac1.stg.frequency = 10;
d.fac1.stg.mean    = 0;
d.fac1.stg.persistent = true;
d.fac1.stg.duration  =  25000; % 25 s of stimulation (the estimated duration of the block)

s=duplicate(d,'SHAM');
s.fac1.stg.duration = stm.rampUp+stm.rampDown; % This ramps up then immediately down- so sham

stimBlck=block('stimBlock',d); 
stimBlck.nrRepeats = 10;
shamBlck = block('shamBlock',s);
shamBlck.nrRepeats = 10;
c.trialDuration = 2500; 
c.iti= 250;
c.addPropsToInform('stg.amplitude','stg.frequency','stg.duration','stg.fun')
c.run(stimBlck,shamBlck); 

% If you want stimulation to continue throughout a block, regardless of its
% duration, you can set the .duration to a large number (there are memory
% constraints... so not inf) and .persistent to true. When the new block
% starts  (or any trial with different stimulation parameters), the current
% stimulation will be terminated and the new one will be started. That new
% one could be 0 mA , or sham as defined here. You can test this by setting
% the nrRepeats to 5 in the above example.  There will be a warning on the
% command line that stimulation was terminated early, but other than that
% the design works; a tACS block followed by a Sham block. The main
% disadvantage is that there is no ramp-down in this case. 






