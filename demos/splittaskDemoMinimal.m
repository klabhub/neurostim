function splittaskDemoMinimal
%Demo experiment using splittaskacrossframes.
%Sometimes we need more than one frame to compute the next image in a
%stimulus (e.g. updating every pixel in a display with random noise).
%Calling rand(1024,1024), for example, takes over 10 ms on most machines.
%This demo shows an example of using the splittaskstimulus class to
%distribute the computational load of preparing the next image (which often
%includes more than one costly task) across frames, and optimize the tasks
%to eliminate frame drops. The visible image is updated every N frames.
%In this demo, the splittaskdemochild stimulus class is just computing a
%bunch of random numbers. See that class to see what it does.
%Nothing is actually shown on the screen in this demo.
%
%See splittaskdemochild and splittasksacrossframes
import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.trialDuration = 3000;
c.saveEveryN = Inf;

%% ============== Add stimuli ==================
im=neurostim.stimuli.splittaskdemochild(c,'costlyTasks');
im.bigFrameInterval = 60;

%Task load optimisation
im.learningRate = im.learningRate/3; %The best learning rate is unique to a rig and experiment plan. Some trial and error required.  
im.loadByFrame = [];    %You can replace this with the values returned from the optimisation after exiting experiment. For me, they were [0.70482     0.68889     0.47981     0.70907      0.7073     0.71013]; 
im.optimise = true;    %Set to false if using hard-coded values in line above.
im.showReport = true;  %Set to false to switch off the optimisation figure

%Specify experimental conditions
myDesign=design('myFac');                      %Type "help neurostim/design" for more options.
myDesign.fac1.costlyTasks.X= 0;             %Three different fixation positions along horizontal meridian

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1000;

%% Run the experiment.
c.subject = 'easyD';
c.run(myBlock);
