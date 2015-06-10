%% Using RGB colors
%  This demo shows how to use RGB colors. 
%

%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.

%% Setup CIC and the stimuli.
c = cic;                            % Create Command and Intelligence Center...
c.position = [0 0 500 500];         % Set the position and size of the window
c.color.background= [0.5 0.5 0.5];
c.colorMode = 'RGB';                % Tell CIC that we'll use RGB colors

c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'

g=stimuli.gabor('gabor');           % Create a gabor stimulus.
g.color = [0.5 0.5];
g.luminance = 0.5;
g.X = 250;                          % Position the Gabor 
g.Y = 250;                          
g.sigma = 20 ;                       % Set the sigma of the Gabor.

f = stimuli.fixation('fix');        % Add a fixation point stimulus
f.color = [1 0];                    % Red
f.luminance = 1;
f.shape = 'DONUT';                  % Shape of the fixation point
f.size = 2; 

% Add stimuli to CIC
c.add(f); 
c.add(g);                           % Add it to CIC.

%% Define conditions and blocks
% Here we vary the peak luminance of the Gabor 
c.addFactorial('contrastFactorial',{'gabor','peakLuminance',{0.75 1}});
% Add a block in whcih we run all conditions in the named factorial 10 times.
c.addBlock('contrastBlock','contrastFactorial',10,'SEQUENTIAL')

%% Run 
c.run % Run the experiment. 

