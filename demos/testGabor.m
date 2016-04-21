import neurostim.*

%% Setup CIC and the stimuli.
c = myRig;
c.trialDuration  = inf;
plugins.debug(c); 

% Create a grating stimulus. This will be used to map out the psychometric
% curve (hence 'gabortest')
g=stimuli.gabor(c,'gabortest');           
g.color = [0.5 0.5 0.5];
g.contrast = 0.5;
g.Y = 0; 
g.X = 0;
g.sigma = 1;                       
g.phaseSpeed = 10;
g.orientation = 90;
g.mask ='CIRCLE';
g.frequency = 3;


% Duplicate the test grating to make a surround
g3= duplicate(g,'surround');
g3.mask = 'ANNULUS';
g3.sigma = [1 2];
g3.contrast  = 0.5;
g3.orientation=0; 
g3.X = '@gabortest.X';

myFac=factorial('test');
myFac.fac1.gabortest.X={-2.5 2.5}; 
myBlock=block('block',myFac);
c.run(myBlock);
