function scripting
%% This demo shows how to use control scripts.
import neurostim.*
%% Setup CIC and the stimuli.
c = myRig;                            

% We'll use two experiment scripts to control this experiment. One is called before
% every frame and it is specified in a separate m-file that should be on
% the path (circlePath.m) . The second is a subfunction defined in this
% file (Matlab allows this only in function m-files, which is why this demo
% file is a function m-file. 
c.addScript('BeforeFrame',@circlePath); % Tell CIC to call this eScript before drawing each frame.
c.addScript('AfterFrame',@respondMouse); % Tell CIC to call this eScript after drawing each frame.
c.addScript('BeforeTrial',@beginTrial); % Tell CIC to call this eScript at the start of each trial.

% The definition of the eScript can be anywhere in this file. The code
% inside the eScript has access to everything in CIC.  Please note that
% this same functionality (jittering parameters across trials) can also be
% achieved (better) by assigning a plugins.jitter object to a condition o
% of the design object  (see adaptiveDemo for an example)
function beginTrial(c)
  c.gabor.contrast = rand; % Chose a random contrast
end

function respondMouse(c)
    [x,y,buttons] = c.getMouse;
    if buttons(1)
        write(c,'detect', [x y]);
        while(buttons(1))
            [~,~,buttons] = c.getMouse;
        end
        c.fix.X = x; % Move the fixation point ('fix') to the click location
        c.fix.Y = y;
        c.endTrial;
    end
end 

% Add a Gabor stimulus that is manipulated in the circlePath eScript. Note
% that the stimuli can be defined after the eScript. The order is irrelevant. 
g=neurostim.stimuli.gabor(c,'gabor');           
g.color         = [0.5 0.5 0.5];
g.contrast      = 0.5;  
g.X             = 0;
g.Y             = 0;
g.sigma         = 3;
g.frequency     = 3;
g.phaseSpeed    = 10;
g.orientation   = 45;
g.mask          = 'CIRCLE';
g.duration      = Inf;

f = neurostim.stimuli.fixation(c,'fix');        % Add a fixation point stimulus
f.color         = [1 0 0];                    
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 1;
f.X                 = 0;
f.Y                 = 0;
f.on                = 0;                % On from the start of the trial


%% Define conditions and blocks, then run. 
% This demonstrates how a condition can keep all 
% stimulus parameters constant, but change some cic parameters.
d=neurostim.design('short vs long');
d.fac1.cic.trialDuration=[2500 5000];

myBlock=neurostim.block('MyBlock',d);
myBlock.nrRepeats=5;
myBlock.randomization='RANDOMWITHREPLACEMENT';
c.order('fix','gabor');
c.run(myBlock);
end