function c= blockDoneTest
% Test that block done and afterBlock updates are working
% BK  - June 2022.

import neurostim.*

%% Setup the controller
c = myRig('debug',true);
c.trialDuration = Inf;
c.screen.color.background = [ 0.5 0.5 0.5];
c.subjectNr= 0;

%% Add a Gabor;
g=stimuli.gabor(c,'grating');
g.color            = [0.5 0.5 0.5];
g.contrast         = 0.25;
g.Y                = 0;
g.X                = neurostim.plugins.jitter(c,{-10,10});
g.sigma            = 3;
g.phaseSpeed       = 0;
g.orientation      = 0;
g.mask             = 'CIRCLE';
g.frequency        = 3;
g.on               = 0;
g.duration         = 500;

k = behaviors.keyResponse(c,'choice');
k.from = 0;
k.maximumRT= Inf;                   %Allow inf time for a response
k.keys = {'a' 'z'};                                 %Press 'a' for "left side of screen" 'z' for right side
k.correctFun = '@double(grating.X > 0) + 1';   %Function returns the index of the correct response (i.e., key 1 or 2)
k.required = true; %   Repeat until correct


%% Setup a single condition
d=design('orientation');
d.conditions(1).grating.orientation = 0;
d.randomization = 'sequential';
d.retry ='ignore';   

% Create a block for this design and specify the repeats per design
myBlock=block('myBlock',d);
myBlock.nrRepeats = 1; 
c.trialDuration = 250;
c.addPropsToInform('cic.blockDone')
c.run(myBlock);
