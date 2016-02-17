
import neurostim.*


Screen('Preference', 'SkipSyncTests', 0);
% Screen('Preference', 'ConserveVRAM', 32);


c = myConfig;                            % Create Command and Intelligence Center...
c.screen.pixels = [0 0 500 500];         % Set the position and size of the window
c.screen.color.background= [0.5 0.5 .5];
c.screen.colorMode = 'RGB';

c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'


gi= stimuli.gabor('inny');
gi.color = [0.5 0.5 0.5];
gi.sigma = 20;
gi.X = 0;
gi.Y = 0;
gi.mask = 'CIRCLE';
gi.alpha = 1; 




g= stimuli.gabor('outy');
g.color = [0.5 0.5 0.5];
g.sigma = [40 20];
g.X = 0;
g.Y = 0;
g.mask = 'ANNULUS';

g.alpha = 1; 
c.add(g);
c.add(gi);

% 
% t = stimuli.text('text');           % create a text stimulus
% t.message = 'Hello World';
% t.font = 'Times New Roman';
% t.textsize = 6;
% t.textstyle = 1;
% t.textalign = 'r';
% t.X = 0;
% t.Y = 0;
% % 
% % Using the object t or its name 'text' 
% % This will evalue t.X+5 everytime t.X is requested (and log any changes).
% t.X='@(text) text.X+5';
% 
% % 
% t.color = [255 255 255];
% c.add(t);



myFac=factorial('myFactorial',1);
myFac.fac1.inny.alpha={0.5 1};
myFac.fac1.outy.alpha={1 0.5};

myBlock=block('myBlock',myFac);
myBlock.randomization='SEQUENTIAL';

c.run(myBlock,'nrRepeats',10);


