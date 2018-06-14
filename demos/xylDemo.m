function xylDemo
%% xyL Demo
%
% This demo shows how to use calibrated colors. 
% 
% You will first need a calibration using a colorimeter or a spectrometer
% This calibration should be saved as a cal struct. For an example, see the
% i1calibration experiment in the tools directory.
%
% In this demo we use an example calibration file that is provided with
% PTB; colors and luminances will only be approximatel right for your
% screen, but they show the principles. 
% 
% The idea is that you program your stimuli using CIE x,y and Luminance as
% the three color values. In other words, where you would otherwise put RGB
% values, you now put xyL values. The PTB imaging pipeline will take care
% of the conversion before these numbers are sent to the graphics card.
%
% BK - Feb 2017

import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig;
%% Tell CIC that we will be using xyL color
c.screen.colorMode = 'XYL'; % Tell PTB that we will use xyL to specify color
c.screen.color.text = [0.33 0.33 1]; % TODO: Text does not seem to work in xyL
c.screen.color.background = [0.33 0.33 25]; % Specify the color of the background
c.screen.calFile = 'PTB3TestCal'; % Tell CIC which calibration file to use (this one is on the search path in PTB): monitor properties
c.screen.colorMatchingFunctions = 'T_xyzJuddVos.mat'; % Tell CIC which CMF to use : speciifies human observer properties.

% Set up some other properties of this experiment. None are critical for
% calibrated color
c.screen.type   = 'GENERIC'; % Using a standard monitor, not a VPIXX or bits++
c.trialDuration = 10;       % We'll use very short trials
c.iti           = 0;            
c.paradigm      = 'xylDemo';
c.subjectNr     = 0;
c.clear         = 0;        % Tell CIC to never clear the screen. Everything that is draw stays on the screen.
c.itiClear      = 0;
% Convpoly to create a colored patch.
% The color is defined as a function of the postion of the patch. Basically
% when the patch moves from the left to the right of the creen, its CIE x coordinate 
% will range from 0 to 1 , and when it moves from bottom to top its CIE y
% coordinate will range from 0 to 1. By varying the X and Y position  (in
% the factorial design below), we trace out CIE color space on the monitor.
% 
ptch = stimuli.convPoly(c,'patch');
ptch.radius       = 1;
ptch.X            = 0;
ptch.Y            = 0;
ptch.nSides       = 10;
ptch.filled       = true;
ptch.color        = '@[(patch.X+0.5*cic.screen.width)/cic.screen.width (patch.Y+0.5*cic.screen.height)/cic.screen.height 40]';
ptch.on           = 0;

%% Define conditions and blocks
% We use a two-way factorial on the position X and Y. Hence on different
% trials, the patch will be shown in different locations on the screen. 
xyl =design('xyl');
xyl.fac1.patch.X = 0.5*(-c.screen.width:2:c.screen.width);
xyl.fac2.patch.Y = 0.5*(-c.screen.height:2:c.screen.height);
blck=block('lmBlock',xyl);
blck.nrRepeats  = 1; % Show each location once
%% Run
c.run(blck);
