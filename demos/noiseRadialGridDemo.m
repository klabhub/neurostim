function noiseRadialGridDemo
%   This demo shows how to present a radial grid of luminance noise, for reverse
%   correlation analysis and/or signal-in-noise detection tasks.
%   Shows how to make use of Matlab's built-in sampling distributions
%   (including clamping to the possible luminance/RGB range), transparency mask, setting an update rate.
%
%   Type >> makedist to see a list of Matlab's supported sampling distributions.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%% ============== Add stimuli ==================
f = stimuli.fixation(c,'fix');
f.X = '@grid.X+sin(fix.frame/60)*8';
f.size = 2;
f.color = [1 1 1];

wn = stimuli.noiseradialgrid(c,'grid');
wn.nWedges = 32;
wn.nRadii = 6;
wn.innerRad = 3;
wn.height = 13;   %Width and height on screen
wn.width = 13;
wn.sampleFun = 'normal'; %Distribution from which luminance values are drawn
wn.parms = [0.5 0.15];          %{mean sd}
wn.bounds = [0 1];
wn.alphaMask = 0.5*ones(wn.size);

%% Experimental design
c.trialDuration = 300000; 

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.grid.X = [-10 0 10];  

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run the experiment.
c.setPluginOrder('fix','grid');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';
c.run(myBlock);

