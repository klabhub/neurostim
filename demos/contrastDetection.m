function contrastDetection
% Contrast detection experiment. 
% Shows Gabor patches in random locations, user is required to click on
% them 

%% Prerequisites. 
import neurostim.*

%% Setup CIC and the stimuli.
c = myRig;   
c.trialDuration = Inf; % A trial can only be ended by a mouse click
c.cursor = 'arrow';
c.screen.color.background = 0.5*ones(1,3);

% This shows how you can extend functionality with dedicated functions
% In this example we add a function that is called before each trial. In
% that function we can execute any matlab code. This particular example
% randomizes the X/Y position. A simpler way to achieve this would be to
% assign a jitter object to the design (Something like d.conditions(:).fix.X =
% jitter(...)), for more info, see adaptiveDemo)
c.addScript('BeforeTrial',@beginTrial); 
function beginTrial(c)
    % Start each trial at a new random position.
  c.gabor.X = (0.5-0.9*rand)*c.screen.width ; 
  c.gabor.Y = (0.5-0.9* rand)*c.screen.height ;
end

% Here we extend the functionality with a mouse-click response handler.
% It will be called after every frame
c.addScript('AfterFrame',@respondMouse);
function respondMouse(c)
    [x,y,buttons] = c.getMouse;
    if buttons(1)
        % Left mouse click
        write(c,'detect', [x y]); % Store the current location of the mouse
        while(buttons(1))
            [~,~,buttons] = c.getMouse;
        end
        % Assess performance.
        distance = sqrt(sum(([x y]-[c.gabor.X c.gabor.Y]).^2)); 
        if distance < 1 
            Snd('Play',0.5*sin((0:10000)/3)); %Correct; high tone
        else
            Snd('Play',0.5*sin((0:10000)/10)) % too far: low tone
        end
        c.endTrial; % And move to the next trial.
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
d = design('contrast');
d.fac1.gabor.contrast = 0:0.1:0.5; % Factorial design; single factor with five levels.
blk = block('contrast',d);
blk.nrRepeats = 10;
c.run(blk);
end 