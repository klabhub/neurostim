function  nsDemoExperiment

import neurostim.*
% Factorweights.
commandwindow;

Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference', 'ConserveVRAM', 32);


% c = cic;                            % Create Command and Intelligence Center...
% c.position = [0 0 1600 1000];         % Set the position and size of the window
% c.color.background= [0 0 0];
% c.colorMode = 'xyl';
% c.iti = 2000;
% c.trialDuration = inf;

c = myConfig;
c.add(plugins.debug);               % Use the debug plugin which allows you to move to the next trial with 'n'

% g=stimuli.gabor('gabor');           % Create a gabor stimulus.
% g.color = [1/3 1/3];
% g.luminance = 30;
% g.X = 250;                          % Position the Gabor
% g.Y = 250;                          
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

g=stimuli.fixation('fix');           % Create a gabor stimulus.
g.on = 0;
g.duration = inf;
g.luminance = 50;
g.X = 0;                          % Position the Gabor
g.Y = 0; 
g.color = [1 1];
g.shape = 'STAR';
g.size = 20;
g.size2 = 10;
c.add(g);

% 
s = stimuli.rdp('dots');
s.color = [1/3 1/3];
s.luminance = 90;
s.motionMode = 0;
s.noiseMode = 0;
s.noiseDist = 1;
s.coherence = 0.8;
s.lifetime = 10;
s.duration = 100;
s.size = 2;
% s.on = 60;
% s.position = [500 1080/2];
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
% s.apertureXYD = [0 0 150];
% s.color = [1 1 1]; % in xyl
% s.coherence = 0.75;
% s.direction = 0;
% c.add(s);


c.addFactorial('myFactorial',...
    {'dots','direction',{0 335 310 285 260}}, ...
    {'dots', 'coherence', {0.75 1}}) ;

c.addBlock('myBlock','myFactorial',10,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.


c.run; 


