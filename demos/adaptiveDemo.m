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
g.duration          = 100;
%jitter(c,'grating','X',{10},'distribution',@(x) (10*(1-2*(rand>0.5)))); % This jitters the location on each trial to be left (-10) or right (+10)

%% Setup user responses
% Take the user response (left/right) and adjust the
% Quest procedure accordingly  (only the k.adapt parameter is specific to
% Quest).
k = plugins.nafcResponse(c,'choice');
k.on = '@grating.on + grating.duration';
k.deadline = '@choice.on + 2000';         %Maximum allowable RT is 2000ms
k.keys = {'a' 'l'};                                          %Press 'a' for "left" motion, 'l' for "right"
k.keyLabels = {'left', 'right'};
k.correctKey = '@double(grating.X> 0) + 1';   %Function returns the index of the correct response (i.e., key 1 ('a' when X<0 and 2 'l' when X>0)
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.


%% Setup the conditions in a factorial and run
myFac=factorial('grating',1);
myFac.fac1.grating.orientation = [-45 45];
 myFac.fac1.grating.X= jitter(c,{-10,10});
myBlock=block('myBlock',myFac);
myBlock.nrRepeats = 40;
c.run(myBlock);


end