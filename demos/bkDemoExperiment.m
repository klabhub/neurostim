
import neurostim.*
% Factorweights.
% Remove KeyStroke?
commandwindow;

Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);


c = cic;                            % Create Command and Intelligence Center...
c.position = [0 0 200 200];         % Set the position and size of the window
c.color.background= [0 0 0];
c.colorMode = 'xyl';
c.add(plugins.debug);               % Use the debug plugin which allows you to move to the next trial with 'n'




t = stimuli.text('text');           % create a text stimulus
t.message = 'Hello World';
t.font = 'Times New Roman';
t.textsize = 6;
t.textstyle = 'italic';
t.textalign = 'r';
t.X = 0;
t.Y = 0;

functional(t,'X',{@plus,{'text','X'},5});
functional(t,'Y',{@plus,{t,'Y'},5});


t.color = [255 255 255];
c.add(t);

% 
s = stimuli.rdp('dots');
s.color = [1 1 1];
s.motionMode = 'spiral';
s.coherence = 1;
s.lifetime = inf;
c.add(s);




c.addFactorial('myFactorial',{'dots','motionMode',{0, 1}}) ; %You can add more direction conditions... Key press 'n' changes direction.... e.g: {'right','left',etc..}
c.addBlock('myFactorial',10,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.


c.run; 


