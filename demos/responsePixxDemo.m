function responsePixxDemo
% reaction time experiment using the responsePixx

%% Prerequisites. 
import neurostim.*

%% Setup CIC and the stimuli.
c = myRig;   
c.trialDuration = '@responsePixx.stopTime'; 
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

v = neurostim.plugins.responsePixx(c,'responsePixx');
v.on = 0;
v.off= Inf;
v.successEndsTrial = true;

c.addPropsToInform('responsePixx.correct','responsePixx.pressedButton','responsePixx.stopTime')
%% Define conditions and blocks, then run. 
% One simple button press block; press the button that lights up...
d = design('press');
d.fac1.responsePixx.correctButtons= 1:5;
d.fac1.responsePixx.lit = 1:5;
blk = block('press',d);
blk.nrRepeats = 1;

r = design('rt');
r.conditions(1).gabor.on= plugins.jitter(c,{250,1250});
r.conditions(1).responsePixx.lit = plugins.responsePixx.BLUE;
r.conditions(1).responsePixx.allowedButtons =plugins.responsePixx.BLUE;
rblk = block('rt',r);
rblk.nrRepeats = 100;

c.run(rblk);
end 