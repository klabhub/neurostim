function  nsDemoExperiment

import neurostim.*
% Factorweights.
% Remove KeyStroke?
commandwindow;

Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);


c = cic;                            % Create Command and Intelligence Center...
c.position = [0 0 1920 1080];         % Set the position and size of the window
c.color.background= [0 0 0];
c.colorMode = 'xyl';
c.iti = 2000;
c.trialDuration = 2000;
c.add(plugins.debug);               % Use the debug plugin which allows you to move to the next trial with 'n'

% g=stimuli.gabor('gabor');           % Create a gabor stimulus.
% g.color = [1/3 1/3];q
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

% g=stimuli.fixation('fix');           % Create a gabor stimulus.
% g.on = 0;
% g.duration = inf;
% g.luminance = 50;
% g.X = 0;                          % Position the Gabor
% g.Y = 0; 
% g.color = [1 1];
% g.shape = 'OVAL';
% g.size = 50;
% g.size2 = 10;
% c.add(g);

% 
s = stimuli.rdp('dots');
s.color = [1/3 1/3];
s.luminance = 90;
s.motionMode = 'linear';
s.noiseMode = 1;
s.noiseDist = 1;
s.coherence = 0.8;
s.lifetime = 10;
s.duration = 200;
% s.on = 60;
% s.position = [500 1080/2];
c.add(s);


k = stimuli.nafcResponse('key');
% k.keys = {'a' 'z' 'x'};   % not working currently
k.stimName = 'dots';
k.var = 'direction';
k.correctResponse = {(@(x) x<300 & x>180) (@(y) y>300 | y<180)};
k.keyLabel = {'clockwise', 'counterclockwise'};
k.endTrialonKeyPress = 1;
c.add(k);

% s = stimuli.shadlendots('dots');
% s.apertureXYD = [0 0 150];
% s.color = [1 1 1]; % in xyl
% s.coherence = 0.75;
% s.direction = 0;
% c.add(s);


c.addFactorial('myFactorial',...
    {'dots','direction',{0 335 310 285 260}}, ...
    {'dots', 'luminance', {50 90}},...
    {'dots', 'position', {[320 540] [1600 540]}}) ;

     %You can add more direction conditions... Key press 'n' changes direction.... e.g: {'right','left',etc..}
c.addBlock('myFactorial',10,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.


c.run; 


