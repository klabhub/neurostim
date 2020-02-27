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
    % For impedance checking a separate protocol has to be used (with
    % current>100 muA).
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
    %
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
    
    properties (SetAccess =public, GetAccess=public)
        stim=false;
        impedanceType= 'DC'; % Set to DC or AC to measure impedance at DC or xx Hz AC.
        NRCHANNELS = 8;  % nrChannels in your device.
        debug = false;
        
        % EEG parms that need fast acces (and therefore not a property)
        eegAfterTrial = []; % Function handle fun(eeg,time,starstimObject)
        eegAfterFrame = []; % Functiona handle fun(eeg,time,starstimObject)
        eegStore= false; % Store the eeg data in the starstim object.
        eegInit= false; % Set to true to initialize eeg stream before experiment (and do not wait until the first trial with non empty o.eegChannels)
    end
    % Public Get, but set through functions or internally
    properties (SetAccess=protected, GetAccess= public)
        NICVersion;
        matNICVersion;
        code= containers.Map('KeyType','char','ValueType','double');
        mustExit= false;
        
        lsl=[];  % The LsL library
        inlet=[];  % An LSL inlet
        
    end
    
    % Public Get, but set through functions or internally
    properties (Transient, SetAccess=protected, GetAccess= public)
        sock;               % Socket for communication with the host.
        markerStream;       % LSL stream to write markers in NIC
        impedanceCheck= false; % Set to false to skip the Z-check at the start of the experiment (debug only)
        
        isTimedStarted= false;
        isShamOn= false;
        
        activeProtocol='';
        tmr; % A timer
    end
    
    
    % Dependent properties
    properties (Dependent)
        status;        % Current status (queries the NIC)
        protocolStatus;    % Current protocol status (queries the NIC)
        isProtocolOn;
        isProtocolPaused;
    end
    
    methods % get/set dependent functions
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
        
        function abort(o)
            stop(o);
        end
        function disp(o)
            disp(['Starstim Host: ' o.host  ' Status: ' o.status]);
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
            o.addProperty('z',NaN);
            o.addProperty('type','tACS');%tACS, tDCS, tRNS
            o.addProperty('mode','BLOCKED');  % 'BLOCKED','TRIAL','TIMED','EEGONLY'
            o.addProperty('path',''); % Set to the folder on the starstim computer where data should be stored.
            % If path is empty, the path of the neurostim output file is
            % used (which may not exist on the remote starstim computer).
            
            o.addProperty('amplitude',NaN);
            o.addProperty('mean',NaN);
            o.addProperty('phase',0);
            o.addProperty('transition',100);
            o.addProperty('frequency',NaN);
            o.addProperty('sham',false);
            o.addProperty('shamDuration',0); % 0 ms means rampup, and immediately ramp down.
            o.addProperty('enabled',true);
            o.addProperty('montage',ones(1,o.NRCHANNELS));%
            
            
            o.addProperty('marker',''); % Used to log markers sent to NIC
            o.addProperty('flipTime',[]); % USed to record fliptimes in logOnset function
            
            
            o.addProperty('eegChannels',[]); % Default to no EEG.
            o.addProperty('eegMaxBuffered',360);% Samples in seconds in buffer.
            o.addProperty('eegRecover',true);  % Try to recover lost connections
            o.addProperty('eegChunkSize',0); % nr samples per chunk (0 = use senders default)
            o.addProperty('eeg',[]); % Collects eeg data per pull (but only if eegStore ==true)
            o.addProperty('eegTime',[])% Starstim time corresponding to eeg data.
            
            % Define  marker events to store in the NIC data file
            o.code('trialStart') = 1;
            o.code('rampUp') = 2;
            o.code('rampDown') = 3;
            o.code('trialStop') = 4;
            o.code('returnFromNIC') = 5; % confirming online change return from function call.
            o.code('protocolStarted') = 6;
            o.code('stopProtocol') = 7;
            o.code('stimOnset') = 8;
            
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
                [ret, ~, o.sock] = MatNICConnect(o.host);
                if ret<0
                    o.cic.error('STOPEXPERIMENT',['Could not connect to ',o.host]);
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
                o.checkRet(ret,'PathFile');
                % File format : % YYYYMMDD_[subject].edf
                % Always generate .easy file, and edf file (NIC requires
                % it), and generate .stim when stimulating.
                % Change in 4.07:
                % patientName, recordEasy, recordNedf, recordSD, recordEDF,
                % socket  (no more STIM file)
                ret = MatNICConfigureFileNameAndTypes(o.cic.subject,true,true,false,true,o.sock);
                o.checkRet(ret,'FileNameAndTypes');
                [ret,o.markerStream] = MatNICMarkerConnectLSL('Neurostim');
                o.checkRet(ret,'Please enable the Neurostim Marker Stream in NIC');
                
                key = keys(o.code);
                vals = values(o.code);
                for i=1:length(o.code)
                    [ret] = MatNICConfigureMarkers (key{i}, vals{i}, o.sock);
                    o.checkRet(ret,['Define marker: ' key{i}]);
                end
                protocolSet = MatNICProtocolSet();
                o.matNICVersion = protocolSet('MATNIC_VERSION');
            end
            unloadProtocol(o); % Remove whatever is loaded currently (if anything)
            % Prepare for EEG reading
            if (~isempty(o.eegChannels) || o.eegInit) && ~o.fake
                openEegStream(o);
                
            end
        end
        
        function openEegStream(o)
            % This will do nothing if the stream is already open, but
            % create a stream otherwise.
            if isempty(o.lsl)
                o.lsl = lsl_loadlib;
            end
            
            if isempty(o.inlet)
                stream = lsl_resolve_byprop(o.lsl,'type','EEG');
                if isempty(stream)
                    error('Failed to creat an EEG inlet');
                else
                    o.inlet = lsl_inlet(stream{1},o.eegMaxBuffered,o.eegChunkSize,double(o.eegRecover));
                    o.inlet.open_stream;% Start buffering
                end
            end
        end
        
        function loadProtocol(o,prtcl)
            if nargin >1
                % new protocol defined
                unloadProtocol(o); % Unload current
                o.protocol= prtcl;
            end
            
            if o.fake
                o.writeToFeed([o.protocol ' protocol loaded'])
                o.activeProtocol = o.protocol;
            else
                % Load the protocol
                if ~strcmpi(o.protocolStatus,'CODE_STATUS_IDLE')
                    o.checkRet(-1,'A protocol is currently running on the NIC. Please stop it first')
                end
                ret = MatNICLoadProtocol(o.protocol,o.sock);
                if ret ~=0
                    o.checkRet(ret,['Protocol ' o.protocol ' is not defined in NIC']);
                else
                    o.activeProtocol = o.protocol;
                    % Would be nice to set everything to zero in the potocol so that only the
                    % parameters defined here (in Neurostim) will be
                    % applied. But, the OnlineChange functions in MatNIC
                    % only work after the protocol has started so the
                    % following code will not work (even after modifying the MatNIC code
                    % to get teh message passed to NIC). (Instead, the user
                    % should define a zero-current protocol, but this has
                    % the disadvantage that a separate protocol is needed
                    % to do Impedance checks.
                    %[ret] = MatNICOnlineAtacsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                     %     o.checkRet(ret,sprintf('tACS DownRamp (Transition: %d)',o.transition));
                     %    [ret] = MatNICOnlineAtdcsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                      %   o.checkRet(ret,sprintf('tDCS DownRamp (Transition: %d)',o.transition));

                end
            end
        end
        
        function unloadProtocol(o)
            if o.fake || ~ischar(o.protocolStatus) || ismember(o.protocolStatus,{'CODE_STATUS_IDLE','CODE_STATUS_STIMULATION_FULL','error/unknown'})
                return; % No protocol loaded.
            end
            ret = MatNICUnloadProtocol(o.sock);
            if ret==-8 % protocol running abort
                stop(o);
                % Then try again
                unloadProtocol(o);
            elseif ret<0
                o.checkRet(ret,'Could not unload the current protocol.')
            else
                o.activeProtocol ='';
            end
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
            if ~isempty(o.eegChannels) && ~o.fake
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
                    
                case 'EEGONLY'
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
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown starstim mode :' o.mode]);
            end
        end
        
        function afterFrame(o)
            %handleEeg(o,o.eegAfterFrame); DISABLED FOR NOW - not likely to be fast enough... need some pacer.
        end
        
        function afterTrial(o)
            switch upper(o.mode)
                case 'BLOCKED'
                    if o.cic.blockDone && o.enabled
                        rampDown(o);
                    end
                case 'TRIAL'
                    if ~o.sham
                        % Rampdown unless this is a sham trial (which has a rampdown scheduled)
                        rampDown(o);
                    end
                case 'TIMED'
                    o.isTimedStarted =false;
                case 'EEGONLY'
                    %nothing to do
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
            if isempty(o.eegChannels) || (isempty(fun) && ~o.eegStore)
                % Nothing to do
                return;
            end
            
            if o.fake
                nrSamples= 1000;
                nrChannels = numel(o.eegChannels);
                tmpEeg = rand([nrSamples nrChannels]);
                time = (0:(nrSamples-1))';
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
            if ~strcmpi(o.mode,'EEGONLY')
                rampDown(o); % Just to be sure (inc case the experiment was terminated early)..
            end
            % Always stop the protocol if it is still runnning
            if ~strcmpi(o.protocolStatus,'CODE_STATUS_IDLE')
                stop(o);
            end
            
            if o.impedanceCheck
                impedance(o);
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
        
        function troubleShoot(o)
            %%
            %             beforeExperiment(o);
            %             loadProtocol(o);
            %             start(o);
            %             %%
            %             o.mean = [-1000 1000 0 0 0 0 0 0];
            %             %for i=1:10
            %                rampUp(o,250);
            %              %   wait(o.tmr)
            %             %end
        end
    end
    
    
    
    methods (Access=protected)
        
        
        function sendMarker(o,m)
            
            if o.fake
                writeToFeed(o,[m ' marker delivered']);
                o.marker = o.code(m); % Log it
            else
                if ~isempty(o.markerStream)
                    ret = MatNICMarkerSendLSL(o.code(m),o.markerStream);
                    o.marker = o.code(m); % Log it
                    if ret<0
                        o.checkRet(ret,[m ' marker not delivered']);
                    end
                else
                    %o.writeToFeed('No marker stream to send markers');
                end
            end
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
            
            waitFor(o,{'CODE_STATUS_STIMULATION_FULL','CODE_STATUS_IDLE'});
            sendMarker(o,'rampUp');
            switch upper(o.type)
                case 'TACS'
                    msg{1} = sprintf('Ramping tACS up in %d ms to:',o.transition);
                    msg{2} = sprintf('\tCh#%d',1:o.NRCHANNELS);
                    msg{3} = sprintf('\t%d mA',perChannel(o,o.amplitude));
                    msg{4} = sprintf('\t%d Hz',perChannel(o,o.frequency));
                    msg{5} = sprintf('\t%d o ',perChannel(o,o.phase));
                    if ~o.fake
                        % Note that this command sets freq and phase
                        % immediately and then ramps the amplitude. This
                        % only makes sense for ramping up from zero amplitude,
                        [ret] = MatNICOnlinetACSChange(perChannel(o,o.amplitude), perChannel(o,o.frequency), perChannel(o,o.phase), o.NRCHANNELS, o.transition, o.sock);
                        o.checkRet(ret,msg);
                    end
                case 'TDCS'
                    msg{1} = sprintf('Ramping tDCS up in %d ms to:',o.transition);
                    msg{2} = sprintf('\tCh#%d',1:o.NRCHANNELS);
                    msg{3} = sprintf('\t%d mA',o.mean);
                    if ~o.fake
                        [ret] = MatNICOnlineAtdcsChange(perChannel(o,o.mean), o.NRCHANNELS, o.transition, o.sock);
                        o.checkRet(ret,msg);
                    end
                case 'TRNS'
                    msg{1} = '??? tRNS not implemented yet';
                    o.checkRet(-1,'tRNS Not implemented yet');
                otherwise
                    error(['Unknown stimulation type : ' o.type]);
            end
            sendMarker(o,'returnFromNIC'); % Confirm MatNICOnline completed (debuggin timing issues).
            
            waitFor(o,'CODE_STATUS_STIMULATION_FULL');
            tReachedPeak = GetSecs;
            
            if o.fake || o.debug
                o.writeToFeed(msg);
            end
            
            if o.sham
                peakLevelDuration =o.shamDuration;
            end
            
            % Schedule the rampDown. Assuming that this line is executed
            % immediately after sending the rampup command to Starstim.
            if isfinite(peakLevelDuration)
                off  = @(timr,events,obj,tPeak) (rampDown(obj,tPeak));
                o.tmr.StartDelay = peakLevelDuration/1000; %\ seconds
                o.tmr.ExecutionMode='SingleShot';
                o.tmr.TimerFcn = {off,o,tReachedPeak};
                start(o.tmr);
            end
            
        end
        
        
        function rampDown(o,tScheduled)
            
            waitFor(o,{'CODE_STATUS_STIMULATION_FULL','CODE_STATUS_IDLE'});
            if o.fake || o.debug
                if nargin ==2
                    o.writeToFeed(sprintf('Ramping %s down to zero in %d ms after %.0f ms at peak level )',o.type, o.transition,1000*(GetSecs-tScheduled)));
                else
                    o.writeToFeed(sprintf('Ramping %s down to zero in %d ms',o.type, o.transition));
                end
            end
            sendMarker(o,'rampDown');
            if ~o.fake
                switch upper(o.type)
                    case 'TACS'
                        %Do NOT use the MatNICOnlinetACSChange function: it will chnage
                        %frequency and phase immediately, but ramp down the
                        %amplitude... that can never be current-conserved
                        %and Starstim will dump exccess current through the
                        %DRL (or CMS), which can cause a slap to the
                        %face...
                        [ret] = MatNICOnlineAtacsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                        o.checkRet(ret,sprintf('tACS DownRamp (Transition: %d)',o.transition));
                    case 'TDCS'
                        [ret] = MatNICOnlineAtdcsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                        o.checkRet(ret,sprintf('tDCS DownRamp (Transition: %d)',o.transition));
                    case 'TRNS'
                        o.checkRet(-1,'tRNS Not implemented yet');
                    otherwise
                        error(['Unknown stimulation type : ' o.type]);
                end
            end
            sendMarker(o,'returnFromNIC'); % Confirm MatNICOnline completed (debuggin timing issues).
            
            
        end
        
        
        %% Protocol start/pause/stop
        % Note that this stops stim as well as EEG. So in most usage this
        % is started once and stopped at the end fo the experiment.
        function start(o)
            % Start the current protocol.
            
            if o.fake
                o.writeToFeed(['Started' o.protocol ' protocol' ]);
            elseif ~o.isProtocolOn
                ret = MatNICStartProtocol(o.sock);
                if ret==0
                    o.writeToFeed(['Started ' o.protocol ' protocol']);
                else
                    o.checkRet(ret,['Protocol ' o.protocol ' could not be started']);
                end
                waitFor(o,{'CODE_STATUS_STIMULATION_FULL','CODE_STATUS_EEG_ON'});
                % This waitFor is slow, and adds at least 1s to
                % the startup, but at least we're in a defined
                % state after the wait.
                % else already started
            end
            sendMarker(o,'protocolStarted');
            
        end
        
        
        
        function stop(o)
            % Stop the current protocol
            sendMarker(o,'stopProtocol');
            if o.fake
                o.writeToFeed(['Stopped ' o.protocol ' protocol']);
            elseif o.isProtocolOn
                ret = MatNICAbortProtocol(o.sock);
                if ret==-2
                    return
                    % already stopped
                else
                    o.checkRet(ret,['Protocol ' o.protocol ' could not be stopped']);
                end
                %else -  already stopped
                waitFor(o,{'CODE_STATUS_PROTOCOL_ABORTED','CODE_STATUS_IDLE'});% Either of these is fine
            end
            
            
        end
        
        function pause(o)
            % Pause the current protocol
            if o.fake
                o.writeToFeed(['Paused ' o.protocol ' protocol']);
            elseif ~o.isProtocolPaused
                ret = MatNICPauseProtocol(o.sock);
                o.checkRet(ret,['Protocol ' o.protocol ' could not be paused']);
                waitFor(o,'CODE_STATUS_IDLE');
                %  else already paused
            end
        end
        
        
        
        function impedance(o)
            % Measure and store impedance.
            if o.fake
                impedance = rand;
            else
                % Do a impedance check and store current values (protocol
                % must be loaded, but not started).
                [ret,impedance] = MatNICManualImpedance(o.impedanceType,o.sock);
                o.checkRet(ret,'Impedance check failed');
            end
            o.writeToFeed(['Impedance check done:' num2str(impedance)]);
            o.z = impedance;  % Update the impedance.
        end
        
        function checkRet(o,ret,msg)
            % Check a return value and display a message if something is
            % wrong.
            if ret<0
                onExit(o)
                o.writeToFeed(msg);
                o.cic.error('STOPEXPERIMENT',['StarStim failed: Status ' o.status ':  ' num2str(ret)]);
            end
        end
        
        function onExit(o)
            stop(o);
            timrs = timerfind('name','starstim.timer');
            if ~isempty(timrs)
                delete(timrs)
            end
            unloadProtocol(o);
            close(o)
            o.mustExit = false;
        end
        
        function waitFor(o,varargin)
            % busy-wait for a sequence of status events.
            % waitFor(o,'a','b') first waits for a then for b
            % waitFor(o,{'a','b'}) waits for either a or b to occur
            
            cntr =1;
            nrInSequence = numel(varargin);
            TIMEOUT = 5;
            tic;
            while (cntr<=nrInSequence && ~o.fake)
                if any(strcmpi(o.protocolStatus,varargin{cntr}))
                    cntr= cntr+1;
                end
                pause(0.025); % Check status every 25 ms.
                if toc> TIMEOUT
                    if iscell(varargin{cntr})
                        stts = [varargin{cntr}{:}];
                    else
                        stts = varargin{cntr};
                    end
                    warning(['Waiting for ' stts ' timed out']);
                    warning(['Last status was ' o.protocolStatus ]);
                    break;
                end
            end
            % disp([varargin{end} ' : ' num2str(toc) 's']);
        end
        
        function  ok = hasValidParameters(o)
            ok = true;
            
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
    end
    
    methods (Static)
        function o= loadobj(o)
            if isstruct(o)
                % Update to current classdef.
                current = neurostim.stimuli.starstim(neurostim.cic('fromFile',true)); % Create current
                fromFile = o;
                %-- This cannot be moved to a function/script due to class access
                %permissions.
                m= metaclass(current);
                dependent = [m.PropertyList.Dependent];
                % Find properties that we can set now (based on the stored fromFile object)
                settable = ~dependent & (strcmpi({m.PropertyList.SetAccess},'public') | strcmpi({m.PropertyList.SetAccess},'protected'));  %~strcmpi({m.PropertyList.SetAccess},'private') & ~[m.PropertyList.Constant];
                storedFn = fieldnames(fromFile);
                missingInSaved  = setdiff({m.PropertyList(settable).Name},storedFn);
                missingInCurrent  = setdiff(storedFn,{m.PropertyList(~dependent).Name});
                toCopy= intersect(storedFn,{m.PropertyList(settable).Name});
                fprintf('Fixing backward compatibility of stored Neurostim object')
                fprintf('\t Not defined when saved (will get current default values) : %s \n', missingInSaved{:})
                fprintf('\t Not defined currently (will be removed) : %s \n' , missingInCurrent{:})
                for i=1:numel(toCopy)
                    try
                        current.(toCopy{i}) = fromFile.(toCopy{i});
                    catch
                        fprintf('\t Failed to set %s(will get current default value)\n', toCopy{i})
                    end
                end
                % ---
                o = current;
            end
            o.mustExit = false;
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
        end
     end
     
    methods (Static)       

     function guiLayout(p)
            % Add plugin specific elements

            h = uilabel(p);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [110 39 30 22];
            h.Text = 'Host';
            
            h = uieditfield(p, 'text','Tag','Host');
            h.Position = [110 17 200 22];
        end
    end
    
    
end