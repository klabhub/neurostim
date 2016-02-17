import neurostim.*
Screen('Preference', 'SkipSyncTests', 1); % Not in  production mode; this is just to run without requiring accurate timing.

%% Setup CIC and the stimuli.
c = cic;                            % Create Command and Intelligence Center...
c.screen.pixels    = [0 0 500 500];        % Set the position and size of the window
c.screen.physical  = [15 15];              % Set the physical size of the window (centimeters)
c.screen.color.background= [0.5 0.5 0.5];
c.screen.colorMode = 'RGB';                % Tell CIC that we'll use RGB colors
c.trialDuration  = inf;
c.add(plugins.debug); 

% Create a grating stimulus. This will be used to map out the psychometric
% curve (hence 'gabortest')
g=stimuli.gabor('gabortest');           
g.color = [0.5 0.5 0.5];
g.contrast = 0.5;
g.Y = 0; 
g.X = 0;
g.sigma = 1;                       
g.phaseSpeed = 10;
g.orientation = 90;
g.mask ='CIRCLE';
g.frequency = 3;


% Duplicate the test grating to make a surround
g3= duplicate(g,'surround');
g3.mask = 'ANNULUS';
g3.sigma = [1 2];
g3.contrast  = 0.5;
g3.orientation=0; 
g3.X = '@(gabortest) gabortest.X';


c.add(g3);
c.add(g);
myFac=factorial('test');
myFac.fac1.gabortest.X={-2.5 2.5}; 

myBlock=block('block',myFac);
c.run(myBlock);
