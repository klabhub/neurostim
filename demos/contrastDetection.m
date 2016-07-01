function c=contrastDetection
% Contrast detection experiment. 
% Shows Gabor patches in random locations, user is required to click on
% them (or look at them and press the space bar).
%

%% Prerequisites. 
import neurostim.*

%% Setup CIC and the stimuli.
c = myRig;   
c.trialDuration = Inf; % A trial can only be ended by a mouse click
c.cursor = 'arrow';
c.screen.color.background = 0.5*ones(1,3);

c.addScript('AfterFrame',@respondMouse); 
c.addScript('BeforeTrial',@beginTrial); 
function beginTrial(c)
    % Start each trial at a new random position.
  c.gabor.X = (0.5-0.9*rand)*c.screen.width ; 
  c.gabor.Y = (0.5-0.9* rand)*c.screen.height ;
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
            Snd('Play',0.5*sin((0:10000)/3)); %Correct; high tone
        else
            Snd('Play',0.5*sin((0:10000)/10)) % too far: low tone
        end
        c.nextTrial;
    end
end

% Add a Gabor stimulus . 
g=stimuli.gabor(c,'gabor');           
g.color = [0.5 0.5 0.5 ];
g.sigma = 0.5;    
g.frequency = 3;
g.phaseSpeed = 0;
g.orientation = 0;
g.mask ='GAUSS';
g.duration = 250;


%% Define conditions and blocks, then run. 
% This demonstrates how a condition can keep all 
% stimulus parameters constant, but change some cic parameters.
fac = factorial('contrast',1);
fac.fac1.gabor.contrast = 0:0.1:0.5;
blk = block('contrast',fac);
blk.nrRepeats = 10;
c.run(blk);
end 