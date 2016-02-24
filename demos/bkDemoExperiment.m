
import neurostim.*


Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);

c= bkConfig;

c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'


gi= stimuli.gabor('inny');
gi.color = [0.5 0.5 0.5];
gi.alpha= 0.5;
gi.contrast = 1;
gi.sigma = 20;
gi.X = 250;
gi.Y = 250;
gi.mask = 'CIRCLE';
gi.alpha = 1; 




g= stimuli.gabor('outy');
g.color = [0.5 0.5 0.5];
g.contrast = 0.5;
g.sigma = [40 20];
g.X = 250;
g.Y = 250;
g.mask = 'ANNULUS';

g.alpha = 1; 
c.add(g);
c.add(gi);

% 
% t = stimuli.text('text');           % create a text stimulus
% t.message = 'Hello World';
% t.font = 'Times New Roman';
% t.textsize = 6;
% t.textstyle = 'italic';
% t.textalign = 'r';
% t.X = 0;
% t.Y = 0;
% 
% % Two variants of functions: using the object t or its name 'text' 
% % This will evalue t.X+5 everytime t.X is requested (and log any changes).
% % functional(t,'X',{@plus,{'text','X'},5}); 
% % functional(t,'Y',{@plus,{t,'Y'},5});
% 
% 
% t.color = [255 255 255];
% c.add(t);



%Specify experimental conditions
myFac=factorial('myFactorial',2);
myFac.fac1.inny.alpha={0.5,1};
myFac.fac2.outy.alpha={1 0.5};

%Specify a block of trials
myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;

%% Run the experiment.
c.cursor = 'arrow';
c.run(myBlock);


