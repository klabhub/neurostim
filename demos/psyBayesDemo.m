function c= psyBayesDemo(varargin)
% Demo to show adaptive threshold estimation using psyBayes.
%
% The subjects task is to detect the location of a Gabor:  left (press
% 'a') or right (press 'l')
%
% The demo uses psyBayes to estimate the threshold
% for correct detection, separately for +45 and -45 degree oriented gratings.
%
% If you run this a second time you get the option to include the pervious run's 
% estimates. 
% 
% The demo can use  key presses, or simulate an observer with a
% fixed threshold by setting pianola to true.
%
% See also adaptiveDemo for QUEST and Staircase procedures
% BK  - Nov 2023.

import neurostim.*
pianola = true; % Set this to true to simulate responses, false to provide your own responses ('a'=left,'l' = right).

% Use a persistent variable to allow successive experiments to continue with
% the adaptive estimation where the previous one left off. (See below).
persistent psy
% NOTE. It would also relatively easy to reuse a psy struct from a saved
% data file. Simply load the file, and use  pluginsByClass(c,'psyBayes')
% to extract the objects and then pass the .psy of those to continuePsy()
% below. 

%% Pianola
% Define a simulated observer with different thresholds for the two
% conditions. This should be visible when you run this demo with pianola=true; one orientation
% should converge on a low contrast, the other on a high contrast.
% Note that this function should return the keyIndex of the correct key (so
% 1 for 'a', 2 for 'l')
simulatedObserver = '@iff(grating.contrast > (0.1+0.5*(cic.condition-1)),grating.X > 0,rand < 0.5) + 1.0';
%% Setup the controller 
c= myRig(varargin{:});
c.trialDuration = Inf;
c.screen.color.background = [ 0.5 0.5 0.5];
c.subjectNr= 0;

%% Add a Gabor;
% We'll simulate an experiment in which
% the grating's location (left or right) is to be detected
% and use this to estimate the contrast threshold
g=stimuli.gabor(c,'grating');
g.color            = [0.5 0.5 0.5];
g.contrast         = 0.25;
g.Y                = 0;

% Used a jitter object to vary position across trials.
% Becuase the same jitter object can be used for all conditions, we assign it
% to the parameter directly. 
g.X                = plugins.jitter(c,{10,-10},'distribution','1ofN'); % Jitter the location of the grating on each trial: either 10 or -10 
% If you'd want to use a different jitter (maybe drawn from a different
% distribution in different conditions) for each condition, then you specify 
% the jitter as part of the design (see below)
g.sigma            = 3;
g.phaseSpeed       = 0;
g.orientation      = 0;
g.mask             = 'CIRCLE';
g.frequency        = 3;
g.on               =  0;
g.duration         = 500;

% Red fixation point
f = stimuli.fixation(c,'reddot');       % Add a fixation point stimulus
f.color             = [1 0 0];
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 0.25;
f.X                 = 0;
f.Y                 = 0;
f.on                = 0;                % On from the start of the trial

  
%% Setup user responses
% Take the user response (Press 'a'  to report detection on the left, press 'l'  for detection on the right)
k = behaviors.keyResponse(c,'choice');
k.from = '@grating.on + grating.duration';
k.maximumRT = 2000;         %Maximum allowable RT is 2000ms
k.keys = {'a' 'l'};                       %Press 'a' for "left" motion, 'l' for "right"
k.correctFun = '@double(grating.X> 0) + 1';   %Function to define what the correct key is in each trial .It returns the index of the correct response (i.e., key 1 ('a' when X<0 and 2 'l' when X>0)
if pianola
    k.simWhat =  simulatedObserver;   % This function will provide a simulated answer
    k.simWhen = '@grating.on + grating.duration+50';  % At this time.
end
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.

%% Setup the conditions in a design object
d=design('orientation');
d.fac1.grating.orientation = [-45 45];  % One factor (orientation)
nrLevels = d.nrLevels;

%% Now setup the adaptive psyBayes estimation
% see adaptiveDemo for more tips on adaptive estimation
% Define a psyBayes object: (the demos folder in the psybayes git
% repository should help understand these parameters).

psyParms.vars = [1 1 0]; % Estimate mu and sigma
psyParms.x = 0.01:0.01:1; % Grating contrast levels
psyParms.rangeMu = [0.01 1 100];
psyParms.rangeSigma = [0.01 0.15 15];
psyParms.rangeLambda = [0.01 0.5 25];
psyParms.priorsMu = [0.5 Inf];
psyParms.priorsLogSigma = [0.1 inf];
psyParms.priorsLambda = [0.1 19];
psyParms.gamma = 0.5; % Guessing rate.
psyParms.psychofun = '@(x,mu,sigma,lambda,gamma) psyfun_pcorrect(x,mu,sigma,lambda,gamma,@psynormcdf);';
adpt = plugins.psyBayes(c, '@choice.correct',psyParms);
adpt = duplicate(adpt,[nrLevels 1]); 
if ~isempty(psy)
    % If we have a stored psy info, re-use it. In a real experiment one
    % would probably ask for explicit confirmation to avoid using the 
    % estimate from one subject for a different subject running in the same matlab
    % session a bit later. (Alternativaly,one could also subject info as
    % persistent and then compare the current with the persistent subject).
    continuePsy(adpt,psy);
end
% Assign the psyBayes object to the contrast values of the grating.
d.conditions(:,1).grating.contrast =   adpt;
% Create a block for this design and specify the repeats per design
myBlock=block('myBlock',d);
myBlock.nrRepeats = 20; % Because the design has 2 conditions, this results in 2*nrRepeats trials.
c.addPropsToInform('grating.contrast','grating.orientation')
c.run(myBlock);

%% The experiment has ended.
% Pull out the psyBayes objects 
adpt = pluginsByClass(c,'psyBayes');
psy = [adpt.psy]; % store their psy structs in the persistent variable.
%% Do some analysis on the data
figure;
% Show the posterior estimates with high-density regions as error bars
posterior(adpt,0.25,true)

end