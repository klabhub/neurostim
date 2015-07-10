function  nsDemoExperiment

import neurostim.*
% Factorweights.
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference', 'ConserveVRAM', 32);


c = cic;                            % Create Command and Intelligence Center...
% c.position = [0 0 1600 1000];         % Set the position and size of the window
% c.color.background= [0 0 0];
% c.colorMode = 'xyl';
% c.iti = 2000;
% c.trialDuration = inf;
c = myConfig(c);
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
% t.font = 'Times New Roman';
% t.textsize = 50;
% t.textstyle = 'italic';
% t.textalign = 'r';
% t.X = 1920/2;
% t.Y = 1080/2;
% t.color = [255 255 255];
% c.add(t);


f=stimuli.fixation('fix');           % Create a fixation stimulus.
f.on = 0;
f.duration = inf;
f.luminance = 50;
f.color = [1 1];
f.shape = 'STAR';
% f.size = 2; 
f.size2 = 1;
% f.angle = '@(cic) cic.frame';
f.X = '@(mouse) mouse.mousex';
f.Y = '@(mouse) mouse.mousey-1';

c.add(f);
% 



m = stimuli.mouse('mouse');
c.add(m);


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



k = stimuli.nafcResponse('key');
c.add(k);
k.keys = {'a' 'z'};
k.stimName = 'dots';
k.var = 'direction';
k.correctResponse = {(@(x) x<300 & x>180) (@(y) y>300 | y<180)};
k.keyLabel = {'clockwise', 'counterclockwise'};
k.endTrialonKeyPress = 1;

% s = stimuli.shadlendots('dots2');
% s.apertureD = 20;
% s.color = [1 1];
% s.luminance = 1;
% s.coherence = 0.8;
% s.speed = 10;
% s.direction = 0;
% c.add(s);


c.addFactorial('myFactorial',...
    {'fix','shape',{'STAR' 'RECT'}}) ;

c.addBlock('myBlock','myFactorial',5,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.

c.add(plugins.output);

b = plugins.fixate;
c.add(b);
% c.add(plugins.reward);

c.add(plugins.eyelink);
% e=plugins.eyelink;
% e.eyeToTrack = 'binocular';

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
