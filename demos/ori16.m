function c = ori16(varargin)
% orientation/direction tuning w/ control script(s) for sending
% triggers via the Display++

% 2017-07-31 - Shaun L. Cloherty <s.cloherty@ieee.org>

import neurostim.*

% setup CIC and the stimuli
c = myRig;                            

% register our eScript(s) with cic
c.addScript('BeforeTrial',@beforeTrial);
c.addScript('BeforeFrame',@beforeFrame);

% define our eScript function(s)...
function beforeTrial(c)
  c.writeToFeed('Send ''trial start'' trigger...\n');
  data = [ones(1,10),zeros(1,248-10)]; % Bit 0
  BitsPlusPlus('DIOCommand',c.mainWindow,1,255,data,0);
  
%   txt = sprintf('dir=%.1f',c.dots.direction);
%   cbmex('comment',128,0,txt);
end

function beforeFrame(c)
  if c.dots.frame == 0
    c.writeToFeed('Send ''dots on'' trigger...\n');
    data = [ones(1,10),zeros(1,248-10)]*2; % Bit 1
    BitsPlusPlus('DIOCommand',c.mainWindow,1,255,data,0);
  end
end

% % add a Gabor stimulus
% g = neurostim.stimuli.gabor(c,'gabor');           
% g.color         = [0.5 0.5 0.5];
% g.contrast      = 0.5;  
% g.X             = 0;
% g.Y             = 0;
% g.sigma         = 3;
% g.frequency     = 3;
% g.phaseSpeed    = 10;
% % g.orientation   = 45;
% g.mask          = 'CIRCLE';
% g.duration      = 1000; % milliseconds?

d = stimuli.rdp(c,'dots');      %Add a random dot pattern.
d.X = 0;                 %Parameters can be set to arbitrary, dynamic functions using this string format. To refer to other stimuli/plugins, use their name (here "fix" is the fixation point).
d.Y = 0;                 %Here, wherever the fixation point goes, so too will the dots, even if it changes in real-time.       
d.on = 100;     %Motion appears 500ms after the subject begins fixating (see behavior section below). 
d.duration = 1000;
d.color = [1 1 1];
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;
d.noiseWidth = 0;

% try this... otherwise cbmex in the eScript
b = plugins.blackrock(c);
b.useMCC = false;

c.iti = '@rand*100+450';%500; %d.duration; % milliseconds
c.trialDuration = d.duration+d.on; % milliseconds

% define conditions and blocks
d = neurostim.design('ori16');
% d.fac1.gabor.orientation = [0:22.5:360-22.5]; % 16 directions?
d.fac1.dots.direction = [0:45:360-45]; % 16 directions?

myBlock = neurostim.block('MyBlock',d);
myBlock.nrRepeats = 1;
myBlock.randomization = 'RANDOMWITHOUTREPLACEMENT';

c.order('dots','eScript');

c.subject = 'Trump';

c.run(myBlock);
end