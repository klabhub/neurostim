import neurostim.*
% Factorweights.
% Remove KeyStroke?


Screen('Preference', 'SkipSyncTests', 1);
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


%Which stimuli do you want to use? Enter 1 for yes.
DotCheck = 0;
DotTwoCheck = 0;
DotThreeCheck = 0; 
DotFourCheck = 0;  %Using all 4 'dots' at the same time creates stimuli where dots move in all 4 directions.
FixationCheck = 0;

% Order matters (drawn back to front.. or alphabetical?)
if DotCheck == 1
    d = stimuli.dots('dot');
    d.color =[0.8 0.8];
    c.add(d);
    c.addFactorial('contrastFactorialDot',{'dot','direction',{'right'}}) %You can add more direction conditions... Key press 'n' changes direction.... e.g: {'right','left',etc..}
    c.addBlock('contrastFactorialDot',10,'SEQUENTIAL') % Add a block in whcih we run all conditions in the factorial 10 times.
end
if DotTwoCheck == 1
    d2 = stimuli.dots('dotTwo');
    d2.color =[0.8 0.8]; 
    c.add(d2);
    c.addFactorial('contrastFactorialDotTwo',{'dotTwo','direction',{'left'}})
    c.addBlock('contrastFactorialDotTwo',10,'SEQUENTIAL')
end
if DotThreeCheck == 1
    d3 =stimuli.dots('dotThree');
    d3.color =[0.8 0.8];
    c.add(d3);
    c.addFactorial('contrastFactorialDotThree',{'dotThree','direction',{'up'}})
    c.addBlock('contrastFactorialDotThree',10,'SEQUENTIAL')
end
if DotFourCheck == 1
    d4 =stimuli.dots('dotFour');
    d4.color = [0.8 0.8];
    c.add(d4);
    c.addFactorial('contrastFactorialDotFour',{'dotFour','direction',{'down'}})
    c.addBlock('contrastFactorialDotFour',10,'SEQUENTIAL')
end
if FixationCheck ==1
    f = stimuli.fixation('fix');
    f.color = [1 1];
    c.add(f);
    c.addFactorial('contrastFactorialFixation',{'fix','shape',{'concirc','tria','circ','rect','oval','star'}}) 
    c.addBlock('contrastFactorialFixation',10,'SEQUENTIAL')
end


%c.add(g);                           % Add it to CIC.


%c.add(plugins.eyelink);
%c.add(plugins.mcc)

% m = myexpt;
% c.add(m);
% 
% Define conditions of the experiment. Here we vary the peak luminance of the 
% Gabor  
    
c.run; 


