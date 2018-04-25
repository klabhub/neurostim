%Test script for openEphys class 
%Alan Ly 26/03/18
clear all 
clear classes
clc 

import neurostim.* 

c = myRig; %call function myRig which constructs cic object 
c.trialDuration = 5000;

%url = zeroMQrr('StartConnectThread', 'tcp://101.188.50.26:5556')
o = neurostim.plugins.openEphys(c, 'HostAddr', 'tcp://101.188.50.26:5556', 'StartMsg', 'Hello World', 'StopMsg', 'Bye', ...
    'CreateNewDir', 1, 'AppendText', 'Thur', 'PrependText', 'April');  

%Dummy stimuli for testing purposes
f = stimuli.fixation(c,'reddot');       
f.color             = [1 0 0];
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 0.1;
f.on                = 0;                % On from the start of the trial
f.X                 = '@eye.x';  % This is all that is needed for gaze-cotingency.
f.Y                 = '@eye.y';

s = stimuli.shadlendots(c,'dots'); %
s.apertureD = 15;
s.color = [1 1 1];
s.coherence = 0.8;
s.speed = 5;
s.maxDotsPerFrame =100;
s.direction = 0;
s.dotSize= 5;
s.Y='@reddot.Y+5';
s.X='@reddot.X+5';

d =design('dummy'); 
d.conditions(1).reddot.size = 0.1; %Dummy condition
blk = block('dummy',d); 
blk.nrRepeats = 10; 
c.run(blk); %Run experiment