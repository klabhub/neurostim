function egiDemo
% Demonstrate use of EGI plugin
% 
import neurostim.*

%% ========= Specify rig configuration  =========
%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.trialDuration = 1500;
c.subjectNr  =0;

%% ============== Add Recording ==================
e =  plugins.egi(c);           % Use the egi plugin
e.clockOffset = 13.5; % Adjust the EGI clock by this much (see tools/egiAvTester how to estimate this for your setup)

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
d.X = 0;                 
d.Y = 0;                 
d.on =   plugins.jitter(c,{500,250},'distribution','normal','bounds',[0 400]); % Turn on at random times
d.duration = 1000;
d.color = [1 1 1];
d.size = 2;
d.nrDots = 200;
d.maxRadius = 5;
d.lifetime = Inf;
d.noiseMode = 1;
d.onsetFunction = @neurostim.plugins.egi.logOnset; % Tell the stimulus to send an event to EGI Netstation everytime it starts.
                                            % This event will be useful in
                                            % the analysis.
%Specify experimental conditions
myFac=design('myFactorial');           %Using a 3 x 2 factorial design.  Type "help neurostim/factorial" for more options.
myFac.fac1.fix.X={-10 0 10};                %Three different fixation positions along horizontal meridian
myFac.fac2.dots.direction={-90 90};         %Two dot directions
myFac.conditions(:).fix.Y = plugins.jitter(c,{0,4},'distribution','normal','bounds',[-5 5]);   %Vary Y-coord randomly from trial to trial (truncated Gaussian)

%Specify a block of trials
myBlock=block('myBlock',myFac);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1;

%% Run the experiment.
c.run(myBlock);
    
