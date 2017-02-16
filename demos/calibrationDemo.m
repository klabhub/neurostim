%% Calibration Demo
%
% Shows how to use calibrated colors
%
import neurostim.*;
%% Setup CIC and the stimuli.
c = klabRig('debug',true,'eyelink',false);    % Create Command and Intelligence Center with specific KLab settings
c.screen.colorMode = 'XYL'; % Allow specification of RGB luminance as color
c.screen.colorCheck =false;
c.screen.type = 'GENERIC';
c.trialDuration = 1000;
c.iti           = 250;
c.paradigm      = 'calibrate';
c.subjectNr      =  0;


c.screen.calibration.gamma =2.2;
c.screen.calibration.bias =0;
c.screen.calibration.gain= 1;
c.screen.calibration.max = [ 5 5 5];
c.screen.calibration.min =0;
c.screen.calibration.calFile = 'PTB3TestCal';
c.dirs.calibration =''; % Current directory has the calibration file.



% Convpoly to create the target patch
target = stimuli.convPoly(c,'target');
target.radius       = 5;
target.X            = 0;
target.Y            = 0;
target.nSides       = 4;
target.filled       = true;
target.color        = 0;
target.on           = 0;
target.duration     = 1000;


%% Define conditions and blocks
lm =design('lum');
lum = (0.5:1:30)';
lm.fac1.target.color = num2cell([lum lum lum],2);
lm.randomization  ='sequential';

xyl =design('xyl');
xyl.fac1.target.color = num2cell([0.6 0.3 10; 0.2 0.2 10; 0.2 0.6 10],2);
xyl.randomization  ='sequential';


blck=block('lmBlock',xyl);
blck.nrRepeats  = 5;
%% Run the calibration
c.run(blck);
