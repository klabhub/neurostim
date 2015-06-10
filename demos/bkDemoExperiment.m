
import neurostim.*


Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);


c = cic;                            % Create Command and Intelligence Center...
c.position = [0 0 500 500];         % Set the position and size of the window
c.color.background= [0.6 0.25 5];
c.colorMode = 'xyl';

c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'


gi= stimuli.gabor('inny');
gi.color = [0.5 0.5];
gi.luminance = 25;
gi.sigma = 20;
gi.X = 250;
gi.Y = 250;



c.add(gi);
%qc.add(g);


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





c.addFactorial('myFactorial',{'inny','frequency',{0.05, 0.01}}) ; %You can add more direction conditions... Key press 'n' changes direction.... e.g: {'right','left',etc..}
c.addBlock('blockName','myFactorial',10,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.


c.run; 


