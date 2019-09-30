function tae
%% 
% Tilt AfterEffect Example
% 
% Data recorded with this experiment can be analyzed with the anaTae
% script.
%  The experiment starts once the subject fixates the red dot (use the
%  mouse), and the task is to determine whether the second grating
%  presented in a trial is clockwise (press 'l') or counterclockwise (press
%  'a') from vertical.
% 
% The first trial has a long adapter, successive trials have short top-up
% adapter. The first block has CCW adaptation, the second block CW.
%
% BK - Feb 2016


import neurostim.*
simulatedObserver =  true; % Simulate an observer to test the logic of the experiment

%% Setup CIC and the stimuli.
c = myRig;                   % Create Command and Intelligence Center...
c.screen.colorMode = 'RGB';  % Using raw RGB values.   

% Create a Gabor stimulus to adapt. 
g=stimuli.gabor(c,'adapt');           
g.color             = [0.5 0.5 0.5];
g.contrast          = 0.5;
g.Y                 = 0; 
g.X                 = 0;
g.sigma             = 3;                       
g.phaseSpeed        = 0;
g.orientation       = 15;
g.mask              ='CIRCLE';
g.frequency         = 3;
g.duration          = 1500;
g.on                = '@fixation.startTime.FIXATING +250'; % Start showing 250 ms after the subject starts fixating (See 'fixation' object below).

% Duplicate the Gabor serve as a test stimulus 
 g2= duplicate(g,'testGabor');
 g2.contrast         = 0.25;  
 g2.on               = '@adapt.off +250';    % Leave a 250 ms blank between adapt and test
 g2.duration         = 500;                  % Show test for 500 ms

% Red fixation point
f = stimuli.fixation(c,'reddot');       % Add a fixation point stimulus
f.color             = [1 0 0];
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 0.25;
f.X                 = 0;
f.Y                 = 0;
f.on                = 0;                % On from the start of the trial



%% Behavioral control

%Make sure there is an eye tracker (or at least a virtual one)
if isempty(c.pluginsByClass('eyetracker'))
    e = neurostim.plugins.eyetracker(c);      %Eye tracker plugin not yet added, so use the virtual one. Mouse is used to control gaze position (click)
    e.useMouse = true;
end

fix = behaviors.fixate(c,'fixation');
fix.from            = 2000;  % If fixation has not been achieved at this time, move to the next trial
fix.to              = '@testGabor.stopTime';   % Require fixation until testGabor has been shown.
fix.X               = 0;
fix.Y               = 0; 
fix.tolerance       = 2;


%Subject's 2AFC response
k = behaviors.keyResponse(c,'choice');
k.from              = '@testGabor.stopTime';    % Responses are accepted only after test stimulus presenation
k.maximumRT         = Inf;                      % There is no time pressure to give an answer.
k.keys              = {'a' 'l'};
if simulatedObserver
    k.simWhen = 1500;% When should the simulated observer press a key.
    k.simWhat =  '@double(mod(testGabor.orientation,180) < 90)+1'; % Which key should the simulated observer press?  (Perfect observer key==1 for ccw, key==2 for cw) - this observer has no TAE!
end
% Trial ends when the choice has been made.
c.trialDuration = '@choice.stopTime';           % The trial duration ( a cic property) is linked to the end of the choice; once a choice is made, the trial ends. 

%% Define conditions and blocks
% We want to show a 70 degree adapter for 30 seconds, then run a block of
% top-up trials with the same adapter, then 110 degree adpater and a block
% of top-up trials. 
longAdapt  =1000;
shortAdapt = 300;
nrRepeats   = 5;
% Lets' first define the standard top-up blocks

cw=design('cw');           % Define a factorial with one factor
cw.fac1.testGabor.orientation  = 90+(-3:1:3); % Test Orientation. This defines the levels of factor 1 (7, with different orientations for the test)
cw.conditions(:).adapt.orientation      = 70;          % We make sure that the adapt stimulus has the correct orientation. Using a single level for a property means it will be used for all levels of the factor.  
cw.conditions(:).adapt.duration          = shortAdapt;       % Make sure the adapter duration is 3s.
cwBlock=block('cwBlock',cw);                  % Define a block based on this factorial
cwBlock.nrRepeats  =nrRepeats;                        % Each condition is repeated this many times in the block 

% Now the block with the 110 degree adapter.
ccw=design('ccw'); 
ccw.fac1.testGabor.orientation    = 90+(-3:1:3); % Test Orietation
ccw.conditions(:).adapt.duration           = shortAdapt;
ccw.conditions(:).adapt.orientation        = 110;
ccwBlock=block('ccwBlock',ccw);
ccwBlock.nrRepeats = nrRepeats;

% Now we define a "block" consisting of a single condition: the long
% adapter. 
longCwFac=design('longAdaptCw');  % Define a factorial with a single factor 
longCwFac.conditions(1).testGabor.orientation    = 90; % Test Orietation
longCwFac.conditions(1).adapt.duration =         longAdapt;  % Adapter duration  - single condition
longCwFac.conditions(1).adapt.orientation =      70;  % Adapter orientation 
longCwBlock = block('longAdaptCw',longCwFac);
longCwBlock.nrRepeats = 1;              % We'll only show this condition once. 
longCwBlock.beforeMessage = 'Press any key to start block 1';

longCcwFac=design('longAdaptCcw'); 
longCcwFac.conditions(1).testGabor.orientation  = 90; % Test Orietation
longCcwFac.conditions(1).adapt.duration= longAdapt;  % Adapter duration
longCcwFac.conditions(1).adapt.orientation = 110;  % Adapter orientation
longCcwBlock = block('longAdaptCCw',longCcwFac);
longCcwBlock.nrRepeats = 1;
longCcwBlock.beforeMessage= 'Press any key to start block 2';

%% Run the experiment   
% Now tell CIC how we want to run these blocks (blocks are sequential
% conditions within a block are randomized by default)
c.run(longCwBlock,cwBlock,longCcwBlock,ccwBlock);

%% Analyze the data
if c.nrTrials <10
    return;
end

%% Retrieve parameters and responses from the CIC object.
[cw,tr]  = get(c.choice.prms.keyIx,'atTrialTime',inf,'withDataOnly',true); % Last value in the trial is the answer
cw = cw==2; % 2 means CW.

% Get values from the trials where we have key presses. (And values after
% the start of the stimulus to make sure we get the values that were
% actually used. 'atTrialTime', inf would work too.
testOrientation =get(c.testGabor.prms.orientation,'after','startTime','trial',tr); 
adaptOrientation = get(c.adapt.prms.orientation,'after','startTime','trial',tr);

%% Pull adapt and test apart,
uA = unique(adaptOrientation);
uT = unique(testOrientation);
figure;
hold on
cCntr=0;
for a=uA(:)'
    stayA= adaptOrientation ==a;
    cCntr=cCntr+1;
    rCntr= 0;
    for t =uT(:)'
        rCntr= rCntr+1;
    stayT = testOrientation ==t;
        fracCw(rCntr,cCntr) = mean(cw(stayA& stayT));
    end
end

%% Graph
% Plot the percentage of trials with the CW response
% for each test orienation, separately for the CW and CCW adapter
plot(uT,100*fracCw,'.-');
xlabel 'Test Ori (\circ)'
ylabel '%CW'
title ('Tilt After Effect')
legend(num2str(uA(:)))
