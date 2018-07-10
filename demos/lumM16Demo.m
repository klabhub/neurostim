function lumM16Demo
%% Calibrated Luminance Demo
%
% This demo shows how to use calibrated luminance to specify your stimuli
% using the M16 mode on a ViewPixx device. This screen type can generate
% high bit-depth monochromatic stimuli (M16 = ~ monochromatic 16 bits), while 
% at the same time having 256 colors available to show simpler items (like a
% red fixation dot), using indexed colors. 
% 
% Have a look at lumDemo first to see how luminance calibration works for
% a generic monitor.
% 
% BK - Mar 2017

import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig;
c.screen.colorMode = 'LUM'; % Allow specification of calibrated luminance as .color
c.screen.color.text = 30;  % Text luminance is 30 cd/m2
c.screen.color.background = 10.5; % A 10.5 cd/m2 luminance background 
% Note that PTB will complain about setting the background to a number
% larger than 1 as it thinks you are using numbers between 0 and 255.
% Ignore the warning, the code actually does the right thing as you can
% check by comparing the convPoly with the background in the second trial.


c.screen.type = 'VPIXX-M16'; % Tell neurostim we will be using a VPIXX monitor in M16 mode
c.trialDuration = 1000;
c.iti           = 150;
c.paradigm      = 'lumM16Demo';
c.subjectNr      =  0;

% Provide the results of your calibration measurement here. 
% 
% To determine thee parameters you measure the luminance for a range of
% gunvalues and then fit the above function (See tools/i1calibrate or 
% utils.ptbcal() for more informatione).
%
% gamma = the gamma of the monitor. Something near 2 usually.
% bias = the lowest gun value. 
% gain = 1 
% min = the smallest luminance that the gun can generate. 0.
% max = the largest luminance that the gun can generate. 
c.screen.calibration.gamma = 2.28; % Just one gamma; there is only one "gun"     
c.screen.calibration.bias = -0.0298;
c.screen.calibration.gain= 1;
c.screen.calibration.max = 100;
c.screen.calibration.min = 0;

% Convpoly to create the target patch (on the left) that will vary in (calibrated)
% luminance
grey = stimuli.convPoly(c,'grey');
grey.radius       = 5;
grey.X            = -10;
grey.Y            = 0;
grey.nSides       = 10;
grey.filled       = true;
grey.color        = 0;
grey.on           = 0;


% Convpoly to create the target patch (on the right) that will have a
% varying (noncalibrated) color across trials.
cPtch = duplicate(grey,'color');
cPtch.X            = +10;
cPtch.overlay      = true; 
% .overlay==true indicates that this stimulsu should be drawn on the color
% overlay, using color index mode. 
c.screen.overlayClut = [1 0 0; ... % .color =1 will be max saturated red
                        0 1 0; ...  % .color =2 will be max saturated green
                        0 0 1; ...  % .color =3 will be blue;
                        0.8 0.3 0.8];    %.color = 4 will be ...
% Neurostim will fill the remaining rows of the CLUT with [1 1 1], such
% that items with a larger color index that the clut you specified should be 
% shown as white.

%% Define conditions and blocks
lmc =design('lumAndColor');
lmc.fac1.grey.color = (0.5:10:10.5); % Vary the luminance  patch (on the left) with calibrated luminance.
lmc.fac2.color.color = [0 1 2 3 4 5];  % Vary the color patch with uncalibrated color indices. 0 = transparent, 1 = red, 2= green,etc.
lmc.randomization  ='sequential'; % Press 'n' to go to the next.
lmcBlck=block('lmBlock',lmc);
lmcBlck.nrRepeats  = 10;

%% Run the demo
c.run(lmcBlck);
