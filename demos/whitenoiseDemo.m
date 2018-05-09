function c=whitenoiseDemo
%   This demo shows how to present a grid of pixel noise, for reverse
%   correlation analysis and/or signal-in-noise detection tasks.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%% ============== Add stimuli ==================
wn = stimuli.noiseraster(c,'grid');
wn.size = [30,60];          %Dimensionality of raster (30 texels high, 50 wide)
wn.height = 10;   %Width and height on screen
wn.width = 20;
wn.distribution = 'normal'; %Distribution from which luminance values are drawn
wn.parms = {0 15};          %{mean sd}
maxContrast = 0.25;
wn.bounds = 128*[-(1-maxContrast) 1-maxContrast];   %Truncate the distribution.

%Specify a signal to embed (the embedding happens automatically in the stimulus class)
sig=sin(linspace(0,8*pi,wn.size(2)));
addProperty(wn,'sinusoid', repmat(sig,wn.size(1),1));
addProperty(wn,'contrast', 1);
wn.signal = '@grid.contrast*grid.sinusoid*128+127';

%% Experimental design
c.trialDuration = 3000;       %End the trial as soon as the 2AFC response is made.

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.grid.contrast = maxContrast*[0 0.5 1];  
myDesign.fac2.grid.X = [-10 0 10];  

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;

%% Run the experiment.
c.order('grid');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';
c.run(myBlock);

