function c=whitenoiseDemo
%   This demo shows how to present a grid of pixel noise, for reverse
%   correlation analysis and/or signal-in-noise detection tasks.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%% ============== Add stimuli ==================
wn = stimuli.noiserastergrid(c,'grid');
wn.size = [32,64];          %Dimensionality of raster (30 texels high, 50 wide)
wn.height = 6.40;   %Width and height on screen
wn.width = 12.80;
wn.distribution = 'normal'; %Distribution from which luminance values are drawn
wn.parms = {0 40};          %{mean sd}
signalContrast = 0.15;
wn.bounds = (1-signalContrast)*[-128,128];%Truncate the distribution.

%Specify a signal to embed (the embedding happens automatically in the stimulus class)
sig=sin(linspace(0,8*pi,wn.size(2)));
wn.signal = signalContrast*repmat(sig,wn.size(1),1)*127+127;

%% Experimental design
c.trialDuration = 30000; 

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.grid.X = [-10 0 10];  

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run the experiment.
c.order('grid');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';
c.run(myBlock);

