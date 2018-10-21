%Test script for openEphys class 
%Alan Ly 26/03/18
clear all 
clear classes 
clc 

import neurostim.* 

c = myRig; %call function myRig which constructs cic object  

o = neurostim.plugins.openEphys(c, 'HostAddr', 'tcp://101.188.35.200:5556', 'StartMsg', 'Hello World', 'StopMsg', 'Bye', ...
     'CreateNewDir', 1, 'AppendText', 'Tue', 'PrependText', 'Jun');  

%Dummy stimuli for testing purposes
f = stimuli.fixation(c,'reddot');       
f.color             = [1 0 0];
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 0.1;
f.on                = 0;                % On from the start of the trial
f.X                 = 0;  % This is all that is needed for gaze-cotingency.
f.Y                 = 0;

s = stimuli.shadlendots(c,'dots'); %
s.apertureD = 15;
s.color = [1 1 1];
s.coherence = 0.8;
s.speed = 5;
s.maxDotsPerFrame =100;
s.direction = 0;
s.dotSize= 5;
s.Y=0;
s.X=0; 

d =design('dummy'); 
d.conditions(1).reddot.size = 0.1; %Dummy condition
blk = block('dummy',d); 
blk.nrRepeats = 100; 
c.run(blk); %Run experiment