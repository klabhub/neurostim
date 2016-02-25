%% 
% Tilt AfterEffect Example
%
%
% BK - Feb 2016

%% Prerequisites. 
import neurostim.*
Screen('Preference', 'SkipSyncTests', 1); % Not in production mode; this is just to run without requiring accurate timing.


%% Setup CIC and the stimuli.
c = bkConfig;                            % Create Command and Intellige nce Center...
c.trialDuration  = inf;

et = plugins.eyetracker(c);
et.useMouse = true;
 



% Create a grating stimulus. This will be used to map out the psychometric
% curve (hence 'testGab')
g=stimuli.gabor(c,'adapt');           
g.color = [0.5 0.5 0.5];
g.contrast = 0.5;
g.Y = 10; 
g.X = 0;
g.sigma = 1;                       
g.phaseSpeed = 0;
g.orientation = 20;
g.mask ='CIRCLE';
g.frequency = 3;
g.duration  = 1000;
g.on = '@fix.startTime +250';


% Duplicate the testGab grating to serve as a reference (its contrast is
% constant). Call this new stimulus 'reference'
g2= duplicate(g,'test');
g2.contrast = 0.25;  
g2.on = '@adapt.off +250';


% Red fixation point
f = stimuli.fixation(c,'fix');        % Add a fixation point stimulus
f.color = [1 0 0];
f.shape = 'CIRC';                  % Shape of the fixation point
f.size = 0.25;
f.X = 0;
f.Y = 0;


fix = plugins.fixate(c,'f1');
fix.from = '@f1.startTime';
fix.to = '@test.endTime';
fix.X = 0;
fix.Y = 0; 
fix.tolerance = 2;
 
%% Define conditions and blocks

%
myFac=factorial('adaptAndTest',3); 
myFac.fac1.adapt.orientation={-20 20}; 
myFac.fac2.test.orientation={-20,-10, -5 , 0, 5, 10, 20};
myBlock=block('myBlock',myFac);
myBlock.nrRepeats=10;
    
%Subject's 2AFC response
k = plugins.nafcResponse(c,'choice');
k.on = '@ f1.to';
k.deadline = Inf; 
k.keys = {'a' 'l'};
k.keyLabels = {'ccw', 'cw'};

c.trialDuration = '@ choice.endTime';

plugins.sound(c);
% 
%     Add correct/incorrect feedback
 s = plugins.soundFeedback(c,'soundFeedback');
 s.path = 'C:/Users/bart.VISION/OneDrive/common/neurostim-ptb/nsSounds/sounds';
 s.add('waveform','fixbreak.wav','when','afterFrame','criterion','@ ~f1.success');
 


plugins.gui(c);
c.order('fix','adapt','test','gui');
c.run(myBlock);
 