% Experiment that tests timing reliability between Matlab and EGI data
% acquisition.
%
% Hardware:
%  Connect the DIN output of the EGI AV Tester to the DIN port on the
%  NetAmp (second from the top, labeled Din 1-8)
%  Connect photodiode to AV tester
%  Position the photodiode in the top left corner of the subject monitor
% 
% NetStation Acquisition:
%   In Hardware Settings, in DIN 1-8, select 'Din 1'
% 
% NSPTB:
%   Start this experiment. The 'subject' will be the computer that this is
%   run on. A Neurostim data file will be generated, but it is not needed
%   in the analysis (yet).
% 
% NetStation:
%   While the experiment runs, you should see the event markers at the top
%   of the data display (GRAT, DIN1, plus other flags showing the start of
%   the trial, end of the trial etc.)
%
%   Once the experiment finishes, open the NetStation MFF output file that 
%   was generated with the 'Event Timing Tester' application (in EGI Utils
%   directory). 
%   From the drop-down menus in the Event Timing Tester: 
%       Choose 'Stim Event Code' =  'GRAT' (the name
%       of the gabor stimulus that generates the visual stimulus and the
%       software events) 
%       Chose "DIN Event Code' = 'DIN1'  (the source of the photodiode
%       detection pulses)
%   Then press Create Timing Table.
% 
%   The relevant numbers to look at are the average, maximum, and minium
%   offsets in the lower left window. A constant offset is fine (and should be
%   used in the analysis to correct alignment;see below), but variance should be
%   minimal. Typically, events are logged with less than 2 ms variation. 
%      
%   Positive offsets means the diode detected the event later than the
%   software logged the event.
% 
% Notes.
%
% 
% EGI's Timing Tester's offset is the difference between DIN1 time and GRAT
% time. 
% The time that is passed to NetStation is the time on the high-precision
% Matlab clock that the screen was flipped to show the grating. So, if PTB
% is working correctly (no frame synchronization errors/frame drops), this
% is the precise moment when the top left of the screen becomes white,
% which is detected with ~0 delay by the photodiode and timed by Netstation
% as the DIN1 event. 
%
% There is no reason why the Matlab clock (o.cic.clockTime) and the
% Netstation clock would have the same origin. So the difference between
% them simply quantifies this difference in origin. Once we know the delay
% we can adjust the TCP timing clock on Netstation to correct it. You do this
% by entereing the mean offset from the Timing Tester as the
% egi.clockOffset parameter.
%
% So run this script once with 100 trials to estimate the offset(using Timing Tester) and
% then enter the mean timing tester offset as the e.clockOffset parameter
% below and then run it for a 1000 trials to confirm that the offset in
% Timing Tester is (close to) zero.
%
% See also demos/egiDemo
% BK  -Nov 2016
% BK - Jan 2019 - major overhaul

import neurostim.*

c= myRig;
c.trialDuration = 500;  % Rapid trials to get many GRAT events in the EGI fiel
c.iti = 150;
c.screen.color.background = [0 0 0];
c.subject = getenv('computername');

%% Setup the EGI Plugin
e = plugins.egi(c); % Add the EGI plugin
% On your first run, set this to 0 to measure the delay between photodiode
% and the TCP generated GRAT event
e.clockOffset = 0;  % In KLab rig this is 13.5 ms. 
% If you have Netstation 3.5 or later and a NetAMP 400 or later then use
% NTPSync mode - it is the most reliable way to keep Matlab and EGI clocks
% synchronized.
e.useNTPSync = true; 
e.syncEveryN = 0;  % NTP synchronization is only done once 
%If you have an older version or NTP does not work, you can try this:
%e.useNTPSync =false; % 
%e.syncEveryN = 25; % In every 25th inter trial interval the EGI TCP clock 
                    % will be adjusted so that we're in sync again. You can
                    % try running this as Inf, and run ~150 trials to see
                    % how often you should sync (Look through the dealys in
                    % the output of the EGI Timing Tester program to see
                    % how fast the clock drifts.
% You may receive a message that NetStation synchronization did not succceed within 2.5ms
% and that synchronization accuracy is something larger. I dont understand
%  the logic behind that message:  the code in Netstation tests how
% long it takes to deliver an event to NetStation. If that is more than 2.5
% ms it complains about lack of synchronization. But this is incorrect: the
% mean event delivery time does not matter for synchronization. It is the
% consistency that matters, but that is not computed. Unless you have a
% very busy network this method should work fine. (And you can confirm by
% looking at the TimingTester results). But for this non-NTP sync, repeated
% synchronization is necessary every 25 trials or so.
                    
%%
% To mimic a real experiment we generate a Gabor stimulus.
g=stimuli.gabor(c,'grating');           
g.color             = [1 1 1];
g.contrast          = 0.25;
g.Y                 = 0; 
g.X                 = 0;
g.sigma             = 3;                       
g.phaseSpeed        = 0;
g.orientation       = 15;
g.mask              ='CIRCLE';
g.frequency         = 3;
g.on                = plugins.jitter(c,{500,250},'distribution','normal','bounds',[0 400]); % Turn on at random times
g.duration          = inf;   
g.phaseSpeed        = 10;

%% Setup for timing test using a photo diode
% To test onset timing, we use the .diode property of the stimulus class.
% It presents a small white square in the top left corner
% of the screen that turns on/off with the stimulus (this is built-in to
% all stimuli).
% On a generic monitor color should be [r g b]. 
% Size is specified as a fraction of the horizontal number of pixels in the monitor 
diode = struct('on',true,'location','nw','color',100,'size',0.01); 
g.diode = diode; % This will turn on at stimulus onset. The EGI AV Tester Diode should be pointed at the NorthWest corner to detect the onset.
% Specifically for EGI interaction we also tell the stimulus to call the
% logOnset function in the egi plugin when the stimulus first turns on in
% each trial. T
g.onsetFunction  =@neurostim.plugins.egi.logOnset;  % This will generate events that are synched to Diode onset over TCP



%% Define conditions and blockçs
f=design('AvTester');     % Define a factorial with one factor
b=block('myBlock',f); 
b.nrRepeats  = 500;        
b.randomization = 'SEQUENTIAL';
%% Run the experiment   
c.run(b);

