function xylTextureDemo
%% xyL Texture Demo
%
% This demo shows that a Gabor texture can also be defined using 
% calibrated xyL colors 
%
% BK - Feb 2017

import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig;
%% Tell CIC that we will be using xyL color
c.screen.colorMode = 'XYL'; % Tell PTB that we will use xyL to specify color
c.screen.color.text = [0.33 0.33 1]; % TODO: Text does not seem to work in xyL
c.screen.color.background = [0.33 0.33 20 ]; % Specify the color of the background
c.screen.calFile = 'PTB3TestCal'; % Tell CIC which calibration file to use (this one is on the search path in PTB): monitor properties
c.screen.colorMatchingFunctions = 'T_xyzJuddVos.mat'; % Tell CIC which CMF to use : speciifies human observer properties.

% Set up some other properties of this experiment. None are critical for
% calibrated color
c.screen.type   = 'GENERIC'; % Using a standard monitor, not a VPIXX or bits++
c.trialDuration = 1000;       % We'll use very short trials
c.iti           = 0;            
c.paradigm      = 'xylTextureDemo';
c.subjectNr     = 0;
c.addPropsToInform('gabor.color');


 
gab = stimuli.gabor(c,'gabor');
gab.color             = [0.33 0.33 20];
gab.contrast          = 1;
gab.Y                 = 0; 
gab.X                 = 0;
gab.sigma             = 1;                       
gab.phaseSpeed        = 10;
gab.orientation       = 90;
gab.mask              ='GAUSS';
gab.frequency         = 1;
gab.duration          = 1500;
gab.on                = 0;
gab.width               =10;
gab.height              =10;


%% Define conditions and blocks
% We use a two-way factorial on the position X and Y. Hence on different
% trials, the patch will be shown in different locations on the screen. 
xyl =design('xyl');
x = 0.2:0.1:0.8;
y = fliplr(x);
l = 25*ones(size(y));
xyl.fac1.gabor.orientation = 0:30:179;
xyl.fac2.gabor.color = num2cell([x' y' l'],2); 
blck=block('lmBlock',xyl);
blck.nrRepeats  = 1; % Show each location once
%% Run
c.run(blck);
