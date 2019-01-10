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

%First specify a (factorial) design 
varyX=design('X');       
varyX.fac1.fix.X=   [-10 0 10]; %Three positions along horizontal meridian
varyX.fac2.fix.shape = {'CIRC','STAR'}; % Combined with a second factor that varies the shape
varyX.fac2.fix.color = {[1 0 0],[0 1 0]}; % and the color

varyY=design('Y');       
varyY.fac1.fix.Y=   [-10 0 10]; %Three positions along vertical meridian


%% Specify a block of trials

% We can generate trials based on these designs and combine them in a
% single flow (block)
flw=neurostim.flow(c);  % The default flow presents trials Sequentially, once each.
flw.addTrials(varyX);
flw.addTrials(varyY);

% To just run each of the conditions once, sequentially:
%c.run(flw);  % Run the flow

% Now lets randomize all of the conditions
flw.randomization = 'RANDOMWITHOUTREPLACEMENT';
%c.run(flw);

% To run the X and Y designs in separate blocks:
% Create the flows/blocks
x = neurostim.flow(c,'name','X','randomization','RANDOMWITHOUTREPLACEMENT'); % Conditions within the block are randomized
x.addTrials(varyX);
y = neurostim.flow(c,'name','Y','randomization','RANDOMWITHOUTREPLACEMENT','nrRepeats',2);  %  The y-design is randomized and each condition is shown twice
y.addTrials(varyY);
% Then combine in them one top flow
flw=neurostim.flow(c);  % The default flow presents trials Sequentially, once each.
flw.addBlock(x);  % Run the x-block first
flw.addBlock(y);  
c.run(flw);