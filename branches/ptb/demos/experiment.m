import neurostim.*
% Factorweights.
% Remove KeyStroke?


Screen('Preference', 'SkipSyncTests', 0);
Screen('Preference', 'ConserveVRAM', 32);

c = cic;                            % Create Command and Intelligence Center...
c.position = [0 0 1280 1024];         % Set the position and size of the window
c.color.background= [0 0 0];
c.colorMode = 'xyL';

%c.add(plugins.gui);                 % Create and add a "GUI" (statuqs report)
% c.gui.props  = 'fix.luminance';   % Show the property in the GUI.


c.add(plugins.debug);               % Use the debug plugin which allows you to move to the next trial with 'n'

% g=stimuli.gabor('gabor');           % Create a gabor stimulus.
% g.color = [1/3 1/3];
% g.luminance = 30;
% g.X = 250;                          % Position the Gabor
% g.Y = 250;                          
% g.sigma = 25;                       % Set the sigma of the Gabor.
% g.phaseSpeed = 10;
% 
f = stimuli.fixation('fix');
f.color = [0.33 0.33];
%d = stimuli.RandomDot('dots');
%d.color =[0.8 0.8];

RandomLinearDotCheck = 0; % Change this to 1 in order to run RandomLinearDots.m
RadialDotCheck = 0; %Change this to 1 in order to run RadialDots.m 

% Order matters (drawn back to front.. or alphabetical?)
%c.add(d);
c.add(f); 
%c.add(g);                           % Add it to CIC.


%c.add(plugins.eyelink);
%c.add(plugins.mcc)

% m = myexpt;
% c.add(m);
% 
% Define conditions of the experiment. Here we vary the peak luminance of the 
% Gabor  

 c.addFactorial('contrastFactorial',{'fix','shape',{'concirc','tria','circ','rect','oval','star'}})  

  
% Add a block in whcih we run all conditions in the factorial 10 times.

 c.addBlock('contrastFactorial',10,'SEQUENTIAL')


if RandomLinearDotCheck == 1
    run RandomLinearDots.m;
    
elseif RadialDotCheck == 1
    run RadialDots.m
else 
    c.run;
end

    
%c.run % Run the experiment. 


