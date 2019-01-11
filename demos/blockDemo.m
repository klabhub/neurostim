function blockDemo
%% Blocks demo
%
% This demo shows how to use messages and functions before and after blocks.
%
% BK - Jul 2017

import neurostim.*;
%% Setup CIC and the stimuli.
c = myRig;
c.screen.colorMode = 'RGB'; % Allow specification of RGB luminance as color
c.screen.color.text = [30 0 0];  % A red text 
c.screen.color.background = [30 30 30]; % A high luminance background that looks "white" (same luminance for each gun)
c.screen.type = 'GENERIC';
c.trialDuration = 1000;
c.iti           = 150;
c.paradigm      = 'lumDemo';
c.subjectNr      =  0;

% Convpoly to create the target patch
ptch = stimuli.convPoly(c,'patch');
ptch.radius       = 5;
ptch.X            = 0;
ptch.Y            = 0;
ptch.nSides       = 10;
ptch.filled       = true;
ptch.color        = 0;
ptch.on           = 0;



%% Define conditions and blocks
lm =design('lum');
% In this block we want to vary the "luminanc" of a grey patch across trials.
lum = (0.0:0.25:1);
lm.fac1.patch.color = lum; 

% Sequence through luminance three times
lmBlck = flow(c,'randomization','sequential','nrRepeats',3,...
                    'beforeMessage','Press any Key to start the luminance block',...
                    'beforeKeyPress', true);
lmBlck.addTrials(lm); % Add the trials from this design to the block.

gr =design('greenred');
% In this block we ramp the luminance of the red gun up from 0.5 to 30, and
% the luminance of the green gun down from 30 to 0.5. So this should look
% like a patch that is first green and then turns more red over time.
gr.fac1.patch.color = num2cell([lum' fliplr(lum)' zeros(numel(lum),1)],2) ;
% We'll sequence through this once, bu add some more complex block
% messages.
grBlck = flow(c,'randomization','sequential','nrRepeats',1,...
                    'beforeMessage', @(c)(['Patch radius is : ' num2str(c.patch.radius)]),... % This shows how you can access parm values 
                    'beforeKeyPress', true,...
                    'afterFunction',@(c) ( disp(['Subject: ' c.subject '. Done at ' num2str(datestr(now,'HH:MM:SS'))])),...% Using a matlab anonymous function works too. c is a pointer to cic.
                    'afterKeyPress',false);
grBlck.addTrials(gr);
%% Run the demo
% Each of the blocks will be run twice, in psuedo random order.
c.run(lmBlck,grBlck,'randomization','RANDOMWITHOUTREPLACEMENT','nrRepeats',2);
