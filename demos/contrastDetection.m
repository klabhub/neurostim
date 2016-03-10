function c=contrastDetection
% Contrast detection experiment. 
% Shows Gabor patches in random locations, user is required to click on
% them (or look at them and press the space bar).
%

%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.

%% Variables
bg = 0.5;

%% Setup CIC and the stimuli.
c = neurostim.cic;                            
c.pixels= 0.5*[0200 0 1600 900];
%c.mirrorPixels= 0.5*[1600 0 1600 900];
c.physical = 1 *[16 9]; % Assume that the 3200 pixels map onto 32 cm.
c.color.background= bg*[1 1 1]; 
c.colorMode = 'RGB';   
c.trialDuration = 1000;

o = neurostim.output.mat;
o.mode = 'DAYFOLDERS';
o.root ='c:\temp\'; 
c.add(o);

c.addScript('AfterFrame',@respondMouse); 
c.addScript('BeforeTrial',@beginTrial); 
function beginTrial(c)
    % Start each trial at a new random position.
  c.gabor.X = (0.5-0.9*rand)*c.physical(1) ; 
  c.gabor.Y = (0.5-0.9* rand)*c.physical(2) ;
end

function respondMouse(c)
    [x,y,buttons] = c.getMouse;
    if buttons(1)
        write(c,'detect', [x y]);
        while(buttons(1))
            [~,~,buttons] = c.getMouse;
        end
        distance = sqrt(sum(([x y]-[c.gabor.X c.gabor.Y]).^2)); 
        if distance < 1 
            Snd('Play',0.5*sin((0:10000)/3))
        else
            Snd('Play',0.5*sin((0:10000)/10))
        end
        c.nextTrial;
    end
end

% Add a Gabor stimulus . 
g=stimuli.gabor('gabor');           
g.color = [bg bg ];
g.luminance = bg ;
g.sigma = 0.5;    
g.frequency = 3;
g.phaseSpeed = 0;
g.orientation = 0;
g.mask ='GAUSS';

c.add(g);                


%% Define conditions and blocks, then run. 
% This demonstrates how a condition can keep all 
% stimulus parameters constant, but change some cic parameters.
c.addFactorial('contrast',{'gabor','contrast',{0, 0.1 ,0.2 ,0.3 ,0.4 ,0.5}}) ;
c.addBlock('contrast','contrast',10,'RANDOMWITHREPLACEMENT')
c.run
end 