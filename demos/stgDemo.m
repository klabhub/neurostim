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

stm = stimuli.stg(c);
stm.libRoot ='c:\github\McsUsbNet';
% Specify shared parameters-  in principle these apply to each of the channels (because
% they are specified as scalars), but by specifing the .channel we limit
% stimulation to that channel alone. Setting .channel = [1 2] would apply
% the same stimulation to both channels. 
stm.channel = [1]; 
stm.currentMode = false; % If you're hooked up to an oscilloscope you want voltage mode. 
stm.rampUp = 1000; % Ramp up/down in 500 ms
stm.rampDown = 1000;
stm.duration =  100; %ms If the trial is shorter than this, the stimulation will be cutoff.
stm.nrRepeats = 50*10;
stm.syncOutChannel = []; % SyncOut Channel 1 will have a TTL out.
stm.phase = 0;   % This will only be used for tACS mode
stm.amplitude = 1000; % mV if currentMode = false
stm.frequency = 10;
stm.fun= 'tACS';
stm.mean = 0;
stm.mode= 'BLOCK';  % In this mode stimulator starts beforeBlock and ends in afterBlock
stm.downloadMode = true;

%% Streaming mode
useStreaming = true;
if useStreaming 
    % This mode can change stimulation on the fly, but it is a bit trickier
    % in that the PC has to ensure a steady flow of new stimulation values.
    % If the (desired) streamingLlatency is long enough (seconds) this works fine,
    % but for shorter latencies, the buffer cannot keep up and there will
    % be periods without stimulation. The plugin warns about this with an
    % underflow message. 
    stm.downloadMode = false;    
    stm.streamingLatency = 2000;    
    stm.streamingChannels = [1 ];
    stm.debugStream = false;
end


%% Design
d =design('DUMMY'); 
d.fac1.stg.frequency = [10 20];
blck=block('dummyBlock',d); 
blck.nrRepeats  = 20;
c.trialDuration = 2000; 
c.iti= 250;
c.addPropsToInform('stg.amplitude','stg.frequency','stg.duration','stg.fun')
c.run(blck); 





