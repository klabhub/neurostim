function adamDemo

import neurostim.*
commandwindow;
% Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);

%% ========= Specify rig configuration  =========
c = cic;
c.screen.pixels = [0 0 1680 1050];       %Projector
c.screen.physical = [50 50/c.screen.pixels(3)*c.screen.pixels(4)];
c.screen.colorMode = 'RGB';
c.screen.color.background= [0.5 0.5 0.5];
c.trialDuration = Inf;
c.iti = 500;
% c.add(plugins.eyelink);
% c.add(plugins.blackrock);
c.add(plugins.debug);

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation('fix');
f.shape = 'CIRC';
f.size = 0.5;
f.color = [1 0 0];
c.add(f);

%Saccade target
t = duplicate(f,'target');
t.shape = 'STAR';
t.X = '@(fix) -fix.X';
c.add(t);

%Random dot pattern
s = stimuli.rdp('dots');
s.on = 500;
s.duration = Inf;
s.color = [1 1 1];
s.size = 6;
s.nrDots = 200;
s.maxRadius = 8;
s.lifetime = Inf;
s.noiseMode = 1;
s.X = '@(fix) fix.X';
s.Y = '@(fix) fix.Y';
s.on = '@(f1) f1.startTime + 500';      %Gaze-contingent onset of motion stimulus.
c.add(s);

%% Create a novel stimulus
a = stimuli.convPoly('octagon');
a.on = 1000;
a.nSides = 8;
a.color = [1 1 1];
a.X = '@(cic,fix) -fix.X + 2*sin(cic.frame/10)';
c.add(a);

%% ========== Add required behaviours =========

%Subject's 2AFC response
k = plugins.nafcResponse('choice');
k.keys = {'a' 'z'};
k.correctResponse = {'@(dots) dots.direction==90' '@(dots) dots.direction==-90'};
k.keyLabel = {'up', 'down'};
k.aq = true;
c.add(k);

%Maintain gaze on the fixation point
g = plugins.fixate('f1');
g.from = 500;
g.duration = 800;
g.X = '@(fix) fix.X';
g.Y = '@(fix) fix.Y';
g.tolerance = 1.5;
c.add(g);

%% Experimental design

%Specify experimental conditions
c.addFactorial('myFactorial', {'fix','X',{-10 10}},{'dots','direction',{90 -90}});

%Specify a block of trials
c.addBlock('myBlock','myFactorial',5,'SEQUENTIAL');

%% Run the experiment.
c.run;
