%Test script for openEphys class 
%Alan Ly 26/03/18
clear all 
clear classes
clc 

this = neurostim.plugins.openEphys('tcp://101.188.50.26:5556'); 
% for i = 1:3
    this = this.beforeExperiment('createnewdir', 1,'recdir', 'C:\OpenEphysRecordings', 'prependtext', 'hello', ...
        'appendtext', 'bye','StartMessage', 'So it begins...');    
    pause(5);
    this = this.afterExperiment('StopMessage', 'So it ends...'); 
    
% end 
