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
%   of the data display (FLIC, DIN1, plus other flags showin the start of
%   the trial, end of the trial etc.)
%
%   Once the experiment finishes, drop the NetStation MFF output file that 
%   was generated onto the 'Event Timing Tester' application (in EGI Utils
%   directory). 
%   From the drop-down menus in the Event Timing Tester: 
%       Choose 'Stim Event Code' =  'FLIC' (the name
%       of the flicker stimulus that generates the visual stimulus and the
%       software events) 
%       Chose "DIN Event Code' = 'DIN1'  (the source of the photodiode
%       detection pulses)
%   Then press Create Timing Table.
% 
%   The relevant numbers to look at are the average, maximum, and minium
%   offsets in the lower left window. A constant offset is fine (and should be
%   used in the analysis to correct alignment), but variance should be
%   minimal. Typically, events are logged with 
%   less than 2 ms variation around this. 
%      
%   Positive offsets means the diode detected the event later than the
%   software logged the event.
% 
% Notes.
%
% Order of events:
% Neurostim: STIMON  ---[3.8 ms]--- LOGSTIMON ---[0.1 ms]---Send FLIC EVENT ---- 
% Netstation: ---------- Netstation Receives DIN1    ------------ NetStation receives FLIC 
% Below, in analyse, we estimate the time between STIMON and LOGSTIMON (delta).
% In an example run it was 3.8 \pm 0.6 ms. I also looked at the time
% between the FLIC event being sent and the stimStarTime being logged it is
% negligible (0.1 ms). 
% 
% EGI's Timing Tester's offset is the difference between DIN1 time and FLIC
% time. The Netstation TCP interface allows you to set the clock that records 
% TCP events such as FLIC. There are a number of issues to consider.
% First, times are stored as int32 so we should set time zero to something
% not too far in the past. This is fine for cic.clockTime (it is zero at
% the start of the experiment).
% Second, there is a delay between sending an event via TCP and it being
% registered by Netstation. NetStation.m checks whether this is below some required
% value (e.g. 2.5 ms by default) and warns if that is not the case. I added
% some code to measure the average delay (7 ms in KLab PTB-P) *and* reset
% the clock time zero to effectively remove this delay. After that
% (egi.syncronize), neurostim and egi time are synched. 
% Third, the delay discussed above (delta) is also pretty stable and should
% be subtracted. I added an fineTuneClockOffset parameter to the egi plugin
% to allow users to do this. 
% 
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
c.trialDuration = 1200;
c.iti = 500;
c.screen.color.background = [0 0 0];
c.subject = getenv('computername');

e = plugins.egi(c); % Add the EGI plugin
e.fineTuneClockOffset = 0;%3.8; % Time between stimStart and logging stimStart.

% Convpoly to drive the photocell
flicker = stimuli.convPoly(c,'flicker');
flicker.radius       = 5;
flicker.X            = -25; % Top-left corned to remove the (deterministic) CRT scan effect (0.5/framerate in the center of the monitor)
flicker.Y            = +15;
flicker.nSides       = 100;
flicker.filled       = true;
flicker.color        = 100; [1 1 1];
flicker.duration     = 10;
flicker.on              =plugins.jitter(c,{500,250},'distribution','normal','bounds',[0 1000]);

%c.addScript('AfterFrame',@locSendEvent); % Tell CIC to call this eScript after drawing each frame.



%% Define conditions and blockçs
f=design('AvTester');     % Define a factorial with one factor

b=block('myBlock',f); 
b.nrRepeats  = 100;       
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