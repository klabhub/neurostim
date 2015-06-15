% Demonstrate how to use functions to define changing paramters.
%
import neurostim.*


Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);


c = cic;                            % Create Command and Intelligence Center...
c.position = [0 0 500 500];         % Set the position and size of the window
c.color.background= [0.5 0.5 0.5];
c.colorMode = 'rgb';

c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'


t = stimuli.text('text');           % create a text stimulus
t.message = 'Hello World';
t.font = 'Times New Roman';
t.color = [1 1 1];
t.textsize = 6;
t.textstyle = 'italic';
t.textalign = 'r';
t.X = 0;
t.Y = 0;

%Two variants of functions: using the object t or its name 'text' 
%This will evalue t.X+5 everytime t.X is requested (and log any changes).
functional(t,'X',{@plus,{'text','X'},5}); 
functional(t,'Y',{@plus,{t,'Y'},5});

c.add(t);


% Define a single condition with red text. X and Y are set to zero so that
% the text starts in the top left corner every trial (otherwise it would
% reuse the last value from the previous trial).
c.addCondition('red',{'text','color',[1 0 0],'text','X',0,'text','Y',0}) ; 
c.addBlock('redBlock','red',10,'SEQUENTIAL') % Add a block in whcih we run this 10 times.



c.run; 


