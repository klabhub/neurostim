function noiseGridDemo
%   This demo shows how to present a grid of luminance noise, for reverse
%   correlation analysis and/or signal-in-noise detection tasks.
%   Shows how to make use of Matlab's built-in sampling distributions
%   (including clamping to a range), transparency mask, setting an update rate.
%
%   Type >> makedist to see a list of Matlab's supported sampling distributions.
import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%% ============== Add stimuli ==================
wn = stimuli.noisegrid(c,'grid');
wn.size_h = 50;  %Dimensionality of raster (30 texels high, 50 wide)
wn.size_v = 30;
wn.height = 9;   %Width and height on screen
wn.width = 15;
wn.distribution = 'normal'; %Distribution from which luminance values are drawn. 
wn.parms = {127 40};          %{mean sd}
wn.bounds = [0 255];
wn.frameInterval=16.666;

%Apply am alpha ramp
wn.alphaMask = repmat(logspace(-1.6,0,wn.size(2)),wn.size(1),1);

f = stimuli.fixation(c,'fix');
f.X = '@grid.X+sin(fix.frame/60)*8';
f.size = 2;
f.color = [0.6 0 0,0.5];

%Specify a signal to embed (the embedding happens automatically in the stimulus class)
% sig=sin(linspace(0,8*pi,wn.size(2)));
% wn.signal = signalContrast*repmat(sig,wn.size(1),1)*127+127;

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

function vals = ramp(o)
%vals = linspace(0,127,o.nRandels);
vals = ones(1,o.nRandels)*127;
vals(1) = 255;