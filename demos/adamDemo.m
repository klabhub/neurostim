function adamDemo

import neurostim.*
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference','TextRenderer',1);
%Screen('Preference', 'ConserveVRAM', 32);

%% ========= Specify rig configuration  =========
c = adamsConfig;
c.add(plugins.debug);
c.trialDuration = 5000;
%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation('fix');
f.shape = 'CIRC';
f.size = 0.5;
f.color = [1/3,1/3,50];
f.on=0;
f.duration = 1000;
c.add(f);

%Saccade target
t = duplicate(f,'target');
t.shape = 'STAR';
t.X = '@(fix) -fix.X';
c.add(t);

%Random dot pattern
s = stimuli.rdp('dots');
s.duration = Inf;
s.color =[1/3,1/3,50];
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
a.on = 1000;
a.nSides = 8;
a.color = [1/3,1/3,50];
%a.X = '@(cic,fix) -fix.X + 2*sin(cic.frame/10)';
a.X = 0;
a.rsvp = {{'nSides',{3 4 5 6 7 8 9 100}},'duration',300,'isi',0};
c.add(a);

%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse('choice');
k.keys = {'a' 'z'};
k.correctResponse = {'@(dots) dots.direction==90' '@(dots) dots.direction==-90'};
k.keyLabel = {'up', 'down'};
k.endsTrial = true;
c.add(k);

% c.add(neurostim.plugins.eyelink);
c.add(neurostim.plugins.gui);

%Maintain gaze on the fixation point
% g = plugins.fixate('f1');
% g.from = 500;
% g.duration = 800;
% g.X = '@(fix) fix.X';
% g.Y = '@(fix) fix.Y';
% g.tolerance = 1.5;
% c.add(g);

%% Experimental design

%Specify experimental conditions
c.addFactorial('myFactorial', {'fix','X',{-10 10}},{'dots','direction',{90 -90}});

%Specify a block of trials
c.addBlock('myBlock','myFactorial',2,'SEQUENTIAL');

%% Run the experiment.
c.order('fix','target','dots','octagon','choice','gui');
c.run;
