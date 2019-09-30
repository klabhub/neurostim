function splittaskDemoMinimal

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.trialDuration = 800;

%% ============== Add stimuli ==================
im=neurostim.stimuli.splittaskstimulus(c,'filt');
im.bigFrameInterval = 6;

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.filt.X= 0;             %Three different fixation positions along horizontal meridian

% answer will not be retried, only trials with a fixation break.

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1000;

%% Run the experiment.
c.subject = 'easyD';
c.run(myBlock);

