function splittaskDemo

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.trialDuration = 5000;
c.saveEveryN = Inf;

%% ============== Add stimuli ==================
im=neurostim.stimuli.fourierFiltImage(c,'filt');

im.bigFrameInterval = 12;
im.imageDomain = 'FREQUENCY';
im.size = [950,950];
%im.size = floor(im.size/60)*60; %Size should be a multiple of the frame rate.
maskSD = 0.125;
im.mask = ifftshift(normpdf(linspace(-1,1,im.size(1)),0,maskSD)'.*normpdf(linspace(-1,1,im.size(2)),0,maskSD));
im.maskIsStatic = true;
im.width = 20;
im.height = im.width*im.size(1)/im.size(2);
    
checkFFT = false;
if checkFFT
    im.imageDomain = 'SPACE';
    pic = double(rgb2gray(imresize(imread('car1.jpg'),im.size)));
    pic=(pic-min(pic(:)))./(max(pic(:))-min(pic(:)));
    im.image = pic;
    im.imageIsStatic = true;
    
    figure
    subplot(2,1,1);
    imagesc(im.image); colormap('gray');
    
    subplot(2,1,2);
    filtImage_freq = fft2(im.image).*im.mask;
    filtImage = ifft2(filtImage_freq,'symmetric');
    imagesc(filtImage); colormap('gray');
    im.addProperty('comparisonImage',filtImage);
    
    %Check piece wise inverse fft
    filtImage = ifft2(filtImage_freq);
    filtImageSym = ifft2(filtImage_freq,'symmetric');
    filtImage2 = ifft(ifft(filtImage_freq).').';
    filtImage3 = ifft(ifft(filtImage_freq).','symmetric').';
    
    
    figure;
    a=filtImageSym;
    b=filtImage3;
    subplot(1,3,1);
    imagesc(a); colormap('gray'); colorbar;
    subplot(1,3,2);
    imagesc(b);colormap('gray');colorbar;
    subplot(1,3,3);
    imagesc(a-b);colormap('gray');colorbar;
end

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

