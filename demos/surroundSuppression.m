function surroundSuppression
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


%% Setup CIC and the stimuli.
c = myRig;                            % Create Command and Intellige nce Center...
c.trialDuration  = inf;
plugins.debug(c); 
 c.screen.color.background = [0.5 0.5 0.5];
% Create a grating stimulus. This will be used to map out the psychometric
% curve (hence 'testGab')
g=stimuli.gabor(c,'testGab');           
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
g2.X='@ -1*testGab.X'; % X  = -X of the testGab
g2.contrast = 0.5;  

% Duplicate the testGab grating to make a surround
g3= duplicate(g,'surround');
g3.mask = 'ANNULUS';
g3.sigma = [1 2];
g3.contrast  = 0.5;
g3.X='@testGab.X'; % X= X of the testGab

% Duplicate the surround to use as the surround of the reference
g4 = duplicate(g3,'referenceSurround');
g4.X='@ -1*testGab.X';
g4.contrast = 1;

% Red fixation point
f = stimuli.fixation(c,'fix');        % Add a fixation point stimulus
f.color = [1 0 0];
f.shape = 'CIRC';                  % Shape of the fixation point
f.size = 0.25;
f.X = 0;
f.Y = 0;


 
%% Define conditions and blocks
surroundContrast = 0.6;
% Create a factorial design with three factors.
% In the first factor (first row), we vary the orientation of the
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
myDesign=design('myFactorial'); 
% You can use cells or vectors to specify the levels of a factor.
myDesign.fac1.surround.orientation={0 0 90 0}; 
myDesign.fac1.surround.contrast={0,surroundContrast,surroundContrast,surroundContrast};
myDesign.fac1.referenceSurround.contrast={0,surroundContrast,0,0};
myDesign.fac2.testGab.contrast=0.1:0.1:0.5;
myDesign.fac3.testGab.X=[-2.5, 2.5];

myBlock=block('myBlock',myDesign);
myBlock.nrRepeats=10;
    
%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on = 0; '@ f1.to';
k.deadline = Inf; '@ f1.to + 3000';
k.keys = {'a' 'l'};
k.keyLabels = {'left', 'right'};
k.correctKey = '@ (sign(testGab.X)>0)*(double(testGab.contrast>reference.contrast)+ 1) + (sign(testGab.X)<0)*(double(testGab.contrast<reference.contrast)+ 1)';  %Function returns 1 or 2

c.trialDuration = '@choice.stopTime'; % Trial ends once the subjects makes a choice (i.e. answers the nAFC)
plugins.sound(c);
% 
%     Add correct/incorrect feedback
s = plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','CORRECT.wav','when','afterFrame','criterion','@ choice.success & choice.correct');
s.add('waveform','INCORRECT.wav','when','afterFrame','criterion','@ choice.success & ~choice.correct');

c.run(myBlock);
 