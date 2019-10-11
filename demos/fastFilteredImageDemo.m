function fastFilteredImageDemo

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.trialDuration = 3000;
c.saveEveryN = Inf;

%% ============== Add stimuli ==================
im=neurostim.stimuli.fastfilteredimage(c,'filtIm');
im.frameInterval = 10;
im.imageDomain = 'FREQUENCY';
im.size = [1024,1024];
im.width = 20;%im.size(1)./c.screen.xpixels*c.screen.width;
im.height = im.width*im.size(1)/im.size(2);
maskSD = 0.05;
im.mask = ifftshift(normpdf(linspace(-1,1,im.size(1)),0,maskSD)'.*normpdf(linspace(-1,1,im.size(2)),0,maskSD));
im.maskIsStatic = true;

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.filtIm.X= 0;             %Three different fixation positions along horizontal meridian

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1000;

%% Run the experiment.
c.subject = 'easyD';
c.run(myBlock);
