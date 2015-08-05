function  nsDemoExperiment

import neurostim.*
% Factorweights.
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference', 'ConserveVRAM', 32);

% c = myConfig('Eyelink',false);
% c = cic;                            % Create Command and Intelligence Center...
% c.screen.pixels = [0 0 1600 1000];         % Set the position and size of the window
% c.screen.color.background= [0 0 0];
% c.screen.colorMode = 'xyl';
% c.iti = 2000;
% c.trialDuration = inf;
c = myConfig;


c.add(plugins.debug);               % Use the debug plugin which allows you to move to the next trial with 'n'

% g=stimuli.gabor('gabor');           % Create a gabor stimulus.
% g.color = [1/3 1/3];
% g.luminance = 30;
% g.X = 0;                          % Position the Gabor
% g.Y = 0;                          
% g.sigma = 25;                       % Set the sigma of the Gabor.
% g.phaseSpeed = 10;
% c.add(g);



% t = stimuli.text('text');           % create a text stimulus
% t.message = 'Hello World';
% t.font = 'Courier New';
% t.textsize = 50;
% t.textalign = 'c';
% t.X = '@(mouse) mouse.mousex';
% t.Y = '@(mouse) mouse.mousey';
% t.antialiasing = 0;
% t.color = [1 1 0.5];
% c.add(t);


% 
f=stimuli.fixation('fix');           % Create a fixation stimulus.
f.on = 0;
f.duration = inf;
f.luminance = 50;
f.color = [1 1];
f.shape = 'STAR';
f.size = 1; 
f.size2 = 1;
% f.angle = '@(cic) cic.frame';
% f.X = '@(mouse) mouse.mousex';
% f.Y = '@(mouse) mouse.mousey';
f.X = 0;
f.Y = 0;
% 
c.add(f);
% 

fl = stimuli.fixation('fix1');
fl.on = 0;
f1.duration = inf;
fl.shape = 'CIRC';
fl.X = 5;
fl.Y = 0;

c.add(fl);


m = stimuli.mouse('mouse');
c.add(m);

% 
s = stimuli.rdp('dots');
s.color = [1/3 1/3];
s.luminance = 100;
s.motionMode = 1;
s.noiseMode = 0;
s.noiseDist = 1;
s.coherence = 0.8;
s.lifetime = 10;
s.duration = Inf;
s.size = 2;
s.maxRadius = 8;
% s.on = 60;
c.add(s);



% k = stimuli.nafcResponse('key');
% c.add(k);
% k.keys = {'a' 'z'};
% k.stimName = 'dots';
% k.var = 'direction';
% k.correctResponse = {(@(x) x<300 & x>180) (@(y) y>300 | y<180)};
% k.keyLabel = {'clockwise', 'counterclockwise'};
% k.endTrialonKeyPress = 1;

% s = stimuli.shadlendots('dots2');
% s.apertureD = 20;
% s.color = [1 1];
% s.luminance = 1;
% s.coherence = 0.8;
% s.speed = 10;
% s.direction = 0;
% c.add(s);


c.addFactorial('myFactorial',...
    {'dots','coherence',{0.1 0.9}}) ;

c.addBlock('myBlock','myFactorial',5,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.

c.add(plugins.output);



% b = plugins.fixate;
% c.add(b);
% c.add(plugins.reward);

% e=plugins.eyelink;
% e.eyeToTrack = 'binocular';

% f1 = plugins.fixate('f1');
% f1.X = 0;
% f1.Y = 0;
% f1.duration = 500;
% c.add(f1);
% f2 = plugins.fixate('f2');
% 
% f2.X = 5;
% f2.Y = 0;
% c.add(f2);
% 
% s=plugins.saccade('sac1',f1,f2);
% c.add(s);
% 
% e = plugins.eyelink;
% e.useMouse = true;
% c.add(e);


% c.add(plugins.mcc);

c.run;

% f=fixate;
% f.from = 100;
% f.to = 1000;
% f.X = 0;
% f.Y = 0;
% f.Z = 0;
% f.reward.type = 'LIQUID';
% f.reward.dur = 100;
% f.reward.when = 'TRIALEND';
% f.reward.when = 'IMMEDIATE';
% c.add(f);
% 
% r = reward
% r.type = 
