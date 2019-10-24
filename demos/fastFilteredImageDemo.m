function fastFilteredImageDemo
%Demo of fast filtered noise. Here, an orientation and SF mask is applied
%in Fourier space, with new noise values generated every N display frames.
%This requires a modern nVidia card with up to date drivers, and the
%Parallel Computing Toolbox. It relies on gpuArray objects.
%
%Frame drops are possible/expected for first few frames, as it learns how
%to distribute the load of computing images across frames optimally. See
%neurostim.stimuli.fastfilteredimage for info on how to access and set this
%optimal load distribution so that there are no frame drops right from the
%start.
%
%Adam Morris, October, 2019

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig('cicConstructArgs',{'rngArgs',{'type','gpuCompatible'}}); %We need to use an RNG on the GPU
c.trialDuration = '@filtIm.duration';
c.saveEveryN = Inf;

%% ============== Add stimuli ==================
imDuration = 1000;
im=neurostim.stimuli.fastfilteredimage(c,'filtIm');
im.bigFrameInterval = 50; %ms
im.duration = imDuration + im.bigFrameInterval; %The image isn't actually shown until trialTime = im.bigFrameInterval, because first image is being computed, so this ensure that the visible part is on for imDuration
im.imageDomain = 'FREQUENCY';
im.size = [1024,1024];
im.width = im.size(1)./c.screen.xpixels*c.screen.width;
im.height = im.width*im.size(1)/im.size(2);
im.maskIsStatic = true;
im.statsConstant = true;
im.optimise = true;
im.showReport = false;
im.mask = gaussLowPassMask(im,24);

%im.mask = deformedAnnulusMask(im,'plot',false);

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.filtIm.X= 0;             %Three different fixation positions along horizontal meridian

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1000;

%% Run the experiment.
c.subject = 'easyD';
c.run(myBlock);
