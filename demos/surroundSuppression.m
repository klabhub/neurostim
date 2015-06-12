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
Screen('Preference', 'SkipSyncTests', 2); % Not in production mode; this is just to run without requiring accurate timing.

%% Setup CIC and the stimuli.
c = cic;                            % Create Command and Intelligence Center...
c.pixels    = [0 0 500 500];        % Set the position and size of the window
c.physical  = [15 15];              % Set the physical size of the window (centimeters)
c.color.background= [0.5 0.5 0.5];
c.colorMode = 'RGB';                % Tell CIC that we'll use RGB colors
c.trialDuration  = inf;
c.add(plugins.gui); 

 
% Create a grating stimulus. This will be used to map out the psychometric
% curve (hence 'test')
g=stimuli.gabor('test');           
g.color = [0.5 0.5];
g.luminance = 0.5;
g.contrast = 0.5;
g.Y = 0; 
g.X = 0;
g.sigma = 1;                       
g.phaseSpeed = 10;
g.orientation = 90;
g.mask ='CIRCLE';
g.frequency = 3;
g.duration  = 30; 

% Duplicate the test grating to serve as a reference (its contrast is
% constant). Call this new stimulus 'reference'
g2= duplicate(g,'referemce');
functional(g2,'X',{@times,{g,'X'},-1}); % X  = -X of the test
g2.contrast = 0.5;  

% Duplicate the test grating to make a surround
g3= duplicate(g,'surround');
g3.mask = 'ANNULUS';
g3.sigma = [1 2];
g3.contrast  = 0.5;
functional(g3,'X',{@times,{g,'X'},1});  % X= X of the test

% Duplicate the surround to use as the surround of the reference
g4 = duplicate(g3,'referenceSurround');
functional(g4,'X',{@times,{g,'X'},-1});
g4.contrast = 1;

% Red fixation point
f = stimuli.fixation('fix');        % Add a fixation point stimulus
f.color = [1 0];                    % Red
f.luminance = 0;
f.shape = 'CIRC';                  % Shape of the fixation point
f.size = 10;
f.X = 0;
f.Y = 0;

% Add stimuli to CIC in reverse draw order. (i.e. f will be on top).
c.add(f); 
c.add(g2);                           
c.add(g3);                          
c.add(g4);                          
c.add(g);                          
 
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
design = {{'surround','orientation',{0,0,90,0},'surround','contrast',{0,surroundContrast,surroundContrast,surroundContrast},'referenceSurround','contrast',{0,surroundContrast,0,0}},...
          {'test','contrast',{0.10, 0.20 ,0.40 ,0.50}},...
          {'test','X',{-2.5, 2.5}}};
% 
%design = {{'test','contrast',{0.10, 0.20 ,0.40 ,0.50}},...
%          {'test','X',{-2.5, 2.5}}};
 
c.addFactorial('orientation',design{:}) ;
c.addBlock('orientation','orientation',10,'RANDOMWITHREPLACEMENT')

% Add response keys that allow the subject to respond whether the
% (center) grating on the left (press 'a') or right (press 'l') had more
% contrast. Becuase the cic.trialDuration ==Inf, this is the only way to
% move to the next trial in this experiment.
c.addResponse('a','write',-1,'nextTrial',true);
c.addResponse('l','write',+1,'nextTrial',true);

c.run % Run the experiment. 
 