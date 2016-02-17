%% Using RGB colors
%  This demo shows how to use RGB colors. 
%

%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.

%% Setup CIC and the stimuli.
c = cic;                            % Create Command and Intelligence Center...
c.screen.pixels = [0 0 500 500];         % Set the position and size of the window
c.screen.color.background= [0.5 0.5 0.5];
c.screen.colorMode = 'RGB';                % Tell CIC that we'll use RGB colors

% c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'

g=stimuli.gabor('gabor');           % Create a gabor stimulus.
g.color = [0.5 0.5 0.5];
g.width = 150;
g.height = 150;
g.X = 0;                          % Position the Gabor 
g.Y = 0;                          
g.sigma = 20;                       % Set the sigma of the Gabor.

f = stimuli.fixation('fix');        % Add a fixation point stimulus
f.color = [1 0 0];                    % Red
f.shape = 'CIRC';                  % Shape of the fixation point
f.size = 10; 

% Add stimuli to CIC
 
c.add(g);                           % Add it to CIC.
c.add(f);

%% Define conditions and blocks
% Here we vary the peak luminance of the Gabor 
myFac=factorial('contrastFactorial');
myFac.fac1.gabor.contrast={0.75 1};

% Add a block in whcih we run all conditions in the named factorial 10 times.
myBlock=block('contrastBlock',myFac);
myBlock.nrRepeats=10;
myBlock.randomization='SEQUENTIAL';

%% Run 
c.run(myBlock); % Run the experiment. 

