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
c = bkxps2013Config;                            % Create Command and Intellige nce Center...
c.trialDuration  = inf;
c.add(plugins.debug); 

et = plugins.eyetracker;
et.useMouse = true;
c.add(et);
 



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
g2.X='@ -testGab.X'; % X  = -X of the testGab
g2.contrast = 0.5;  

% Duplicate the testGab grating to make a surround
g3= duplicate(g,'surround');
g3.mask = 'ANNULUS';
g3.sigma = [1 2];
g3.contrast  = 0.5;
g3.X='@ testGab.X'; % X= X of the testGab

% Duplicate the surround to use as the surround of the reference
g4 = duplicate(g3,'referenceSurround');
g4.X='@ -testGab.X';
g4.contrast = 1;

% Red fixation point
f = stimuli.fixation('fix');        % Add a fixation point stimulus
f.color = [1 0 0];
f.shape = 'CIRC';                  % Shape of the fixation point
f.size = 1;
f.X = 0;
f.Y = 0;


fix = plugins.fixate('f1');
fix.from = 200; %'@(f1) f1.startTime';
fix.to = 1000; %'@(dots) dots.endTime';
fix.X = 0;% '@(fix) fix.X';
fix.Y = 0; %'@(fix) fix.Y';
fix.tolerance = 3;
c.add(fix);

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
design = {{'surround','orientation',{0,0,90,0},'surround','contrast',{0,surroundContrast,surroundContrast,surroundContrast},'referenceSurround','contrast',{0,surroundContrast,0,0}},...
          {'testGab','contrast',{0.10, 0.20 ,0.40 ,0.50}},...
          {'testGab','X',{-2.5, 2.5}}};
% 
%design = {{'testGab','contrast',{0.10, 0.20 ,0.40 ,0.50}},...
%          {'testGab','X',{-2.5, 2.5}}};
myFac=factorial('myFactorial',3); 
myFac.fac1.surround.orientation={0 0 90 0}; 
myFac.fac1.surround.contrast={0,surroundContrast,surroundContrast,surroundContrast};
myFac.fac1.referenceSurround.contrast={0,surroundContrast,0,0};
myFac.fac2.testGab.contrast={0.10, 0.20 ,0.40 ,0.50};
myFac.fac3.testGab.X={-2.5, 2.5};

myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;
    
%Subject's 2AFC response
k = c.add(plugins.nafcResponse('choice'));
k.on = 0; '@ f1.to';
k.deadline = Inf; '@ f1.to + 3000';
k.keys = {'a' 'l'};
k.keyLabels = {'left', 'right'};
k.correctKey = '@ sign(testGab.X) *double(testGab.contrast>reference.contrast)+ 1';  %Function returns 1 or 2

c.trialDuration = '@ choice.endTime';
 c.add(plugins.sound);
% 
%     Add correct/incorrect feedback
 s = c.add(plugins.soundFeedback('soundFeedback'));
 s.path = 'C:\Temp\neurostim-ptb\nsSounds\sounds';
 s.add('waveform','CORRECT','when','afterFrame','criterion','@ choice.success & choice.correct');
 s.add('waveform','INCORRECT','when','afterFrame','criterion','@ choice.success & ~choice.correct');


% c.add(plugins.gui);
% c.order('fix','reference', 'gui');
c.run(myBlock);
 