%% 
% Tilt AfterEffect Example
%
%
% BK - Feb 2016

%TODO 
% Dimming task (generic?)
% Add stimulation


%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 1); % Not in production mode; this is just to run without requiring accurate timing.


%% Setup CIC and the stimuli.
c = bkConfig;                            % Create Command and Intelligence Center...

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
g.on                = '@f1.startTime +250';


% Duplicate the Gabor serve as a test stimulus 
g2= duplicate(g,'testGabor');
g2.contrast         = 0.25;  
g2.on               = '@adapt.off +250';
g2.duration         = 500;

% Convpoly to create a dimming task
circle = stimuli.convPoly(c,'dimmer');
circle.radius = 3;
circle.X = 0;
circle.Y = 0;
circle.nSides = 100;
circle.filled = true;
circle.color = [0.5 0.5 0.5 0.5];




% Red fixation point
f = stimuli.fixation(c,'fix');        % Add a fixation point stimulus
f.color             = [1 0 0];
f.shape             = 'CIRC';                  % Shape of the fixation point
f.size              = 0.25;
f.X                 = 0;
f.Y                 = 0;
f.on                = 0;



%% Behavioral control
fix = plugins.fixate(c,'f1');
fix.from            = '@f1.startTime';
fix.to              = '@testGabor.endTime';
fix.X               = 0;
fix.Y               = 0; 
fix.tolerance       = 2;

% Add an eye tracker. eyetracker is a dummy eyetracker that follows mouse
% clicks. 
et = plugins.eyetracker(c);
et.useMouse         = true;
%  
%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on                = '@ testGabor.endTime';
k.deadline          = Inf; 
k.keys              = {'a' 'l'};
k.keyLabels         = {'ccw', 'cw'};

% Trial ends when the choice has been made.
c.trialDuration = '@ choice.endTime';

%% Define conditions and blocks

% Long adapter
% longAdaptFac=factorial('longAdapt',1); 
% longAdaptFac.fac1.adapt.duration= {3000};  % Adapter orietnation
% longAdaptBlock = block('longAdapt',longAdaptFac);
% longAdaptBlock.nrRepeats = 1;


cw=factorial('cw',1); 
cw.fac1.testGabor.orientation    = neurostim.utils.vec2cell(90+(-3:1:3)); % Test Orietation
cwBlock=block('cwBlock',cw);
cwBlock.beforeFunction = '@adapt.orientation= 70';
cwBlock.nrRepeats  =5;

ccw=factorial('ccw',1); 
ccw.fac1.testGabor.orientation    = neurostim.utils.vec2cell(90+(-3:1:3)); % Test Orietation
ccwBlock=block('ccwBlock',ccw);
ccwBlock.beforeFunction = '@adapt.orientation=110';
ccwBlock.nrRepeats = 5;
    
%plugins.gui(c);
c.run(cwBlock,ccwBlock);
 