function c=scripting
%% This demo shows how to use control scripts.


%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.

%% Setup CIC and the stimuli.
c = cic;                            
c.position = [0 0 500 500];         
c.color.background= [0.2 0.2 0.2];
c.colorMode = 'RGB';   
c.trialDuration = 5000;

% We'll use two experiment scripts to control this experiment. One is called before
% every frame and it is specified in a separate m-file that should be on
% the path (circlePath.m) . The second is a subfunction defined in this
% file (Matlab allows this only in function m-files, which is why this demo
% file uses a function. 
c.addScript('BeforeFrame',@circlePath); % Tell CIC to call this eScript before drawing each frame.
c.addScript('BeforeTrial',@beginTrial); % Tell CIC to call this eScript at the start of each trial.
% The definition of the eScript can be anywhere in this file. The code
% inside the eScript as access to everything in CIC. 
function beginTrial(c)
  c.fix.X = rand*400-250; % Start each trial with a random horizontal position of the fixation dot.
end 

% Add a Gabor stimulus that is manipulated in the circlePath eScript. Note
% that the stimuli can be defined after the eScript. The order is irrelevant. 
g=stimuli.gabor('gabor');           
g.color = [0.5 0.5 ];
g.luminance = 0.5;
g.peakLuminance = 1;
g.X = 250;                          
g.Y = 250;                          
g.sigma = 50;                       
g.phaseSpeed = 10;
g.orientation =0;
g.mask ='GAUSS';

f = stimuli.fixation('fix');        % Add a fixation point stimulus
f.color = [1 0];                    
f.luminance = 0;

% Add stimuli  to CIC. The order in which they are added is the *reverse* of 
% the order in which they will be drawn. Because we want the fixation on top of the
% gabor, we add it first.          
c.add(f);
c.add(g);                


%% Define conditions and blocks and run. 
% This also demonstrates how a condition can keep all 
% stimulus parameters constant, but change some cic parameters.
c.addCondition('short',{'cic','trialDuration',2500}) ;
c.addCondition('long',{'cic','trialDuration',5000}) ;
c.addBlock('all',{'short','long'},5,'RANDOMWITHREPLACEMENT')
c.run 
end