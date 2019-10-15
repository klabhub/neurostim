function fastFilteredImageDemo

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.trialDuration = 1000;
c.saveEveryN = Inf;

%% ============== Add stimuli ==================
im=neurostim.stimuli.fastfilteredimage(c,'filtIm');
im.bigFrameInterval = 2;
im.imageDomain = 'FREQUENCY';
im.size = [1024,1024];
im.width = im.size(1)./c.screen.xpixels*c.screen.width;
im.height = im.width*im.size(1)/im.size(2);
im.maskIsStatic = true;
im.statsConstant = true;
im.optimise = true;
im.showReport = false;
%im.mask = gaussLowPassMask(im,24);
im.mask = annulusMask(im,'plot',false);

% myIm = ones(im.size);
% myIm = complex(myIm);
% im.image=gpuArray(myIm);

% m=zeros(im.size);
% f1 = round(im.size/2+0.5+10);
% f2 = round(im.size/2+0.5-10);
% m(f1,f1) = 1;
% m(f2,f2) = 1;
% im.mask=gpuArray(ifftshift(m));

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.filtIm.X= 0;             %Three different fixation positions along horizontal meridian

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1000;

%% Run the experiment.
c.subject = 'easyD';
c.run(myBlock);
