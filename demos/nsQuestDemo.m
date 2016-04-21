% Quest threshold estimation demo
% TODO
erro('NOT FUNCTIONAL')
import neurostim.*

c= myRig;
% Add a limited lifetime dot pattern
l=stimuli.rdp(c,'dots');
% Vary the nrDots across conditions. This factorial is given the name 'nrDots'
myFac=factorial('nrDots',1);
myFac.fac1.dots.nrDots= [10:10:40];

% We will do threshold estimation by varying the coherence parameter 
% using a separate QUEST for each condition
% We guess that the threshold is 10^-2 with an SD of 0.5 for each condition.
% QUEST wants the guess as a log10 contrast!
l.setupThresholdEstimation('coherence','QUEST','guess',-2,'guessSD',3);
% Run a block with the conditions from the 'size' factorial. 
% Repeat each condition 40 times.

myBlock=block('myBlock',myFac);

% c.addBlock('coherence','nrDots',10,'BLOCKRANDOMWITHREPLACEMENT');
% The quest responder class (see questResponder.m) shows how to control 
% the logic flow in an experiment. In this case it actually simulates
% responses.
logic = questResponder; 
c.add(logic)
c.run(myBlock)

[m,sd]= threshold(l);
figure;
staircase = cat(2,l.quest.q.intensity)';
plot(staircase);
xlabel 'Trials'
ylabel 'Coherence'
title (['Quest Estimates : ' num2str(m,2) ' \pm ' num2str(sd)])

