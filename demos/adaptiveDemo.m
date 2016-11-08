function c= adaptiveDemo
% Demo to show adaptive threshold estimation.
%
% The subjects task is to detect the location of a Gabor:  left (press
% 'a') or right (press 'l')
%
% The demo can use QUEST or a Staircase procedure to estimate the threshold
% for correct detection, separately for +45 and -45 degree oriented gratings.
%
% The demo can use  key presses, or simulate an ideal observer with a
% fixed threshold. 
% 
% BK  - Nov 2016.

import neurostim.*

method = 'QUEST'; % Set this to QUEST or STAIRCASE 
pianola = true; % Set this to true to simulate responses, false to provide your own responses ('a'=left,'l' = right).

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
myFac=factorial('orientation',1);
myFac.fac1.grating.orientation = [-45 45];
% Here we add adaptive parameters. The simplest adaptive parameter is used to jitter
% parameters across trials. Use the jitter class for this.
myFac.fac1.grating.X= plugins.jitter(c,{10},'distribution',@(x)(x*(1-2*(rand>0.5)))); % Jitter the location of the grating on each trial: either 10 or -10 using the function


if strcmpi(method,'QUEST')
    % To estimate threshold adaptively, the Quest method can be used. We need
    % to define two functions to map the random intensity variable with values between
    % -Inf and Inf that Quest "optimizes" to a meaningful contrast value. We'll
    % assume that the Quest intensity models the log10 of the contrast. i2p and
    % p2i implement that mapping.
    i2p = @(x) (min(10.^x,1)); % Map Quest intensity to contrast values in [0 , 1]
    p2i = @(x) (log10(x));
    % Define a quest procedure with an initial guess, and our confidence in
    % that guess, and tell the Quest procedure which function to evaluate to
    % determine whether the response was correct or not. To setup Quest to use
    % the subject's responses, use the following:
    if ~pianola
        myFac.fac1.grating.contrast = plugins.quest(c, '@choice.correct','guess',p2i(0.25),'guessSD',4,'i2p',i2p,'p2i',p2i);
    else
        % Iif you'd like to see Quest in action, without pressing buttons, we
        % can simulate responses with this trialResult function (note that you also have
        % to set c.trialDuration < Inf for this to work, otherwise CIC keeps waiting for a button press)
        myFac.fac1.grating.contrast = plugins.quest(c, '@grating.contrast>(0.1+0.7*(grating.cic.condition-1))','guess',p2i(0.25),'guessSD',4,'i2p',i2p,'p2i',p2i);
        c.trialDuration = 150;
        % Note that the function
        % '@grating.contrast>(0.1+0.7*(grating.cic.condition-1))' 
        % return true (=correct ) for contrasts above 0.1 in the first condition and
        % above 0.8 in the second condition. Hence the expected thresholds
        % should be 0.1 and 0.7 for the two conditions (=orientations). 
    end
elseif strcmpi(method,'STAIRCASE')    
    % As an alternative adaptive threshold estimation procedure, consider the 1-up 1-down staircase with fixed 0.01 stepsize on contrast.
    % With user responses, youuse:
    if ~pianola
        myFac.fac1.grating.contrast = plugins.nDown1UpStaircase(c,'@choice.correct',rand,'min',0,'max',1,'weights',[1 1],'delta',0.1);
    else
        %  For a pianola version of the demo, we simulate responses at the end
        %  of the trial
        myFac.fac1.grating.contrast = plugins.nDown1UpStaircase(c,'@grating.contrast>(0.1+0.7*(grating.cic.condition-1))',rand,'min',0,'max',1,'weights',[1 1],'delta',0.01);
        c.trialDuration = 150;
    end
end
myBlock=block('myBlock',myFac);
myBlock.nrRepeats = 25;
c.run(myBlock);

%% Do some analysis
load ([c.fullFile '.mat'],'data');
import neurostim.utils.*;
conditions=getproperty(data,'condition','cic');
conditions = [conditions{:}];
contrast = getproperty(data,'contrast','grating');
contrast = [contrast{:}];
uV = unique(conditions);
figure;
hold on
for u=uV
    stay = conditions ==u;
    plot(contrast(stay),'.-');
end
xlabel 'Trial'
ylabel 'Contrast '
title ([method ' in action...'])
end