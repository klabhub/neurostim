function jitteredITIDemo(minJitter, maxJitter, varargin)
% Demo to show variable inter-trial interval.
%
% cf. https://github.com/klabhub/neurostim/issues/204
%
% DS  - Aug 2022.

import neurostim.*

if nargin < 2
    maxJitter = 1000;
end
if nargin < 1
    minJitter = 500;
end

%% Setup the controller 
c= myRig(varargin{:});

%c.trialDuration = inf;
c.screen.color.background = [ 0.5 0.5 0.5];
c.subjectNr= 0;

%% Add a Gabor;
% We'll simulate an experiment in which
% the grating's location (left or right) is to be detected
% and use this to estimate the contrast threshold
g=stimuli.gabor(c,'grating');
g.color            = [0.5 0.5 0.5];
g.contrast         = 1;
g.X                = 0;
g.Y                = 0;
g.sigma            = 3;
g.phaseSpeed       = 0;
g.orientation      = 0;
g.mask             = 'CIRCLE';
g.frequency        = 3;
g.on               =  0;
g.duration         = 200;

g.addProperty('jitteredITI',[]);
g.jitteredITI = plugins.jitter(c,{minJitter, maxJitter}); 
c.iti = '@grating.jitteredITI';

d = neurostim.design('myDesign');

% specify a block of trials
myBlock = block('myBlock',d);
myBlock.nrRepeats = 100;

% now run the experiment...
c.run(myBlock); % run the paradigm



%% Do some analysis on the data
import neurostim.utils.*;

histogram(get(c.prms.iti,'atTrialTime',inf),10);
xlabel('ITI [s]');
ylabel('#trials');
end

