function c= adaptiveParmTest
% Demo to test that adaptive parms are set correctly
% A previous NS version failed to set/update a default jitter if the design
% only had a condition (and not factors).
% Run this, then check
%  c.blocks(1).design.specs(1)
% It shoud have two jitter objects, one for X, one for orientation.
%  c.blocks(1).design.specs(2)
% Should have a constant value (10) for X and a jitter for Y
% BK  - April 2022.

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

%% Setup the conditions in a design object
d=design('orientation');
d.conditions(1).grating.orientation = neurostim.plugins.jitter(c,{-45,45},'distribution','1ofN');

d.conditions(2).grating.Y = neurostim.plugins.jitter(c,{-10,10});
d.conditions(2).grating.X = 10;  % Overrules the jitter assigned to the object
d.randomization = 'sequential';
% Create a block for this design and specify the repeats per design
myBlock=block('myBlock',d);
myBlock.nrRepeats = 1; 
c.trialDuration = 250;
c.run(myBlock);
%% Show
c.blocks(1).design.specs(1)
c.blocks(1).design.specs(2)