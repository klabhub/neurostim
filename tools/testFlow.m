%function testFlow
%{
Testing program flow.

%}
import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.addPropsToInform('flow.name','fix.X','fix.Y'); % Show this value on the command prompt after each trial (i.e. whether the answer was correct and whether fixation was successful).
c.subjectNr = 0;
c.trialDuration = 1000;

%%  A single stimulus
f=stimuli.fixation(c,'fix');    %Add a fixation stimulus object (named "fix") to the cic. It is born with default values for all parameters.
f.shape = 'CIRC';               %The seemingly local variable "f" is actually a handle to the stimulus in CIC, so can alter the internal stimulus by modifying "f".               
f.size = 0.25;
f.color = [1 0 0];
f.on= 0;                         %What time should the stimulus come on? (all times are in ms)
f.duration = Inf;               %How long should it be displayed?
f.X= 0;
f.Y =0;
%% 

%Specify experimental conditions
varyX=design('X');       
varyX.fac1.fix.X=   [-10 0 10]; %Three positions along horizontal meridian

varyY=design('Y');       
varyY.fac1.fix.Y=   [-10 0 10]; %Three positions along vertical meridian


%Specify a block of trials
blk=neurostim.flow(c);
blk.addTrials(varyX);
blk.addTrials(varyY);
blk.randomization = 'RANDOMWITHOUTREPLACEMENT';
root = neurostim.flow(c);
root.addBlock(blk);
root.addBlock(blk,'nrRepeats',2)


root = neurostim.flow(c);
h = root.addBlock([],'name','first');
h = h.addBlock([],'name','second','nrRepeats',2);
h.addBlock(blck,'name','third')
c.run(blk);
    
