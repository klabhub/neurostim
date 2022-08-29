classdef intan < neurostim.plugins.ePhys
    % Plugin for interfacing with the Intan GUI via tcp/ip
    % Example usage:
    % o = neurostim.plugins.intan(c,'intan',[RecDir].[SettingsFile]);
    % Optional parameters may be specified via name-value pairs:
    % RecDir - Directory used for saving Intan generated datafiles
    % SettingsFile - .isf Intan settings file for a specific electrode
    % configuration
    
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
        estimulus = {};     % Contains a pointer to the active estim plugin
        activechns = {};    % Contains a list of active stimulation channels
        handshake = 0;      % Controls whether the Intan manager plugin will halt execution of the thread while awaiting
        % a handshake from the Intan firmware over the
        % TCP connection. !!Important!!
        cfgFcn = [];        % Can be given an anonymous function that specifies the channel mapping. Overrides other channel mapping sources
        cfgFile = [];       % Can be given a filepath that contains the channel mapping.
        settingsFcn = [];   % Can be given an anonymous function that specifies the Intan settings file. Overrides other channel mapping sources
        settingsPath = [];  % Can be given a filepath that contains the Intan settings file.
        settingsFile = [];  % Contains the Intan settings file path.
        chnList = [];       % Used to pass a list of channels for amplifier settle configuration
        saveDir = 'C:\Data';% Provides the base path to the Data directory on the recording machine. Default is C:\Data
        chnMap = [];        % Contains the channel mapping for the experiment.        
    end
    
    methods (Access=public)
        %% Constructor
        function o = intan(c,name,varargin)
            % Intan does not have any dependencies on the host computer
            % Parse arguments
            pin = inputParser;
            pin.KeepUnmatched = true;            
            pin.addParameter('tcpSocket', '');
            pin.addParameter('testMode', 0, @isnumeric); % Test mode that disables stimulation and recording            
            pin.addParameter('saveDir','',@ischar); % Contains the saveDir string associated with the current recording
            pin.parse(varargin{:});
            args = pin.Results;
            
            % Call parent class constructor
            o = o@neurostim.plugins.ePhys(c,name,pin.Unmatched);
            
            % Initialise class properties
            o.addProperty('tcpSocket',args.tcpSocket);
            o.addProperty('testMode',args.testMode);
            o.addProperty('isRecording',false);
            o.addProperty('loggedEstim',[],'validate',@iscell);
            if ~isempty(args.saveDir)
                o.saveDir = args.saveDir;
            end
        end
        
        %% Generic Communcation
        function sendMessage(o,msg)
            % Send a message to Intan
            if ~iscell(msg)
                msg = {msg};
            end
            for ii = 1:numel(msg)
                try
                    writeline(o.tcpSocket,msg{ii});
                catch % older matlab?
                    fprintf(o.tcpSocket,msg{ii});
                end
            end
        end
        function msg = readMessage(o)
            % Read a message from Intan
            try
                msg = readline(o.tcpSocket);
            catch % older matlab?
                msg = fscanf(o.tcpSocket);
            end
            msg = string(msg(1:end-1));
        end
        
        %% Neurostim Events
        function beforeExperiment(o)
            % Create a tcp/ip socket
            o.tcpSocket = neurostim.plugins.intan.createTCPobject;
            msg = o.readMessage;
            if ~strcmp(msg,"READY")
                disp('ERROR. BAD CONNECTION.')
            end
            flushinput(o.tcpSocket)
            % Grab the channel mapping
            o.chnMap = o.loadIntanChannelMap;
            % Send the settings file to Intan
            o.setSettings();            
            % Configure Intan for amplifier settling
            o.ampSettle();
            % Set the save path in Intan (again)
            o.setSavePath();
            % Start recording
            o.startRecording();
        end

        function beforeTrial(o)
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
                msg{4} = strcat('pulseTrainPeriod=',num2str((1e6/o.estimulus{ii}.fre)));
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
            % Grab the settings file
            o.settingsFile = o.loadSettingsFile;
            % Verify TCP connections
            o.handshake = 1;
            o.checkTCPOK;
            % Tell Intan to load the settings file
            o.sendMessage(['LOADSETTINGS=' o.settingsFile]);
        end
        function setSavePath(o)
            % Set the Intan save path
            o.saveDir = o.setSaveDir(o.saveDir);
            % Verify TCP connections
            o.handshake = 1;
            o.checkTCPOK;
            % Pass the savepath to Intan
            o.sendMessage(['SETSAVEPATH=' o.saveDir]);            
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
                    switch ceil(thisChn / 32)
                        case 1 % port A
                            c = ['A-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                        case 2 % port B
                            c = ['B-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                        case 3 % port C
                            c = ['C-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                        case 4 % port D
                            c = ['D-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                    end
                else                    
                    c = [o.estimulus{args.index}.port '-' num2str(thisChn-1,'%03d')]; % Intan is 0-indexed
                end
            elseif args.chn
                thisChn = o.chnMap(args.chn);
                switch ceil(thisChn / 32)
                    case 1 % port A
                        c = ['A-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                    case 2 % port B
                        c = ['B-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                    case 3 % port C
                        c = ['C-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                    case 4 % port D
                        c = ['D-' num2str(mod(thisChn-1,32),'%03d')]; % Intan is 0-indexed
                end
            end
        end
        function chnMap = loadIntanChannelMap(o)
            if isa(o.cfgFcn, 'function_handle') && strncmp(char(o.cfgFcn), '@', 1)
                % If this property is an anonymous function, get channel map from here
                chnMap = o.cfgFcn();
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
            saveDir = strsplit(saveDir,filesep);
            saveDir = strjoin(saveDir(1:end-1),filesep);
            [y,m,d] = ymd(datetime(o.cic.date,'InputFormat','dd MMM yyyy'));
            saveDir = [saveDir filesep num2str(y,'%4.0f') filesep num2str(m,'%02.0f') filesep num2str(d,'%02.0f') filesep o.cic.file];
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
                % Verify TCP connections
                o.handshake = 1;
                o.checkTCPOK;
                o.sendMessage('RECORD');
                o.isRecording = true;
                % Expect a message from Intan here
                msg = o.readMessage;
                msg = split(msg,'=');
                % This should always be true
                while ~strcmp(msg{1},'SAVE')
                    warning('Intan did not notify neurostim of its saveDir. This is a non-critical error.');
                    msg = o.readMessage;
                    msg = split(msg,'=');
                end
                o.saveDir = msg{2};
            end
        end
        function stopRecording(o)
            if ~o.testMode
                o.handshake = 1;
                o.checkTCPOK;
                o.sendMessage('STOP');
                o.isRecording = false;
                clear o.tcpSocket;
            end
        end
    end
    methods (Static)
        function t = createTCPobject
            CONNECTION = '0.0.0.0'; % Allows connections from any IP
            PORT = 9004;            % Can be anything, but must be consistent. Don't use a common port.
            TIMEOUT = 1;            % How long execution will wait for a response (seconds)
            
            if ispc
                myIP = neurostim.plugins.intan.getIP;
                disp(['The IP address is: ' myIP]);
                disp(['The port is: ' num2str(PORT)]);
            else
                disp('This is not Windows, so we do not know IP. It should be configured correctly elsewhere.');
            end
            try
                t = tcpserver(CONNECTION,PORT,'Timeout',TIMEOUT);
                while ~t.Connected
                    pause(0.01);
                end
            catch % older matlab?
                t = tcpip(CONNECTION,PORT,'NetworkRole','server','Timeout',TIMEOUT);
                fopen(t);
            end
        end
        function myIP = getIP
            keyboard;
            [~,myIP]=system('ipconfig');
            myIP = strsplit(myIP,'IPv4 Address');
            myIP = splitlines(myIP{2});
            myIP = strsplit(myIP{1},':');
            myIP = myIP{2}(2:end);
        end
    end
end