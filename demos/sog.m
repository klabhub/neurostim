%% 
% Stream of Gratings Example
% 
% Data recorded with this experiment can be analyzed with the anaSog script
%
% BK - Feb 2016


%% Prerequisites. 
import neurostim.*


%% Setup CIC and the stimuli.
c = bkConfig;                            % Create Command and Intelligence Center...
c.trialDuration = 3000;

%plugins.gui(c);         % Show a gui (dual screens only)

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
g.addRSVP('orientation',utils.vec2cell(0:30:359),'duration',5000/60,'isi',2000/60,'randomization','RANDOMWITHREPLACEMENT');

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
fix.X               = 0;
fix.Y               = 0; 
fix.tolerance       = 2;

% Add an eye tracker. eyetracker is a dummy eyetracker that follows mouse
% clicks. Without this, the fixation object will not work.
et = plugins.eyetracker(c);
et.useMouse         = true;     



%% Define conditions and blocks

fac=factorial('fac',1);           % Define a factorial with one factor
fac.fac1.grating.contrast = 0.25:0.25:1;
fac.randomization = 'SEQUENTIAL';
blck=block('block',fac);                  % Define a block based on this factorial
blck.nrRepeats  =1;                        % Each condition is repeated this many times 

%% Run the experiment   
% Now tell CIC how we want to run these blocks 
c.run(blck);
 