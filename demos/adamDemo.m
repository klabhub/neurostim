function adamDemo

import neurostim.*
commandwindow;
% Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);

%% ========= Specify rig configuration  =========
c = adamsConfig;
c.add(plugins.debug);
c.trialDuration = Inf;

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation('fix');
f.shape = 'CIRC';
f.size = 0.5;
f.color = [1 1 50];
f.on=0;
f.duration = 1000;
c.add(f);

%Saccade target
t = duplicate(f,'target');
t.shape = 'STAR';
t.size = 3;
t.X = '@(fix) -fix.X';
c.add(t);

%Random dot pattern
s = stimuli.rdp('dots');
s.duration = Inf;
s.color = [0.3 0.3 100];
s.size = 6;
s.nrDots = 200;
s.maxRadius = 8;
s.lifetime = Inf;
s.noiseMode = 1;
s.X = '@(fix) fix.X';
s.Y = '@(fix) fix.Y';
s.on = '@(fix) fix.on + 500';
c.add(s);

%% Create a novel stimulus
a = stimuli.convPoly('octagon');
a.on = '@(f1) f1.startTime';
a.nSides = 8;
a.color = [0.5 1 50];
%a.X = '@(cic,fix) -fix.X + 2*sin(cic.frame/10)';
a.X = 0;
%a.rsvp = {{'nSides',{3 4 5 6 7 8 9 100},{'color',{[1 0.5 50],[0.5 1 50]}}},'duration',250,'isi',0};
c.add(a);

%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse('choice');
k.keys = {'a' 'z'};
k.correctResponse = {'@(dots) dots.direction==90' '@(dots) dots.direction==-90'};
k.keyLabel = {'up', 'down'};
k.endsTrial = true;
c.add(k);

e = neurostim.plugins.eyelink;
e.useMouse = true;
c.add(e);

%Maintain gaze on the fixation point
g = plugins.fixate('f1');
g.from = 3000;
g.duration = 5000;
g.X = '@(fix) fix.X';
g.Y = '@(fix) fix.Y';
g.tolerance = 1.5;
c.add(g);


c.add(plugins.reward('defaultReward'));
% b = plugins.liquidReward('liquid');
% b.when='AFTERTRIAL';
% c.add(b);

%% Experimental design

%Specify experimental conditions
c.addFactorial('myFactorial', {'fix','X',{-10 10}},{'dots','direction',{90 -90}});

%Specify a block of trials
c.addBlock('myBlock','myFactorial',2,'SEQUENTIAL');

%% Run the experiment.
c.run;
