function c=glshaderDemo
%   This demo shows how to present a grid of pixel noise, for reverse
%   correlation analysis and/or signal-in-noise detection tasks.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%% ============== Add stimuli ==================

f = stimuli.fixation(c,'fix');
f.X = 0;
f.Y = 0;
f.size = 0.25;
f.color=[1 0 0];

g = stimuli.gllutimageChildDemo(c,'grid');
g.nGridElements = 225;

%% Experimental design
c.trialDuration = 30000; 

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.grid.X = 0;  

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run the experiment.
c.order('fix','grid');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';
c.run(myBlock);

