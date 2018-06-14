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
lm.randomization  ='sequential'; % Sequence through luminance. Press 'n' to go to the next.
lmBlck=block('lmBlock',lm);
lmBlck.nrRepeats  = 1;
lmBlck.beforeMessage = 'Press any Key to start the luminance block';
lmBlck.beforeKeyPress = true;  % Subject must press key to continue 


gr =design('greenred');
% In this block we ramp the luminance of the red gun up from 0.5 to 30, and
% the luminance of the green gun down from 30 to 0.5. So this should look
% like a patch that is first green and then turns more red over time.
gr.fac1.patch.color = num2cell([lum' fliplr(lum)' zeros(numel(lum),1)],2) ;
gr.randomization  ='sequential'; % Sequence through luminance. Press 'n' to go to the next.
grBlck=block('lmBlock',gr);
grBlck.nrRepeats  = 1;
grBlck.beforeMessage = '@[''Patch radius is : '' num2str(patch.radius)]'; % This shows how to use a Neurostim function as the message (the function should return a string).
grBlck.beforeKeyPress = true; 
grBlck.afterFunction = @(c) ( disp(['Subject: ' c.subject '. Done at ' num2str(datestr(now,'HH:MM:SS'))])); % Using a matlab anonymous function works too. c is a pointer to cic.
grBlck.afterKeyPress = false; % No waiting

%% Run the demo
c.run(lmBlck,grBlck);
