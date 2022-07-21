function intanDemo
%% Intan Demo
%
% This demo shows how to use the Intan plugin to stimulate and record ephys
% data
%
% 2022 - 07 - 21 - Tim Allison-Walker

import neurostim.*
commandwindow;

%% ========= Specify rig configuration  =========

%Create a Command and Intelligence Centre object (the central controller for everything). Here a cic is returned with some default settings for this computer, if it is recognized.
c = myRig;
c.addPropsToInform('estim1.fpa'); % Show this value on the command prompt after each trial (i.e. whether the answer was correct and whether fixation was successful).
c.addPropsToInform('estim1.chn');
c.addPropsToInform('estim2.fpa');
c.addPropsToInform('estim2.chn');

%% ========== Add Intan plugin ================
% Add the Intan plugin
i = neurostim.plugins.intan(c,'intan');
i.testMode = 1;                             % Disable stimulation and recording while testing
i.cfgFcn = @() channel_map_function;        % (Optional) Provide an anonymous function that returns the channel mapping
i.cfgFile = path_to_channel_map_file;       % (Optional) Provide a path to a file that contains the channel mapping
i.settingsFcn = @() settings_function;      % (Optional) Provide an anonymous function that returns a path to the .isf Intan settings file on the acquisition machine
i.settingsFile = path_to_settings_file;     % (Optional) Provide a path to the .isf Intan settings file on the acquisition machine
i.saveDir = path_to_output_directory;       % (Optional) Provide a base path for saved Intan data. Defaults to 'C:\Data';

%% ========== Add electrical stimuli ==========
p = stimuli.estim(c,'estim1');
p.on = 500;                     % Stimulation ON time relative to start of trial (ms)
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
p2.on = 1000;                    % Stimulation ON time relative to start of trial (ms)
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

%% ========== Add a MCC DAQ to control the digital line ===========
plugins.mcc(c);

%% ========== Experimental design ===========
c.trialDuration = 2000; % Trials last 2000 ms

%% ========== Specify experimental conditions ===========
myDesign=design('dummy');                      %Type "help neurostim/design" for more options.
myDesign.fac1.estim1.enabled = [1,1,1,0,0,1,1,1];
myDesign.fac1.estim1.chn = [1,1,1,1,1,1,1,1];
myDesign.fac1.estim1.fpa = [1,3,5,-1,-1,1,3,5];
myDesign.fac1.estim1.spa = [1,3,5,-1,-1,1,3,5];
myDesign.fac1.estim2.enabled = [0,0,0,0,0,1,1,1];
myDesign.fac1.estim2.chn = [2,2,2,2,2,2,2,2];
myDesign.fac1.estim2.fpa = [1,3,5,-1,-1,1,3,5];
myDesign.fac1.estim2.spa = [1,3,5,-1,-1,1,3,5];
myBlock=block('myBlock',myDesign);             %Create a block of trials using the factorial. Type "help neurostim/block" for more options.
myBlock.nrRepeats=1;

%% ========== Make sure the plugins are in the right order ===========
c.order(['mcc'],['estim1'],['estim2'],['intan']); %#ok<NBRAK>

%% ========== Run it ===========
c.run(myBlock);
end