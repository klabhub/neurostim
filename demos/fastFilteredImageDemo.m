function fastFilteredImageDemo
%Demo of fast filtered noise and automatic re-distribution of computation
%across frames to avoid frame drops. Here, we show low-pass filtered noise,
%updated with new noise values every N-frames. All costly calcluations
%(e.g. inverse Fourier transform) are performed on the GPU using Matlab's
%gouArray class. This requires a modern nVidia card with up to date
%drivers, and the Parallel Computing Toolbox.
%
%Frame drops are possible/expected for first few frames, as it learns how
%to distribute the load of computing images across frames optimally. See
%neurostim.stimuli.fastfilteredimage and
%neurostim.stimuli.splittasksacrossframes for info on how to access and set
%this optimal load distribution so that there are no frame drops right from
%the start.
%
%The demo shows a real-time report (perhaps hidden behind stimulus window)
%of frame drops and how it is distributing the task load.
%
%Adam Morris, October, 2019

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig('cicConstructArgs',{'rngArgs',{'type','gpuCompatible'}}); %We need to use an RNG on the GPU
c.trialDuration = '@filtIm.on+filtIm.duration';
c.saveEveryN = Inf;

%% ============== Add stimuli ==================
frInterval = 1000./c.screen.frameRate;
imDuration = 100*frInterval; %Show for 100 frames
im=neurostim.stimuli.fastfilteredimage(c,'filtIm');
im.bigFrameInterval = 4*frInterval; %ms, set here to 4 frames
im.on=50*frInterval-im.bigFrameInterval; %Our image isn't actually visible until *after* the first full interval (during which time it is being computed)
im.duration = imDuration + im.bigFrameInterval; %The image isn't actually shown until trialTime = im.bigFrameInterval, because first image is being computed, so this ensure that the visible part is on for imDuration
im.imageDomain = 'FREQUENCY';
im.size = [c.screen.ypixels,c.screen.ypixels];
im.height = c.screen.height;
im.width = im.height*im.size(2)/im.size(1);
im.maskIsStatic = true;
im.statsConstant = true;
im.optimise = true;
im.learningRate = im.learningRate/4; %Best learning rate depends on many things, so some trial and error might be needed. This worked for me.
im.showReport = true;
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
