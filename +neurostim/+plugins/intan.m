classdef intan < neurostim.plugins.ePhys
    % Plugin for interfacing with the Intan GUI via tcp/ip
    % Example usage:
    % o = neurostim.plugins.intan(c,'intan',[RecDir].[SettingsFile]);
    % Optional parameters may be specified via name-value pairs:
    % RecDir - Directory used for saving Intan generated datafiles
    % SettingsFile - .isf Intan settings file for a specific electrode
    % configuration

    %% The Intan plugin has now been updated to work with our custom build of the Intan RHX v3.1 software

    %% -- deprecated -- for Intan versions below 3.1.0 %%
    % Here's a list of commands Intan will recognise
    % 'channel=A-001' % Initialises a new parameter set
    % 'SET' % Commands Intan to program the headstage with new
    % parameters
    % ======= !!IMPORTANT!! ========
    % Every call to 'SET' costs ~200 ms and necessitates a handshake
    % between Intan and MATLAB to prevent desynchronisation
    % Avoid excess 'SET' calls wherever possible
    % 'HELLO' % Returns 'How are you?'
    % 'RUOK' % Flushes the socket and returns 'YEAH'. Checks for
    % TCP/IP response, maintains synchronisation between sockets
    % 'RUN' % Starts the Intan GUI running - this will not save
    % data
    % 'RECORD' % Starts the Intan GUI running - this will save data
    % to the given filepath
    % 'STOP' % Stops the Intan GUI running
    % 'OPENSTIM' % Opens the selected stim parameters dialog window. Used
    % for setting amp settle options
    % 'CLOSESTIM' % Closes the stim parameters dialog window
    % 'RECOVER' % Returns 'PHEW'. Used for clearing the sockets on
    % both ends of the connection.
    % 'MCS' % Enables multi-channel stimulation. Be extremely
    % careful with parameter sets.
    % 'NOMCS' % Disables multi-channel stimulation. Default
    % 'DALL' % Clears all stimulation parameters on all channels.
    % 'CHANGEFRAME=1' % Changes the selected frame for OPENSTIM
    % 'SETSAVEPATH' % Sets the filepath used for saving data
    % 'LOADSETTINGS' % Loads an on-disk settings file

    properties
        testMode = 0;       % Flag for test mode. Disables TCP communications and stim for rapid stimulus testing
        estimulus = {};     % Contains a pointer to the active estim plugin
        activechns = {};    % Contains a list of active stimulation channels
        chns = {};          % Contains a list of stimulation parameters for all channels
        tcpSocket = [];     % Contains a TCP socket for communication with Intan
        clearComms = true;  % Flag for clearing communications after the experiment
        handshake = 0;      % Controls whether the Intan manager plugin will halt execution of the thread while awaiting
        % a handshake from the Intan firmware over the
        % TCP connection. !!Important!!
        cfgFcn = [];        % Can be given an anonymous function that specifies the channel mapping. Overrides other channel mapping sources
        cfgFile = [];       % Can be given a filepath that contains the channel mapping.
        chnMap = [];        % Stores the channel mapping
        settingsFcn = [];   % Can be given an anonymous function that specifies the Intan settings file. Overrides other channel mapping sources
        settingsPath = [];  % Can be given a filepath that contains the Intan settings file.
        settingsStruct = [];% Can contain a list of settings to apply to Intan. Automatically populated with default values.
        settingsFile = [];  % Contains the Intan settings file path.
        applySettings = false;% Flag for applying settings to Intan.
        chnList = [];       % Used to pass a list of channels for amplifier settle configuration
        numChannels = 0;    % The number of active channels in Intan
        ports = [];         % List of enabled Intan ports
        saveDir = '';       % Intan acquisition directory
        intanVer = 3.1;     % The Intan acqusition software version
        iFormat = 'single'; % Default format for Intan operation. single: 'pause' between trials or trials: 'stop' between trials
        sFormat = 'OneFilePerChannel'; % Contains Intan save format - one file per signal (amplifier.dat, time.dat) or per channel (amp-001.dat, amp-002.dat)
    end

    methods (Access=public)
        %% Constructor
        function o = intan(c,name,varargin)
            % Intan does not have any dependencies on the host computer
            % Parse arguments
            pin = inputParser;
            pin.KeepUnmatched = true;
            pin.addParameter('testMode', 0, @isnumeric); % Test mode that disables stimulation and recording
            pin.addParameter('saveDir','C:\Data',@ischar); % Contains the saveDir string associated with the current recording
            pin.addParameter('hostPort',5000, @isnumeric); % The port Intan will use to communicate with neurostim            
            pin.parse(varargin{:});
            args = pin.Results;
            % Call parent class constructor
            o = o@neurostim.plugins.ePhys(c,name,pin.Unmatched);

            % Initialise class properties
            o.addProperty('isRecording',false);
            o.addProperty('loggedEstim',[],'validate',@iscell);
            o.addProperty('hostPort',args.hostPort);

            % Update properties
            o.testMode = args.testMode;
            o.saveDir = args.saveDir;            
        end

        %% Generic Communcation
        function sendMessage(o,msg)
            % Send a message to Intan
            if ~iscell(msg)
                msg = {msg};
            end
            if o.intanVer >= 3.1
                for ii = 1:numel(msg)
                    try
                        writeline(o.tcpSocket,msg{ii});
                        pause(0.05);
                    catch % older matlab?
                        fprintf(o.tcpSocket,msg{ii});
                        pause(0.05);
                    end
                end
            else
                for ii = 1:numel(msg)
                    try
                        writeline(o.tcpSocket,msg{ii});
                        pause(0.01);
                    catch % older matlab?
                        fprintf(o.tcpSocket,msg{ii});
                        pause(0.01);
                    end
                end
            end
        end
        function msg = readMessage(o)
            % Read a message from Intan
            if o.intanVer >= 3.1
                try msg = char(read(o.tcpSocket));
                catch % older matlab?
                    msg = fscanf(o.tcpSocket);
                end
            else
                try
                    msg = readline(o.tcpSocket);
                catch % older matlab?
                    msg = fscanf(o.tcpSocket);
                end
                msg = string(msg(1:end-1));
            end
        end

        %% Neurostim Events
        function beforeExperiment(o)
            % Create a tcp/ip socket
            o.createTCPobject;
            if ~o.intanVer >= 3.1
                msg = o.readMessage;
                if ~strcmp(msg,"READY")
                    disp('ERROR. BAD CONNECTION.')
                end
                flushinput(o.tcpSocket)
            end
            % Grab the channel mapping
            o.chnMap = o.loadIntanChannelMap;
            % Create port mapping
            if o.intanVer >= 3.1
                o.portMapping;
            end
            % Tell Intan to stop running
            o.sendMessage('set runmode stop;');
            % Send the settings file to Intan
            if o.applySettings
                o.setSettings();
            end
            % Send default stimulation settings to Intan
            %o.setDefaultStim(); %% TODO
            % Set the save path in Intan
            o.setSavePath();
            % Configure old Intan for amplifier settling
            if o.intanVer < 3.1
                o.ampSettle();
            end
            % Start recording
            o.startRecording();
        end

        function beforeTrial(o)
            if o.intanVer < 3.1
                if ~isempty(o.activechns)
                    marker = ones(1,numel(o.activechns));
                    for ii = 1:numel(o.estimulus)
                        thisChn = getIntanChannel(o,'index',ii);
                        for jj = 1:numel(o.activechns)
                            if strcmp(o.activechns{jj},thisChn)
                                marker(jj) = 0;
                            end
                        end
                    end
                    kk = find(marker == 1,1,'last');
                    msg = {};
                    for jj = 1:numel(o.activechns)
                        if marker(jj) % Disable all channels not used in the coming trial
                            msg{1} = strcat('channel=',o.activechns{jj});
                            msg{2} = 'enabled=0';
                            o.sendMessage(msg);
                            if jj == kk
                                o.sendSet();
                                o.handshake = 1;
                                o.checkTCPOK;
                            end
                        end
                    end
                    o.activechns = {};
                end
            end
            % Log o.estimulus
            o.loggedEstim = o.estimulus;
            o.setupIntan();
        end
        function afterTrial(o)
            o.estimulus = {};
        end
        function afterExperiment(o)
            o.stopRecording();
        end

        %% Setup Intan Firmware
        function setupIntan(o)
            if o.intanVer >= 3.1
                msg = {};
                for jj = 1:numel(o.activechns)
                    msg{end+1} = ['set ' o.activechns{jj} '.StimEnabled False;'];
                end
                for ii = 1:numel(o.estimulus)
                    thisChn = o.getIntanChannel('index',ii);
                    switch o.estimulus{ii}.pot
                        case 0
                            if o.estimulus{ii}.pot ~= o.chns{o.estimulus{ii}.chn}.pot
                                msg{end+1} = ['set ' thisChn '.PulseOrTrain SinglePulse;']; %#ok<*AGROW>
                                msg{end+1} = ['set ' thisChn '.NumberOfStimPulses 1;'];
                            end
                        case 1
                            if o.estimulus{ii}.pot ~= o.chns{o.estimulus{ii}.chn}.pot
                                msg{end+1} = ['set ' thisChn '.PulseOrTrain PulseTrain;'];
                            end
                            if o.estimulus{ii}.nod == 1 && o.estimulus{ii}.nod ~= o.chns{o.estimulus{ii}.chn}.nod
                                msg{end+1} = ['set ' thisChn '.NumberOfStimPulses ' num2str(o.estimulus{ii}.nsp) ';'];
                            elseif o.estimulus{ii}.nod == 2 && o.estimulus{ii}.nod ~= o.chns{o.estimulus{ii}.chn}.nod
                                nsp = floor((o.estimulus{ii}.pod / 1e6) * o.estimulus{ii}.fre);
                                if nsp > 256
                                    nsp = 256;
                                end
                                msg{end+1} = ['set ' thisChn '.numberOfStimPulses ' num2str(nsp) ';'];
                            end
                    end
                    o.chns{o.estimulus{ii}.chn}.pot = o.estimulus{ii}.pot;
                    o.chns{o.estimulus{ii}.chn}.nod = o.estimulus{ii}.nod;
                    if o.estimulus{ii}.fre ~= o.chns{o.estimulus{ii}.chn}.fre
                        o.chns{o.estimulus{ii}.chn}.fre = o.estimulus{ii}.fre;
                        msg{end+1} = ['set ' thisChn '.PulseTrainPeriodMicroseconds ' num2str((1e6/o.estimulus{ii}.fre)) ';'];
                    end
                    if o.estimulus{ii}.ptr ~= o.chns{o.estimulus{ii}.chn}.ptr
                        o.chns{o.estimulus{ii}.chn}.ptr = o.estimulus{ii}.ptr;
                        msg{end+1} = ['set ' thisChn '.RefractoryPeriodMicroseconds ' num2str(o.estimulus{ii}.ptr) ';'];
                    end
                    if o.estimulus{ii}.fpd ~= o.chns{o.estimulus{ii}.chn}.fpd
                        o.chns{o.estimulus{ii}.chn}.fpd = o.estimulus{ii}.fpd;
                        msg{end+1} = ['set ' thisChn '.FirstPhaseDurationMicroseconds ' num2str(o.estimulus{ii}.fpd) ';'];
                    end
                    if o.estimulus{ii}.spd ~= o.chns{o.estimulus{ii}.chn}.spd
                        o.chns{o.estimulus{ii}.chn}.spd = o.estimulus{ii}.spd;
                        msg{end+1} = ['set ' thisChn '.SecondPhaseDurationMicroseconds ' num2str(o.estimulus{ii}.spd) ';'];
                    end
                    if o.estimulus{ii}.ipi ~= o.chns{o.estimulus{ii}.chn}.ipi
                        o.chns{o.estimulus{ii}.chn}.ipi = o.estimulus{ii}.ipi;
                        msg{end+1} = ['set ' thisChn '.InterphaseDelayMicroseconds ' num2str(o.estimulus{ii}.ipi) ';'];
                    end
                    if o.estimulus{ii}.fpa ~= o.chns{o.estimulus{ii}.chn}.fpa
                        o.chns{o.estimulus{ii}.chn}.fpa = o.estimulus{ii}.fpa;
                        msg{end+1} = ['set ' thisChn '.FirstPhaseAmplitudeMicroAmps ' num2str(o.estimulus{ii}.fpa) ';'];
                    end
                    if o.estimulus{ii}.spa ~= o.chns{o.estimulus{ii}.chn}.spa
                        o.chns{o.estimulus{ii}.chn}.spa = o.estimulus{ii}.spa;
                        msg{end+1} = ['set ' thisChn '.SecondPhaseAmplitudeMicroAmps ' num2str(o.estimulus{ii}.spa) ';'];
                    end
                    if o.estimulus{ii}.prAS ~= o.chns{o.estimulus{ii}.chn}.prAS
                        o.chns{o.estimulus{ii}.chn}.prAS = o.estimulus{ii}.prAS;
                        msg{end+1} = ['set ' thisChn '.PostTriggerDelayMicroseconds ' num2str(o.estimulus{ii}.prAS+10) ';'];
                        msg{end+1} = ['set ' thisChn '.PreStimAmpSettleMicroseconds ' num2str(o.estimulus{ii}.prAS) ';'];
                    end
                    if o.estimulus{ii}.poAS ~= o.chns{o.estimulus{ii}.chn}.poAS
                        o.chns{o.estimulus{ii}.chn}.poAS = o.estimulus{ii}.poAS;
                        msg{end+1} = ['set ' thisChn '.RefractoryPeriodMicroseconds ' num2str(o.estimulus{ii}.poAS+100) ';'];
                        msg{end+1} = ['set ' thisChn '.PostStimAmpSettleMicroseconds ' num2str(o.estimulus{ii}.poAS) ';'];
                    end
                    if o.estimulus{ii}.prCR ~= o.chns{o.estimulus{ii}.chn}.prCR
                        o.chns{o.estimulus{ii}.chn}.prCR = o.estimulus{ii}.prCR;
                        msg{end+1} = ['set ' thisChn '.PostStimChargeRecovOnMicroseconds ' num2str(o.estimulus{ii}.prCR) ';'];
                    end
                    if o.estimulus{ii}.poCR ~= o.chns{o.estimulus{ii}.chn}.poCR
                        o.chns{o.estimulus{ii}.chn}.poCR = o.estimulus{ii}.poCR;
                        msg{end+1} = ['set ' thisChn '.PostStimChargeRecovOffMicroseconds ' num2str(o.estimulus{ii}.poCR) ';'];
                    end
                    switch o.estimulus{ii}.stSH
                        case 0
                            if o.estimulus{ii}.stSH ~= o.chns{o.estimulus{ii}.chn}.stSH
                                o.chns{o.estimulus{ii}.chn}.stSH = o.estimulus{ii}.stSH;
                                msg{end+1} = ['set ' thisChn '.Shape Biphasic;'];
                            end
                        case 1
                            if o.estimulus{ii}.stSH ~= o.chns{o.estimulus{ii}.chn}.stSH
                                o.chns{o.estimulus{ii}.chn}.stSH = o.estimulus{ii}.stSH;
                                msg{end+1} = ['set ' thisChn '.Shape BiphasicWithInterphaseDelay;'];
                            end
                        case 2
                            if o.estimulus{ii}.stSH ~= o.chns{o.estimulus{ii}.chn}.stSH
                                o.chns{o.estimulus{ii}.chn}.stSH = o.estimulus{ii}.stSH;
                                msg{end+1} = ['set ' thisChn '.Shape Triphasic;'];
                            end
                    end
                    switch o.estimulus{ii}.enAS
                        case 0
                            if o.estimulus{ii}.enAS ~= o.chns{o.estimulus{ii}.chn}.enAS
                                o.chns{o.estimulus{ii}.chn}.enAS = o.estimulus{ii}.enAS;
                                msg{end+1} = ['set ' thisChn '.EnableAmpSettle False;'];
                            end
                        case 1
                            if o.estimulus{ii}.enAS ~= o.chns{o.estimulus{ii}.chn}.enAS
                                o.chns{o.estimulus{ii}.chn}.enAS = o.estimulus{ii}.enAS;
                                msg{end+1} = ['set ' thisChn '.EnableAmpSettle True;'];
                            end
                    end
                    switch o.estimulus{ii}.maAS
                        case 0
                            if o.estimulus{ii}.maAS ~= o.chns{o.estimulus{ii}.chn}.maAS
                                o.chns{o.estimulus{ii}.chn}.maAS = o.estimulus{ii}.maAS;
                                msg{end+1} = ['set ' thisChn '.MaintainAmpSettle False;'];
                            end
                        case 1
                            if o.estimulus{ii}.maAS ~= o.chns{o.estimulus{ii}.chn}.maAS
                                o.chns{o.estimulus{ii}.chn}.maAS = o.estimulus{ii}.maAS;
                                msg{end+1} = ['set ' thisChn '.MaintainAmpSettle True;'];
                            end
                    end
                    switch o.estimulus{ii}.enCR
                        case 0
                            if o.estimulus{ii}.enCR ~= o.chns{o.estimulus{ii}.chn}.enCR
                                o.chns{o.estimulus{ii}.chn}.enCR = o.estimulus{ii}.enCR;
                                msg{end+1} = ['set ' thisChn '.EnableChargeRecovery False;'];
                            end
                        case 1
                            if o.estimulus{ii}.enCR ~= o.chns{o.estimulus{ii}.chn}.enCR
                                o.chns{o.estimulus{ii}.chn}.enCR = o.estimulus{ii}.enCR;
                                msg{end+1} = ['set ' thisChn '.EnableChargeRecovery True;'];
                            end
                    end
                    switch o.estimulus{ii}.enabled
                        case 0
                            msg{end+1} = ['set ' thisChn '.StimEnabled False;'];
                        case 1
                            msg{end+1} = ['set ' thisChn '.StimEnabled True;'];
                    end
                    msg{end+1} = ['set trial ' num2str(o.cic.trial) ';'];
                    if strcmp(o.iFormat,'single')
                        o.sendMessage('set runmode pause;');
                    elseif strcmp(o.iFormat,'trial')
                        o.sendMessage('set runmode stop;');
                    end
                    o.sendMessage(msg);
                    o.activechns(numel(o.activechns)+1) = {thisChn};
                    for jj = 1:numel(o.activechns)
                        o.sendMessage(['execute uploadstimparameters ' o.activechns{jj} ';']);
                        o.getUploadInProgress;
                    end
                    if ~any(cellfun(@(x) strcmp(thisChn,x),o.activechns))
                        o.sendMessage(['execute uploadstimparameters ' thisChn ';']);
                        o.getUploadInProgress;
                    end
                    o.activechns = {};
                    if strcmp(o.iFormat,'single')
                        o.sendMessage('set runmode unpause;');
                    elseif strcmp(o.iFormat,'trial')
                        o.sendMessage('set runmode record;');
                    end
                end
            else
                % Convert the parameter set into strings
                % Convert the channel number into an Intan channel identifier
                for ii = 1:numel(o.estimulus)
                    thisChn = getIntanChannel(o,'index',ii);
                    msg{1} = strcat('channel=',thisChn);
                    msg{2} = strcat('pulseOrTrain=',num2str(o.estimulus{ii}.pot));
                    if o.estimulus{ii}.pot
                        if o.estimulus{ii}.nod == 1
                            msg{3} = strcat('numberOfStimPulses=',num2str(o.estimulus{ii}.nsp));
                        elseif o.estimulus{ii}.nod == 2
                            nsp = floor((o.estimulus{ii}.pod / 1e6) * o.estimulus{ii}.fre);
                            if nsp > 99
                                nsp = 99;
                            end
                            msg{3} = strcat('numberOfStimPulses=',num2str(nsp));
                        end
                    else
                        msg{3} = 'numberOfStimPulses=1';
                    end
                    msg{4} = strcat('pulseTrainPeriod=',num2str(min((1e6/o.estimulus{ii}.fre),1e6)));
                    msg{5} = strcat('refractoryPeriod=',num2str(o.estimulus{ii}.ptr));
                    msg{6} = strcat('firstPhaseDuration=',num2str(o.estimulus{ii}.fpd));
                    msg{7} = strcat('secondPhaseDuration=',num2str(o.estimulus{ii}.spd));
                    msg{8} = strcat('interphaseDelay=',num2str(o.estimulus{ii}.ipi));
                    msg{9} = strcat('firstPhaseAmplitude=',num2str(o.estimulus{ii}.fpa));
                    msg{10} = strcat('secondPhaseAmplitude=',num2str(o.estimulus{ii}.spa));
                    msg{11} = strcat('preStimAmpSettle=',num2str(o.estimulus{ii}.prAS));
                    msg{12} = strcat('postStimAmpSettle=',num2str(o.estimulus{ii}.poAS));
                    msg{13} = strcat('postStimChargeRecovOn=',num2str(o.estimulus{ii}.prCR));
                    msg{14} = strcat('postStimChargeRecovOff=',num2str(o.estimulus{ii}.poCR));
                    msg{15} = strcat('stimShape=',num2str(o.estimulus{ii}.stSH));
                    msg{16} = strcat('enableAmpSettle=',num2str(o.estimulus{ii}.enAS));
                    msg{17} = strcat('maintainAmpSettle=',num2str(o.estimulus{ii}.maAS));
                    msg{18} = strcat('enableChargeRecovery=',num2str(o.estimulus{ii}.enCR));
                    msg{19} = strcat('ID=',num2str(o.cic.trial));
                    msg{20} = strcat('enabled=',num2str(o.estimulus{ii}.enabled));
                    o.sendMessage(msg);
                    o.activechns(numel(o.activechns)+1) = {thisChn};
                end
                if numel(o.estimulus) > 0
                    o.sendSet();
                    reply = o.readMessage;
                    while ~strcmpi(reply,['Parameter ' num2str(o.cic.trial) ' Set'])
                        reply = o.readMessage;
                    end
                end
                o.handshake = 1;
                o.checkTCPOK;
            end
        end

        %% Specific Intan Commands
        function sendSet(o)
            if o.cic.stage == 1
                o.sendMessage('SET');
            elseif o.cic.stage == 2
                c.error('CONTINUE','SET Command called to Intan during a trial. This is a critical error');
            end
        end
        function setActive(o,e)
            o.estimulus(numel(o.estimulus)+1) = {e};
        end
        function setSettings(o)
            if o.intanVer >= 3.1
                o.loadIntanFormat;
                %% Populate default values
                % Save file formatting
                settings.saveFormat = ['FileFormat ' o.sFormat ';'];
                settings.saveSpikes = 'SaveSpikeData true;';
                settings.saveSpikeSnapshots = 'SaveSpikeSnapshots true;';
                settings.saveDCAmplifierWaveforms = 'SaveDCAmplifierWaveforms false;';
                settings.createNewDir = 'createNewDirectory true;';
                if strcmp(o.iFormat,'single')
                    settings.createNewDirTrial = 'createNewDirectoryTrial false;';
                elseif strcmp(o.iFormat,'trial')
                    settings.createNewDirTrial = 'createNewDirectoryTrial true;';
                end
                % Default display filters
                settings.NotchFilter = 'NotchFilterFreqHertz 50;';
                % Default display settings
                settings.FilterDisplay1 = 'FilterDisplay1 High;';
                settings.ArrangeBy = 'ArrangeBy Filter;';
                settings.LabelWidth = 'LabelWidth Narrow;';
                % Artifact Suppresssion
                settings.ArtifactSuppression = 'ArtifactSuppressionEnabled true;';
                settings.ArtifactsShown = 'ArtifactsShown true;';
                settings.ArtifactSuppressionThreshold = 'ArtifactSuppressionThresholdMicroVolts 500;';
                % Amplifier Fast Settle
                settings.HeadstageGlobalSettle = 'HeadstageGlobalSettle true;';
                % Digital In Channels
                settings.DigitalIn1 = 'DIGITAL-IN-01.enabled true;';
                settings.DigitalIn2 = 'DIGITAL-IN-02.enabled true;';
                settings.AnalogIn1 = 'ANALOG-IN-1.enabled true;';
                % Apply the channel mapping
                x = [o.cfg.xcoords{:}];
                y = [o.cfg.ycoords{:}];
                uShank = unique(x);
                uElectrode = unique(y);
                if all(uElectrode < 0)
                    uElectrode = fliplr(uElectrode);
                end
                for ii = 1:numel(o.chnMap)
                    settings.(['CHN' num2str(ii)]) = [o.getIntanChannel('chn',ii) '.customchannelname S' num2str(find(x(ii) == uShank,1)) 'E' num2str(find(y(ii) == uElectrode,1)) ';'];
                    settings.(['CHN' num2str(ii) 'Order']) = [o.getIntanChannel('chn',ii) '.UserOrder ' num2str(ii - (ceil(ii/32)-1) * 32 - 1) ';'];
                end
                % Store the default settings
                o.settingsStruct = settings;
                % Apply these settings
                fnames = fieldnames(o.settingsStruct);
                for ii = 1:numel(fieldnames(o.settingsStruct))
                    o.sendMessage(['set ' o.settingsStruct.(fnames{ii})]);
                end
                o.sendMessage('execute uploadampsettlesettings true;');
                o.getUploadInProgress;
                o.sendMessage('execute uploadchargerecoverysettings;');
                o.getUploadInProgress;
                o.sendMessage('execute uploadbandwidthsettings;');
                o.getUploadInProgress;
                o.sendMessage('execute uploadstimparameters;');
                o.getUploadInProgress;
            else
                % Grab the settings file
                o.settingsFile = o.loadSettingsFile;
                % Verify TCP connections
                o.handshake = 1;
                o.checkTCPOK;
                % Tell Intan to load the settings file
                o.sendMessage(['LOADSETTINGS=' o.settingsFile]);
            end
        end
        function setSavePath(o)
            % Set the Intan save path
            o.saveDir = o.setSaveDir(o.saveDir);
            savePath = split(o.saveDir,'\');
            saveFile = savePath{end};
            savePath = strjoin(savePath(1:end-1),'\');
            % Pass the savepath to Intan
            if o.intanVer >= 3.1
                o.sendMessage(['set FileName.Path ' savePath]);
                o.sendMessage(['set FileName.BaseFileName ' saveFile]);
            else
                o.sendMessage(['SETSAVEPATH=' savePath '\' saveFile]);
            end
        end
        function setDefaultStim(o)
            % Default stim parameters

            % Check for estimulus defaults

            o.sendMessage('execute uploadstimparameters');
            o.getUploadInProgress;
        end
        function portMapping(o)
            % Handles conversion from channel mapping to port numbering
            exp = '(?<nChn>\d+)';
            o.sendMessage('get a.numberamplifierchannels');
            rstr = o.readMessage;
            numC = regexp(rstr,exp,'names');
            numC = str2double(numC.nChn);
            if numC > 0
                o.ports{end+1} = 'A';
                o.numChannels = o.numChannels + numC;
            end
            o.sendMessage('get b.numberamplifierchannels');
            rstr = o.readMessage;
            numC = regexp(rstr,exp,'names');
            numC = str2double(numC.nChn);
            if numC > 0
                o.ports{end+1} = 'B';
                o.numChannels = o.numChannels + numC;
            end
            o.sendMessage('get c.numberamplifierchannels');
            rstr = o.readMessage;
            numC = regexp(rstr,exp,'names');
            numC = str2double(numC.nChn);
            if numC > 0
                o.ports{end+1} = 'C';
                o.numChannels = o.numChannels + numC;
            end
            o.sendMessage('get d.numberamplifierchannels');
            rstr = o.readMessage;
            numC = regexp(rstr,exp,'names');
            numC = str2double(numC.nChn);
            if numC > 0
                o.ports{end+1} = 'D';
                o.numChannels = o.numChannels + numC;
            end
            if o.numChannels ~= numel(o.chnMap)
                warning('Intan does not have the same number of enabled channels as the provided configuration. Proceed at your own risk.');
            end
            % Sets up a cell array of default channel parameters
            for ii = 1:o.numChannels
                newChn = [];
                newChn.chn = o.getIntanChannel('chn',ii');
                newChn.fpa = 0;
                newChn.spa = 0;
                newChn.fpd = 0;
                newChn.spd = 0;
                newChn.ipi = 0;
                newChn.pot = 0;
                newChn.nod = 1;
                newChn.nsp = 0;
                newChn.fre = 80;
                newChn.pod = 0;
                newChn.ptr = 1e3;
                newChn.prAS = 0;
                newChn.poAS = 0;
                newChn.prCR = 0;
                newChn.poCR = 0;
                newChn.stSH = 1;
                newChn.enAS = 0;
                newChn.maAS = 0;
                newChn.enCR = 0;
                o.chns{ii} = newChn;
            end
        end
        %% Handle Channel Mapping
        function c = getIntanChannel(o,varargin)
            % Handle input
            p = inputParser;
            p.addParameter('index',0,@isnumeric);
            p.addParameter('chn',0,@isnumeric);
            p.parse(varargin{:});
            args = p.Results;
            if args.index
                thisChn = o.chnMap(o.estimulus{args.index}.chn);
                % Sanitise channel numbering to 1 - 32 for Intan port numbering
                % schemes
                if isempty(o.estimulus{args.index}.port)
                    c = [o.ports{ceil(thisChn / 32)} '-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                else
                    c = [o.estimulus{args.index}.port '-' num2str(thisChn-1,'%03d')]; % Intan is 0-indexed
                end
            elseif args.chn
                thisChn = o.chnMap(args.chn);
                c = [o.ports{ceil(thisChn / 32)} '-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
            end
        end
        function chnMap = loadIntanChannelMap(o)
            if isa(o.cfgFcn, 'function_handle') && strncmp(char(o.cfgFcn), '@', 1)
                % If this property is an anonymous function, get channel map from here
                chnMap = o.cfgFcn();
                if iscell(chnMap)
                    tmp = [];
                    for ii = 1:numel(chnMap)
                        tmp = [tmp,chnMap{ii}];
                    end
                    chnMap = tmp;
                end
                return
            end
            if isa(o.cfgFile, 'file') && ~isempty(dir(o.cfgFile))
                % If this property contains a file, get channel map from here
                config = load(o.cfgFile,'chnMap');
                assert(exist(config.chnMap,'var'),'Could not parse the contents of the provided channel map file. Please double-check.');
                chnMap = config.chnMap;
            end
        end
        function settingsFile = loadSettingsFile(o)
            if isa(o.settingsFcn, 'function_handle') && strncmp(char(o.settingsFcn), '@', 1)
                % If this property is an anonymous function, get channel map from here
                settingsFile = o.settingsFcn();
                return
            end
            if isa(o.settingsPath,'char')
                % If this property contains a path, use this as the path to the settings file
                settingsFile = o.settingsPath;
            end
        end
        function loadIntanFormat(o)
            % If this property is an anonymous function, get channel map from here
            if ~isempty(o.cfg)
                o.iFormat = o.cfg.iFormat;
                if isa(o.cfg,'marmodata.intan.formats.ofps')
                    o.sFormat = 'OneFilePerSignal';
                elseif isa(o.cfg,'marmodata.intan.formats.ofpc')
                    o.sFormat = 'OneFilePerChannel';
                end
            end
        end
        %% Handle Amplifier Settle Configuration
        function ampSettle(o)
            % Configure each channel in the experiment for amplifier settle
            if o.chnList == 0
                pause(1);
                return;
            end
            for ii = 1:numel(o.chnList)
                switch ceil(o.chnList(ii)/32)
                    case 1 % port A
                        o.sendMessage('changePort=0');
                    case 2 % port B
                        o.sendMessage('changePort=1');
                    case 3 % port C
                        o.sendMessage('changePort=2');
                    case 4 % port D
                        o.sendMessage('changePort=3');
                end
                msg{1} = strcat('channel=',o.getIntanChannel('chn',o.chnList(ii)));
                msg{2} = 'enabled=1';
                msg{3} = 'firstPhaseAmplitude=0';
                msg{4} = 'secondPhaseAmplitude=0';
                msg{5} = 'stimShape=1';
                msg{6} = 'preStimAmpSettle=200';
                msg{7} = 'postStimAmpSettle=500000';
                msg{8} = 'enableAmpSettle=1';
                o.sendMessage(msg);
                o.sendSet;
                pause(0.1);
                o.sendMessage(strcat('changeFrame=',num2str(mod(o.chnList(ii)-1,32))));
                pause(0.1);
                o.sendMessage('OPENSTIM');
                pause(0.1);
                o.sendMessage('CLOSESTIM');
                pause(0.1);
                o.handshake = 1;
                o.checkTCPOK;
                o.sendMessage('RUN');
                pause(0.1);
                o.sendMessage('STOP');
                pause(0.1);
                msg{2} = 'enabled=0';
                o.sendMessage(msg);
                pause(0.1);
                o.sendSet;
            end
        end

        %% Force Uniform Save Directory
        function saveDir = setSaveDir(o,saveDir)
            saveDir = strsplit(saveDir,'\');
            saveDir = strjoin(saveDir(1:end-1),'\');
            [y,m,d] = ymd(datetime(o.cic.date,'InputFormat','dd MMM yyyy'));
            saveDir = [saveDir '\' num2str(y,'%4.0f') '\' num2str(m,'%02.0f') '\' num2str(d,'%02.0f') '\' o.cic.file];
        end

        %% Generic Health Check
        function OK = checkTCPOK(o)
            if o.handshake
                OK = 0;
                while(~OK)
                    % Initialise the check
                    flushinput(o.tcpSocket);
                    o.sendMessage('RUOK');
                    msg = o.readMessage;
                    if ~strcmp(msg,"YEAH")
                        OK = 0;
                    else
                        OK = 1;
                    end
                    flushinput(o.tcpSocket);
                end
                o.handshake = 0; % Disable handshake
                flushinput(o.tcpSocket);
            end
        end
    end % methods (public)

    methods (Access = protected)
        function startRecording(o)
            if ~o.testMode
                if o.intanVer >= 3.1
                    o.sendMessage('set trial 0;');
                    pause(0.05);
                    o.sendMessage('set runmode record;');
                    o.isRecording = true;
                    % Expect a message from Intan here
                    notifSaveDir = 0;
                    while ~notifSaveDir
                        msg = o.readMessage;
                        expectedReturnString = 'Return: FileName ';
                        if contains(msg, expectedReturnString)
                            o.saveDir = msg(length(expectedReturnString)+1:end);
                            notifSaveDir = 1;
                        end
                        pause(0.01);
                    end
                    if isempty(o.saveDir)
                        warning('Intan did not notify neurostim of its saveDir. This is a non-critical error.');
                    end
                else
                    o.handshake = 1;
                    o.checkTCPOK;
                    pause(0.1);
                    o.sendMessage('RECORD');
                    msg = o.readMessage();
                    msg = strsplit(msg,'=');
                    if strcmp(msg{1},'SAVE')
                        o.saveDir = msg{2};
                    end
                    if isempty(o.saveDir)
                        warning('Intan did not notify neurostim of its saveDir. This is a non-critical error.');
                    end
                end
            end
        end
        function stopRecording(o)
            if ~o.testMode
                tf = isMATLABReleaseOlderThan('R2021a');
                if tf
                    if o.intanVer >= 3.1
                        o.sendMessage('set runmode stop;');
                        o.isRecording = false;
                        if o.clearComms
                            fclose(o.tcpSocket);                            
                        end
                        clear o.tcpSocket;
                        o.tcpSocket = [];
                    else
                        o.handshake = 1;
                        o.checkTCPOK;
                        o.sendMessage('STOP');
                        o.isRecording = false;
                        if o.clearComms
                            fclose(o.tcpSocket);
                        end
                        clear o.tcpSocket;
                        o.tcpSocket = [];
                    end
                else
                    if o.intanVer >= 3.1
                        o.sendMessage('set runmode stop;');
                        o.isRecording = false;                        
                        clear o.tcpSocket;                        
                        o.tcpSocket = [];
                    else
                        o.handshake = 1;
                        o.checkTCPOK;
                        o.sendMessage('STOP');
                        o.isRecording = false;
                        clear o.tcpSocket;
                        o.tcpSocket = [];
                    end
                end
            end
        end
        function uploadInProgress = getUploadInProgress(o)
            % Query if upload is currently in progress. If it still is, then wait
            % 100 ms and try again until it's not
            pause(0.05);
            uploadInProgress = "True";
            while ~strcmp(uploadInProgress, "False")
                o.sendMessage('get uploadinprogress');
                msg = o.readMessage;
                expectedReturnString = 'Return: UploadInProgress ';
                if contains(msg, expectedReturnString)
                    uploadInProgress = msg(length(expectedReturnString)+1:end);
                end
                pause(0.1);
                if strcmp(o.readMessage,'Board must be running in order to stop')
                    keyboard;
                end
            end
        end
        function createTCPobject(o)
            if ~isempty(o.tcpSocket)
                % Test the connection
                o.sendMessage('get runmode');
                if isempty(o.readMessage)
                    % Failed. Reset the connection.
                    o.tcpSocket = [];
                    o.createTCPobject;
                end
            else
                tf = isMATLABReleaseOlderThan('R2021a');
                if tf
                    if o.intanVer >= 3.1
                        o.tcpSocket = tcpip(o.hostAddr,o.hostPort,'NetworkRole','client','Timeout',1); %#ok<TCPC>
                        fopen(o.tcpSocket);
                    else
                        o.tcpSocket = tcpip(o.hostAddr,o.hostPort,'NetworkRole','server','Timeout',1); %#ok<TCPS>
                        disp('Please connect Intan to neurostim');
                        fopen(o.tcpSocket);
                    end
                else
                    if o.intanVer >= 3.1
                        o.tcpSocket = tcpclient(o.hostAddr,o.hostPort,'ConnectTimeout',30,'Timeout',1);
                    else
                        disp('Please connect Intan to neurostim');
                        o.tcpServer = tcpserver(o.hostAddr,o.hostPort,'ConnectTimeout',30,'Timeout',1);
                    end
                end
            end
        end
    end
end