function jitteredITIDemo(minJitter, maxJitter, varargin)
% Demo to show variable inter-trial interval.
%
% INPUT:
% minJitter: minimum inter-trial interval in [s]
% maxJitter: maximum inter-trial interval in [s]
%
% cf. https://github.com/klabhub/neurostim/issues/204
%
% DS  - Sep 2022.

import neurostim.*

if nargin < 2
    maxJitter = 1000;
end
if nargin < 1
    minJitter = 500;
end

%% Setup the controller 
c = myRig(varargin{:});
c.screen.color.background = [ 0.5 0.5 0.5];
c.subjectNr= 0;

%% Add a Gabor;
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


%% key part - adding the property to a regular plugin (gabor in this case), not to CIC
% Properties of cic are special (in the sense that they are not updated at 
% the start of the trial ) and can therefore not be set in a design. This 
% is to avoid all kinds of issues with Internal /bookkeeping parameters of 
% CIC being changed on a per-trial basis.

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

