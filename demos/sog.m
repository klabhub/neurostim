function sog
%% 
% Stream of Gratings Example
% 
% Shows how a single stimulus ( a grating in this case) can be shown as a 
% rapid visual stream (RSVP) with one or more of its properties changing within a
% trial. 
%
% The experiment starts with a red dot, click with a mouse to fixate, then
% the stream of gratings will show.
% 
% BK - Feb 2016


%% Prerequisites. 
import neurostim.*


%% Setup CIC and the stimuli.
c = myRig;         % Create Command and Intelligence Center...
c.trialDuration = '@fixation.startTime+3000';
c.screen.color.background = [0.5 0.5 0.5]; 

% Create a Gabor stimulus to adadot. 
g=stimuli.gabor(c,'grating');           
g.color             = [0.5 0.5 0.5];
g.contrast          = 0.25;
g.Y                 = 0; 
g.X                 = 0;
g.sigma             = 3;                       
g.phaseSpeed        = 0;
g.orientation       = 15;
g.mask              ='CIRCLE';
g.frequency         = 3;
g.on                =  '@fixation.startTime +250'; % Start showing 250 ms after the subject starts fixating (See 'fixation' object below).

% We want to show a rapid stream of gratings. Use the factorial class to
% define these "conditions" in the stream.
stream =design('ori');           % Define a factorial with one factor
stream.fac1.grating.orientation = 0:30:359; % Assign orientations
stream.randomization = 'RANDOMWITHOUTREPLACEMENT'; % Randomize
g.addRSVP(stream,'duration',5*1000/c.screen.frameRate,'isi',2*1000/c.screen.frameRate); % Tell the stimulus that it should run this stream (in every trial). 5 frames on 2 frames off.

% Alternatively, you may want to stream gratings with both orientation and
% contrast varied.
% stream =design('ovc');           % Define a factorial with two fa0ctors
% stream.fac1.grating.orientation = 0:30:359; % Assign orientations
% stream.fac2.grating.contrast = [0 0.25 0.5 1]; % Contrasts including 0
% stream.randomization = 'RANDOMWITHOUTREPLACEMENT'; % Randomize
% g.addRSVP(stream,'log',true,'duration',5*1000/c.screen.frameRate,'isi',15*1000/c.screen.frameRate); % Tell the stimulus that it should run this stream (in every trial). 5 frames on 2 frames off.

%% This is all you need for an rsvp stream. The rest is just to make it into a full experiment.

% Red fixation point
f = stimuli.fixation(c,'reddot');       % Add a fixation point stimulus
f.color             = [1 0 0];
f.shape             = 'CIRC';           % Shape of the fixation point
f.size              = 0.25;
f.X                 = 0;
f.Y                 = 0;
f.on                = 0;                % On from the start of the trial



%% Behavioral control
fix = plugins.fixate(c,'fixation');
fix.from            = '@fixation.startTime';  % Require fixation from the moment fixation starts (i.e. once you look at it, you have to stay).
fix.to              = '@grating.stopTime';   % Require fixation until testGabor has been shown.
fix.X               = '@reddot.X';
fix.Y               = '@reddot.Y';
fix.tolerance       = 2;


%% Define conditions and blocks
% We will show the stream of gratings with different contrasts in each
% trial.
% d=design('contrast');           % Define a factorial with one factor
% d.fac1.grating.contrast = 0.1:0.2:1; % From 10 to 100% contrast
% d.randomization = 'RANDOMWITHOUTREPLACEMENT';

% Or (if the stream already varies contrast and orientation, we vary
% nothing across trials).
d=design('dummy');           % Define a factorial with one factor
% Nothing to vary here but we need at least one condition
d.conditions(1).grating.X = 0; % Dummy
blck=block('block',d);                  % Define a block based on this factorial
blck.nrRepeats  =10;                        % Each condition is repeated this many times 

%% Run the experiment   
c.cursor = 'arrow';
% Now tell CIC how we want to run these blocks 
c.run(blck);
 