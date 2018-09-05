function logLatencyTestScript
    % Calculates the delay from setting a parameter to the time at which it
    % is logged.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

lat = plugins.logLatencyTest(c,'latTest'); 

%% ============== Add stimuli ==================
%Random dot pattern
d = stimuli.rdp(c,'dots');     
d.X =0;      
d.Y = 0;              
d.on = 2500;     
d.duration = Inf;
d.maxRadius = 5;

%% Experimental design
c.trialDuration = 5000;
c.iti = 2000;

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.dots.X=   [-10 0 10];             %Three different fixation positions along horizontal meridian

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=100;

%% Run the experiment.
c.order('dots');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';
c.run(myBlock);

results(lat);
