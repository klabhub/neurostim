%% 
% Steady State EEG Experiment
% The luminance of a blank screen is modulated sinusoidally, with or
% without concurrent tACS stimulation. EEG is recorded to determine 
% the steady state following of the evoked responses.
%
%
% BK - Feb 2016

%TODO 
% Add stimulation
% Add EEG recording


%% Prerequisites. 
import neurostim.*


%% Setup CIC and the stimuli.
c = klabConfig;    % Create Command and Intelligence Center with specific KLab settings
c.trialDuration = 4000; 
c.iti           = 500;


% Convpoly to create the luminance modulation
flicker = stimuli.convPoly(c,'flicker');
flicker.radius       = c.screen.width;
flicker.X            = 0;
flicker.Y            = 0;
flicker.nSides       = 4;
flicker.filled       = true;
flicker.color        = '@[1 1 1 (0.5*sin(2*pi*(fixation.time-250)*flicker.userData)+0.5)]';
flicker.on           = '@fixation.startTime+250';


stim = stimuli.starstim(c,'stim');
stim.fake           = true;
stim.host           = 'localhost';
stim.template       = 'steadystate';


% Red fixation point
f = stimuli.fixation(c,'reddot');    
f.color             = [1 0 0];
f.shape             = 'CIRC';        
f.size              = 0.1;
f.X                 = 0;
f.Y                 = 0;
f.on                = 0;             


%% Behavioral control
fix = plugins.fixate(c,'fixation');
fix.from            = '@fixation.startTime';  % Require fixation from the moment fixation starts (i.e. once you look at it, you have to stay).
fix.to              = '@cic.trialDuration';   % Require fixation for this long
fix.X               = 0;
fix.Y               = 0; 
fix.tolerance       = 2;

% Add an eye tracker. eyetracker is a dummy eyetracker that follows mouse
% clicks. Without this, the fixation object will not work.
et = plugins.eyetracker(c);
et.useMouse         = true;     


%% Define conditions and blockçs
tf=factorial('tf',1);           % Define a factorial with one factor
tf.fac1.flicker.userData    = [0 2.^(0:7)]/1000;
tfBlock=block('tfBlock',tf); 
tfBlock.nrRepeats  =5;       
tfBlock.randomization = 'SEQUENTIAL';
%% Run the experiment   
c.run(tfBlock);
 