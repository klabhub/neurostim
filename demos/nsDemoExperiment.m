function  nsDemoExperiment

import neurostim.*
% Factorweights.
commandwindow;
Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference','TextRenderer',1);
% Screen('Preference', 'ConserveVRAM', 32);

% c = myConfig('Eyelink',false);
% c = cic;                            % Create Command and Intelligence Center...
% c.screen.pixels = [0 0 1600 1000];         % Set the position and size of the window
% c.screen.color.background= [0 0 0];
% c.screen.colorMode = 'xyl';
% c.iti = 2000;
% c.trialDuration = inf;
c = myConfig;
c.output.saveFrequency=2;
e = plugins.eyelink;
e.useMouse = true;
c.add(e);
c.add(plugins.debug);               % Use the debug plugin which allows you to move to the next trial with 'n'
% c.add(plugins.output);
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
% f.on = 0;
% f.duration = 100;
f.duration = Inf;
f.luminance = 50;
f.color = [1 1];
% f.color = '@(cic,fix) [cic.screen.color.background(1) fix.color(1)]';
f.shape = 'STAR';
f.size = 1; 
f.size2 = 1;

% f.rsvp(30,30,{'angle',{0 45 90 135 180 225 270 315 360}});
% f.angle = '@(cic) cic.frame';
% f.Y = '@(mouse) mouse.mousey';
% f.X = 0;
% f.Y = 0;
% 
c.add(f);
% 

fl = stimuli.fixation('fix1');
fl.on = 0;
fl.duration = Inf;
fl.shape = 'CIRC';
fl.X = -10;
fl.Y = 10;
f1.color=[1/3 1/3];
f1.luminance=100;

c.add(fl);


% m = stimuli.mouse('mouse');
% c.add(m);


%  
s = stimuli.rdp('dots');
s.color = [1 1];
s.luminance = 100;
s.motionMode = 1;
s.noiseMode = 0;
s.noiseDist = 1;
s.coherence = 1;
s.lifetime = 10;
s.duration = Inf;
s.size = 2;
s.maxRadius = 8;
c.add(s);



% k = plugins.nafcResponse('key');
% c.add(k);
% k.keys = {'a' 'z'};
% k.stimName = 'dots';
% k.var = 'direction';
% k.correctResponse = {'@(dots) dots.direction<300 & dots.direction>180' '@(dots) dots.direction>300 | dots.direction<180'};
% k.keyLabel = {'clockwise', 'counterclockwise'};
% k.endsTrial = true;

% s = stimuli.shadlendots('dots2');
% s.apertureD = 20;
% s.color = [1 1];
% s.luminance = 1;
% s.coherence = 0.8;
% s.speed = 10;
% s.direction = 0;
% c.add(s);


c.addFactorial('myFactorial',...
    {'fix','shape',{'CIRC' 'STAR'}});
f.rsvp = {{'shape',{'CIRC' 'STAR'}},'duration',100,'isi',0,'randomization','SEQUENTIAL'};
c.addBlock('myBlock','myFactorial',5,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.
% c.add(plugins.mcc);
% c.add(plugins.output);
% % 
% b = plugins.fixate;
% c.add(b);
% c.add(plugins.reward);
% 
% e=plugins.eyelink;
% e.eyeToTrack = 'binocular';

f1 = plugins.fixate('f1');
f1.X = 0;
f1.Y = 0;
f1.duration = 500;
c.add(f1);
f2 = plugins.fixate('f2');

f2.X = 5;
f2.Y = 0;
c.add(f2);

c.add(plugins.gui);
s=plugins.saccade('sac1',f1,f2);
c.add(s);

% b = plugins.liquidReward('liquid');
% b.when='AFTERTRIAL';
% c.add(b);
% c.add(plugins.mcc);
d = plugins.soundReward('sound');
c.add(d);
c.order('dots','fix','fix1','gui');
c.run;