classdef starstim < neurostim.stimulus
    % A stimulus that can stimulate electrically using the StarStim device from
    % Neurelectrics.
    %
    %
    % Setup in NIC: (Once)
    %
    %  Go to Settings (under Protocol) and Activate TCP Server Markers and
    %  TimeStamp, provide the name 'Neurostim' for the Markers Lab
    %  Streaming layer 1.
    %
    %  Note that Markers (e.g. TrialStart) will not be saved if the name does
    %  not match 'Neurostim' (but on the neurostim side there is no way to detect this).
    % Your only cue that something is wrong is that you will not see
    % markers in the NIC window.
    %
    % A protocol (defined in the NIC) specifies which electrodes are
    % connected, which record EEG, and which stimulate. You select a protocol
    % by providing its name (case-sensitive) to the starstim plugin .
    %
    % Note that all stimluation parameters will be set here in
    % in the starstim matlab stimulus. The (single step) protocol should
    % set stim **currents to 0 muA**  and chose a very long duration.
    % This plugin will load the protocol, (which will record EEG but stimulate
    % at 0 currents) and then change stimulation parameters on the fly.
    %
    % Impedance checking in the NIC Gui interferes with the subsequent running
    % of a protocol from MatNIC  (Nov 2021). If you need to use the NIC GUI, be sure
    % % to restart it after performing manual impedance checks.  Also, NIC
    % will not measure impedances for channels with 0 current so a separate
    % protocol is needed to do z-checks. 
    % The recommended approach is to do z-check from nsGui, using the z Now
    % button. For this, specify the protocol to use (e.g. a protocol in
    % which all electrodes used in the experiment are marked as stimulation
    % electrodes; the current levels can be zero) , then select AC or DC
    % and press Z-Now. The z values will be stored in the data file for the
    % next experiment. 
    % 
    % If Z-Check is set to AC or DC , an impedance check is performed both
    % before the experiment starts and after it ends. Note that this would
    % be in addition to the Z Now button presses. 
    % 
    % So, the quickest way to start an experiment is to use the Z-now
    % button during electrode setup (for repeated measurements), then set
    % Z-type to None, and press the Go button. The only loss is the z
    % measurement at the end of the experiment.
    %
    % Filenaming convention for NIC output uses the name of the step in the
    % protocol. Leaving the step name blank creates cleaner file names
    % (YYYMMDDHHMMSS.subject.edf). This plugin creates a subdirectory with
    % the name of the Neurostim file to store the NIC output files (this
    % assumes Neurostim has access to the same folder as the machine running
    % the NIC; or at least a machine with the same name...).
    %
    % There are different modes to control stimulation, with increasing levels of
    % temporal and parameter control.  (.mode)
    % NIC:
    %  This ignores all current parameters specified in Neurostim; it
    %  starts the requested protocol before the start of the experiment,
    %  and then simply keeps running without changing anything (but while
    %  sending trial markers etc)
    %  
    % BLOCKED:
    %    Simplest mode: trigger the start of a named protocol in the first
    %   trial in a block in which .enabled =true and keep running until the
    %    last trial in that block.
    %
    % TRIAL:
    %   Start the rampup of the protocol before each .enabled=true trial,
    %   and ramp it down after each such trial.
    %
    % TIMED:
    %  Here stimulation starts in each .enabled=true trial at starstim.on
    %  and ends .duration ms later.
    %
    % EEGONLY:
    %   No stimulation, just EEG recording
    %
    % Stimulation Type and Parameters
    %   .transition  - time in ms of the ramp up/down  (at least 100 ms)
    %   .duration     - duration of stimulation (TIMED mode only)
    %   .type       - tACS, tDCS,tRNS
    %
    %   .amplitude (muA), .frequency (Hz) , .phase (deg) - tACS only :
    %                                       one value per channel. Integers only!
    %   .mean                           - tDCS only : one integer value per
    %   channel. Must add up to zero.
    %
    %   .zProtocol - Name of the protocol to use before (and after) the
    %   experiment to measure impedance.
    %    .impedanceType - AC, or DC, or NONE to skip z measurements
    %    before/after experiment.
    %
    %
    % In each mode , you can use sham stimulation (.sham =
    % true); this means that the protcol will ramp up and immediately down
    % again using the .transition duration.
    %
    % See startstimDemo for more details and examples
    %
    % PERFORMANCE:
    %  The NIC software, especially when it is actively stimulating, puts a
    %  heavy load on the CPU and, if running on the same machine as
    %  Neurostim, can lead to frequent framedrops (which, becaese it
    %  depends on stimulation, could correlate with an experimental
    %  design!). So it is highly recommended to run NIC on a separate
    %  machine. Connecting to it via TCP/IP is trivial (just provide the IP
    %  number or name of the NIC machine in the constructor)
    %
    % BK - Feb 2016, 2017
    % Nov - 2021 - Revisions to allow z-checks, and to avoid execution loops.

    properties (Constant)
        % Define  marker events to store in the NIC data file
        code   = containers.Map({'trialStart','rampUp','rampDown','trialStop','returnFromNIC','protocolStarted','stopProtocol','stimOnset'},{1,2,3,4,5,6,7,8})
    end


    properties (SetAccess =public, GetAccess=public)
        stim=false;
        impedanceType= 'None'; % Set to DC or AC to measure impedance at DC or xx Hz AC. None to not check
        NRCHANNELS = 8;  % nrChannels in your device.
        debug = false;
        verbose = false;


        % EEG parms that need fast acces (and therefore not a property)
        eegAfterTrial = []; % Function handle fun(eeg,time,starstimObject)
        eegAfterFrame = []; % Functiona handle fun(eeg,time,starstimObject)
        eegStore= false; % Store the eeg data in the starstim object.
        eegInit= false; % Set to true to initialize eeg stream before experiment (and do not wait until the first trial with non empty o.eegChannels)
    end

    properties (SetAccess={?neurostim.plugin},GetAccess=public)
        NICVersion;
        matNICVersion;               
    end
    
    % Public Get, but set through functions or internally
    properties (SetAccess={?neurostim.plugin}, GetAccess= public)
        mustExit= false;
    end

    % Public Get, but set through functions or internally
    properties (Transient, SetAccess={?neurostim.plugin}, GetAccess= public)
        sock;               % Socket for communication with the host.
        markerStream;       % LSL stream to write markers in NIC

        isTimedStarted= false;
        isShamOn= false;

        activeProtocol='';
        tmr; % A timer

        lsl=[];  % The LsL library
        inlet=[];  % An LSL inlet
    end


    % Dependent properties
    properties (Dependent)
        status;        % Current status (queries the NIC)
        protocolStatus;    % Current protocol status (queries the NIC)
        isProtocolOn;
        isProtocolPaused;
        isConnected;
        eegStream;   %True if processing eeg here (afterTrial or afterFrame), or storing in cic).
    end

    methods % get/set dependent functions
        function v = get.eegStream(o)
            v =(~isempty(o.eegAfterTrial) || ~isempty(o.eegAfterFrame)  || o.eegStore)  && ~o.fake;
        end
        function v = get.isConnected(o)
            if isempty(o.sock)
                v = false;
            else
                [ret] = MatNICQueryStatus(o.sock);
                v = ret==0;
            end
        end
        function [v] = get.status(o)
            if o.fake
                v = ' Fake OK';
            else
                [~, v] = MatNICQueryStatus(o.sock);
                if isempty(v) || (isnumeric(v) && v==0)
                    v= 'error/unknown';
                end
            end
        end

        function v = get.protocolStatus(o)
            if o.fake
                v = ' Fake Protocol OK';
            else
                [~, v] = MatNICQueryStatusProtocol(o.sock);
                if isempty(v) || (isnumeric(v) && v==0)
                    v= 'error/unknown';
                end
            end
        end

        function v= get.isProtocolOn(o)
            if o.fake
                v =true;
            else
                stts = o.protocolStatus;
                if isempty(stts) || ~ischar(stts) || strcmpi(stts,'error/unknown')
                    v =false;
                else
                    v = ismember(stts,{'CODE_STATUS_PROTOCOL_RUNNING','CODE_STATUS_STIMULATION_FULL','CODE_STATUS_STIMULATION_RAMPUP','CODE_STATUS_EEG_ON'});
                    % Hacked soltion to the 'stimulation full' protocol
                    % status that impedance checks leave behind.
                    if strcmpi(stts,'CODE_STATUS_STIMULATION_FULL') && ...
                            (strcmpi(o.status,'CODE_STATUS_CHECK_IMPEDANCE_FISNISHED') || strcmpi(o.status,'CODE_STATUS_REMOTE_CONTROL_ALLOWED'))
                        % It is not really 'on'
                        % The firsr happens after a MatNIC triggered
                        % impedance check, the second after running a
                        % manual impedance chcek in NIC, and then unloading
                        % the protocol manually by clicking the edit
                        % button (which is a workaround to mix manual NIC
                        % control for pre-experiment checks, followed by
                        % neurostim control of the actual experiment).
                        v = false;
                    end
                end
            end

        end

        function v= get.isProtocolPaused(o)
            if o.fake
                v =true;
            else
                stts = o.protocolStatus;
                if isempty(stts) || ~ischar(stts)
                    v =true; % No protcol status means it is not running...??
                else
                    v = ismember(stts,{'CODE_STATUS_PROTOCOL_PAUSED', 'CODE_STATUS_IDLE'});
                end
            end
        end


    end

    methods % Public
        function verboseOutput(o,fun,inout)
            if o.verbose
                o.writeToFeed(sprintf('\t %s:%s \t %s \t %s\n',fun,inout,o.status,o.protocolStatus))
            end
        end
        function abort(o)
            stop(o)
        end
        function disp(o)
            fprintf('Starstim Host: %s  Status: %s',o.host,o.status);
        end

        % Destructor
        function delete(o)
            if o.fake
                return;
            end
            if o.mustExit
                onExit(o);
            end
        end
        % Constructor. Provide a handle to CIC, the Starstim hostname.
        % You can fake a NIC by specifying 'fake' as the hostname
        function [o] = starstim(c,hst)


            o=o@neurostim.stimulus(c,'starstim');
            if nargin <2
                hst = 'localhost';
            end

            o.addProperty('host',hst);
            o.addProperty('protocol',''); % Case Sensitive - must exist on host
            o.addProperty('fake',false);
            o.addProperty('z',NaN,'sticky',true);
            o.addProperty('zProtocol','','sticky',true); %THe protocol to be used for impedance checks.
            o.addProperty('type','tACS');%tACS, tDCS, tRNS
            o.addProperty('mode','BLOCKED');  % 'BLOCKED','TRIAL','TIMED','EEGONLY', 'NIC'
            o.addProperty('path',''); % Set to the folder on the starstim computer where data should be stored.
            % If path is empty, the path of the neurostim output file is
            % used (which may not exist on the remote starstim computer).
            o.addProperty('experimentDuration',inf); % Time in ms to stop the experiment. 
            % Used only in NIC mode.Use this to match the neurostim
            % experiment duration to the protocol defined in NIC. The
            % duration is relative to the start of the protocol

            o.addProperty('amplitude',NaN);
            o.addProperty('mean',NaN);
            o.addProperty('phase',0);
            o.addProperty('transition',100);
            o.addProperty('frequency',NaN);
            o.addProperty('sham',false);
            o.addProperty('shamDuration',0); % 0 ms means rampup, and immediately ramp down.
            o.addProperty('enabled',true);
            o.addProperty('montage',ones(1,o.NRCHANNELS));%

            o.addProperty('tRNSFilter','off'); % Use this to limit tRNS to a specific band. See starstim.trnsFilter()
            o.addProperty('tRNSFilterParms',[]);

            o.addProperty('marker',''); % Used to log markers sent to NIC
            o.addProperty('flipTime',[]); % USed to record fliptimes in logOnset function


            o.addProperty('eegChannels',[]); % Default to no EEG.
            o.addProperty('eegMaxBuffered',360);% Samples in seconds in buffer.
            o.addProperty('eegRecover',true);  % Try to recover lost connections
            o.addProperty('eegChunkSize',0); % nr samples per chunk (0 = use senders default)
            o.addProperty('eeg',[]); % Collects eeg data per pull (but only if eegStore ==true)
            o.addProperty('eegTime',[])% Starstim time corresponding to eeg data.

            
        end            


        function beforeExperiment(o)

            v = which('MatNICVersion');
            if isempty(v) && ~o.fake
                error('The MatNIC library is not on your Matlab path');
            end

            %% Remove straggling timers
            timrs = timerfind('name','starstim.timer');
            if ~isempty(timrs)
                o.writeToFeed('Deleting timer stragglers.... last experiment not terminated propertly?');
                delete(timrs)
            end
            o.tmr= timer('name','starstim.timer');

            %% Connect to host - check some prerequisites/setup
            if o.fake
                o.writeToFeed(['Starstim connected to ' o.host]);
            else
                if ~o.isConnected
                    % The object may already have a connection (from the
                    % z-Now button in the gui), if not; try to connect now.
                    [ret, ~, o.sock] = MatNICConnect(o.host);
                    checkFatalError(o,ret,['Connect to ',o.host]);
                end
                o.mustExit = true;

                % This only makes sense if both the Neurostim computer and
                % the NIC computer have access to the same path. Otherwise
                % NIC will complain...
                if isempty(o.path)
                    pth = o.cic.fullFile; % This is without the extension
                    if ~exist(pth,'dir')
                        mkdir(pth);
                    end
                else
                    pth = o.path;
                end

                ret  = MatNICConfigurePathFile (pth, o.sock); % Specify target directory
                checkFatalError(o,ret,['Set PathFile to ' pth]);
                % File format : % YYYYMMDD_[subject].edf
                % Always generate .easy file, and edf file (NIC requires
                % it), and generate .stim when stimulating.
                % Change in 4.07:
                % patientName, recordEasy, recordNedf, recordSD, recordEDF,
                % socket  (no more STIM file)
                ret = MatNICConfigureFileNameAndTypes(o.cic.subject,true,true,false,true,o.sock);
                checkFatalError(o,ret,'Set FileNameAndTypes');
                [ret,o.markerStream] = MatNICMarkerConnectLSL('Neurostim');
                checkFatalError(o,ret,'Enable the Neurostim Marker Stream in NIC');

                key = keys(o.code);
                vals = values(o.code);
                for i=1:length(o.code)
                    [ret] = MatNICConfigureMarkers (key{i}, vals{i}, o.sock);
                    checkFatalError(o,ret,['Define marker: ' key{i}]);
                end
                protocolSet = MatNICProtocolSet();
                o.matNICVersion = protocolSet('MATNIC_VERSION');
            end

            unloadProtocol(o); % Remove whatever is loaded currently (if anything)
            if ~strcmpi(o.impedanceType,'NONE')
                impedance(o); % Measure and store the impedance.
            end

            % Prepare for EEG reading
            if (~isempty(o.eegChannels) || o.eegInit) && o.eegStream
                openEegStream(o);
            end

        end

        function openEegStream(o)
            o.verboseOutput('openEegStream','entry')
            % This will do nothing if the stream is already open, but
            % create a stream otherwise.
            if isempty(o.lsl)
                o.lsl = lsl_loadlib;
            end

            if isempty(o.inlet)
                stream = lsl_resolve_byprop(o.lsl,'type','EEG');
                if isempty(stream)
                    allLsl = lsl_resolve_all(o.lsl);
                    if ~isempty(allLsl)
                        str = strjoin(cellfun(@(x) (string([x.type ':' x.name ' '])),allLsl));
                    else
                        str = 'No LSL streams found';
                    end
                    o.cic.error('STOPEXPERIMENT',sprintf('No EEG stream found. (%s)',str));
                else
                    o.inlet = lsl_inlet(stream{1},o.eegMaxBuffered,o.eegChunkSize,double(o.eegRecover));
                    o.inlet.open_stream;% Start buffering
                end
            end
            o.verboseOutput('openEegStream','exit')
        end

        function loadProtocol(o)
            o.verboseOutput('loadProtocol','entry')
            if o.fake
                o.activeProtocol = o.protocol;
            else
                % Load the protocol
                ret = MatNICLoadProtocol(o.protocol,o.sock);
                checkFatalError(o,ret,['Load protocol ' o.protocol ]);
                o.activeProtocol = o.protocol;
            end
            o.verboseOutput('loadProtocol','exit')
        end

        function unloadProtocol(o)
            o.verboseOutput('unloadProtocol','entry')
            if o.fake;return;end
            if ~ismember(o.protocolStatus,{'CODE_STATUS_IDLE','error/unknown'})
                ret = MatNICUnloadProtocol(o.sock);
                switch (ret)
                    case -6
                        % Already unloaded
                        ret =0;
                    case -8
                        % protocol running.  abort then try again
                        MatNICAbortProtocol(o.sock);
                        ret = MatNICUnloadProtocol(o.sock);
                    case -7
                        % Impedance check running. Abort, then try again
                        MatNICAbortManualCheckImpedances(o.sock);
                        ret = MatNICUnloadProtocol(o.sock);
                    case  0
                        % All good
                    otherwise

                end
                if ret==0
                    o.activeProtocol ='';
                end
                checkFatalError(o,ret,'Unload protocol');
            end
            o.verboseOutput('unloadProtocol','exit')
        end




        function beforeTrial(o)
            if isempty(o.protocol)
                o.cic.error('STOPEXPERIMENT','The Starstim plugin requires a protocol to be specified');
                return;
            end
            %% Load the protocol if it has changed
            if ~strcmpi(o.protocol,o.activeProtocol)
                stop(o);
                unloadProtocol(o);
                loadProtocol(o);              
                start(o);  % Start it (protocols should have zero current and a long duration)
            end

            if ~hasValidParameters(o)
                return;
            end

            %% Open eeg stream if necessary
            if ~isempty(o.eegChannels) && o.eegStream
                openEegStream(o); % This will do nothing if the stream is already open
            end
            sendMarker(o,'trialStart'); % Mark in Starstim data file


            %% Depending on the mode, do something
            switch upper(o.mode)
                case 'BLOCKED'
                    % Starts before the first trial in a block
                    if o.cic.blockTrial ==1 && o.enabled
                        rampUp(o);
                    end
                case 'TRIAL'
                    if o.enabled
                        rampUp(o);
                    end
                case 'TIMED'
                    % Do nothing
                case 'EEGONLY'
                    % Do nothing
                case 'NIC'
                    % Do nothing
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown starstim mode :' o.mode]);
            end


        end

        function beforeFrame(o)
            % ******* DEVELOPER NOTE ****************
            % When adding more complex , timed modes of stimulation, take
            % care to ensure current conservation. This is tricky
            % especially when ussing the MatNICOnlinetACSChange function
            % which applies frequency and phase changes immediately, and
            % then ramps the amplitude (best not to use that one).

            switch upper(o.mode)
                case {'BLOCKED','TRIAL'}
                    % These modes do not change stimulation within a
                    % trial/block - nothing to do.
                case 'TIMED'
                    % Single shot start
                    %                     ret =0;
                    if o.isTimedStarted
                        % Started this trial. Nothing to do.
                    elseif strcmpi(o.tmr.Running,'On')
                        % Not started this trial but still running from a
                        % previous start. Deal with this by stopping the
                        % old one, waiting until it is zero, then starting
                        % the new one.  all in a busy wait...?
                        o.writeToFeed('Oh Oh Stim commands overlap... ');
                    else
                        rampUp(o,o.duration);
                        o.isTimedStarted = true;
                    end
                case 'EEGONLY'
                    %Do nothing
                case 'NIC'
                    % Do nothing
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown starstim mode :' o.mode]);
            end
        end

        %function afterFrame(o)
        %handleEeg(o,o.eegAfterFrame); DISABLED FOR NOW - not likely to be fast enough... need some pacer.
        %end

        function afterBlock(o)
            switch upper(o.mode)
                case 'BLOCKED'
                    if o.enabled && ~o.sham
                        rampDown(o);
                    end
                otherwise
                    %Nothing to do
            end
        end
        
        function afterTrial(o)
            switch upper(o.mode)
                case 'BLOCKED'
                    %Nothing to do
                case 'TRIAL'
                    if ~o.sham
                        % Rampdown unless this is a sham trial (which has a rampdown scheduled)
                        rampDown(o);
                    end
                case 'TIMED'
                    o.isTimedStarted =false;
                case 'EEGONLY'
                    %nothing to do
                case 'NIC'
                    % Check whether it is time to end the experiment
                    [~,~,~,startTime]  = get(o.prms.marker,'dataIsMember',o.code('protocolStarted'));
                    if ~isempty(startTime) && neurostim.cic.clockTime > max(startTime)+o.experimentDuration
                        o.writeToFeed(sprintf('Time is up (%2.2f min)',o.experimentDuration/60000));
                        endExperiment(o.cic);   
                    end
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown starstim mode :' o.mode]);
            end

            % Send a trial start marker to the NIC
            sendMarker(o,'trialStop');
            handleEeg(o,o.eegAfterTrial);
        end


        function handleEeg(o,fun)
            % fun is a function_handle : either o.eegAfterTrial or
            % o.eegAfterFrame
            if isempty(o.eegChannels) || isempty(fun) 
                % Nothing to do
                return;
            end

            if o.fake
                nrSamples= 1000;
                nrChannels = numel(o.eegChannels);
                tmpEeg = rand([nrSamples nrChannels]);
                time = (0:(nrSamples-1))';
            elseif isempty(o.inlet)
                % Allow graceful exit
                o.writeToFeed('No EEG inlet...fake EEG');
                tmpEeg = [];
            else
                [tmpEeg,time] = o.inlet.pull_chunk;
                tmpEeg = tmpEeg(o.eegChannels,:)';
                time = time';
            end

            [nrSamples,nrChannels] = size(tmpEeg);
            if nrSamples ==0
                o.writeToFeed('No EEG Data received....?');
                tmpEeg = nan(1,nrChannels);
                time = nan;
            end


            if ~isempty(fun)
                try
                    fun(tmpEeg,time,o); % [nrSamples nrChannels]
                catch me
                    o.writeToFeed('The eeg analysis function failed');
                    me.message
                end
            end
            if o.eegStore
                o.eeg  = tmpEeg;
                o.eegTime = time;
            end
        end

        function afterExperiment(o)

            if isvalid(o.tmr)
                o.tmr.stop; % Stop the timer
            end

            switch upper(o.mode)            
                case 'EEGONLY'
                    %Nothing to do
                case 'NIC'
                    % Rely on NIC to handle the rampdown
                otherwise
                    rampDown(o); % Just to be sure (inc case the experiment was terminated early)..
            end

            
            % Always stop the protocol if it is still runnning
            if ~strcmpi(o.protocolStatus,'CODE_STATUS_IDLE')
                stop(o);
            end


            % Perform z-check ('ac', or 'dc' type)            
            if ~strcmpi(o.impedanceType,'NONE')
                impedance(o); % Measure and store the impedance.
            end
            unloadProtocol(o);

            if o.fake
                o.writeToFeed('Closing Markerstream');
            else
                if ~isempty(o.inlet)
                    o.inlet.close_stream;
                    o.inlet = []; % Force a delete
                end
                MatNICMarkerCloseLSL(o.markerStream);
                o.markerStream = [];
                close(o)
            end
            o.writeToFeed('Stimulation done. Connection with Starstim closed');
        end

    end



    methods (Access=protected)


        function sendMarker(o,m)

            if o.fake
                ret =0;                
            else
                ret = MatNICMarkerSendLSL(o.code(m),o.markerStream);                                
            end
            o.marker = o.code(m); % Log it
            checkFatalError(o,ret,['Deliver marker ' m]);
        end

        function v = perChannel(o,v)
            if isscalar(v)
                v = v*o.montage;
            end
        end

        %% Stimulation Control

        % Based on current parameters; ramp up the current. If this is a
        % sham mode, define a timer that will ramp down again.
        function rampUp(o,peakLevelDuration)
            if nargin<2
                peakLevelDuration =Inf;
            end

            waitFor(o,'PROTOCOL',{'CODE_STATUS_STIMULATION_FULL','CODE_STATUS_IDLE'});
            sendMarker(o,'rampUp');
            tSendUp = GetSecs;
            switch upper(o.type)
                case 'TACS'
                    msg{1} = sprintf('Ramping tACS up in %d ms to:',o.transition);
                    msg{2} = sprintf('\tCh#%d',1:o.NRCHANNELS);
                    msg{3} = sprintf('\t%d mA',perChannel(o,o.amplitude));
                    msg{4} = sprintf('\t%d Hz',perChannel(o,o.frequency));
                    msg{5} = sprintf('\t%d o ',perChannel(o,o.phase));
                    if o.fake
                        ret = 0;
                    else
                        % Note that this command sets freq and phase
                        % immediately and then ramps the amplitude. This
                        % only makes sense for ramping up from zero amplitude,
                        % hence it use here in the rampUp
                        [ret] = MatNICOnlinetACSChange(perChannel(o,o.amplitude), perChannel(o,o.frequency), perChannel(o,o.phase), o.NRCHANNELS, o.transition, o.sock);
                    end
                case 'TDCS'
                    msg{1} = sprintf('Ramping tDCS up in %d ms to:',o.transition);
                    msg{2} = sprintf('\tCh#%d',1:o.NRCHANNELS);
                    msg{3} = sprintf('\t%d mA',o.mean);
                    if o.fake
                        ret =0;
                    else
                        [ret] = MatNICOnlineAtdcsChange(perChannel(o,o.mean), o.NRCHANNELS, o.transition, o.sock);
                    end
                case 'TRNS'
                    msg{1} = sprintf('Turning on tRNS');
                    msg{2} = sprintf('\tCh#%d',1:o.NRCHANNELS);
                    msg{3} = sprintf('\t%d mA',o.amplitude);
                    setFilterTrns(o,true);
                    if o.fake
                        ret = 0;
                    else
                        [ret] = MatNICOnlineAtrnsChange(perChannel(o,o.amplitude), o.NRCHANNELS, o.sock);
                    end
                otherwise
                    ret= -100;
                    msg = ['Unknown stimulation type : ' o.type];
            end
            checkFatalError(o,ret,msg);
            sendMarker(o,'returnFromNIC'); % Confirm MatNICOnline completed (debuggin timing issues).
            waitFor(o,'PROTOCOL','CODE_STATUS_STIMULATION_FULL');
            tReachedPeak = GetSecs;          
            if o.sham
                peakLevelDuration =o.shamDuration;
            end

            % Schedule the rampDown. 
            if isfinite(peakLevelDuration)
                % I'm not sure waitFor(CODE_STATUS_STIMULATION_FULL) always
                % works with starstim; it seems as if this status is returend even
                % before the transition is complete. (and in Fake mode it returns immediately) 
                % Make sure the scheduled rampDown delay is never shorter than the
                % transition time.
                additionalDelay  = max(0,o.transition - (tReachedPeak-tSendUp));
                off  = @(timr,events,obj,tPeak) (rampDown(obj,tPeak));
                o.tmr.StartDelay = round(additionalDelay + peakLevelDuration)/1000; %\ seconds
                o.tmr.ExecutionMode='SingleShot';
                o.tmr.TimerFcn = {off,o,tReachedPeak};
                start(o.tmr);
            end

        end


        function rampDown(o,tScheduled)
            waitFor(o,'PROTOCOL',{'CODE_STATUS_STIMULATION_FULL','CODE_STATUS_IDLE'});
            if nargin ==2
                timeAtPeak = 1000*(GetSecs-tScheduled);
            else
                timeAtPeak = 0;
            end               
            sendMarker(o,'rampDown');
            if o.fake
                ret=0;
            else
                switch upper(o.type)
                    case 'TACS'
                        % USe this instaed of the MatNICOnlinetACSChange function: the latter changes e
                        %frequency and phase immediately, but ramps down the amplitude... that can never be current-conserved
                        %and Starstim will dump exccess current through the
                        % DRL (or CMS), which can cause a slap to the face...
                        [ret] = MatNICOnlineAtacsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                    case 'TDCS'
                        [ret] = MatNICOnlineAtdcsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                    case 'TRNS'
                        [ret] = MatNICOnlineAtrnsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.sock);
                        setFilterTrns(o,false); % Remove filter.
                    otherwise
                        o.cic.error('STOPEXPERIMENT',['Unknown stimulation type : ' o.type]);
                        ret= -1;
                end
            end
            checkFatalError(o,ret,sprintf('%s DownRamp (Transition: %d, peakTime %f)',o.type,o.transition,timeAtPeak));
            sendMarker(o,'returnFromNIC'); % Confirm MatNICOnline completed (debuggin timing issues).
        end


        %% Protocol start/pause/stop
        % Note that this stops stim as well as EEG. So in most usage this
        % is started once and stopped at the end fo the experiment.
        function start(o)
            o.verboseOutput('start','entry')
            % Start the current protocol.
            if o.fake
                ret = 0;
            else
                ret = MatNICStartProtocol(o.sock);
                switch (ret)
                    case 0
                        % All good.
                    case -10
                        % Already runnning
                        ret =0;
                    otherwise
                        %Nothind to do (fails below)
                end
                waitFor(o,'PROTOCOL',{'CODE_STATUS_STIMULATION_FULL','CODE_STATUS_EEG_ON'});
                % This waitFor is slow, and adds at least 1s to
                % the startup, but at least we're in a defined
                % state after the wait.
                % else already started
            end
            checkFatalError(o,ret,['Start protocol ' o.protocol ]);
            sendMarker(o,'protocolStarted');
            o.verboseOutput('start','exit')
        end



        function stop(o)
            % Stop the current protocol
            o.verboseOutput('stop','entry')
            sendMarker(o,'stopProtocol');
            if o.fake
                ret  = 0;
            elseif o.isProtocolOn
                ret = MatNICAbortProtocol(o.sock);
                if ret==-2 
                    % stopped
                    ret =0;
                else
                   % Some error
                end
                waitFor(o,'PROTOCOL',{'CODE_STATUS_PROTOCOL_ABORTED','CODE_STATUS_IDLE'});% Either of these is fine
            else
                % Nothing to do
                ret = 0;
            end
            checkFatalError(o,ret,['Stop protocol ' o.protocol ]);
            o.verboseOutput('stop','exit')
        end

        function pause(o)
            o.verboseOutput('pause','entry')
            % Pause the current protocol
            if o.fake
                ret = 0;                
            else
                ret = MatNICPauseProtocol(o.sock);
                if ret == -6
                    % Already paused
                    ret = 0;
                else
                    %Some error 
                end
                waitFor(o,'PROTOCOL','CODE_STATUS_IDLE');
            end
            checkFatalError(o,ret,['Pause protocol ' o.protocol s]);
            o.verboseOutput('pause','exit')
        end



        function impedance(o)
            % Measure and store impedance.
            % One problem with this impedance check is that, once it
            % completes, the status is CODE_STATUS_STIMULATION_FULL ; that caused
            % problems for some of the sanity checks in th code, but we try
            % to detect this now and proceed as if no stimuation is being
            % applied.

            if o.fake
                impedance = rand;
                ret = 0;
            elseif strcmpi(o.impedanceType,'NONE')
                % Only reading impedance that may or may not have been measured manually
                [ret,impedance] = MatNICGetImpedance(o.sock);
            else
                % Use the static function that is also used by zNow button in nsGui
                [ret,impedance] = neurostim.stimuli.starstim.manualImpedanceCheck(o.zProtocol,o.impedanceType,o.sock);
            end
            checkNonFatalError(o,ret,['zProtocol: ' o.zProtocol ' - '  o.impedanceType  ' z check : [' num2str(impedance(:)'/1000,2) '] kOhm']);
            o.z = impedance;  % Update the impedance.
        end

        function checkFatalError(o,ret,msg)
            if ret<0
                onExit(o);
                o.writeToFeed(['FATAL ERROR:' msg ' Status:' o.status ' ProtocolStatus: ' o.protocolStatus]);
                o.cic.error('STOPEXPERIMENT','StarStim generated a fatal error');
            elseif o.verbose
                o.writeToFeed(['SUCCESS: ' msg ' Status:' o.status ' ProtocolStatus: ' o.protocolStatus]);
            end
        end

        function checkNonFatalError(o,ret,msg)
            if ret<0
                o.writeToFeed(['NONFATAL ERROR:' msg ' Status:' o.status ' ProtocolStatus: ' o.protocolStatus]);
            elseif o.verbose
                o.writeToFeed(['SUCCESS: ' msg ' Status:' o.status ' ProtocolStatus: ' o.protocolStatus]);
            end
        end

        function onExit(o)
            if o.mustExit
                MatNICAbortProtocol(o.sock);
                timrs = timerfind('name','starstim.timer');
                if ~isempty(timrs)
                    delete(timrs)
                end
                MatNICUnloadProtocol(o.sock)
                close(o)
            end
            o.mustExit = false;
        end


        function waitFor(o,protocolOrStatus,varargin)
            % busy-wait for a sequence of status events.
            % waitFor(o,'a','b') first waits for a then for b
            % waitFor(o,{'a','b'}) waits for either a or b to occur

            cntr =1;
            nrInSequence = numel(varargin);
            TIMEOUT = 5;
            tic;
            while (cntr<=nrInSequence && ~o.fake)
                switch upper(protocolOrStatus)
                    case 'PROTOCOL'
                        nowStatus= o.protocolStatus;
                    case 'STATUS'
                        nowStatus = o.status;
                    otherwise
                        error('Unknonw mode')
                end

                if any(strcmpi(nowStatus,varargin{cntr}))
                    cntr= cntr+1;
                end
                pause(0.025); % Check status every 25 ms.
                if toc> TIMEOUT
                    if iscell(varargin{cntr})
                        stts = [varargin{cntr}{:}];
                    else
                        stts = varargin{cntr};
                    end
                    o.writeToFeed(['Waiting for ' stts ' timed out']);
                    o.writeToFeed(['Last protocol status was ' o.protocolStatus ]);
                    break;
                end
            end
            % disp([varargin{end} ' : ' num2str(toc) 's']);
        end

        function  ok = hasValidParameters(o)
            ok = true;
            if strcmpi(o.mode,'NIC')
                % Just doing what the NIC GUI plans. Always valid
                return;
            end
            % Floating point values result in zero current being applied by
            % Starstim. Flag an error.
            if any(~isnan(o.amplitude) & (round(o.amplitude) ~=o.amplitude & o.amplitude <=2000 & o.amplitude >=0))
                o.cic.error('STOPEXPERIMENT',['AC Amplitudes must be integer values (in micro ampere [0 2000]). Please correct:' num2str(o.amplitude)]);
                ok = false;
            end

            if any(~isnan(o.phase) & (round(o.phase) ~=o.phase | o.phase <0 | o.phase >359))
                o.cic.error('STOPEXPERIMENT',['AC phase must be integer values [0 359]. Please correct:' num2str(o.phase)]);
                ok = false;
            end


            if any(~isnan(o.frequency) & (round(o.frequency) ~=o.frequency | o.frequency <0))
                o.cic.error('STOPEXPERIMENT',['AC frequency must be integer values (in Hz  and >0). Please correct:' num2str(o.frequency)]);
                ok = false;
            end


            if any(~isnan(o.mean) & (round(o.mean) ~=o.mean & o.mean <=2000 & o.mean >=-2000))
                o.cic.error('STOPEXPERIMENT',['DC Mean Current must be integer values (in micro ampere [-2000 2000]). Please correct:' num2str(o.mean)]);
                ok = false;
            end


            %% Check current conservation.

            minF = max(o.frequency,0.01); % Lowest frequency 0.01Hz.
            t = repmat((0:0.1:(1/minF))',[1 o.NRCHANNELS]); % One cycle for all.
            nrT = size(t,1);
            acCurrent = repmat(perChannel(o,o.amplitude),[nrT 1]).*sin(pi/180*repmat(perChannel(o,o.phase),[nrT 1]) + 2*pi*t.*repmat(perChannel(o,o.frequency),[nrT,1]));
            currentThreshold = 1;% 1 muA excess is probably an error
            if any(abs(sum(acCurrent,2))>currentThreshold)
                o.cic.error('STOPEXPERIMENT','AC Current not conserved. Please check starstim.amplitude , .frequency , and .phase numbers');
                ok = false;
            end

            dcCurrent = sum(perChannel(o,o.mean));
            if dcCurrent> currentThreshold
                o.cic.error('STOPEXPERIMENT','DC Current not conserved. Please check starstim.mean');
                ok = false;
            end
        end

        function close(o)
            % Close connection with NIC
            if isa(o.sock,'java.net.Socket')
                close(o.sock)
                %else probably failed to create a sock...or fake
            end
        end

        function setFilterTrns(o,enable)
            if enable
                switch upper(o.tRNSFilter)
                    case 'OFF'
                        setFilterTrns(o,false);
                        return;
                    case 'ALPHA'
                        param1 = o.tRNSFilterParms(1);
                        param2 = 0; % Not used.
                    case 'LOW'
                        param1 = o.tRNSFilterParms(1);
                        param2 = 0; % Not used.
                    case 'HIGH'
                        param1 = o.tRNSFilterParms(1);
                        param2 = 0; % Not used.
                    case 'BANDPASS'
                        param1 = o.tRNSFilterParms(1);
                        param2 = o.tRNSFilterParms(2);
                end
                if o.fake
                    ret= 0; 
                else
                    ret = MatNICEnableTRNSFilter(o.tRNSFilter,param1,param2,o.sock);                    
                end
                checkFatalError(o,ret,sprintf('Set tRNS filter to %s with parameters [%3.2f %3.2f]',o.tRNSFilter,param1,param2));
            else
                if o.fake
                    ret= 0;
                else
                    [ret] = MatNICDisableTRNSFilter (o.sock);                    
                end
                checkFatalError(o,ret,'Disable tRNS filter');
            end
        end
    end

    methods (Static)
        % Classdef has changed over time; fix backward compatibility here.
        % This cannot be replaced with a generic plugin.loadoj as that function
        % will not know what kind of object Matlab just tried to load.
        function o= loadobj(o)
            if isstruct(o)
                % This saved object did not match the current classdef.
                % Create a current class def
                current = neurostim.stimuli.starstim(neurostim.cic('fromFile',true)); % Create current
                % And use this to update the old one:
                o = neurostim.plugin.updateClassDef(o,current);  % This updating is generic or all plugins
            end
            o.mustExit = false; % No active connection on load, so no need to exit.
        end

        function logOnset(s,flipTime)
            % This function sends a message to NIC to indicate that
            % a stimulus (s) just appeared on the screen (i.e. first frame flip)
            % I use a static function to make the notation easier for the
            % user, but by using CIC I nevertheless make use of the (only)
            % starstim object that is currently loaded.
            % INPUT
            % s =  stimulus that generated the onset event.
            % startTime = flipTime in clocktime (i.e. not relative to the
            % trial)
            s.cic.starstim.flipTime = flipTime;
            sendMarker(s.cic.starstim,'stimOnset'); % Send a marker to NIC.
        end


    end


    %% GUI Functions
    methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = eyelink plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            if strcmpi(parms.onOffFakeKnob,'Fake')
                o.fake=true;
            else
                o.fake =false;
            end
            o.host = parms.Host;
            o.impedanceType= parms.zType;
            o.verbose = parms.Verbose;
            if ~isempty(parms.zProtocol)
                o.zProtocol = parms.zProtocol;
            end
            if ~isempty(parms.ZNow.UserData)
                % The user has already connected to starstim with the ZNow
                % button. Re-use the socket and store the last measurement.
                if  o.fake
                    o.z = NaN;
                else
                    o.sock =  parms.ZNow.UserData.socket;
                    o.z = parms.ZNow.UserData.z;
                    if MatNICQueryStatus(o.sock)<0
                        o.writeToFeed('Could not connect to Starstim. Device disconnected?  Trying to reconnect.')
                        o.sock = []; % Force a reconnection
                    end
                end
            end
        end
    end

    methods (Static)

        function guiLayout(p)
            % Add plugin specific elements

            % HOST
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [110 39 30 22];
            h.Text = 'Host';
            h = uieditfield(p, 'text','Tag','Host');
            h.Position = [110 17 150 22];

            % Perform Z-Check beforeExperiment
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [270 39 90 22];
            h.Text = 'Z-Check';


            % Pick Z-type
            h = uidropdown(p,'Tag','zType','Items',{'None','AC','DC'});
            h.Position = [270 17 40 20];
            h.Tooltip = 'Select to perform a z-check before the first trial';

            % Specify zProtocol
            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [320 39 150 22];
            h.Text = 'Z-Protocol';
            h = uieditfield(p, 'text','Tag','zProtocol');
            h.Position = [320 17 150 22];
            h.Tooltip = 'Protocol to use for Z-checks with Z Now and before experiment starts.';

            % Button to do manual z-check
            h =uibutton(p,'push','Text','Z Now','Tag','ZNow','ButtonPushedFcn',@(btn,evt) neurostim.stimuli.starstim.zNowButtonClick(btn,p));
            h.Position  = [475 17 50 20];
            h.Tooltip = 'Press to perform a manual Z-check now';

            % Button to do manual z-check
            h =uicheckbox(p,'Text','Verbose','Tag','Verbose');
            h.Position  = [530 17 50 20];
            h.Tooltip = 'Check to show debugging output on the command line';

        end

        function zNowButtonClick(btn,pnl)
            % Make a direct connection (i.e. without using the starstim
            % object code) to start an impedance check.
            % This is meant for initial cap setup, as a replacement for the
            % button in the NIC gui, which is incompatible with the way we
            % interact with the device (protocol is loaded and the status is STIMULATION_FULL after the z-check in NIC).
            %
            % If this function has been used, then opon starting an actual experiment,
            %  the last z-values are stored in the starstim object(see
            %  guiSet) and the connection with the device is re-used.
            %
            % BK -  November 2021

            debug= false; %#ok<*UNRCH>
            parms = nsGui.getParms(pnl);
            if isempty(btn.UserData) ||     MatNICQueryStatus (btn.UserData.socket) ~=0
                % Try to connect
                if debug
                    fprintf('Connecting to %s\n',parms.Host);
                    ret = 0; socket= 0;
                else
                    [ret, status, socket] = MatNICConnect (parms.Host);
                end
                if ret==0
                    btn.UserData = struct('socket',socket,'z',nan);
                else
                    errordlg(sprintf('Could not connect to %s (Status: %s)\n',parms.host,status),'Z Now','modal');
                end
            else
                socket= btn.UserData.socket;
            end

            if ~strcmpi(parms.zType,'NONE') || isempty(parms.zProtocol)
                if debug
                    fprintf('Measuring z now....\n');
                    ret=0;z=rand(1,8)*10000;
                else
                    % Call the static function.
                    [ret,btn.UserData.z] = neurostim.stimuli.starstim.manualImpedanceCheck(parms.zProtocol,parms.zType,socket);
                end
                if ret==0
                    msgbox(char([parms.Host ' - Z (' parms.zType '):'], [ '[' num2str(btn.UserData.z(:)'/1e3,2) '] kOhm']),'Z Now');
                else
                    errordlg(sprintf('Z Measurement failed (Protocol: %s)',parms.zProtocol),'Z Now','modal');
                end
            else
                msgbox('Pick an impedance type (AC/DC) from the drop-down and specify a zProtocol.','Z Now');
            end
        end

        %  A function to perform zCheck with a specified protocol and
        %  type. Static function so that it can be used by the gui and by
        %  the object in beforeExperiment. Note that this unloads the
        %  current protocol and replaces with zProt.
        %  So use beforeExperiment or afterExperiment
        %  only.
        function [ret,z] = manualImpedanceCheck(zProt,zType,sock)
            if  isempty(zProt)
                warning('No z-Protocol specified');
                ret=-1;z=NaN;
                return
            end

            fprintf('*** Starting Impedance Check. Please wait. *** \n')
            MatNICUnloadProtocol(sock);
            MatNICLoadProtocol(zProt, sock);
            [~, z] = MatNICManualImpedance(zType, sock);
            [ret] = MatNICLoadProtocol(zProt, sock);
            fprintf('*** Completed Impedance Check.             *** \n')
        end
    end


end