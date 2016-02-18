 %% 
% Surround Suppression Example
%
% Demonstrates how to copy stimuli, how to link them to each other with
% functions, how to setup a factorial design, and how to add simple subject
% key responses.
%
% BK - Jun 2015

%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 0); % Not in production mode; this is just to run without requiring accurate timing.
Screen('Preference','TextRenderer',1);

%% Setup CIC and the stimuli.
c = cic;                            % Create Command and Intelligence Center...
c.screen.pixels    = [0 0 500 500];        % Set the position and size of the window
c.screen.physical  = [15 15];              % Set the physical size of the window (centimeters)
c.screen.color.background= [0.5 0.5 0.5];
c.screen.colorMode = 'RGB';                % Tell CIC that we'll use RGB colors
c.trialDuration  = inf;
c.add(plugins.debug); 

 
% Create a grating stimulus. This will be used to map out the psychometric
% curve (hence 'testGab')
g=stimuli.gabor('testGab');           
g.color = [0.5 0.5 0.5];
g.contrast = 0.5;
g.Y = 0; 
g.X = 0;
g.sigma = 1;                       
g.phaseSpeed = 10;
g.orientation = 90;
g.mask ='CIRCLE';
g.frequency = 3;
g.duration  = Inf; 

% Duplicate the testGab grating to serve as a reference (its contrast is
% constant). Call this new stimulus 'reference'
g2= duplicate(g,'reference');
g2.X='@(testGab) -testGab.X'; % X  = -X of the testGab
g2.contrast = 0.5;  

% Duplicate the testGab grating to make a surround
g3= duplicate(g,'surround');
g3.mask = 'ANNULUS';
g3.sigma = [1 2];
g3.contrast  = 0.5;
g3.X='@(testGab) testGab.X'; % X= X of the testGab

% Duplicate the surround to use as the surround of the reference
g4 = duplicate(g3,'referenceSurround');
g4.X='@(testGab) -testGab.X';
g4.contrast = 1;

% Red fixation point
f = stimuli.fixation('fix');        % Add a fixation point stimulus
f.color = [1 0 0];
f.shape = 'CIRC';                  % Shape of the fixation point
f.size = 1;
f.X = 0;
f.Y = 0;

% Add stimuli to CIC in reverse draw order. (i.e. f will be on top).
c.add(g); 
c.add(g4);                           
c.add(g3);                          
c.add(g2);                          
c.add(f);                          
 
%% Define conditions and blocks
surroundContrast = 0.6;
% Create a factorial design (a cell array) with three factors (three cell
% arrays ). In the first factor (first row), we vary the orientation of the
% surround stimulus, the contrast of the surround stimulus and the contrast
% of the referenceSurround stimulus (all at the same time in pairwise fashion).
% The result is that the screen will show 
% 1) two gratings 
% 2) two gratings with surrounds
% 3) a grating on one side and a grating with surround on the other
% 4) a grating and a grating with an orthogonal surround on the other.
%
% The second factor varies the contrast (to map out the psychometric
% curve determining that relates the percept of "which (center) grating has more
% contrast?" to the actual contrast of the test stimulus.
%
% The third factor just ensures that the reference and test stimulus appear
% on the left and right equally often
%

myFac=factorial('myFactorial',3); 
myFac.fac1.surround.orientation={0 0 90 0}; 
myFac.fac1.surround.contrast={0,surroundContrast,surroundContrast,surroundContrast};
myFac.fac1.referenceSurround.contrast={0,surroundContrast,0,0};
myFac.fac2.testGab.contrast={0.10, 0.20 ,0.40 ,0.50};
myFac.fac3.testGab.X={-2.5, 2.5};

myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;


c.add(plugins.gui);

% c.addFactorial('orientation',design{:}) ;
% c.addBlock('orientation','orientation',10,'RANDOMWITHREPLACEMENT')
% 
% Add response keys that allow the subject to respond whether the
% (center) grating on the left (press 'a') or right (press 'l') had more
% contrast. Becuase the cic.trialDuration ==Inf, this is the only way to
% move to the next trial in this experiment.
c.addResponse('a','write',-1,'nextTrial',true);
c.addResponse('l','write',+1,'nextTrial',true);
c.run(myBlock);
% c.run % Run the experiment. 
  