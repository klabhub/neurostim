function starstimClosedLoopDemo
% Shows how a closed loop paradigm with stimulation and eeg can be setup.
% See also starstimDemo for stimulation only examples
% 
% BK - Jan 2019

import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig('debug',true);
c.screen.colorMode = 'RGB'; % Allow specification of RGB luminance as color
c.screen.color.text = [1 0 0];  % Red text 
c.screen.color.background = [0.5 0.5 0.5]; % A high luminance background that looks "white" (same luminance for each gun)
c.dirs.output = 'c:/temp/';

c.screen.type = 'GENERIC';
c.trialDuration = 4000;
c.iti           = 150;
c.paradigm      = 'stimClosedLoopDemo';
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
stm.host = 'localhost';
stm.fake = false;   % Set to false if you're connected to a machine with NIC running
stm.protocol ='AboutNothing';  % This is a protocol that exists on the host (it has a long duration and it generates zero currents.)
stm.enabled = true;            
stm.mode = 'TRIAL';
stm.type = 'tDCS';
stm.transition = 500;  % Ramp up/down time
stm.duration  =1000;
stm.eegChannels = [3 4 5]; % From the protocol - we'll close the loop with these channels
stm.eegAfterTrial = @analyzeEeg; % This function will be called after each trial. In it, we can do whatever we want to close the loop.
%Defaut currents for the tDCS
stm.mean = [1000 -1000 0 0  0 0 0 0];
% We are going to change the mean in the analyzeEeeg function and set it to
% a new value, based on the eeg. Therefore we need to make the 'mean'
% parameter 'sticky' which means that its value will not be changed by CIC
% when the new trial starts. Without this the default would be restored at
% the beginning of each trial
makeSticky(stm,'mean');

% Creat a block
d =design('DUMMY'); 
d.fac1.patch.color  =  {[0 1 0],[1 0 0]}; %Green patch/red patch - 
d.randomization = 'RANDOMWITHREPLACEMENT';
blck=block('dummyBlock',d); 
blck.nrRepeats  = 15;
c.trialDuration = 2000; 
c.iti = 250;
c.addPropsToInform('starstim.mean')
c.run(blck); 

end

function analyzeEeg(eeg,time,o)
% Will be called with an eeg chunk at the end of a trial.
% o is the starstim object.

% Example of showing a rudimentary scrolling chart.
showEeg(eeg,time,o);

% Do some "analysis"
v   =var(eeg);
goUp = mod(round(v(1)),2)==0; % Result of the analysis is a decision to increase or decrease current.

if goUp 
    % Next trial, increase the current by 10 muA
    o.mean = o.mean + 100*sign(o.mean);  % Adjust the starstim parameter on the basis of the "analysis"
else
    o.mean = o.mean -100*sign(o.mean);
end
end



function showEeg(eeg,time,o)
% Simple, scrolling eeg chart.
% eeg is the eeg signal read in the time between the current and previous 
% call to this function.
% time is the sample time corresponding to the eeg
% o is the starstim object
figure(1);
if o.cic.trial==1
    clf;    
end
[nrSamples,nrChannels] = size(eeg);
ax =gca;
% Concatenate with previous data
if ~isempty(ax.Children)
    xData= ax.Children(1).XData';
    yData = cat(1,ax.Children.YData)';
    normalization = ax.UserData;
else    
    xData = [];
    yData =[];
    normalization = zeros(1,nrChannels);
end

yOffset = (1:nrChannels); % Offset the channels vertically

normalization = max([normalization; max(abs(eeg))]); % Normalize to the max over all.
normalization(normalization==0) = 1;
newY = repmat(yOffset,[nrSamples 1]) + eeg./repmat(normalization,[nrSamples 1]); 
yData = cat(1,yData,newY);
xData =cat(1,xData,time);
ax.UserData = normalization;
out = xData< (time(1) - 60); % Scroll 60s.
xData(out) = [];
yData(out,:)= [];
plot(xData,yData)
xlabel 'Time (s)'
ylabel 'EEG'
ax.YTick = 1:nrChannels;
ax.YTickLabels = num2str(o.eegChannels');
    
end


