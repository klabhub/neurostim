
import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig;
c.screen.colorMode = 'RGB'; % Allow specification of RGB luminance as color
c.screen.color.text = [1 0 0];  % A red text 
c.screen.color.background = [0.5 0.5 0.5]; % A high luminance background that looks "white" (same luminance for each gun)
c.dirs.output = 'c:/temp/';

c.screen.type = 'GENERIC';
c.trialDuration = 2000;
c.iti           = 150;
c.paradigm      = 'stimDemo';
c.subjectNr      =  0;

% Convpoly to create the target patch
ptch = stimuli.convPoly(c,'patch');
ptch.radius       = 5;
ptch.X            = 0;
ptch.Y            = 0;
ptch.nSides       = 10;
ptch.filled       = true;
ptch.color        = 0;
ptch.on           = 0;

fake = false;
stm = stimuli.starstim(c,'Neurostim.StimTest','localhost',fake);
stm.stim  = false;
stm.mode = 'SINGLE';
stm.on = 500;
stm.duration = 2000; 
stm.stimType = 'AC';
stm.amplitude = [0 0 1000 0 0 0 0 0 ];
stm.frequency   = 20;
stm.transition = 1000;

%% Define conditions and blocks
lm =design('lum');
lm.fac1.starstim.frequency= 5:10:100;
lm.randomization  ='sequential'; % Sequence through luminance. Press 'n' to go to the next.
lmBlck=block('lmBlock',lm);
lmBlck.nrRepeats  = 5;


%% Run the demo
c.run(lmBlck);