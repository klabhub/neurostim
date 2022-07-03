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
    end
    
    methods (Access=public)
        %% Constructor
        function o = intan(c,name,varargin)
            % Intan does not have any dependencies on the host computer
            % Parse arguments
            pin = inputParser;
            pin.KeepUnmatched = true;
            pin.addParameter('CreateNewDir', 1, @(x) assert(x == 0 || x == 1, 'It must be either 1 (true) or 0 (false).'));
            pin.addParameter('RecDir', '', @ischar); % Save path on the Intan computer            
            pin.addParameter('SettingsFile', '', @ischar); % Settings file for Intan
            pin.addParameter('tcpSocket', '');
            pin.addParameter('testMode', 0, @isnumeric); % Test mode that disables stimulation and recording            
            pin.addParameter('chnMap', [], @isnumeric);            
            pin.addParameter('saveFile','',@ischar); % Contains the saveFile string associated with the current recording            
            pin.parse(varargin{:});
            args = pin.Results;
            % Call parent class constructor
            % Pass HostAddr to the parent constructor via the 'Unmatched'
            % property of the input parser
            o = o@neurostim.plugins.ePhys(c,name,pin.Unmatched);            

            % Initialise class properties
            o.addProperty('createNewDir',args.CreateNewDir,'validate',@isnumeric);
            o.addProperty('recDir',args.RecDir,'validate',@ischar);
            o.addProperty('settingsFile',args.SettingsFile,'validate',@ischar);
            o.addProperty('tcpSocket',args.tcpSocket);
            o.addProperty('testMode',args.testMode);
            o.addProperty('chnMap',args.chnMap);
            o.addProperty('saveFile',args.saveFile,'validate',@ischar);
            o.addProperty('isRecording',false);
        end

        %% Generic Communcation
        function sendMessage(o,msg)
            % Send a message to Intan
            if ~iscell(msg)
                msg = {msg};
            end
            for ii = 1:numel(msg)
                fprintf(o.tcpSocket,msg{ii});
            end            
        end
        function msg = readMessage(o)
            % Read a message from Intan
            msg = fscanf(o.tcpSocket);
            msg = string(msg(1:end-1));            
        end

        %% Neurostim Events
        function beforeExperiment(o)     
            % Create a tcp/ip socket           
            o.tcpSocket = o.local_TCPIP_server;
            % Grab the channel mapping
            o.chnMap = o.loadIntanChannelMap;
            % Grab the settings file
            o.settingsFile = o.loadSettingsFile;
            % Verify TCP connections
            o.sendMessage('RUOK');
            % Tell Intan to load the settings file
            o.sendMessage(['LOADSETTINGS=' o.cic.estim.settingsFile]);
            % Set the Intan save path
            o.sendMessage(['SETSAVEPATH=' o.cic.estim.recDir]);
            o.startRecording();            
        end
        function beforeTrial(o)
            if ~isempty(o.activechns)
                marker = ones(1,numel(o.activechns));
                for ii = 1:numel(o.estimulus)
                    thisChn = getIntanChannel(o,ii);                    
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
                        o.sendSet();
                        if jj == kk
                            o.handshake = 1;
                            o.checkTCPOK;
                        end
                    end
                end
                o.activechns = {};
            end
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
                thisChn = getIntanChannel(o,ii);
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
            o.sendSet();            
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

        %% Handle Channel Mapping
        function c = getIntanChannel(o,ii)
            thisChn = o.chnMap(o.estimulus{ii}.chn);
            % Sanitise channel numbering to 1 - 32 for Intan port numbering
            % schemes
            while thisChn > 32
                thisChn = thisChn - 32;
            end
            c = [o.estimulus{ii}.port '-' num2str(thisChn-1,'%03d')]; % Intan is 0-indexed
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
            end
        end
    end
    methods (Access = protected)
        function startRecording(o)
            if ~o.testMode
                o.sendMessage('RECORD');
                o.isRecording = true;
                % Expect a message from Intan here
                msg = o.readMessage;
                msg = split(msg,'=');
                % This should always be true
                if strcmp(msg{1},'SAVE')
                    o.saveFile = msg{2};
                else
                    warning('Intan did not notify neurostim of its saveFile. This is a non-critical error.');
                end
            end
        end
        function stopRecording(o)
            if ~o.testMode
                o.sendMessage('STOP');
                o.isRecording = false;
            end
        end
        function t = local_TCPIP_server(o)
            CONNECTION = '0.0.0.0'; % Use '0.0.0.0' to allow any connection, from anywhere
            PORT = 9004;            % Can be anything, but must be consistent. Don't use a common port.
            TYPE = 'server';        % Use 'client' to connect to the other side of this connection.
            TIMEOUT = 1;            % How long execution will wait for a response (seconds)
            myIP = neurostim.plugins.intan.getIP;            
            disp(['The IP address is: ' myIP]);
            disp(['The port is: ' num2str(PORT)]);
            t = tcpip(CONNECTION,PORT,'NetworkRole',TYPE,'Timeout',TIMEOUT);
            fopen(t);
            msg = o.readMessage;
            if ~strcmp(msg,"READY")
                disp('ERROR. BAD CONNECTION.')
            end
            flushinput(t)
        end
    end
    methods (Static)        
        function myIP = getIP
            [~,myIP]=system('ipconfig');
            myIP = strsplit(myIP,'IPv4 Address');
            myIP = splitlines(myIP{2});
            myIP = strsplit(myIP{1},':');
            myIP = myIP{2}(2:end);
        end        
    end
end