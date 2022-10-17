function saccadeIntanDemo(varargin)
% Show how to implement a simple task where the subject has to fixate one
% point and then saccade to a second. Implements an Intan plugin to allow
% electrical stimulation
%
%   This demo shows how to use:
%       - Behavioral control
%       - Electrical stimulation
%
%   The task:
%
%       (1) "Fixate" on the fixation point to start the trial by clicking on it with the mouse
%       (2) Fixate the new target once it appears.
%
%   *********** Press "Esc" twice to exit a running experiment ************

p = inputParser;
p.KeepUnmatched = true;
p.addParameter('bit',1,@(x) validateattributes(x,{'numeric'},{'nonempty','scalar','>=',1,'<=',8}));

p.parse(varargin{:});

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.addPropsToInform('saccade.stateName'); % Show this value on the command prompt after each trial (i.e. whether the answer was correct and whether fixation was successful).

%Make sure there is an eye tracker (or at least a virtual one)
if isempty(c.pluginsByClass('eyetracker'))
    e = neurostim.plugins.eyetracker(c);      %Eye tracker plugin not yet added, so use the virtual one. Mouse is used to control gaze position (click)
    e.useMouse = true;
end

%% ============== Add stimuli ==================

%Fixation dot
f=stimuli.fixation(c,'fix');    %Add a fixation stimulus object (named "fix") to the cic. It is born with default values for all parameters.
f.shape = 'CIRC';               %The seemingly local variable "f" is actually a handle to the stimulus in CIC, so can alter the internal stimulus by modifying "f".               
f.size = 0.25;
f.color = [1 0 0];
f.on=0;                         %What time should the stimulus come on? (all times are in ms)
f.duration = 3000;              %How long should it be displayed?

t = duplicate(f,'target');      % make a duplicate, called target.
t.X = NaN;                      % Will be varied in the factorial design, below.
t.on = '@fix.on + fix.duration';  % Use a function to turn on when target turns off

%% ========== Add Intan plugin ================
% Add the Intan plugin
i = neurostim.plugins.intan(c);
i.testMode = 0; % Disable stimulation and recording while testing
i.mapPath = 'C:\Users\localadmin\Documents\git\EPhysLabSoftware\Experimental Design\Constants\NN-Mapping-ISeries.mat';
i.mcs = 1;      % Enable (1) or disable (0) stimulation on multiple channels simultaneously

%% ========== Add electrical stimuli ==========
p = stimuli.estim(c,'estim');
p.recDir = 'C:\Users\localadmin\Desktop\Data\BehaviourTest\estim_pen1';
p.on = '@target.on';            % Stimulation ON time relative to start of trial (ms)
p.duration = 1000;              % Stimulation duration relative to ON time (ms)
p.enabled = NaN;                % Enables (1) or disables (0) stimulation
p.chn = NaN;                    % Stimulation channel(s)                    % Will be varied below
p.fpa = NaN;                    % Stimulation first phase amplitude (uA)    % Will be varied below
p.spa = NaN;                    % Stimulation second phase amplitude (uA)   % Will be varied below
p.fpd = 200;                    % Stimulation first phase duration (us)
p.spd = 200;                    % Stimulation second phase duration (us)
p.ipi = 100;                    % Inter-phase interval (us)
p.pot = 1;                      % Single pulse (0) or train (1) % Will override any other pulse train parameters
p.nod = 1;                      % Specify number of stimulation pulses (1) or total duration of pulse train (2)
p.nsp = 10;                     % Number of stimulation pulses % Max 99
p.pod = 200000;                 % Duration of stimulation pulses (us) % Max 99 pulses
p.fre = 200;                    % Frequency of stimulation (Hz)
p.ptr = 1e6;                    % Post-pulse-train refractory period
p.prAS = 200;                   % Pre-stimulus amp settle START (us, relative to stimulation)
p.poAS = 160000;                % Post-stimulus amp settle END (us, relative to stimulation)
p.prCR = 100000;                % Post-stimulus charge recovery START (us, relative to stimulation)
p.poCR = 150000;                % Post-stimulus charge recovery END (us, relative to stimulation)
p.stSH = 1;                     % Stimulus pulse shape. 1 = biphasic charge balanced
p.enAS = 1;                     % Enable (1) or disable (0) amp settle
p.maAS = 1;                     % Maintain (1) or end (0) amp settle throughout stimulus pulse trains
p.enCR = 1;                     % Enable (1) or disable (0) charge recovery
p.port = 'A';                   % The port Intan uses to communicate to the headstage. Only used by Intan

