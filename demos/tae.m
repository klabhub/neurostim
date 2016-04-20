%% 
% Tilt AfterEffect Example
% 
% Data recorded with this experiment can be analyzed with the anaTae script
%
% BK - Feb 2016

%TODO 
% Dimming task (generic?)
% Add stimulation


%% Prerequisites. 
import neurostim.*


%% Setup CIC and the stimuli.
c = bkConfig;                            % Create Command and Intelligence Center...
 
%plugins.gui(c);         % Show a gui (dual screens only)

% Create a Gabor stimulus to adadot. 
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
g.on                = '@fixation.startTime +250'; % Start showing 250 ms after the subject starts fixating (See 'fixation' object below).


% Duplicate the Gabor serve as a test stimulus 
g2= duplicate(g,'testGabor');
g2.contrast         = 0.25;  
g2.on               = '@adapt.off +250';    % Leave a 250 ms blank between adapt and test
g2.duration         = 500;                  % Show test for 500 ms

% Convpoly to create a dimming task
circle = stimuli.convPoly(c,'dimmer');
circle.radius       = '@testGabor.sigma';
circle.X            = 0;
circle.Y            = 0;
circle.nSides       = 100;
circle.filled       = true;
circle.color        = 0;'@[0.5 0.5 0.5 0.8*randi(60)>35]';
circle.on           = Inf;'@adapt.on';




% Red fixation point
f = stimuli.fixation(c,'reddot');       % Add a fixation point stimulus
f.color             = [1 0 0];
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 0.1;
f.X                 = 0;
f.Y                 = 0;
f.on                = 0;                % On from the start of the trial



%% Behavioral control
fix = plugins.fixate(c,'fixation');
fix.from            = '@fixation.startTime';  % Require fixation from the moment fixation starts (i.e. once you look at it, you have to stay).
fix.to              = '@testGabor.stopTime';   % Require fixation until testGabor has been shown.
fix.X               = 0;
fix.Y               = 0; 
fix.tolerance       = 2;

% Add an eye tracker. eyetracker is a dummy eyetracker that follows mouse
% clicks. Without this, the fixation object will not work.
et = plugins.eyetracker(c);
et.useMouse         = true;     

%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on                = '@ testGabor.stopTime';    % Responses are accepted only after test stimulus presenation
k.deadline          = Inf;                      % There is no time pressure to give an answer.
k.keys              = {'a' 'l'};
k.keyLabels         = {'ccw', 'cw'};
% Trial ends when the choice has been made.
c.trialDuration = '@ choice.stopTime';           % The trial duration ( a cic property) is linked to the end of the choice; once a choice is made, the trial ends. 

%% Define conditions and blocks
% We want to show a 70 degree adapter for 30 seconds, then run a block of
% top-up trials with the same adapter, then 110 degree adpater and a block
% of top-up trials. 


% Lets' first define the standard top-up blocks

cw=factorial('cw',1);           % Define a factorial with one factor
cw.fac1.testGabor.orientation  = 90+(-3:1:3); % Test Orientation. This defines the levels of factor 1 (7, with different orientations for the test)
cw.fac1.adapt.orientation      = 70;          % We make sure that the adapt stimulus has the correct orientation. Using a single level for a property means it will be used for all levels of the factor.  
cw.fac1.adapt.duration          = 3000;       % Make sure the adapter duration is 3s.
cwBlock=block('cwBlock',cw);                  % Define a block based on this factorial
cwBlock.nrRepeats  =5;                        % Each condition is repeated this many times 

% Now the block with the 110 degree adapter.
ccw=factorial('ccw',1); 
ccw.fac1.testGabor.orientation    = 90+(-3:1:3); % Test Orietation
ccw.fac1.adapt.duration           = 3000;
ccw.fac1.adapt.orientation        = 110;
ccwBlock=block('ccwBlock',ccw);
ccwBlock.nrRepeats = 10;

% Now we define a "block" consisting of a single condition: the long
% adapter. 
longCwFac=factorial('longAdaptCw',1);  % Define a factorial with a single factor 
longCwFac.fac1.adapt.duration =         10000;  % Adapter duration  - single condition
longCwFac.fac1.adapt.orientation =      70;  % Adapter orientation 
longCwBlock = block('longAdaptCw',longCwFac);
longCwBlock.nrRepeats = 1;              % We'll only show this condition once. 

longCcwFac=factorial('longAdaptCcw',1); 
longCcwFac.fac1.adapt.duration= 10000;  % Adapter duration
longCcwFac.fac1.adapt.orientation = 110;  % Adapter orientation
longCcwBlock = block('longAdaptCCw',longCcwFac);
longCcwBlock.nrRepeats = 1;

%% Run the experiment   
% Now tell CIC how we want to run these blocks (blocks are sequential,
% conditions within a block are randomized by default)
c.run(longCwBlock,cwBlock,longCcwBlock,ccwBlock);
 