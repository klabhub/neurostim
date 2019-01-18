%function egiAvTester
% Experiment that tests timing reliability between NSPTB and EGI data
% acquisition
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
%   used in the analysis to correct alignment), but variance should be
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
% There is no reason why the Matlab clock (o.cic.clockTime) and the
% Netstation clock would have the same origin so the difference between
% them simply quantifies this difference in origin. Once we know the delay
% we can adjust the TCP timing clock on Netstation to correct it. You do this
% by entereing the mean offset from the Timing Tester as the
% egi.clockOffset parameter.

%
%  After doing this there is still an offset between the physical event of
%  stimulus onset (diode flash) and the TCP event. This is due to 
%When e.fineTuneOff
% With these settings in an example run the remaining offset was ~10 ms (1/85Hz), 
% (with positive numbers signifying that the Diode was
% detected after the TCP event (checked sign of this by delaying the FLIC
% event longer; this makes offsets more negative).
% 
% This implies that the FLIC Events are generated before the actual monitor
% flip occurs, which means that time keeping in NS PTB was off by a frame?
%
% TODO:
%   Add Audio tests
%   Incorporate the NS output file in the timing test to validate alignment
%   in Matlab too.
%
% BK  -Nov 2016

import neurostim.*

c= klabRig;
c.trialDuration = 500;
c.iti = 500;
c.screen.color.background = [0 0 0];
c.subject = getenv('computername');

e = plugins.egi(c); % Add the EGI plugin
e.clockOffset = 11; % 
e.syncEveryN = 10;

% To mimic a real experiment we generate a Gabor stimulus.
g=stimuli.gabor(c,'grating');           
g.color             = [0.5 0.5 0.5];
g.contrast          = 0.25;
g.Y                 = 0; 
g.X                 = 0;
g.sigma             = 3;                       
g.phaseSpeed        = 0;
g.orientation       = 15;
g.mask              ='CIRCLE';
g.frequency         = 3;
g.on                =  plugins.jitter(c,{500,250},'distribution','normal','bounds',[0 400]); % Turn on at random times
g.duration          = inf;   
g.phaseSpeed        = 10;

% To test onset timing, we use a small white square in the top left corner
% of the screen that turns on/off with the stimulus (this is built-in to
% all stimuli).
% On a generic monitor color should be [r g b]. 
% Size is specified as a fraction of the horizontal number of pixels in the monitor 
diode = struct('on',true,'location','nw','color',100,'size',0.01); 
g.diode = diode; % This will turn on at stimulus onset. The EGI AV Tester Diode should be pointed at the NorthWest corner to detect the onset.
% Specifically for EGI interaction we also tell the stimulus to call the
% logOnset function in the egi plugin when the stimulus first turns on in
% each trial.
g.onsetFunction  =@neurostim.plugins.egi.logOnset;  % This will generate events that are synched to Diode onset over TCP



%% Define conditions and blockçs
f=design('AvTester');     % Define a factorial with one factor
b=block('myBlock',f); 
b.nrRepeats  = 2500;       
b.randomization = 'SEQUENTIAL';
%% Run the experiment   
c.run(b);

%analyse(c.fullFile)
% end
% 
% function analyse(filename)
% load ([filename '.mat'])
% % Retrieve the time that the flicker onset was logged.
% % The data in this event is the actual fliptime (i.e. when PTB started the
% % stimulus in the top left of the monitor). The event is generated a bit
% % later; that is stored as the time of the event. Here we calculate what
% % the difference is so that we can correct for it in interpreting the
% % difference between photo-diode and TCP events in Netstation. 
% 
% 
% [v,t,t] = get(c.flicker.prms.startTime);
% [v,t,t] = get(c.egi.prms.startTime);
% v=[v{:}];
% out =isinf(v) ;
% v(out) =[];
% t(out) = [];
% tr(out) = [];
% %tr=tr-1;
% nrTr = max(tr);
% stimOnTime = nan(nrTr,1);
% eventGeneratedTime = nan(nrTr,1);
% for i=1:nrTr
%     stay = tr ==i;
%     [stimOnTime(i),ix]= min(v(stay));
%     tStay = t(stay);
%     eventGeneratedTime(i) = tStay(ix);
% end
% 
% % 
% %  [v,t,tr] = neurostim.utils.getproperty(data,'eventCode','egi','onePerTrial',false);
% %  out = ~strcmpi(v,'FLIC');
% %  v(out) = [];
% %  t(out) = [];
% %  tr(out)=[];
% 
% %%
% figure(1);
% clf
% subplot(1,2,1);
% plot(eventGeneratedTime,stimOnTime,'.')
% title(strrep(filename,'\','/'))
% axis equal
% axis square
% xlabel 'Trial Time (ms)'
% ylabel 'Flip Time (ms)'
% subplot(1,2,2);
% bins = -15:1:15;
% delta = eventGeneratedTime-stimOnTime;
% [m,s] = mstd(delta);
% hist(delta,bins)
% xlabel '\Delta (ms)'
% ylabel '#'
% title (char(['Mean \Delta : ' num2str(m,3) ' \pm ' num2str(s,2)],'Subtract this from offsets in Netstation'));
% 
% end
% 
% % Function that uses the EGI plugin to send an event to Netstation. This
% % relies ont he fact that the egi plugin has the name egi and is added to
% % CIC in the code above. Logging different codes could be achieved by using
% % an anonymous function like @(o,v) (sendEvent(o,v,'BLOB') as the
% % postproces function.
% function v= locSendEvent(c,code)
% if nargin <2
%     code = 'EVT';
% end
% %if c.flicker.on
% o.cic.egi.event(code); % This uses the handle to the egi plugin we know exists in the o.cic handle
% end