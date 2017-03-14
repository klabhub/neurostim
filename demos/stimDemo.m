
import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig;
c.screen.colorMode = 'RGB'; % Allow specification of RGB luminance as color
c.screen.color.text = [1 0 0];  % Red text 
c.screen.color.background = [0.5 0.5 0.5]; % A high luminance background that looks "white" (same luminance for each gun)
c.dirs.output = 'c:/temp/';

c.screen.type = 'GENERIC';
c.trialDuration = 4000;
c.iti           = 150;
c.paradigm      = 'stimDemo';
c.subjectNr      =  0;

% Convpoly to create the target patch
ptch = stimuli.convPoly(c,'patch');
ptch.radius       = 5;
ptch.X            = 0;
ptch.Y            = 0;
ptch.nSides       = 100;
ptch.filled       = true;
ptch.color        = [1 1 0];
ptch.on           = 0;

fake = false; % To test without NIC software
stm = stimuli.starstim(c,'protocol name','localhost',fake);

%% Example TRIGGER Mode
% Load a protocol, start the ramp up phase in the first trial for which .stim=true
% and start that trial as soon as ramp-up is complete. The protocol keeps
% running as programmed in NIC software. Neurostim sends trialStart markers
% to NIC (and these can be seen in the NIC interface) but does not interact 
% with it in any other way. Once the first trial with .stim =false is reached 
% (or at the end of the experiment) the protocol is paused (before that
% trial starts). The protocol is started again before the next .stim=true
% trial. Multiple steps in a protocol will run consecutively, as defined 
% in the  protocol.
%
d =design('DUMMY');
stm.protocol = 'Neurostim.StimTest.Trigger';
d.conditions(1).starstim.mode= 'trigger';
d.conditions(1).starstim.stim = true; % Start the protocol before trial 1
% and stop it at the end of the experiment.
blck=block('dummyBlock',d); 
blck.nrRepeats  = 5;
c.run(blck);


%% Example TRIAL mode
% In this mode the protocol will ramp up before
% each trial in which .stim=true (essentially adding ITI) and ramp down 
% after each such trial (adding more ITI there).  The ramp-down time is as
% defined in the protocol (current 1s minimum). Note that stim.on times are
% ignored in this mode (and in the TRIGGER mode). 
% Becuase the protocol is simply started/paused repeatedly, this mode makes
% most sense to deliver one kind of stimulation (let's say 10 Hz Ac) to one
% set of electrodes. In that case you'd define a single protocol in NIC
% which has the appropriate montage, set the stim parameters (1mA,
% 10Hz,etc.) and set the duration of the protocol to something that is much
% longer than your experiment. 
% The temporal resolution of this stim paradigm is limited by the allowable
% ramp settings in the NIC. Currently a ramp takes at least 1s and it takes longer
% until the stimulation is in stable state (i.e.
% CODE_STATUS_STIMULATION_FULL)
% d =design('DUMMY');
% stm.protocol = 'Neurostim.StimTest.Trial';
% stm.mode= 'TRIAL';
% d.fac1.starstim.stim = [ false true];
% d.fac1.patch.color  =  {[0 1 0],[1 0 0]};
% d.randomization = 'RANDOMWITHREPLACEMENT';
% blck=block('dummyBlock',d); 
% blck.nrRepeats  = 15;
% c.trialDuration = 3000; 
% c.run(blck); 





