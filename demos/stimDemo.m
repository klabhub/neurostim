
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

stm = stimuli.starstim(c,'localhost');

%% Example TRIGGER Mode
% Load a protocol, start the ramp up phase in the first trial for which .enabeled=true
% and start that trial as soon as ramp-up is complete. The protocol keeps
% running as programmed in NIC software. Neurostim sends trialStart markers
% to NIC (and these can be seen in the NIC interface) but does not interact 
% with it in any other way. Once the first trial with .enabled =false is reached 
% (or at the end of the experiment) the protocol is paused (before that
% trial starts). The protocol is started again before the next .enabdled=true
% trial. Multiple steps in a NIC protocol will run consecutively, as defined 
% in the NIC protocol.
%
% This mode is useful for stimulation paradigms on a time scale
% of whole experiments or blocks. For instance in the example below, the
% first block uses a different protocol than the second block. 

% d =design('d1');
% d.conditions(1).starstim.protocol = 'Neurostim.StimTest.Trigger';
% d.conditions(1).starstim.mode= 'trigger';
% d.conditions(1).starstim.enabled = true; 
% blck=block('dummyBlock',d); 
% blck.nrRepeats  = 2;
% %   c.run(blck);  % Jusr running this block would start the protocol before trial 1
% % and stop it at the end of the experiment.
% % Create a duplicate of the design, but change the protocol
% d2 =duplicate(d,'d2');
% d2.conditions(1).starstim.protocol = 'Neurostim.StimTest.Trial';
% blck2=block('dummyBlock2',d2); 
% blck2.nrRepeats  = 2;
% c.run(blck,blck2,'nrRepeats',2); % Run sequentially. The .Trial protocol will be loaded before the first trial of the second block.



%% Example TRIAL mode
% In this mode the protocol will ramp up before
% each trial in which .enabled=true (adding ITI) and ramp down 
% after each such trial (adding more ITI there).  The ramp-down time is as
% defined in the protocol (current 1 second minimum). Note that stim.on times are
% ignored in this mode (and in the TRIGGER mode). 
% Becuase the protocol is simply started/paused repeatedly, this mode makes
% most sense to deliver one kind of stimulation (let's say 10 Hz Ac) to one
% set of electrodes. In that case you'd define a single protocol in NIC
% which has the appropriate montage, set the stim parameters (1mA,
% 10Hz,etc.) and set the duration of the protocol to something that is much
% longer than your experiment. 
% The temporal resolution of this stim paradigm is limited by the allowable
% ramp settings in the NIC. Currently a ramp takes at least 1 s and it takes longer
% until the stimulation is in stable state (i.e.
% CODE_STATUS_STIMULATION_FULL)
d =design('DUMMY');
d.fac1.starstim.enabled = [ false true];
d.fac1.patch.color  =  {[0 1 0],[1 0 0]};
d.conditions(:).starstim.protocol = 'Neurostim.StimTest.Trial';
d.conditions(:).starstim.mode = 'TRIAL';
d.randomization = 'RANDOMWITHREPLACEMENT';
blck=block('dummyBlock',d); 
blck.nrRepeats  = 15;
c.trialDuration = 3000; 
c.run(blck); 





