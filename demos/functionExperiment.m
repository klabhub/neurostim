% Demonstrate how to use functions to define changing paramters.
%
import neurostim.*


Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'ConserveVRAM', 32);


c = cic;                            % Create Command and Intelligence Center...
c.screen.pixels = [0 0 1800 1200];         % Set the position and size of the window
c.screen.color.background= [0.5 0.5 0.5];
c.screen.colorMode = 'rgb';

% c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'


t = stimuli.text('text');           % create a text stimulus
t.message = 'Hello World';
t.font = 'Times New Roman';
t.color = [1 1 1];
t.textsize = 50;
t.textstyle = 'italic';
t.textalign = 'c';
t.X = 0;
t.Y = 0;

% Example of a function
%This will evalue t.X+5 everytime t.X is requested (and log any changes).
t.X='@(text) text.X+5';

c.add(t);


% Define a single condition with red text.

myFac=factorial('myFactorial');
myFac.fac1.text.color={[1 0 0]};
myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;

c.run(myBlock);


