%Test script for openEphys class 
%Alan Ly 26/03/18
clear all 
clear classes
clc 

import neurostim.* 

c = myRig; %call function myRig which constructs cic object 

%url = zeroMQrr('StartConnectThread', 'tcp://101.188.50.26:5556')
o = neurostim.plugins.openEphys(c,'tcp://101.188.50.26:5556'); 

o.startMsg = 'Begin';
o.stopMsg = 'End';

 %for i = 1:3
    o = o.beforeExperiment('prependtext', 'integrate', ...
        'appendtext', 'neurostim');    
    pause(5)
    o = o.afterExperiment; 
    pause(5)
 %end 
