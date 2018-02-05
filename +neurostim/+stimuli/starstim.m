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
    %
    % Note that all stimluation parameters will be set here in
    % in the starstim matlab stimulus. The (single step) protocol should just set all
    % **currents to zero**  and chose a very long duration. That way this
    % plugin can start the protocol (which will record EEG but stimulate
    % at 0 currents) and then change stimulation parameters on the fly.
    %
    % Filenaming convention for NIC output uses the name of the step in the
    % protocol. Leaving the step name blank creates cleaner file names
    % (YYYMMDDHHMMSS.subject.edf). This plugin creates a subdirectory with
    % the name of the Neurostim file to store the NIC output files (this
    % assumes Neurostim has access to the same folder as the machine running 
    % the NIC; or at least a machine with a similar folder name...).
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
        tmr; % A timer
    end
    
    
    % Dependent properties
    properties (Dependent)
        status@char;        % Current status (queries the NIC)
        protocolStatus@char;    % Current protocol status (queries the NIC)        
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
            o.addProperty('protocol',''); % Case Sensitive - must exist on host
            o.addProperty('fake',fake);
            o.addProperty('z',NaN);
            o.addProperty('stimType','');
            
            o.addProperty('amplitude',NaN);            
            o.addProperty('mean',NaN);
            o.addProperty('phase',0);
            o.addProperty('transition',100);
            o.addProperty('frequency',NaN);
            o.addProperty('sham',false);
            o.addProperty('enabled',true);
            
            
            o.addProperty('marker',''); % Used to log markers sent to NIC
            
            % Define  marker events to store in the NIC data file
            o.code('trialStart') = 1;
            o.code('rampUp') = 2;
            o.code('rampDown') = 3;            
            o.code('trialStop') = 4;
            o.code('returnFromNIC') = 5; % confirming online change return from function call.
            o.code('startProtocol') = 6;
            o.code('stopProtocol') = 7;
        end
        
        function beforeExperiment(o)
            
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
                [ret, stts, o.sock] = MatNICConnect(o.host);
                if ret<0
                    o.cic.error('STOPEXPERIMENT',['Could not connect to ',o.host]);
                end                                    
                o.mustExit = true;
                
                % This only makes sense if both the Neurostim computer and
                % the NIC computer have access to the same path. Otherwise
                % NIC will complain... 
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
            
            if ~hasValidParameters(o)
                return;
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
                    
                        
               
                otherwise
                    o.cic.error(['Unknown starstim mode :' o.mode]);
            end
            
          
        end
        
        function beforeFrame(o)
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
                    o.isTimedStarted =false;                   
                otherwise
                    o.cic.error(['Unknown starstim mode :' o.mode]);
            end
            
            % Send a trial start marker to the NIC
            sendMarker(o,'trialStop');
        end
        
        function afterExperiment(o)
            
            
            o.tmr.stop; % Stop the timer
            
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
                o.markerStream = [];
                close(o.sock);
            end
            o.writeToFeed('Stimulation done. Connection with Starstim closed');
            
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
                    o.writeToFeed('No marker stream to send markers');
                end
            end
        end
        
        function v = perChannel(o,v)
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
            
            sendMarker(o,'rampUp');
            switch upper(o.type)
                case 'TACS'
                    msg{1} = sprintf('Ramping tACS up in %d ms to:',o.transition);
                    msg{2} = sprintf('\tCh#%d',1:o.NRCHANNELS);
                    msg{3} = sprintf('\t%d mA',o.amplitude);
                    msg{4} = sprintf('\t%d Hz',o.frequency);
                    msg{5} = sprintf('\t%d o ',o.phase);
                    if o.fake
                        o.writeToFeed(msg);
                    else                                                 
                        [ret] = MatNICOnlinetACSChange(perChannel(o,o.amplitude), perChannel(o,o.frequency), perChannel(o,o.phase), o.NRCHANNELS, o.transition, o.sock);                        
                        o.checkRet(ret,msg);
                    end
                case 'TDCS'
                    msg{1} = sprintf('Ramping tDCS up in %d ms to:',o.transition);
                    msg{2} = sprintf('\tCh#%d',1:o.NRCHANNELS);
                    msg{3} = sprintf('\t%d mA',o.mean);
                    if o.fake
                        o.writeToFeed(msg);
                    else 
                        [ret] = MatNICOnlineAtdcsChange(perChannel(o,o.mean), o.NRCHANNELS, o.transition, o.sock);
                        o.checkRet(ret,msg);
                    end
                case 'TRNS'
                    o.checkRet(-1,'tRNS Not implemented yet');
                otherwise
                    error(['Unknown stimulation type : ' o.type]);
            end            
            sendMarker(o,'returnFromNIC'); % Confirm MatNICOnline completed (debuggin timing issues).
            
            if o.sham
                peakLevelDuration =0;
            end
            
            % Schedule the rampDown. Assuming that this line is executed
            % immediately after sending the rampup command to Starstim.
            if isfinite(peakLevelDuration)
                off  = @(timr,events,obj,tSchedule) (rampDown(obj,tSchedule));                
                o.tmr.StartDelay = (o.transition+peakLevelDuration)/1000; % seconds
                o.tmr.ExecutionMode='SingleShot';
                o.tmr.TimerFcn = {off,o,GetSecs};
                start(o.tmr);
            end
            
        end
        
        
        function rampDown(o,tScheduled)
            sendMarker(o,'rampDown');
            if o.fake
                if nargin ==2
                    o.writeToFeed('Ramping %s down to zero in %d ms after %.0f ms )',o.type, o.transition,1000*(GetSecs-tScheduled));
                else
                    o.writeToFeed('Ramping %s down to zero in %d ms',o.type, o.transition);
                end
            else
                waitFor(o,{'CODE_STATUS_STIMULATION_FULL','CODE_STATUS_IDLE'});
                switch upper(o.type)
                    case 'TACS'
                        [ret] = MatNICOnlinetACSChange(zeros(1,o.NRCHANNELS), zeros(1,o.NRCHANNELS), zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
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
            
            sendMarker(o,'startProtocol');          
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
            sendMarker(o,'returnFromNIC'); % Confirm MatNICOnline completed (debuggin timing issues).
        
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
            sendMarker(o,'returnFromNIC'); % Confirm MatNICOnline completed (debuggin timing issues).
       
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
            close(o.sock);
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
                    warning(['Waiting for ' varargin{cntr} ' timed out']);
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
            t = repmat((0:0.1:(1/min(o.frequency)))',[1 o.NRCHANNELS]); % One cycle for all.
            nrT = size(t,1);
            acCurrent = repmat(o.amplitude,[nrT 1]).*sin(pi/180*repmat(perChannel(o,o.phase),[nrT 1]) + 2*pi*t.*repmat(perChannel(o,o.frequency),[nrT,1]));
            currentThreshold = 1;% 1 muA excess is probably an error
            if any(abs(sum(acCurrent,2))>currentThreshold)
                o.cic.error('STOPEXPERIMENT','AC Current not conserved. Please check stastim.amplitude , .frequency , and .phase numbers');
                ok = false;
            end
            dcCurrent = sum(perChannel(o,o.mean));
            if dcCurrent> currentThreshold
                o.cic.error('STOPEXPERIMENT','DC Current not conserved. Please check starstim.mean');
                ok = false;
            end
        end
    end
    
    
end