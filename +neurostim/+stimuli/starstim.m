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
    % assumes Neurostim runs on the same machine as the NIC).
    %
    % There are different modes to operate this plugin, with increasing levels of
    % temporal and parameter control.  (.mode)
    % BLOCKED:
    %    Simplest mode: trigger the start of a named protocol in the first
    %   trial in which .enabled =true and keep running until a trial is about
    %   to start that has .enabled =false (or the end of the trial, whichever
    %   is earlier).
    %
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
    %  to be at least 100 ms. Ramp up starst at starstim.on time in each
    %  trial.
    %  This mode ignores .sham  (as you can implement your own by setting
    %  .duration to, say, 1 ms)
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
    % recommended (to ensure that every ITI is 2 s). In TIMED mode, the
    % sham stimulation will last 2*starstim.transition plus 1 frame.
    %
    % See startstimDemo for more details and examples
    %
    % BK - Feb 2016, 2017
    
    properties (SetAccess =public, GetAccess=public)
        stim@logical =false;
        impedanceType@char = 'DC'; % Set to DC or AC to measure impedance at DC or xx Hz AC.
        
        mode@char = 'BLOCKED'; % 'BLOCKED','TRIAL','TIMED'
        NRCHANNELS = 8;  % nrChannels in your device.
    end
    % Public Get, but set through functions or internally
    properties (SetAccess=protected, GetAccess= public)
        tacsTimer@timer =timer;    % Created as needed in o.tacs
        NICVersion;
        matNICVersion;
        code@containers.Map = containers.Map('KeyType','char','ValueType','double');
    end
    
    % Public Get, but set through functions or internally
    properties (Transient, SetAccess=protected, GetAccess= public)
        sock;               % Socket for communication with the host.
        markerStream;       % LSL stream to write markers in NIC
        impedanceCheck@logical = false; % Set to false to skip the Z-check at the start of the experiment (debug only)
        
        isOnlineStarted@logical = false;
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
                    v = ismember(stts,{'CODE_STATUS_PROTOCOL_RUNNING','CODE_STATUS_STIMULATION_FULL',});
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
        
        
        function v = get.nowType(o)
            v = o.stimType;
        end
        
        function v = get.nowAmplitude(o)
            if ~isempty(o.montage) && isscalar(o.amplitude)
                v = o.amplitude*o.montage;
            else
                v = expand(o,o.amplitude);
            end
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
            if o.fake;
                return;
            end
            stop(o);
            unloadProtocol(o);
            close(o.sock);
            
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
            
            o.addProperty('sham',false);
            o.addProperty('enabled',true);
            
            
             
            % Define  marker events to store in the NIC data file
            o.code('trialStart') = 1;
            o.code('stimStart') = 2;
            o.code('stimStop') = 3;
            o.code('trialStop') = 4;
        end
        
        function beforeExperiment(o)
            % Connect to the device, load the protocol.
            if o.fake
                o.writeToFeed(['Starstim fake conect to ' o.host]);
            else
                [ret, stts, o.sock] = MatNICConnect(o.host);
                o.checkRet(ret,['Host:' stts]);
                [pth,file] = fileparts(c.fullFile);
                pth = fullfile(pth,file);
                if ~exist(pth,'dir')
                    mkdir(pth);
                end
                ret  = MatNICConfigurePathFile (pth, o.sock); % Specify target directory
                o.checkRet(ret,'PathFile');
                % File format : % YYYYMMDD_[subject].edf
                % Always generate .easy file, and edf file (NIC requires
                % it), and generate .stim when stimulating.
                ret = MatNICConfigureFileNameAndTypes(c.subject,true,false,true,true,false,o.sock);
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
            
            %%
            % Delete any remaning timers (if the previous run was ok, there
            % should be none)
            % FUTURE WORK to get more fine grained control
            %             timrs = timerfind('name','starstim.tacs');
            %             if ~isempty(timrs)
            %                 o.writeToFeed('Deleting timer stragglers.... last experiment not terminated propertly?');
            %                 delete(timrs)
            %             end
            
            
            
            
            
        end
        
        function loadProtocol(o,prtcl)
            if nargin >1
                % new protocol defined
                unloadProtocol(o); % Unload current
                o.protocol= prtcl;
            end
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
        
        function unloadProtocol(o)
            if ~ischar(o.protocolStatus) || strcmpi(o.protocolStatus,'CODE_STATUS_IDLE')
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
            if o.fake
                o.writeToFeed('Starstim fake start stim');
                return;
            end
            
            
            %% Load the protocol if it has changed
            if ~strcmpi(o.protocol,o.activeProtocol)
                stop(o);
                unloadProtocol(o);
                loadProtocol(o);
            end
            switch upper(o.mode)
                case {'BLOCKED','TRIAL'}
                    if o.enabled
                        if ~o.isShamOn
                            start(o);  % If it is already on, it won't start again
                        end
                        if o.sham
                            pause(o);
                            o.isShamOn = true;
                        elseif o.isShamOn
                            start(o);
                            o.isShamOn = false;
                        end
                    else
                        pause(o);
                        o.isShamOn = false;
                    end
                case 'TIMED'
                    if o.enabled
                        start(o);
                    end
                    switch (o.nowType)
                        case 'DC'
                            % nothing to do here.
                        case 'AC'
                            ret = MatNICOnlineFtacsChange(o.nowFrequency, o.NRCHANNELS,o.sock);
                            o.checkRet(ret,'TIMED tACS frequency change failed');
                            ret = MatNICOnlinePtacsChange(o.nowPhase, o.NRCHANNELS, o.sock);
                            o.checkRet(ret,'TIMED tACS phase change failed');
                        case 'RNS'
                            disp('RNS Not implemented yet');
                    end
                otherwise
                    c.error(['Unknown starstim mode :' o.mode]);
            end
            
            % Send a trial start marker to the NIC
            ret = MatNICMarkerSendLSL(o.code('trialStart'),o.markerStream);
            if ret<0
                o.checkRet(ret,'Trialstart marker not delivered');
            end
            
        end
        
        function beforeFrame(o)
            if o.fake
                return;
            end
            switch upper(o.mode)
                case {'BLOCKED','TRIAL'}
                    % nothing to do
                    ret =0;
                case 'TIMED'
                    ret =0;
                    if ~o.isOnlineStarted
                        switch (o.nowType)
                            case 'DC'
                                ret = MatNICOnlineAtdcsChange(o.nowMean, o.NRCHANNELS, o.transition, o.sock);
                            case 'AC'
                                ret = MatNICOnlineAtacsPeak(o.nowAmplitude,o.NRCHANNELS,o.transition,o.duration,o.transition,o.sock);
                            case 'RNS'
                                disp('RNS Not implemented yet');
                                ret = -1;
                        end
                        o.isOnlineStarted = true;
                    elseif o.sham && ~o.isShamOn
                        % Ramp back down
                        switch (o.nowType)
                            case 'DC'
                                ret = MatNICOnlineAtdcsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                            case 'AC'
                                ret = MatNICOnlineAtacsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                            case 'RNS'
                                disp('RNS Not implemented yet');
                                ret = -1;
                        end
                        o.isShamOn = true;
                    end
                    
                otherwise
                    c.error(['Unknown starstim mode :' o.mode]);
            end
            if ret<0
                o.checkRet(ret,[ o.nowType  ' parameter change failed']);
            end
            
        end
        
        function afterTrial(o) 
            if o.fake
                o.writeToFeed('Starstim fake afterTrial stim');
                return;
            end
            
            ret = 0;
            
            switch upper(o.mode)
                case 'BLOCKED'
                    % Nothing to do (trigger mode keeps running across ITI/trials)
                case 'TRIAL'
                    pause(o);
                    % Indicate that the current pause is not the sham. (Otherwise a sham trial
                    % following a sham trial would not ramp up; see beforeTrial)
                    o.isShamOn = false;
                case 'TIMED'
                    if o.itiOff && o.isOnlineStarted
                        switch (o.nowType)
                            case 'DC'
                                ret = MatNICOnlineAtdcsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                            case 'AC'
                                ret = MatNICOnlineAtacsChange(zeros(1,o.NRCHANNELS), o.NRCHANNELS, o.transition, o.sock);
                            case 'RNS'
                                disp('RNS Not implemented yet');
                                ret = -1;
                        end
                        if ret<0
                            o.checkRet(ret,['Turning off ' o.nowType  ' stim after trial failed']);
                        end
                        o.isOnlineStarted = false;
                    end
                    o.isShamOn = false;
                otherwise
                    c.error(['Unknown starstim mode :' o.mode]);
            end
            
            % Send a trial start marker to the NIC
            ret = MatNICMarkerSendLSL(o.code('trialStop'),o.markerStream);
            if ret<0
                o.checkRet(ret,'trialStop marker not delivered');
            end
            
        end
        
        function afterExperiment(o) 
            if o.fake
                o.writeToFeed('Starstim fake afterExperiment');
                return;
            end
            
            % Always stop the protocol if it is still runnning
            if ~strcmpi(o.protocolStatus,'CODE_STATUS_IDLE')
                stop(o);
            end
            
            % Mode specific clean up?
            switch upper(o.mode)
                case 'BLOCKED'
                case 'TRIAL'
                case 'TIMED'
                otherwise
                    c.error(['Unknown starstim mode :' o.mode]);
            end
            
            %           % FUTURE WORK to get more fine grained control
            %             timrs = timerfind('name','starstim.tacs');
            %             if ~isempty(timrs)
            %                 o.writeToFeed('Deleting timer stragglers.... last experiment not terminated propertly?');
            %                 delete(timrs)
            %             end
            %
            
            if o.impedanceCheck
                impedance(o);
            end
            
            unloadProtocol(o);
            MatNICMarkerCloseLSL(o.markerStream);
            close(o.sock);
            
        end
    end
    
    
    
    methods (Access=protected)
        
        function v = expand(o,v)
            if isscalar(v)
                v = v*ones(1,o.NRCHANNELS);
            end
        end
        
        % FUTURE WORK to get more fine grained control     use timers in matlab
        %         function tacs(o,amplitude,channel,transition,duration,frequency)
        %             % function tacs(o,amplitude,channel,transition,duration,frequency)
        %             % Apply tACS at a given amplitude, channel, frequency. The current is ramped
        %             % up and down in 'transition' milliseconds and will last 'duration'
        %             % milliseconds (including the transitions).
        %
        %             if duration>0 && isa(o.tacsTimer,'timer') && isvalid(o.tacsTimer) && strcmpi(o.tacsTimer.Running,'off')
        %                 c.error('STOPEXPERIMENT','tACS pulse already on? Cannot start another one');
        %             end
        %
        %             if o.fake
        %                 o.writeToFeed([ datestr(now,'hh:mm:ss') ': tACS frequency set to ' num2str(frequency) ' on channel ' num2str(channel)]);
        %             else
        %                 ret = MatNICOnlineFtacsChange (frequency, channel, o.sock);
        %                 o.checkRet(ret,'FtacsChange');
        %             end
        %             if o.fake
        %                 o.writeToFeed(['tACS amplitude set to ' num2str(amplitude) ' on channel ' num2str(channel) ' (transition = ' num2str(transition) ')']);
        %             else
        %                 ret = MatNICOnlineAtacsChange(amplitude, channel, transition, o.sock);
        %                 o.checkRet(ret,'AtacsChange');
        %             end
        %
        %             if duration ==0
        %                 toc
        %                 stop(o.tacsTimer); % Stop it first (it has done its work)
        %                 delete (o.tacsTimer); % Delete it.
        %             else
        %                 % Setup a timer to end this stimulation at the appropriate
        %                 % time
        %                 tic
        %                 off  = @(timr,events,obj,chan,trans) tacs(obj,0*chan,chan,trans,0,0);
        %                 o.tacsTimer  = timer('name','starstim.tacs');
        %                 o.tacsTimer.StartDelay = (duration-2*transition)/1000;
        %                 o.tacsTimer.ExecutionMode='SingleShot';
        %                 o.tacsTimer.TimerFcn = {off,o,channel,transition};
        %                 start(o.tacsTimer);
        %             end
        %
        %         end
        
        function start(o)
            % Start the current protocol.
            if o.fake
                o.writeToFeed('Start Stim');
            elseif ~o.isProtocolOn
                ret = MatNICStartProtocol(o.sock);
                o.checkRet(ret,['Protocol ' o.protocol ' could not be started']);
                waitFor(o,'CODE_STATUS_STIMULATION_FULL');
                % This waitFor is slow, and adds at least 1s to
                % the startup, but at least we're in a defined
                % state after the wait.
                %else already started
            end
        end
        
        function stop(o)
            % Stop the current protocol
            if o.fake
                o.writeToFeed('Stimulation stopped');
            elseif o.isProtocolOn
                ret = MatNICAbortProtocol(o.sock);
                o.checkRet(ret,['Protocol ' o.protocol ' could not be stopped']);
                %else -  already stopped
            end
            
        end
        
        function pause(o)
            % Pause the current protocol
            if o.fake
                o.writeToFeed('Stimulation stopped');
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
                close(o.sock);
                o.cic.error('STOPEXPERIMENT',['StarStim failed: Status ' o.status ':  ' num2str(ret) ' ' msg]);
            end
        end
        
        
        function waitFor(o,varargin)
            % busy-wait for a sequence of status events.
            cntr =1;
            nrInSequence = numel(varargin);
            TIMEOUT = 5;
            tic;
            while (cntr<=nrInSequence && toc <TIMEOUT)
                if strcmpi(o.protocolStatus,varargin{cntr})
                    cntr= cntr+1;
                end
                pause(0.1); % Check status every 100 ms.
            end
        end
        
    end
    
    
end