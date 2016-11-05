function c=nsQuestDemo 
% Quest threshold estimation demo

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
jitter(c,'grating','X',{10},'distribution',@(x) (10*(1-2*(rand>0.5)))); % This jitters the location on each trial to be left (-10) or right (+10)

%% Setup quest
% Threshold estimation by varying the contrast  parameter 
% using QUEST. The Quest intentsity parameter is a Gaussian random variable (i.e. it
% has negative values too) so to map this onto contrast we do Quest on
% log10(intensity), which means that contrast = 10^intensity.
% Define anynomous functions to do these conversions:
i2p = @(x) (min(10.^x,1)); % Map Quest intensity to contrast values in [0 , 1]
p2i = @(x) (log10(x));    % Map contrast values to quest intensity.
% Tell the stimulus that its 'contrast' parameter will uese quest. Our
% initial guess for the threshold is contrast=0.4. 
g.setupThresholdEstimation('contrast','QUEST','guess',p2i(0.25),'guessSD',4,'i2p',i2p,'p2i',p2i);

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
k.adapt = 'grating';                                    % This tells the plugin that after the subject gives a response , its correctness (as determined by correctKey above) is used to adapt the threshold parameter of the grating stimulus. 
c.trialDuration = '@choice.stopTime';       %End the trial as soon as the 2AFC response is made.


%%  Pianola version
% To see the threshold estimation in action without pressing
% buttons, we can define an ideal observer . 
% Tell CIC to call this eScript after drawing each frame. To use your own
% key presses, just comment out this line
c.addScript('AfterFrame',@respondOptimal); 
function respondOptimal(c)
    thresholds = [ 0.25 0.8]; % Simulated thresholds for the two test orientations
 if c.trialTime > c.grating.duration
                % The simulated observer responds once the grating has been
                % presented, 
                % Simulate what an observer that matches the assumptions of
                % Quest would do. Note that we have to use p2i to convert
                % between the contrast parameter that the grating stimulus
                % uses and the intensity parameter that Quest uses
                % internally.   
                 response=QuestSimulate(c.grating.quest.q(c.condition),p2i(c.grating.contrast),p2i(thresholds(c.condition)));
                answer(c.grating,response); % Tell the grating stimulus about the answer
                c.endTrial;
            end
end

%% Setup the conditions in a factorial and run
myFac=factorial('grating',1);
myFac.fac1.grating.orientation = [-45 45];
myBlock=block('myBlock',myFac);
myBlock.nrRepeats = 40;
c.run(myBlock);

%% Once it is done, show the Quest results
[m,sd,contrasts]= threshold(g);
figure;
hold on
for i=1:2
    plot(contrasts{i});
end
legend('Ori -45','Ori +45');
xlabel 'Trial'
ylabel 'Test Contrast'
title (['Quest Threshold Contrast Estimates. Mean: ' num2str(m,2) '  Std:' num2str(sd)])

end