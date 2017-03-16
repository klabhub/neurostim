
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

%% Example BLOCKED Mode
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
% 
% This mode also allows for a Sham option. When .sham=true, the protocol is
% ramped up and immeditately ramped down again. It stays in sham until the
% next trial in which .sham=false (in which the protocol is ramped up again
% and then continues).
%
% d =design('d1');
% d.conditions(1).starstim.protocol = 'Neurostim.StimTest.Trigger';
% d.conditions(1).starstim.mode= 'BLOCKED';
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
% c.addPropsToInform('starstim.enabled','starstim.sham')
% c.run(blck,blck2,'nrRepeats',2,'randomization','sequential'); % Run sequentially. The .Trial protocol will be loaded before the first trial of the second block.



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
% until the stimulation is in stable state (i.e.  CODE_STATUS_STIMULATION_FULL)
% This time is spent in the ITI. This would result a longer ITI
% before a stimulated trial than before a non-stimulated trial. So if the design involves
% such trials (.enabled = false and .enabled =true) then it may be wise to
% set the c.iti to 2s such that all ITIs are equally long. 
% A similar issue arises with sham controls; the ramp up/down takes place
% in the ITI and will make that ITI longer than an ITI withotu sham. Again,
% setting the ITI to a longer time should solve this. 
% %
% d =design('DUMMY'); 
% d.fac1.starstim.enabled = [ false true];
% d.fac2.starstim.sham    = [ false true];
% d.fac1.patch.color  =  {[0 1 0],[1 0 0]};
% d.conditions(:).starstim.protocol = 'Neurostim.StimTest.Trial';
% d.conditions(:).starstim.mode = 'TRIAL';
% d.randomization = 'RANDOMWITHREPLACEMENT';
% blck=block('dummyBlock',d); 
% blck.nrRepeats  = 15;
% c.trialDuration = 3000; 
% c.iti = 2000;
% c.addPropsToInform('starstim.enabled','starstim.sham')
% c.run(blck); 



%% Example TIMED  mode.
% In this mode, stimulation can be turned on at a specific time in a trial (starstim.on)
% and it will last for a specified, fixed duration  (starstim.duration).
% Stimulation ends at the end of each trial, unless .itiOff = false in
% which case it will continue in the ITI unti starstim.duration has been
% reached. 
% In this mode you should setup your protocol with 0 amplitude currents on all 
% channels and then define the actual current amplitudes (and phases in the
% neurostim script). Note that you have to define both inward and outward
% currents and that this should add up to zero at all times.
% 
% Note that there is a minimum ramp up and rampdown time of 100 ms. If .on
% = 50, the ramp up will start at t=50 ms (and therefore the earliest time
% it is at full amplitude will be t=150ms, assuming that .transition is
% set to 100.

d =design('DUMMY'); 
stm.transition = 100; % time to transition from zero to full stim and from full stim to zero.
stm.stimType = 'AC';
stm.enabled  =true;
inout = [1 1/3 1/3 1/3 0 0 0 0];  % #1 = stim, #2-4 = return, each at 1/3.
stm.phase = [0    180 180 180 0 0 0 0]; % Anti-phase for return to conserve power.
stm.protocol = 'Neurostim.StimTest.Timed';
stm.mode = 'TIMED'; 

d.fac1.starstim.frequency = [1 2 5 10 20 40];
d.fac2.starstim.duration  = [1000 2000];
d.fac3.starstim.amplitude = {1500*inout, 500*inout, 2000*inout};
d.randomization = 'RANDOMWITHREPLACEMENT';
blck=block('dummyBlock',d); 
blck.nrRepeats  = 15;
c.trialDuration = 3000; 
c.iti= 2000;
c.addPropsToInform('starstim.amplitude','starstim.frequency','starstim.duration')
c.run(blck); 






