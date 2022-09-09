classdef stg < neurostim.stimulus
    % Plugin used to communicate with the MultiChannel Systems Stimulator
    % (e.g. STG4002).
    %
    % On Windows this uses the .NET libraries provided by MultiChannel Systems.
    % These are available at https://github.com/multichannelsystems/McsUsbNet.git
    %
    % Before using this stimulus, you should clone that repository to some
    % folder on your machine, and in your code, set the .libRoot property of the
    % stg stimulus to point to that folder.
    %
    % You should also install MC Stimulus II on your
    % computer (www.multichannelsystems.com/software/mc-stimulus-ii) for
    % the drivers that come with it. That standalone app adds some useful
    % testing and debugging potential, too.
    %
    % The connection/initialization of the device
    % happens in the beforeExperiment() function; device parameters cannot
    % be changed after that.
    %
    % *** IMPORTANT ***
    % [channels]  should always be specified in base-1: Channel 1 is the
    % first channel.
    % [currents] in user functions should always be defined in mA (and user
    % accessible functions in this object return current measures in mA).
    % [voltage] in user functions should always be defined in mV (and user
    % accessible functions in this object return voltage measures in mV).
    %
    % To define stimulation parameters, set the following properties:
    %
    % fun - This can be a stimulation mode ('tDCS', 'tACS','tRNS') or a
    %       function handle that takes a vector of times in milliseconds as
    %       its first input, and the STG object as its second input (so
    %       that you can use its properties as set in the "current" trial
    %       to modify the output of the function). The output of the
    %       function should be a vector of currents/voltages in milliamps
    %       or millivolts with a length that matches its first input
    %       argument (i.e., the time vector)
    % duration - Duration of stimulation [ms]
    % channel - A single channel number (base-1)
    % syncOutChannel - Channel for sync-out pulse (optional, base-1)
    % mean - Mean (DC) value of current/voltage [mA/mV].
    % frequency - Frequency of sinusoidal tACS [Hz]
    % amplitude - Amplitude of sinusoid [mA/mV]  (ignored for tDCS)
    % phase - Phase of sine [degrees]
    % rampUp - Duration of linear ramp-up [ms]
    % rampDown - Duration of linear ramp-down [ms]
    % nrRepeats - How often the stimulsu should be repeated. For instance
    % for a periodic stimulus; define duration as one period, and repeat it
    % as often as you like. This saves memory on the STG. Note that a
    % constant stimlus is also periodic, so a tDCS stimulus should also use
    % nrRepeats> 0.
    %
    % Each of these parameters can be specified as a scalar (thus applying
    % to all channels equally) or as a vector with a different entry for
    % each channel. For 'fun', use a cell array with one element per
    % channel.
    %
    % EXAMPLE
    %   stg.libRoot = 'c:/github/McsUsb/';  % Point to the Git repo with .NET libraries
    %   stg.channel = [1 2];  % Stimulate both channel 1 and 2
    %   stg.fun  = 'tDCS'
    %   stg.mean = [1 -1]
    %   stg.duration =1000;
    %   This will do 1000 ms of anodal stimulation on the first channel (together with its
    %   return) and cathodal on the second.
    %   To stimulate for longer periods of time, use the nrRepeats
    %   parameter, otherwise your STG's memory will fill up.
    %
    % EXAMPLE
    %  To define a 10 second long 10 Hz sine, define 1 cycle (i.e. 100 ms) and set
    %  nrRepeats to 100;
    % stg.func ='tACS';
    % stg.frequency =10;
    % stg.amplitude =0.5;
    % stg.duration = 100;
    % stg.repeats = 100;
    %
    % The nrRepeats should also be used for your own function stimuli that
    % can be repeated (to prevent the STG memory from filling up).
    %
    % BK - June 2018
    %
    % ## Programming notes
    % The temporal resolution of the device is 20 mus/50 kHz.
    % Even though there is a NET command to set this rate, it does not work.
    % The support on the MCS website stated that output
    % rate cannot be set on (some) STG devices, so this is disabled here.
    %

        
    properties (Constant)
        streamingBufferThreshold = 50; % refill the PC buffer when it drops below 50%.
        outputRate = 50e3; % 50 Khz is fixed
        LOOPPAUSE = 1; % wait one second when starting/stopping hte streaming loop
    end

    properties (SetAccess = public)
        debugStream = false;
    end
    properties (SetAccess = protected)
        chunkStartTime; % [ms]
        nrRefills; % Count how many times the streamingDataHandler is called to fill a channel.

        triggerTime = [];
        triggerSent = false;

        vRange;  % Voltage range [mV], per channel
        iRange;  % Current range [mA], per channel
        vResolution;  % Voltage resolution in mV per channel
        iResolution;% Curretn resolution in mA per channel
        nrChannels;
        nrSyncOutChannels;
        totalMemory; % device memory in bytes.
        rampDownComplete =false;
    end

    properties (SetAccess = protected, Transient)
        device =[]; % handle to the device, once connected.
        assembly=[]; % The .Net assembly
        deviceList;  % List of all devices on USB
        deviceListEntry; % The device in the list that we will connect to (the first one, currently)
        cleanupObj; % Object to handle cleanup in o.cleanup
        isStreaming =false;
        isDownload = true;
        forceDownRampFrom = inf; % Used to signal an early stop of stimulation.

    end

    properties (Dependent =true)
        isConnected; % Boolean
        chunkBytes; % number bytes per chunk (PC buffer is updated in "chunks" and STG memory is 1 chunk (for each trigger))
        chunkDuration; % Duration in ms.
        pcBufferBytes; % Bytes allocated to the ring bugger on the PC.
    end

    %get/set
    methods
        function v = get.pcBufferBytes(o)
            % When the streamDataHandler is called, we want to have 1 chunk
            % available (so that it can be filled)
            v = (o.streamingBufferThreshold/100+1)*o.chunkBytes;
        end

        function v = get.isConnected(o)
            % Boolean to check whether the device is connected.
            v = o.fake || (~isempty(o.device) && o.device.IsConnected());
        end

        function v =get.chunkBytes(o)
            % #Samples per chunk *2 bytes/sample
            v = 2*ceil(o.chunkDuration/1000*o.outputRate);
        end

        function v =get.chunkDuration(o)
            % Worst case is a full buffer (1+x)*chunkDuration=latency.
            v = ceil(o.streamingLatency*(1+o.streamingBufferThreshold/100));
        end
    end

    methods

        function cleanup(o)
            % This is called when the object is cleared from memory
            % (cleanupObj was setup with oncleanup) to make sure we
            % discconnect.Not sure this really works though...
            if isvalid(o) && ~isempty(o.device)
                if o.isStreaming
                    o.device.StopLoop;
                    pause(o.LOOPPAUSE);
                end
                o.device.Disconnect;
            end
        end

        function o = stg(c)
            % Constructor
            % c = handle to CIC
            %
            % The constructor only initializes the Matlab object with properties.
            % Connection to the device happens in beforeExperiment.

            o = o@neurostim.stimulus(c,'stg');

            o.addProperty('fake',false);

            % Location of Net libraries
            o.addProperty('libRoot','');

            % Read-only properties
            o.addProperty('deviceName','');
            o.addProperty('hwVersion','');
            o.addProperty('manufacturer','');
            o.addProperty('product','');
            o.addProperty('serialNumber','');

            % Read/write properties.
            o.addProperty('currentMode',true);
            o.addProperty('downloadMode',true);
            o.addProperty('streamingLatency',100); % Allowable latency in streaming mode
            o.addProperty('enabled',true);
            o.addProperty('mode','TRIAL');%,@(x) (ischar(x) && ismember(upper(x),{'TRIAL','BLOCK','TIMED'})));

            % Stimulation properties
            o.addProperty('fun','tDCS','validate',@(x) (isa(x,'function_handle') || (ischar(x) && ismember(x,{'tDCS','tACS','tRNS'}))));
            o.addProperty('channel',[]);
            o.addProperty('streamingChannels',[]);
            o.addProperty('mean',0);
            o.addProperty('frequency',0);
            o.addProperty('amplitude',0);
            o.addProperty('phase',0);
            o.addProperty('rampUp',0);
            o.addProperty('rampDown',0);
            o.addProperty('syncOutChannel',[]);
            o.addProperty('nrRepeats',1);
            o.addProperty('sham',false);


        end





        function beforeExperiment(o)
            tic
            if o.fake;return;end
            %% Load the relevant NET assembly if necessary
            asm = System.AppDomain.CurrentDomain.GetAssemblies;
            assemblyIsLoaded = any(arrayfun(@(n) strncmpi(char(asm.Get(n-1).FullName), 'McsUsbNet', length('McsUsbNet')), 1:asm.Length));
            if ~assemblyIsLoaded
                if isempty(o.libRoot) || ~exist(o.libRoot,'dir')
                    error('The STG stimulus relies on the .NET libraries that are available on GitHub (https://github.com/multichannelsystems/McsUsbNet.git). \n Clone those first and point stg.libRoot to the local folder');
                end
                switch computer
                    case 'PCWIN64'
                        sub = 'x64';
                    otherwise
                        error(['Sorry, the MCS .NET libraries are not available on your platform: ' computer]);
                end
                lib = fullfile(o.libRoot,sub);
                if ~exist(lib,'dir')
                    error('The %s folder with does not exist.',lib);
                end
                lib = fullfile(lib,'McsUsbNet.dll');
                if ~exist(lib,'file')
                    error('The .NET library file (%s) does not exist.',lib);
                end
                o.assembly = NET.addAssembly(lib);
            end
            import Mcs.Usb.*

            %% Search devices.
            o.deviceList = CMcsUsbListNet(DeviceEnumNet.MCS_STG_DEVICE);
            nrDevices =  o.deviceList.GetNumberOfDevices();
            if nrDevices >1
                % For now just warn - selection could be added.
                warning(o,'Found more than one STG device; using the first one');
            end
            if nrDevices ==0
                error('No STG device connected');
            end
            % Get a handle to the first in the list
            o.deviceListEntry    = o.deviceList.GetUsbListEntry(0);
            % Get some of its properties to store
            o.deviceName = char(  o.deviceListEntry.DeviceName);
            o.hwVersion = char(  o.deviceListEntry.HwVersion);
            o.manufacturer = char(  o.deviceListEntry.Manufacturer);
            o.product = char(  o.deviceListEntry.Product);
            o.serialNumber  = char(  o.deviceListEntry.SerialNumber);

            %% Connect
            o.isStreaming = ~o.downloadMode;
            o.isDownload = o.downloadMode; % Local copies for faster access
            connect(o);        

            if o.isStreaming
                % Start the loop before the first trial
                o.device.StartLoop;                
                pause(o.LOOPPAUSE);  
            end
        end

        function beforeTrial(o)
            %% Depending on the mode, do something
            switch upper(o.mode)
                case 'BLOCK'
                    % Starts before the first trial in a block
                    % (cannot be done in beforeBlock as the parms for the
                    % condition in the block will not have been set yet).
                    if o.cic.blockTrial ==1 && o.enabled
                        prepareStimulus(o);
                        start(o);
                    end
                case 'TRIAL'
                    if o.enabled
                        prepareStimulus(o);
                        start(o); % Trigger it now
                    end
                case 'TIMED'
                    if o.enabled
                        if o.isDownload
                            prepareStimulus(o);
                            % trigger in beforeFrame
                        end
                    end
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown STG mode :' o.mode]);
            end
        end

        function beforeFrame(o)
            % Send a start trigger to the device
            switch upper(o.mode)
                case {'BLOCK','TRIAL'}
                    % These modes do not change stimulation within a
                    % trial/block - nothing to do.
                case 'TIMED'
                    % Start the first time beforeFrame is called
                    if ~o.triggerSent && o.enabled
                        start(o);
                    end
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown STG mode :' o.mode]);
            end
        end

        function afterTrial(o)
            switch upper(o.mode)
                case 'BLOCK'
                    % Nothing to do
                case {'TRIAL','TIMED'}
                    stop(o);
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown STG mode :' o.mode]);
            end
        end


        function afterBlock(o)
            switch upper(o.mode)
                case 'BLOCK'                    
                    stop(o);                    
                otherwise
                    % Nothing  to do
            end
        end

        function afterExperiment(o)
            % Discconnect from the device.
            stop(o);
            
            disconnect(o);
            delete(o.deviceList); o.deviceList =[];
            delete(o.device); o.device = [];
        end

    end


    methods (Access=public)
        function mask = chan2mask(o,channels)
            % Convert an array of  base-1 channel number to a channel bit mask
            if any(channels>o.nrChannels | channels<1)
                error(o.cic,['stg Channels should be between 1 and ' num2str(o.nrChannels)]);
            end
            mask = uint32(0);
            for c= channels
                mask = bitor(mask,bitset(mask,c));
            end
        end

        function start(o)
            % Trigger the stimulation.            
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not start stg. Device not connected.'); %#ok<*CTPCT>
            else
                o.nrRefills = zeros(1,o.nrChannels);
                if o.fake
                    o.writeToFeed('Start Stimulation');
                else
                    o.device.SendStart(chan2mask(o,o.channel)); % Trigger channels                
                end                
                o.triggerTime = o.cic.clockTime;    
            end    
            o.triggerSent = true;
        end

        function stop(o)
            % Stop the triggered channels from continuing.
            if ~o.triggerSent;return;end % Nothing to do.
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not stop stg. Device not connected.');
            else
                 if o.isDownload
                     if o.fake
                        o.writeToFeed('Stop Stimulation');
                     else
                        % Hard stop
                        o.device.SendStop(chan2mask(o,o.channel));
                     end
                else
                    o.forceDownRampFrom = o.chunkStartTime;                   
                    while ~o.rampDownComplete
                        pause(.5);
                        fprintf('Waiting for ramp down\n')
                    end
                    pause(o.streamingLatency/1000);
                 end               
            end
            o.triggerSent = false;
        end

        function keyboard(o,key)
            % Only used in debugStream mode to fake a datahandler call from
            % STG.
            switch upper(key)
                case 'T'
                    for c=o.channel
                        streamingDataHandler(o,c-1); % Fake a call from STG (base-0)
                    end

            end
        end

        function streamingDataHandler(o,trigger)
            % Called from the .NET libraries when the PC buffer is below
            % the threshold and needs to be refilled. Errors in this
            % function will cause Matlab to crash...
            if ~o.isConnected
                o.writeToFeed('Streaming data handler called when STG was not connected (ignored)');
                return;
            end
            % trigger is a uint32 from STG, which is base-0.
            % To avoid calls from unused triggers, set their
            % callbackthrshold to 0 (see setupTriggers).
            % Because setupTriggers maps triggers to channels:
            thisChannel = trigger+1;             % base -1            
            spaceInBytes = double(o.device.GetDataQueueSpace(thisChannel-1));
            if spaceInBytes==o.pcBufferBytes && ~(o.nrRefills(thisChannel)==0)
                o.writeToFeed(sprintf('Data streaming underflow. Increase your latency (%.0f)? ',o.streamingLatency))
            end
            if spaceInBytes >= o.chunkBytes
                o.nrRefills(thisChannel)  = o.nrRefills(thisChannel)+1;
                if ~ismember(thisChannel,o.channel)
                    o.writeToFeed(sprintf(' streamingDataHandler for channel (%d, base-1) from STG - output set to zero (channel not in use this trial)',thisChannel));
                    thisChunk = zeros(1,o.chunkDuration/1000*o.outputRate);
                    isFinalRamp = false;
                else                
                    [thisChunk,isFinalRamp] = stimulusForStream(o,thisChannel);
                end
              
                if o.currentMode
                    thisChunk = (2^15-1)*thisChunk/o.iRange(thisChannel);
                else
                    thisChunk = (2^15-1)*thisChunk/o.vRange(thisChannel);
                end
                data = NET.convertArray(thisChunk, 'System.Int16');
                nrQueued = o.device.EnqueueData(thisChannel-1, data);
                if isFinalRamp 
                    % Wait until the samples that were left pluse the new
                    % chunk (which inlcudes the final ramp) are done.
                    secs = (o.pcBufferBytes-spaceInBytes)/2/o.outputRate+o.chunkDuration/1000;
                    WaitSecs(secs);
                    o.rampDownComplete = true; % Signal 
                end
                o.writeToFeed(sprintf('Channel %d: Buffer space %d bytes (chunk = %d), que %d bytes.', thisChannel, spaceInBytes,o.chunkBytes,nrQueued));
            end
        end

        function streamingErrorHandler(~,varargin)
            fprintf('Error handler\n')
        end

        function connect(o)
            % Connect to the device and setup the devic
            if o.fake
                o.writeToFeed('Connect to STG');
                return
            end
            if ~o.isConnected
                if o.isDownload
                    % Use download mode
                    o.device  = Mcs.Usb.CStg200xDownloadNet;
                else
                    % Use streaming mode.
                    % Reserve room on the PC ring buffer  (1 more than
                    % calculated - for some reason the .Net routines
                    % allocate 1 less than what is specified here).
                    if o.debugStream
                        o.device  = Mcs.Usb.CStg200xStreamingNet(o.pcBufferBytes+1);
                        addKey(o,'t','Trigger data handler',false);
                    else
                        o.device  = Mcs.Usb.CStg200xStreamingNet(o.pcBufferBytes+1,@o.streamingDataHandler,@o.streamingErrorHandler); % Use streaming mode
                    end
                end
                % With the lockMask set to 0, crashes in NS allow
                % reconnection later. (Couldn't find documentation to
                % confirm this ...but it seems to work).
                lockMask = 0;
                status = o.device.Connect(o.deviceListEntry,lockMask);
                if status ==0
                    o.writeToFeed(['Connected to ' o.product]);
                    o.cleanupObj = onCleanup(@o.cleanup);
                else
                    error(o.cic,'STOPEXPERIMENT',['Could not connect to the ' o.product ' stg device (' char(Mcs.Usb.CMcsUsbNet.GetErrorText(status)) ' ). ']);
                    return;
                end
                o.nrChannels = double(o.device.GetNumberOfAnalogChannels);
                o.nrSyncOutChannels = double(o.device.GetNumberOfSyncoutChannels);
                o.totalMemory = double(o.device.GetTotalMemory);
                if o.isDownload
                    % Triggers are assigned to channels, not segments. On its own this does not do anything- still need to call setupTrigger code.
                    o.device.DisableMultiFileMode();
                else
                    % Set some streaming options
                    o.device.DisableContinousMode; % when running out of data (but at 0 v/a output; no need to retrigger)
                    nrTriggers = o.device.GetNumberOfTriggerInputs;  % obtain number of triggers in this STG
                    triggerCapacity=uint32(o.chunkBytes*ones(1,nrTriggers)+1); % 1 chunk  of bytes (2*nrSamples) each
                    o.device.SetCapacity(NET.convertArray(triggerCapacity,'System.UInt32'))
                end

                if o.currentMode
                     o.device.SetCurrentMode();
                else
                    o.device.SetVoltageMode();
                end

                for chan=0:o.nrChannels-1
                    [o.vResolution(chan+1),o.iResolution(chan+1)]  = o.device.GetAnalogResolution(chan);
                    [o.vRange(chan+1),o.iRange(chan+1)]  = o.device.GetAnalogRanges(chan);
                end

                % Conver A to mA. voltage is already in mV.
                o.iResolution = o.iResolution/1000;
                o.iRange = o.iRange/1000;
                setupTriggers(o); % Map triggers to channels 1->1 , 2->2
                
            end
        end




        function disconnect(o)
            % Disconnect
            if o.isConnected && ~o.fake
                o.device.Disconnect();
            end
        end


        function setupTriggers(o)
            % Map triggers to channels: trigger 1 starts channel 1 etc.
            %
            if o.fake
                o.writeToFeed('SetupTriggers STG');
                return
            end

            nrTriggers = o.device.GetNumberOfTriggerInputs();  % obtain number of triggers in this STG
            % Initialize everything to zero
            channelMap = NET.createArray('System.UInt32', nrTriggers);
            % "Diagonalize"
            for thisChan = 1:o.nrChannels
                channelMap(thisChan) = chan2mask(o,thisChan);
            end
            % All triggers trigger the same (single) syncout channel for
            % now
            if numel(o.syncOutChannel) >1 
                error('Currently therer can be only one syncout channel per experiment');
            end

            syncoutMap = NET.convertArray(chan2mask(o,o.syncOutChannel)*ones(1,nrTriggers,'uint32'),'System.UInt32');           
            if o.isDownload
                repeatMap  = NET.convertArray(ones(1,o.nrChannels,'uint32'),'System.UInt32', nrTriggers);
                % The repeats are defined in downloadStimulus. This should
                % be just 1 for each trigger/channel
                % Assign these mappings starting from trigger 0 to : STG is base-0
                o.device.SetupTrigger(0,channelMap,syncoutMap,repeatMap);
            else
                % Set the callback threshold for all triggers/channels.
                digoutMap = NET.convertArray(zeros(1,nrTriggers,'uint32'),'System.UInt32'); % Not clear what this is, but zeros seems to work
                autostart = NET.convertArray(zeros(1,nrTriggers,'uint32'),'System.UInt32'); % Not clear what this is, but zeros seems to work
                callbackThreshold = zeros(1,nrTriggers);
                callbackThreshold(ismember(1:o.nrChannels,o.streamingChannels)) = o.streamingBufferThreshold;
                callbackThreshold =NET.convertArray(callbackThreshold,'System.UInt32');
                o.device.SetupTrigger(channelMap, syncoutMap, digoutMap, autostart, callbackThreshold);
                o.nrRefills  = zeros(1,o.nrChannels);
                o.chunkStartTime  = zeros(1,o.nrChannels);          
            end
        end

        function [signal,isFinalRamp] = stimulusForStream(o,channel)
            [duration,amp,freq,pha,mea,thisFun,nrRepeats] = channelParms(o,channel);

            totalDuration = duration/1000*nrRepeats; % seconds
            step = 1/o.outputRate; %STG resolution
            from = o.chunkStartTime(channel)/1000; % seconds
            to  = from+o.chunkDuration/1000-step; % seconds
            time = from:step:to;

            %% Set the basic stimulus shape
            if ischar(thisFun)
                switch upper(thisFun)
                    case 'TACS'
                        signal = amp*sin(2*pi*freq*time+pha*pi/180)+mea;
                    case 'TDCS'
                        signal = mea*ones(size(time));
                    case 'TRNS'
                        error('NIY')
                    otherwise
                        error(o.cic,'STOPEXPERIMENT',['Unknown MCS/STG stimulation function: ' fun]);
                end
            elseif isa(thisFun,'function_handle')
                % User-specified function handle.
                signal = thisFun(time,o);
                if numel(signal) ~=numel(time)
                    error(o.cic,'STOPEXPERIMENT','The stimulus function returns an incorrect number of time points');
                end
            end

            [ramp,isFinalRamp] = linearRampForStream(o,from,to,totalDuration,channel);
            % Check that ramp is not longer  than chunk
            signal =signal.*ramp;
            o.chunkStartTime(channel) = o.chunkStartTime(channel)+o.chunkDuration; % ms
        end

        function [v,isFinalRamp] = linearRampForStream(o,from,to,totalDuration,channel)
            % Compute the ramp for the specified times

            changePerSecond = 1./(o.rampUp/1000);
            t = from:1/o.outputRate:to;
            v = ones(size(t));
            inRampUp = t<o.rampUp/1000;
            v(inRampUp) = t(inRampUp)*changePerSecond;
            if isfinite(o.forceDownRampFrom(channel))
                % Early end of stimulation
                downStart=min(totalDuration,o.forceDownRampFrom(channel)/1000);
            else
                % Regular stimulation
                downStart=(totalDuration-o.rampDown/1000);
            end
            inRampDown = t>=downStart;
            v(inRampDown) = 1-min(1,(t(inRampDown)-downStart)*changePerSecond);
            isFinalRamp = to>= (downStart+o.rampDown/1000);
        end




        function [signal,duration,nrRepeats] = stimulusForDownload(o,channel)
            % Only used by download mode to create teh main stimulus (the
            % ramps are added in downloadStimulus to allow the use of
            % nrRepeats for this "main" stimulus).
            [duration,amp,freq,pha,mea,thisFun,nrRepeats] = channelParms(o,channel);
            step = 1/o.outputRate; %STG resolution (20 mus)
            time = 0:step:(duration/1000-step);
            %% Set the basic stimulus shape
            if ischar(thisFun)
                switch upper(thisFun)
                    case 'TACS'
                        if (duration<1000/freq)
                            o.writeToFeed(sprintf('The sinusoid on channel %d will be truncated .. increase duration (%.2f->%.2f)? ',channel, duration,1000/freq));
                        end
                        signal = amp*sin(2*pi*freq*time+pha*pi/180)+mea;
                    case 'TDCS'
                        signal = mea*ones(size(time));
                    case 'TRNS'
                        error('NIY')
                    otherwise
                        error(o.cic,'STOPEXPERIMENT',['Unknown MCS/STG stimulation function: ' fun]);
                end
            elseif isa(thisFun,'function_handle')
                % User-specified function handle.
                signal = thisFun(time,o);
                if numel(signal) ~=numel(time)
                    error(o.cic,'STOPEXPERIMENT','The stimulus function returns an incorrect number of time points');
                end
            end
        end

        function prepareStimulus(o)
            % Called before sending the start trigger
            if o.isStreaming 
                % The PC buffer should be empty and STG should not be
                % polling now. Fill the buffer with the current stimuli
                o.chunkStartTime = zeros(1,o.nrChannels);
                o.nrRefills = zeros(1,o.nrChannels);
                for c=o.channel
                    streamingDataHandler(o,c-1); % Fake a call from STG (base-0)
                end
            else
                clearDownloadStimulus(o);
                downloadStimulus(o);
            end 
        end

        function clearDownloadStimulus(o)
            for i=1:o.nrChannels
                o.device.ClearChannelData(uint32(i-1));
                o.device.ClearSyncData(uint32(i-1));
            end
        end

        function downloadStimulus(o)
            % The function that sends channel and syncout data to the
            % device in download mode. It is called before each block or trial.
            if o.fake
                o.writeToFeed('Download Stimulus to STG');
            elseif ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not set the stimulation stimulus - device disconnected');
            end 
            % Define the values of the stimulus
            for thisChannel = o.channel                
                [signal,thisDuration,thisNrRepeats] = stimulusForDownload(o,thisChannel);
                %% Add ramp if requested
                if o.rampUp>0
                    nrRepeatsInRamp = ceil(o.rampUp/thisDuration);
                    if nrRepeatsInRamp ~= o.rampUp/thisDuration
                        o.writeToFeed('The ramp up period has been changed to the nearest larger integer multiple of the stimulus period');
                    end
                    fullSignalForRamp =  repmat(signal,[1 nrRepeatsInRamp]);
                    rampUpSignal = linspace(0,1,numel(fullSignalForRamp)).*fullSignalForRamp;
                else
                    rampUpSignal = [];
                end

                if o.rampDown>0
                    nrRepeatsInRamp = ceil(o.rampDown/thisDuration);
                    if nrRepeatsInRamp ~= o.rampDown/thisDuration
                        o.writeToFeed('The ramp down period has been changed to the nearest larger integer multiple of the stimulus period');
                    end
                    fullSignalForRamp =  repmat(signal,[1 nrRepeatsInRamp]);
                    rampDownSignal = linspace(1,0,numel(fullSignalForRamp)).*fullSignalForRamp;
                else
                    rampDownSignal = [];
                end


                %%  Code the signal
                % Convert to DAC values
                if o.currentMode
                    % Need amplitude in nA
                    scale = 1e5;  % Convert specified mA to nA
                    if o.fake
                        valueCode = 1;
                    else
                        valueCode = Mcs.Usb.STG_DestinationEnumNet.channeldata_current;
                    end
                else
                    %  Need amplitude in muV
                    scale = 1e3;  % Convert mV to muV
                    if o.fake
                        valueCode =1;
                    else
                        valueCode = Mcs.Usb.STG_DestinationEnumNet.channeldata_voltage;
                    end
                end

                step= 1./o.outputRate;
                if o.sham
                    %Up and immediately down
                    values =    [scale*rampUpSignal          scale*rampDownSignal];
                    duration  = [ones(1,numel(rampUpSignal)),ones(1,numel(rampDownSignal))]*(step/1e-6);
                    syncValue = [ones(1,numel(rampUpSignal)),ones(1,numel(rampDownSignal))];
                else
                    % A block that starts with 0 amplitude and 0 duration and
                    % ends with n ampltidude and 0 duration is repeated n
                    % times. This is used to repeat sines, or to create a long
                    % duration constant stimulus.
                    values =    [scale*rampUpSignal           0,    scale*signal,               thisNrRepeats,   scale*rampDownSignal];
                    duration  = [ones(1,numel(rampUpSignal)), 0,    ones(1,numel(signal)),      0,             ones(1,numel(rampDownSignal))]*(step/1e-6);
                    syncValue = [ones(1,numel(rampUpSignal)), 0,    ones(1,numel(signal)),      thisNrRepeats,   ones(1,numel(rampDownSignal))];
                end

                if ~o.fake
                    % Clear channel and send stimulus data to device
                    amplitudeNet = NET.convertArray(int32(values), 'System.Int32');
                    durationNet  = NET.convertArray(uint64(duration), 'System.UInt64');
                    o.device.PrepareAndSendData( uint32(thisChannel-1), amplitudeNet, durationNet,valueCode);
                    % Add the syncout
                    if ~isempty(o.syncOutChannel)
                        amplitudeNet = NET.convertArray(int32(syncValue), 'System.Int32');
                        o.device.PrepareAndSendData(uint32(o.syncOutChannel-1),amplitudeNet,durationNet,Mcs.Usb.STG_DestinationEnumNet.syncoutdata);
                    end
                end

            end
        end

        function [thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun,thisNrRepeats] = channelParms(o,channel)
            % Channel is 1:nrChannels
            ix = find(o.channel == channel);
            thisDuration = neurostim.stimuli.stg.expandSingleton(o.duration,ix);
            thisAmplitude = neurostim.stimuli.stg.expandSingleton(o.amplitude,ix);
            thisFrequency = neurostim.stimuli.stg.expandSingleton(o.frequency,ix);
            thisPhase = neurostim.stimuli.stg.expandSingleton(o.phase,ix);
            thisMean = neurostim.stimuli.stg.expandSingleton(o.mean,ix);
            thisFun = neurostim.stimuli.stg.expandSingleton(o.fun,ix);
            thisNrRepeats = neurostim.stimuli.stg.expandSingleton(o.nrRepeats,ix);
        end

    end
    methods (Static)
        function v = expandSingleton(vals,ix)
            if isscalar(vals) || ischar(vals)
                v = vals;
            else
                if ix<=numel(vals)
                    if iscell(vals)
                        v =vals{ix};
                    else
                        v =vals(ix);
                    end
                else
                    v=NaN; %#ok<NASGU>
                    error(['Mismatched specification : ' num2str(numel(vals)) ' parameters specified, but #' num2str(ix) ' requested']);
                end
            end
        end

        function guiLayout(~)
            % Add plugin specific elements
        end

    end

    %% GUI Functions
    methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            if strcmpi(parms.onOffFakeKnob,'Fake')
                o.fake=true;
            else
                o.fake =false;
            end
            %             o.downloadMode = ~parms.Streaming;
        end
    end


end