function adamDemo

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========
c = cic;
c.screen.pixels = [0 0 1024 768];
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
f.shape = 'STAR';
f.color = [1 0 0];
c.add(f);

%Random dot pattern
s = stimuli.rdp('dots');
s.on = 60;
s.duration = 60;
s.color = [1 1 1];
s.size = 6;
s.nrDots = 200;
s.maxRadius = 8;
s.coherence = 0.5;
s.lifetime = 30;
s.X = '@(fix) fix.X';
s.Y = '@(fix) fix.Y';
% s.on = '@(f1) f1.startTime + 500';      %Gaze-contingent onset of motion stimulus.
c.add(s);

% %Create a novel stimulus
a = stimuli.polygon('Marcello');
a.on = 90;
a.nSides = 8;
a.X = '@(cic,fix) -fix.X + 3*sin(cic.frame/10)';
c.add(a);

%% ========== Add required behaviours =========

%Subject's response
k = stimuli.nafcResponse('key');
k.keys = {'a' 'z'};
% k.correctResponse = {'@(dots) dots.direction==90' '@(dots) dots.direction==-90'};
c.add(k);
k.stimName = 'dots';
k.var = 'direction';
k.correctResponse = {(@(x) x==90) (@(y) y==-90)};
k.keyLabel = {'up', 'down'};
k.endTrialonKeyPress = 1;

% %Maintain gaze on the fixation point
% g = plugins.fixate('f1');
% g.from = 500;
% g.duration = 1000;
% g.X = '@(fix) fix.X';
% g.Y = '@(fix) fix.Y';
% g.tolerance = 1.5;
% c.add(g);

%% Experimental design

%Specify experimental conditions
c.addFactorial('myFactorial', {'fix','X',{-10 10},'dots','direction',{90 -90}});

%Specify a block of trials
c.addBlock('myBlock','myFactorial',5,'SEQUENTIAL');

%% Run the experiment.
c.run;
