function starstimDemo
import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig('debug',true);
c.screen.colorMode = 'RGB'; % Allow specification of RGB luminance as color
c.screen.color.text = [1 0 0];  % Red text 
c.screen.color.background = [0.5 0.5 0.5]; % A high luminance background that looks "white" (same luminance for each gun)
c.dirs.output = 'z:/klab/';

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

stm = stimuli.starstim(c,'starstim');
stm.fake = true;   % Set to false if you're connected to a machine with NIC running
stm.protocol ='AboutNothing';  % This is a protocol that exists on the host (it has a long duration and it generates zero currents.)
stm.enabled = true;            
%% Example BLOCKED Mode
% Load a protocol, start the ramp up phase in the first trial for which .enabeled=true
% and start that trial as soon as ramp-up is complete. Neurostim sends trialStart markers
% to NIC (and these can be seen in the NIC interface) but does not interact 
% with it in any other way. Once the last trial in the block is done 
% (or at the end of the experiment) the current is ramped down. 
% The protocol is ramped up again if a subsequent block has .enabled =true.
%
% This mode is useful for stimulation paradigms on a time scale
% of whole experiments or blocks. For instance in the example below, the
% first block uses a different protocol than the second block. 
% 
% This mode also allows for a Sham option. When .sham=true, the protocol is
% ramped up and immeditately ramped down again. It stays in sham for the
% whole block. 
% %
% stm.mode = 'BLOCKED';  % Choose a mode
% stm.type = 'tACS'; 
% stm.frequency = 10; % 10 Hz stimulation
% stm.phase = [0 180 zeros(1,6)]; % First two electrodes in anti-phase
% stm.amplitude = [1 1 zeros(1,6)];  % 1 mA of current 
% stm.transition = 500; % 500 ms ramp up/down
% 
% d =design('d1');
% d.conditions(1).starstim.sham = false;  
% blck=block('stimBlock',d); 
% blck.nrRepeats  = 5;
% 
% d2 =duplicate(d,'d2');
% d2.conditions(1).starstim.sham= true;
% blck2=block('shamBlock',d2); 
% blck2.nrRepeats  = 5;
% c.addPropsToInform('starstim.enabled','starstim.sham'); 
% c.run(blck,blck2,'nrRepeats',2,'randomization','sequential'); % Run sequentially. The .Trial protocol will be loaded before the first trial of the second block.
% 
% 
% 
% %% Example TRIAL mode
% In this mode the protocol will ramp up before
% each trial in which .enabled=true (adding ITI) and ramp down 
% after each such trial (adding more ITI there).  Note that stim.on times are
% ignored in this mode (and in the BLOCKED mode). 
% Because the protocol is simply ramped up/down repeatedly, this mode makes
% most sense to deliver one kind of stimulation (let's say 10 Hz Ac) to one
% set of electrodes. In that case you'd define a single protocol in NIC
% which has the appropriate montage, set the stim parameters (1mA,
% 10Hz,etc.) and set the duration of the protocol to something that is much
% longer than your experiment. 
% The temporal resolution of this stim paradigm is limited by the allowable
% ramp settings in the NIC. Currently a ramp (.transition) takes at least 100 ms 
% This time is spent in the ITI. This would result a longer ITI
% before a stimulated trial than before a non-stimulated trial. So if the design involves
% such trials (.enabled = false and .enabled =true) then it may be wise to
% set the c.iti to 1s such that all ITIs are equally long. 
% A similar issue arises with sham controls; the ramp up/down takes place
% in the ITI and will make that ITI longer than an ITI without sham. Again,
% setting the ITI to a longer time should solve this. 
%
% %
% d =design('DUMMY'); 
% d.fac1.starstim.sham = [ false true];
% d.fac1.patch.color  =  {[0 1 0],[1 0 0]}; %Green patch is Sham, red patch Stim.
% stm.enabled = true;
% stm.mode = 'TRIAL';
% stm.type = 'tDCS';
% stm.mean = [1000 -333 -333 -334 0 0 0 0 ]; % 1mA in through first , and out through second to fourth electrode. You can use the other electrodes for EEG.
% stm.transition = 500;  % Ramp up/down time
% d.conditions(:).starstim.mode = 'TRIAL';
% d.randomization = 'RANDOMWITHREPLACEMENT';
% blck=block('dummyBlock',d); 
% blck.nrRepeats  = 15;
% c.trialDuration = 2000; 
% c.iti = 1000;
% c.addPropsToInform('starstim.enabled','starstim.sham')
% c.run(blck); 
% 


%% Example TIMED  mode.
% In this mode, stimulation can be turned on at a specific time in a trial (starstim.on)
% and it will last for a specified, fixed duration  (starstim.duration).
% Stimulation ends at the end of each trial, unless .itiOff = false in
% which case it will continue in the ITI unti starstim.duration has been
% reached. 
% 
% Note that there is a minimum ramp up and rampdown time of 100 ms. If .on
% = 50, the ramp up will start at t=50 ms (and therefore the earliest time
% it is at full amplitude will be t=150ms, assuming that .transition is
% set to 100.
% % 
d =design('DUMMY'); 
stm.transition = 100; % time to transition from zero to full stim and from full stim to zero.
stm.type = 'tACS';
stm.enabled  =true;
inout = [1 .33 .33 .34 0 0 0 0];  % #1 = stim, #2-4 = return, each at 1/3.
stm.phase = [0 180 180 180 0 0 0 0]; % Anti-phase for return to conserve power.
stm.protocol = 'AboutNothing';
stm.mode = 'TIMED'; 
stm.amplitude = 1000*inout;
d.fac1.starstim.frequency = [5 40];
d.fac2.starstim.duration  = [1000 2000];
d.fac3.starstim.amplitude = {500*inout, 2000*inout};
d.randomization = 'RANDOMWITHREPLACEMENT';
blck=block('dummyBlock',d); 
blck.nrRepeats  = 15;
c.trialDuration = 3000; 
c.iti= 1000;
c.addPropsToInform('starstim.amplitude','starstim.frequency','starstim.duration')
c.run(blck); 



% 


