function c= adaptiveDemo
import neurostim.*
%% Setup the controller
c= myRig;
c.trialDuration = Inf;
c.screen.color.background = [ 0.5 0.5 0.5];
c.subjectNr= 0;

%% Add a Gabor; 
% We'll simulate an experiment in which
% the grating's location (left or right) is to be detected
% and use this to estimate the contrast threshold
g=stimuli.gabor(c,'grating');           
g.color             = [0.5 0.5 0.5];
g.contrast         = 0.25;
g.Y                     = 0; 
g.X                     = 0;
g.sigma             = 3;                       
g.phaseSpeed   = 0;
g.orientation     = 0;
g.mask               = 'CIRCLE';
g.frequency        = 3;
g.on                    =  0; 
g.duration          = 500;

%% Setup user responses
% Take the user response (left/right) 
k = plugins.nafcResponse(c,'choice');
k.on = '@grating.on + grating.duration';
k.deadline = '@choice.on + 2000';         %Maximum allowable RT is 2000ms
k.keys = {'a' 'l'};                                          %Press 'a' for "left" motion, 'l' for "right"
k.keyLabels = {'left', 'right'};
k.correctKey = '@double(grating.X> 0) + 1';   %Function returns the index of the correct response (i.e., key 1 ('a' when X<0 and 2 'l' when X>0)
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.


%% Setup the conditions in a factorial 
myFac=factorial('grating',1);
myFac.fac1.grating.orientation = [-45 45];
% Here we add adaptive parameters. The simplest adaptive parameter is used to jitter 
% parameters across trials. Use the jitter class for this. 
 myFac.fac1.grating.X= jitter(c,{10},'distribution',@(x)(x*(1-2*(rand>0.5)))); % Jitter the location of the grating on each trial: either 10 or -10 using the function
% To estimate threshold adaptively, the Quest method can be used. We need
% to define two functions to map the random intensity variable with values between
% -Inf and Inf that Quest "optimizes" to a meaningful contrast value. We'll
% assume that the Quest intensity models the log10 of the contrast. i2p and
% p2i implement that mapping.
 i2p = @(x) (min(10.^x,1)); % Map Quest intensity to contrast values in [0 , 1]
p2i = @(x) (log10(x));   
% Define a quest procedure with an initial guess, and our confidence in
% that guess, and tell the Quest procedure which function to evaluate to
% determine whether the response was correct or not.
 myFac.fac1.grating.contrast = quest(c, '@choice.correct','guess',p2i(0.25),'guessSD',4,'i2p',i2p,'p2i',p2i);
 
 myBlock=block('myBlock',myFac);
myBlock.nrRepeats = 40;
c.run(myBlock);


end