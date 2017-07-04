function c=testForFunctionProps
%This used to be a test for how long function properties would take to
%evaluate. Now it is a test-bed for implementation of str2fun, as well as
%block.beforeFunction etc.

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;

%% ============== Add stimuli ==================
%Fixation dot
f=stimuli.fixation(c,'fix');    %Add a fixation stimulus object (named "fix") to the cic. It is born with default values for all parameters.
f.shape = 'CIRC';               %The seemingly local variable "f" is actually a handle to the stimulus in CIC, so can alter the internal stimulus by modifying "f".               
f.size = 0.25;
f.color = [1 0 0];
f.on=0;                         %What time should the stimulus come on? (all times are in ms)
f.duration = Inf;               %How long should it be displayed?

%Random dot pattern
d = stimuli.rdp(c,'dots');      %Add a random dot pattern.
d.X = '@dots.Y+dots.deleteMe';                 %Parameters can be set to arbitrary, dynamic functions using this string format. To refer to other stimuli/plugins, use their name (here "fix" is the fixation point).
d.Y = 0;                        %Here, wherever the fixation point goes, so too will the dots, even if it changes in real-time.       
d.on = 0;     %Motion appears 500ms after the subject begins fixating (see behavior section below). 
d.duration = 100000;
d.color = [1 1 1];
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;


%% Experimental design
c.trialDuration = d.duration;       %End the trial as soon as the 2AFC response is made.

%Specify experimental conditions
myDesign=design('myFac');                       %Type "help neurostim/design" for more options.
myDesign.fac1.dots.direction=[-90 90];         %Two dot directions

%Specify a block of trials
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=10;
myBlock.beforeMessage = @(c) num2str(c.dots.X);

%% Run the experiment.
c.order('dots');   %Ignore this for now - we hope to remove the need for this.
c.subject = 'easyD';

profile on;
c.run(myBlock);
profile off;
rep = profile('info');

this = arrayfun(@(x) strcmpi(x.FunctionName,'parameter>parameter.getValue'),rep.FunctionTable);
results = rep.FunctionTable(this);
disp(['Calls: ' num2str(results.NumCalls) ' - Time per call = ', num2str(results.TotalTime./results.NumCalls*1000), 'ms']);

this = arrayfun(@(x) strcmpi(x.FunctionName,'parameter>parameter.getFunValue'),rep.FunctionTable);
if any(this)
results = rep.FunctionTable(this);
disp(['Calls: ' num2str(results.NumCalls) ' - Time per call = ', num2str(results.TotalTime./results.NumCalls*1000), 'ms']);
end
keyboard
    
