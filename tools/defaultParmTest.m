function c= defaultParmTest
% Demo to test that default parms are set correctly
% BK  - Feb 2017.

import neurostim.*

%% Setup the controller
c= myRig;
c.trialDuration = Inf;
c.screen.color.background = [ 0.5 0.5 0.5];
c.subjectNr= 0;

%% Add a Gabor;
% We'll simulate an experiment in which
% the grating's location (left or right) is to be detected
% and use this to estimate the contrast threshold
g=stimuli.gabor(c,'grating');
g.color             = [0.5 0.5 0.5];
g.contrast         = 0.25;
g.Y                     = 0;
g.X                     = 0;
g.sigma             = 3;
g.phaseSpeed   = 0;
g.orientation     = 0;
g.mask               = 'CIRCLE';
g.frequency        = 3;
g.on                    =  0;
g.duration          = 500;

%% Setup the conditions in a design object
d=design('orientation');
d.fac1.grating.orientation = [-45 45];  % One factor (orientation)
d.fac1.grating.X                = [-10 10];
d.conditions(2,1).grating.contrast = '@1'; % Only the X=10 grating should have high contrast
d.randomization = 'sequential';
% Create a block for this design and specify the repeats per design
myBlock=block('myBlock',d);
myBlock.nrRepeats = 10; 
c.trialDuration = 250;
c.run(myBlock);