%% ========== Add a second estimulus plugin ==========
p2 = stimuli.estim(c,'estim2');
p2.recDir = 'C:\Users\localadmin\Desktop\Data\BehaviourTest\estim_pen1';
p2.on = '@fix.on';               % Stimulation ON time relative to start of trial (ms)
p2.duration = 1000;              % Stimulation duration relative to ON time (ms)
p2.enabled = NaN;                % Enables (1) or disables (0) stimulation
p2.chn = NaN;                    % Stimulation channel(s)                    % Will be varied below
p2.fpa = NaN;                    % Stimulation first phase amplitude (uA)    % Will be varied below
p2.spa = NaN;                    % Stimulation second phase amplitude (uA)   % Will be varied below
p2.fpd = 200;                    % Stimulation first phase duration (us)
p2.spd = 200;                    % Stimulation second phase duration (us)
p2.ipi = 100;                    % Inter-phase interval (us)
p2.pot = 1;                      % Single pulse (0) or train (1) % Will override any other pulse train parameters
p2.nod = 1;                      % Specify number of stimulation pulses (1) or total duration of pulse train (2)
p2.nsp = 10;                     % Number of stimulation pulses % Max 99
p2.pod = 200000;                 % Duration of stimulation pulses (us) % Max 99 pulses
p2.fre = 200;                    % Frequency of stimulation (Hz)
p2.ptr = 1e6;                    % Post-pulse-train refractory period
p2.prAS = 200;                   % Pre-stimulus amp settle START (us, relative to stimulation)
p2.poAS = 160000;                % Post-stimulus amp settle END (us, relative to stimulation)
p2.prCR = 100000;                % Post-stimulus charge recovery START (us, relative to stimulation)
p2.poCR = 150000;                % Post-stimulus charge recovery END (us, relative to stimulation)
p2.stSH = 1;                     % Stimulus pulse shape. 1 = biphasic charge balanced
p2.enAS = 1;                     % Enable (1) or disable (0) amp settle
p2.maAS = 1;                     % Maintain (1) or end (0) amp settle throughout stimulus pulse trains
p2.enCR = 1;                     % Enable (1) or disable (0) charge recovery
p2.port = 'A';                   % The port Intan uses to communicate to the headstage. Only used by Intan

%% ========== Add required behaviours =========
g = behaviors.saccade(c,'saccade');
g.X = '@fix.X';
g.Y = '@fix.Y';
g.from = 2000;       % If fixation has not started at this time, move to the next trial
g.to = '@fix.stopTime'; 
g.saccadeDuration = 2000;
g.targetDuration = 1000;
g.targetX = '@target.X';
g.targetY = '@target.Y';
g.tolerance = 3;
g.failEndsTrial = true;
g.successEndsTrial  = true;

%% ========== Specify feedback/rewards ========= 
% Play a correct/incorrect sound for the 2AFC task
plugins.sound(c);           %Use the sound plugin

% Add correct/incorrect feedback
s= plugins.soundFeedback(c,'soundFeedback');
s.add('waveform','correct.wav','when','afterTrial','criterion','@saccade.isSuccess');
s.add('waveform','incorrect.wav','when','afterTrial','criterion','@saccade.isSuccess');

%% ========== Add a MCC DAQ to control the digital line ===========
plugins.mcc(c);

%% Experimental design
c.trialDuration = inf;                        % Trials are infinite, but the saccade behavior ends the trial on success or fail.

%Specify experimental conditions
myDesign=design('dummy');                      %Type "help neurostim/design" for more options.
myDesign.fac1.target.X = [-15,-15,-15,5,5,-10,-10,-10];
myDesign.fac1.estim.enabled = [1,1,1,0,0,1,1,1];
myDesign.fac1.estim.chn = [1,1,1,1,1,1,1,1];
myDesign.fac1.estim.fpa = [1,3,5,-1,-1,1,3,5];
myDesign.fac1.estim.spa = [1,3,5,-1,-1,1,3,5];
myDesign.fac1.estim2.enabled = [0,0,0,0,0,1,1,1];
myDesign.fac1.estim2.chn = [2,2,2,2,2,2,2,2];
myDesign.fac1.estim2.fpa = [1,3,5,-1,-1,1,3,5];
myDesign.fac1.estim2.spa = [1,3,5,-1,-1,1,3,5];
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1;
%% Make sure the plugins are in the right order
c.setPluginOrder(['eye'],['saccade'],['sound'],['soundFeedback'],['mcc'],['fix'],['target'],['estim'],['estim2'],['intan']); %#ok<NBRAK>
%% Run it
c.run(myBlock);    
