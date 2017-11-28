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
    %
    % A protocol (defined in the NIC) specifies which electrodes are
    % connected, which record EEG, and which stimulate. You select a protocol
    % by providing its name (case-sensitive) to the starstim plugin constructor.
    % In the 'BLOCKED' and 'TRIAL' mode, the protocol as defined in the NIC
    % interface is run "as is" (i.e. except for starting/pausing/stopping
    % the protocol, there are no changes to its parameters).
    %
    % Filenaming convention for NIC output uses the name of the step in the
    % protocol. Leaving the step name blank creates cleaner file names
    % (YYYMMDDHHMMSS.subject.edf). This plugin creates a subdirectory with
    % the name of the Neurostim file to store the NIC output files (this
    % assumes Neurostim runs on the same machine as the NIC; see below).
    %
    % There are different modes to operate this plugin, with increasing levels of
    % temporal and parameter control.  (.mode)
    % BLOCKED:
    %    Simplest mode: trigger the start of a named protocol in the first
    %   trial in which .enabled =true and keep running until a trial is about
    %   to start that has .enabled =false (or the end of the experiment, whichever
    %   is earlier).Note that the .transition variable is ignored in this
    %   mode: the ramp duration in the protocol is used instead.
    % TRIAL:
    %   Start the rampup of the protocol before each .enabled=true trial, then
    %   and ramp it down after each such trial. Because pausing/starting takes
    %    1-2 s this only works for long trials.
    %
    % TIMED:
    %  Here stimulation starts in each .enabled=true trial at starstim.on
    %  The parameters of stimulation are set here in Neurostim by defining
    %  .amplitude, .frequency, .phase and a fixed duration. (note that if
    %  you use a Neurostim function for the duration, it will be evaluated
    %  before the start of the trial, and not updated during the trial). To
    %  use this mode, you should define a protocol that identifies all
    %  electrodes, but has zero current for each. Those values are then
    %  overruled by Neurostim.
    %  Ramping up/down is controlled by the .transition parameter which has
    %  to be at least 100 ms. Ramp up starts at starstim.on time in each
    %  trial.
    %
    % In each mode, you can switch NIC protocols by assinging a new value to
    % .protocol. This switch is done before the trial in which .protocol
    % gets its new value. The time needed to do this is incorporated into
    % the ITI.
    %
    % In each mode , you can use sham stimulation (.sham =
    % true); this means that the protcol will ramp up and immediately down
    % again. In BLOCKED and TRIAL mode, the minimum transition time defined in
    % NIC is 1s, this takes ~2s, so setting the iti in CIC to 2s is
    % recommended (to ensure that every ITI is 2 s).
    %
    % See startstimDemo for more details and examples
    %
    % PERFORMANCE:
    %  The NIC software, especially when it is actively stimulating, puts a
    %  heavy load on the CPU and, if running on the same machine as
    %  Neurostim, can lead to frequent framedrops (which, becuase it
    %  depends on stimulation, coudl correlate with an experimental
    %  design!). So it is highly recommended to run NIC on a separate
    %  machine, connecting to it via TCP/IP is trivial (just provide the IP
    %  number of the NIC machine in the constructor)
    %
    % BK - Feb 2016, 2017
    
    properties (SetAccess =public, GetAccess=public)
        stim@logical =false;
        impedanceType@char = 'DC'; % Set to DC or AC to measure impedance at DC or xx Hz AC.
        type = 'tACS'; %tACS, tDCS, tRNS
        mode@char = 'BLOCKED'; % 'BLOCKED','TRIAL','TIMED'
        NRCHANNELS = 8;  % nrChannels in your device.
        debug = false;
    end
    % Public Get, but set through functions or internally
    properties (SetAccess=protected, GetAccess= public)
        NICVersion;
        matNICVersion;
        code@containers.Map = containers.Map('KeyType','char','ValueType','double');
        mustExit@logical = false;
        
    end
    
    % Public Get, but set through functions or internally
    properties (Transient, SetAccess=protected, GetAccess= public)
        sock;               % Socket for communication with the host.
        markerStream;       % LSL stream to write markers in NIC
        impedanceCheck@logical = false; % Set to false to skip the Z-check at the start of the experiment (debug only)
        
        isTimedStarted@logical = false;
        isShamOn@logical = false;
        
        activeProtocol@char='';
    end
    
    
    % Dependent properties
    properties (Dependent)
        status@char;        % Current status (queries the NIC)
        protocolStatus@char;    % Current protocol status (queries the NIC)
        nowType@char;
        nowAmplitude@double;
        nowFrequency@double;
        nowPhase@double;
        nowTransition@double;
        nowMean@double;
        isProtocolOn@logical;
        isProtocolPaused@logical;
    end
    
    methods % get/set dependent functions
        function [v] = get.status(o)
            if o.fake
                v = ' Fake OK';
            else
                [~, v] = MatNICQueryStatus(o.sock);
            end
        end
        
        function v = get.protocolStatus(o)
            if o.fake
                v = ' Fake Protocol OK';
            else
                [~, v] = MatNICQueryStatusProtocol(o.sock);
            end
        end
        
        function v= get.isProtocolOn(o)
            if o.fake
                v =true;
            else
                stts = o.protocolStatus;
                if isempty(stts) || ~ischar(stts)
                    v =false;
                else
                    v = ismember(stts,{'CODE_STATUS_PROTOCOL_RUNNING','CODE_STATUS_STIMULATION_FULL','CODE_STATUS_STIMULATION_RAMPUP'});
                end
                if o.debug
                    o.writeToFeed(stts);
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
                if o.debug
                    o.writeToFeed(stts);
                end
            end
        end
        
        
        
        function v = get.nowAmplitude(o)
            if ~isempty(o.montage) && isscalar(o.amplitude)
                v = o.amplitude*o.montage;
            else
                v = expand(o,o.amplitude);
            end
            v=round(v); % If the currents are float, starstim does nothing...
        end
        
        function v = get.nowFrequency(o)
            v = expand(o,o.frequency);
        end
        
        function v = get.nowPhase(o)
            v = expand(o,o.phase);
        end
        
        function v = get.nowTransition(o)
            v = o.transition;
        end
        
        function v=get.nowMean(o)
            v = expand(o,o.mean);
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
            
            v = which('MatNICVersion');
            if isempty(v)
                error('The MatNIC library is not on your Matlab path');
            end
            
            o=o@neurostim.stimulus(c,'starstim');
            fake = strcmpi(hst,'fake');
            if nargin <2
                hst = 'localhost';
            end
            
            o.addProperty('host',hst);
            o.addProperty('protocol',''); % Case Sensitive
            o.addProperty('fake',fake);
            o.addProperty('z',NaN);
            o.addProperty('stimType','');
            o.addProperty('itiOff',true);
            
            o.addProperty('amplitude',NaN);
            o.addProperty('montage',[]);
            o.addProperty('mean',NaN);
            o.addProperty('phase',0);
            o.addProperty('transition',NaN);
            o.addProperty('frequency',NaN);
            o.addProperty('multiTrialDuration',0);
            o.addProperty('sham',false);
            o.addProperty('enabled',true);
            
            
            
            % Define  marker events to store in the NIC data file
            o.code('trialStart') = 1;
            o.code('stimStart') = 2;
            o.code('stimStop') = 3;
            o.code('trialStop') = 4;
        end
        
        function beforeExperiment(o)
            
            %% Remove straggling timers
            timrs = timerfind('name','starstim.timer');
            if ~isempty(timrs)
                o.writeToFeed('Deleting timer stragglers.... last experiment not terminated propertly?');
                delete(timrs)
            end
            
            %% Connect to host - check some prerequisites/setup
            if o.fake
                o.writeToFeed(['Starstim connected to ' o.host]);
            else
                [ret, stts, o.sock] = MatNICConnect(o.host);
                o.checkRet(ret,['Host:' stts]);
                o.mustExit = true;
                
                pth = o.cic.fullFile; % This is without the extension
                if ~exist(pth,'dir')
                    mkdir(pth);
                end
                ret  = MatNICConfigurePathFile (pth, o.sock); % Specify target directory
                o.checkRet(ret,'PathFile');
                % File format : % YYYYMMDD_[subject].edf
                % Always generate .easy file, and edf file (NIC requires
                % it), and generate .stim when stimulating.
                ret = MatNICConfigureFileNameAndTypes(o.cic.subject,true,false,true,true,false,o.sock);
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
                end
            end
        end
        
        function unloadProtocol(o)
            if o.fake || ~ischar(o.protocolStatus) || strcmpi(o.protocolStatus,'CODE_STATUS_IDLE') || strcmpi(o.protocolStatus,'CODE_STATUS_STIMULATION_FULL')
                return; % No protocol loaded.
            end
            ret = MatNICUnloadProtocol(o.sock);
            if ret<0
                o.checkRet(ret,'Could not unload the current protocol.')
            else
                o.activeProtocol ='';
            end
        end

                
        
        
        function beforeTrial(o)
            %% Load the protocol if it has changed
            if ~strcmpi(o.protocol,o.activeProtocol)
                stop(o);
                unloadProtocol(o);
                loadProtocol(o);
                start(o);  % Start it (protocols should have zero current and a long duration)
            end
            
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
                    %                     if o.enabled
                    %                         start(o);
                    %                         waitFor(o,'CODE_STATUS_STIMULATION_FULL');
                    %                     end
                    %                     switch (o.nowType)
                    %                         case 'DC'
                    %                             % nothing to do here.
                    %                         case 'AC'
                    %                             ret = MatNICOnlineFtacsChange(o.nowFrequency, o.NRCHANNELS,o.sock);
                    %                             o.checkRet(ret,'TIMED tACS frequency change failed');
                    %                             ret = MatNICOnlinePtacsChange(o.nowPhase, o.NRCHANNELS, o.sock);
                    %                             o.checkRet(ret,'TIMED tACS phase change failed');
                    %                         case 'RNS'
                    %                             disp('RNS Not implemented yet');
                    %                     end
                otherwise
                    o.cic.error(['Unknown starstim mode :' o.mode]);
            end
            
            sendMarker(o,'trialStart'); % Mark in Starstim data file
            
        end
        
        function beforeFrame(o)
            switch upper(o.mode)
                case {'BLOCKED','TRIAL'}
                    % These modes do not change stimulation within a
                    % trial/block - nothing to do.
                case 'TIMED'
                    %                     % Single shot start
                    %                     ret =0;
                    %                     if ~o.isTimedStarted
                    %                         waitFor(o,'CODE_STATUS_STIMULATION_FULL');
                    %                         switch (o.nowType)
                    %                             case 'DC'
                    %                                 ret = MatNICOnlineAtdcsChange(o.nowMean, o.NRCHANNELS, o.nowTransition, o.sock);
                    %                             case 'AC'
                    %                                 if o.duration>=10000
                    %                                     %% Use a timer in matlab
                    %                                     off  = @(timr,events,obj) (timerOff(obj));
                    %                                     tmr= timer('name','starstim.timer');
                    %                                     tmr.StartDelay = (o.duration-o.nowTransition)/1000;
                    %                                     tmr.ExecutionMode='SingleShot';
                    %                                     tmr.TimerFcn = {off,o};
                    %                                     ret = MatNICOnlineAtacsChange(o.nowAmplitude,o.NRCHANNELS,o.nowTransition,o.sock);
                    %                                     start(tmr);
                    %                                 else
                    %                                     ret = MatNICOnlineAtacsPeak(o.nowAmplitude,o.NRCHANNELS,o.nowTransition,o.duration,o.nowTransition,o.sock);
                    %                                 end
                    %                             case 'RNS'
                    %                                 disp('RNS Not implemented yet');
                    %                                 ret = -1;
                    %                         end
                    %                         o.isTimedStarted = true;
                    %                     end
                    %                      if ret<0
                    %                         o.checkRet(ret,[ o.nowType  ' parameter change failed']);
                    %                     end
                otherwise
                    o.cic.error(['Unknown starstim mode :' o.mode]);
            end
            
        end
        
        function afterTrial(o)
            switch upper(o.mode)
                case 'BLOCKED'
                    if o.cic.blockDone
                        rampDown(o);
                    end
                case 'TRIAL'
                    if ~o.sham
                        % Rampdown unless this is a sham trial (which has a rampdown scheduled)
                        rampDown(o);
                    end
                case 'TIMED'
                    %                     o.isTimedStarted =false;
                    %waitFor(o,'CODE_STATUS_IDLE');
                otherwise
                    o.cic.error(['Unknown starstim mode :' o.mode]);
            end
            
            % Send a trial start marker to the NIC
            sendMarker(o,'trialStop');
        end
        
        function afterExperiment(o)
            
            
            timrs = timerfind('name','starstim.timer');
            if ~isempty(timrs)
                delete(timrs)
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
                MatNICMarkerCloseLSL(o.markerStream);
                close(o.sock);
            end
            o.writeToFeed('Stimulation done. Connection with Starstim closed');
            
        end
    end
    
    
    
    methods (Access=protected)
        
        
        function sendMarker(o,m)
            if o.fake
                writeToFeed(o,[m ' marker delivered']);
            else
                ret = MatNICMarkerSendLSL(o.code(m),o.markerStream);
                if ret<0
                    o.checkRet(ret,[m ' marker not delivered']);
                end
            end
        end
        
        function v = expand(o,v)
            if isscalar(v)
                v = v*ones(1,o.NRCHANNELS);
            end
        end
        
        %% Stimulation Control
        
        % Based on current parameters; ramp up the current. If this is a
        % sham mode, define a timer that will ramp down again.
        function rampUp(o,peakLevelDuration)
            if nargin<2
                peakLevelDuration =Inf;
            end
            
            if o.fake
                o.writeToFeed('Ramping up in %3.3fms to:',o.nowTransition);
                tbl = [o.nowAmplitude;o.nowFrequency;o.nowPhase];
                o.writeToFeed(['\n' sprintf('%3.1fmA \t %3.0fHz \t %3.0f deg\n',tbl)]);
            else
                switch upper(o.type)
                    case 'TACS'
                        [ret] = MatNICOnlinetACSChange(o.nowAmplitude, o.nowFrequency, o.nowPhase, o.NRCHANNELS, o.nowTransition, o.sock);
                        tbl = [o.nowAmplitude;o.nowFrequency;o.nowPhase];
                        checkRet(ret,sprintf('tACS upRamp (Transition: %d) \n %s',o.nowTransition,['\n' sprintf('%3.1fmA \t %3.0fHz \t %3.0f deg\n',tbl)]));
                    case 'TDCS'
                        [ret] = MatNICOnlineAtdcsChange(o.nowMean, o.NRCHANNELS, o.nowTransition, o.sock);
                        checkRet(ret,sprintf('tDCS upRamp (Transition: %d): %d mA',o.nowTransition,o.nowMean));
                    case 'TRNS'
                        checkRet(-1,'tRNS Not implemented yet');
                    otherwise
                        error(['Unknown stimulation type : ' o.type]);
                end
            end
            
            if o.sham
                peakLevelDuration =0;
            end
            
            % Schedule the rampDown. Assuming that this line is executed
            % immediately after 
            if isfinite(peakLevelDuration)
                off  = @(timr,events,obj) (rampDown(obj));
                tmr= timer('name','starstim.timer');
                tmr.StartDelay = (o.nowTransition+peakLevelDuration)/1000; % microseconds
                tmr.ExecutionMode='SingleShot';
                tmr.TimerFcn = {off,o};
                start(tmr);
            end
              
        end
        
        
        function rampDown(o)
            if o.fake
                o.writeToFeed('Ramping down to zero in %d ms',o.nowTransition);
            else
                switch upper(o.type)
                    case 'TACS'
                        [ret] = MatNICOnlinetACSChange(zeros(1,o.NRCHANNELS), zeros(1,o.NRCHANNELS), zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.nowTransition, o.sock);                        
                        checkRet(ret,sprintf('tACS DownRamp (Transition: %d)',o.nowTransition));
                    case 'TDCS'
                        [ret] = MatNICOnlineAtdcsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.nowTransition, o.sock);
                        checkRet(ret,sprintf('tDCS DownRamp (Transition: %d)',o.nowTransition));
                    case 'TRNS'
                        checkRet(-1,'tRNS Not implemented yet');
                    otherwise
                        error(['Unknown stimulation type : ' o.type]);
                end
            end
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
                waitFor(o,'CODE_STATUS_STIMULATION_FULL');
                % This waitFor is slow, and adds at least 1s to
                % the startup, but at least we're in a defined
                % state after the wait.
                % else already started
            end
        end
        
        
        
        function stop(o)
            % Stop the current protocol
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
                o.cic.error('STOPEXPERIMENT',['StarStim failed: Status ' o.status ':  ' num2str(ret) ' ' msg]);
            end
        end
        
        function onExit(o)
            stop(o);
            timrs = timerfind('name','starstim.timer');
            if ~isempty(timrs)
                delete(timrs)
            end
            unloadProtocol(o);
            close(o.sock);
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
                    warning(['Waiting for ' varargin{cntr} ' timed out']);
                    warning(['Last status was ' o.protocolStatus ]);
                    break;
                end
            end
            % disp([varargin{end} ' : ' num2str(toc) 's']);
        end
        
    end
    
    
end