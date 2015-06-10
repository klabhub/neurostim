%% Using RGB colors 
%  This demo shows how to use RGB colors. 
%

%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.

%% Setup CIC and the stimuli.
c = cic;                            % Create Command and Intelligence Center...
c.position = [0 0 500 500];         % Set the position and size of the window
c.color.background= [0.5  0.5 0.5];
c.colorMode = 'RGB';                % Tell CIC that we'll use RGB colors

c.add(plugins.gui);                 % Create and add a "GUI" (status report)
c.add(plugins.debug);               % Use the debug plugin; this allows you to move to the next trial with 'n'

g=stimuli.gabor('inner');           % Create a gabor stimulus.
g.color = [0.5 0.5 ];
g.luminance = 0.5;
g.peakLuminance = 1;
g.X = 250;                          % Position the Gabor 
g.Y = 250;                          
g.sigma = [50 25];                       % Set the sigma of the Gabor.
g.phaseSpeed = 10;
g.orientation =90;
g.alpha = 1;
g.mask ='ANNULUS';


g2=stimuli.gabor('outer');           % Create a gabor stimulus.
g2.color = [0.5 0.5];
g2.luminance = 0.5;
g2.X = 250;                          % Position the Gabor 
g2.Y = 250;                          
g2.sigma = 25 ;                       % Set the sigma of the Gabor.
g2.phaseSpeed = 10;
g2.orientation = 90;
g2.mask = 'CIRCLE';q 
g2.alpha = 1; 

f = stimuli.fixation('fix');        % Add a fixation point stimulus
f.color = [1 0];                    % Red
f.luminance = 0;
f.shape = 'DONUT';                  % Shape of the fixation point
f.size = 2; 

% Add stimuli to CIC
c.add(f); 
c.add(g);                          
c.add(g2);                           

%% Define conditions and blocks
% We dont want to vary anything for now.
c.addCondition('dummy',{}) ;
c.addBlock('dummy','dummy',10,'SEQUENTIAL')

%% Run 
c.run % Run the experiment. 

