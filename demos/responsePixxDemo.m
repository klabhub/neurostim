function responsePixxDemo
% Reaction time experiment using the responsePixx

%% Prerequisites. 
import neurostim.*

%% Setup CIC and the stimuli.
c = myRig;   
c.trialDuration = '@pixx.stopTime'; 
c.screen.color.background = 0.5*ones(1,3);

% Add a Gabor stimulus . 
g=stimuli.gabor(c,'gabor');           
g.color = [0.5 0.5 0.5 ];
g.sigma = 0.5;    
g.frequency = 3;
g.phaseSpeed = 0;
g.orientation = 0;
g.mask ='GAUSS';
g.duration = 250;

v = behaviors.pixxResponse(c,'pixx');
v.on = 0;
v.off= Inf;
v.successEndsTrial = true;
v.keys= {'b','r'}; % Allow use of b and r buttons
v.lit = {'b','r'}; % light them up
v.correctFun = '@1'; % ix=1 ('b') is the "correct" one...
v.maximumRT = 1000;

c.addPropsToInform('pixx.correct','pixx.button','pixx.stopTime')

%% Define conditions and blocks, then run. 
r = design('rt');
r.conditions(1).gabor.on= plugins.jitter(c,{250,1250});
rblk = block('rt',r);
rblk.nrRepeats = 100;
c.run(rblk);
end 