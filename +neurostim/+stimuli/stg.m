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
    % This code uses the STG Download mode (stimulus is prepared in matlab,
    % sent to the device, and then triggered). The resolution of the
    % sitmulus is 20 mus. This cannot be changed - trying to set the output
    % rate results in strange and somewhat unpredictable changes of the
    % stimulus shape. The support on the MCS website stated that output
    % rate cannot be set on (some) STG devices, so this is disabled here.
    %
    % Note that for a tDCS stimulus, the 
    % An attempt at Streaming Mode did not work. The code is still in here
    % but it does not run. Use Download only.
    
    properties (Constant)
        outputRate = 50000; % 50 Khz is fixed
        streamingBufferThreshold = 50; % Fill the buffer when it is half empty
    end
    
    
    properties (SetAccess = protected)
        
        trigger=1; % The trigger that is used to turn a pattern on per trial. This is stopped at the end of a trial
        triggerTime = [];
        triggerSent = false;
        
    end
    
    properties (SetAccess = protected, Transient)
        device =[]; % handle to the device, once connected.
        assembly=[]; % The .Net assembly
        deviceList;  % List of all devices on USB
        deviceListEntry; % The device in the list that we will connect to (the first one, currently)
        cleanupObj; % Object to handle cleanup in o.cleanup
        
    end
    
    properties (Dependent =true)
        nrChannels;
        nrSyncOutChannels;
        range;
        resolution; % resolution per channel in mV and mA.
        totalMemory; % in bytes.
        isConnected; % Boolean
        streamingBufferSize; % Nr samples in the buffer; calculated from latency
    end
    
    %get/set
    methods
        function v = get.resolution(o)
            % Returns a struct with the resolution per channel in mV and mA.
            if o.isConnected
                for chan=0:o.nrChannels-1
                    [voltage(chan+1),current(chan+1)]  = o.device.GetAnalogResolution(chan); %#ok<AGROW>
                end
            else
                voltage =  NaN;
                current  = NaN;
            end
            v.voltage = double(voltage);      % mV
            v.current = double(current)/1000; % convert to mA.
        end
        
        
        function v = get.range(o)
            % Returns a struct with the range (maximum absolute value)
            % per channel in mV and mA.
            if o.isConnected
                for chan=0:o.nrChannels-1
                    [voltage(chan+1),current(chan+1)]  = o.device.GetAnalogRanges(chan); %#ok<AGROW>
                end
            else
                voltage =  NaN;
                current  = NaN;
            end
            v.voltage = double(voltage);        % mV
            v.current = double(current)/1000;   % Convert to mA
        end
        
        function v = get.nrChannels(o)
            % Returns the number of analog output channels on the current device.
            if o.isConnected
                v = double(o.device.GetNumberOfAnalogChannels);
            else
                v = 0;
            end
        end
        
        function v = get.nrSyncOutChannels(o)
            % Returns the number of sync output channels on the current device.
            if o.isConnected
                v = double(o.device.GetNumberOfSyncoutChannels);
            else
                v = 0;
            end
        end
        
        
        function v = get.totalMemory(o)
            %Returns the total number of bytes in memory.
            if o.isConnected
                v = double(o.device.GetTotalMemory);
            else
                v = 0;
            end
        end
        
        function v = get.isConnected(o)
            % Boolean to check whether the device is connected.
            v = ~isempty(o.device) && o.device.IsConnected();
        end
        
        function v =get.streamingBufferSize(o)
            v = round((100/o.streamingBufferThreshold)*(o.streamingLatency*o.outputRate/1000));
        end
    end
    
    methods
        
        function delete(o)
            % Destructor; disconnect and cleanup the .NET objects
            disconnect(o);
            delete(o.deviceList);
            delete(o.device);
        end
        
        function cleanup(o)
            % This is called when the object is cleared from memory
            % (cleanupObj was setup with oncleanup) to make sure we
            % discconnect.Not sure this really works though...
            o.device.Disconnect;
        end
        
        function o = stg(c,downLoadMode)
            % Constructor
            % c = handle to CIC
            % lib = folder that contains the .NET libraries.
            % downloadMode = true (Streaming not implemented yet)
            %
            % The constructor only initializes the Matlab object with properties.
            % Connection to the device happens in beforeExperiment.
            
            if nargin <2
                downLoadMode = true;
            end
            
            if ~downLoadMode
                error('Sorry Streaming Mode is not functional yet');
            end
            
            o = o@neurostim.stimulus(c,'stg');
            
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
            o.addProperty('downloadMode',downLoadMode);
            o.addProperty('streamingLatency',100); % Allowable latency in streaming mode
            
            o.addProperty('mode','TRIAL',@(x)ischar(x) && ismember(upper(x),{'TRIAL','BLOCKED','TIMED'}));
            
            % Stimulation properties
            o.addProperty('fun','tDCS','validate',@(x) (isa(x,'function_handle') || (ischar(x) && ismember(x,{'tDCS','tACS','tRNS'}))));
            o.addProperty('channel',[]);
            o.addProperty('mean',0);
            o.addProperty('frequency',0);
            o.addProperty('amplitude',0);
            o.addProperty('phase',0);
            o.addProperty('rampUp',0);
            o.addProperty('rampDown',0);
            o.addProperty('syncOutChannel',[]);
            o.addProperty('nrRepeats',1);            
            
        end
        
        function beforeExperiment(o)
            
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
            
            %% 
            % Connect to the device, and clear its memory to get a clean start..
            connect(o);            
            reset(o);
        end
        
        function beforeTrial(o)
            setupTriggers(o); % Map triggers to the set of channels for this trial
            if o.downloadMode
                downloadStimulus(o); % Send the stimulus
            else
                o.device.StartLoop;
                %pause(0.5);
            end
            
            
            %% Depending on the mode, do something
            switch upper(o.mode)
                case 'BLOCKED'
                    % Starts before the first trial in a block
                    if o.cic.blockTrial ==1 && o.enabled
                        start(o);
                    end
                case 'TRIAL'
                    if o.enabled
                        start(o);
                    end
                case 'TIMED'
                    % Do nothing here - trigger in beforeFrame
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown STG mode :' o.mode]);
            end

            
        end
        
        function beforeFrame(o)
            % Send a start trigger to the device          
            switch upper(o.mode)
                case {'BLOCKED','TRIAL'}
                    % These modes do not change stimulation within a
                    % trial/block - nothing to do.
                case 'TIMED'
                    % Start the first time beforeFrame is called                   
                    if ~ o.triggerSent                        
                        start(o);                        
                    end              
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown STG mode :' o.mode]);
            end            
        end
        
        function afterTrial(o)
            switch upper(o.mode)
                case 'BLOCKED'
                    if o.cic.blockDone && o.enabled
                        stop(o); % Brute force stop- better to wait until done to get the rampdown....
                    end
                case 'TRIAL'                    
                    stop(o);         % Brute force stop- better to wait until done to get the rampdown....                               
                case 'TIMED'
                    stop(o);  % Brute force stop- better to wait until done to get the rampdown...
                otherwise
                    o.cic.error('STOPEXPERIMENT',['Unknown STG mode :' o.mode]);
            end          
        end
        
        function afterExperiment(o)
            % Discconnect from the device.
            stop(o);  % Brute force stop- better to wait until done to get the rampdown...
            if ~o.downloadMode
                o.device.StopLoop;
            end
            reset(o);
            disconnect(o);
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
            % Trigger the stimulation. The mapping from trigger to channels
            % has been setup elsewhere. Currently we're only using 1
            % trigger (o.trigger)
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not start stg. Device not connected.'); %#ok<*CTPCT>
            else
                o.device.SendStart(o.trigger);
                o.triggerSent = true;
                o.triggerTime = o.cic.clockTime;
            end
        end
        function stop(o)
            % Stop the triggered channels from continuing.
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not stop stg. Device not connected.');
            else
                o.device.SendStop(o.trigger);
                o.triggerSent = false;
            end
        end
        
        function connect(o)
            % Connect to the device and setup the device object to wwork in
            % STG Download mode.
            if ~o.isConnected
                if o.downloadMode
                    o.device  = Mcs.Usb.CStg200xDownloadNet(); % Use download mode
                else
                    % Use streaming mode. BK could not get the callback
                    % functions to work. Using polling instead  (see
                    % streamStimulus)
                    o.device  = Mcs.Usb.CStg200xStreamingNet(1000);%o.outputRate);%,@o.streamingDataHandler,@o.streamingErrorHandler); % Use streaming mode
                    nrTriggers = o.device.GetNumberOfTriggerInputs();  % obtain number of triggers in this STG
                    triggercapacity = NET.createArray('System.UInt32', nrTriggers);
                    for i = 1:nrTriggers
                        triggercapacity(i) = 1000; % 1 second
                    end
                    o.device.SetCapacity(triggercapacity);            % setup the STG
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
                
                if o.downloadMode
                    % Triggers are assigned to channels, not segments. On its own this does not do anything- still need to call setupTrigger code.
                    o.device.DisableMultiFileMode();
                else
                    % Set some streaming options
                    o.device.EnableContinousMode; % keep running when running out of data (but at 0 v/a output; no need to retrigger)
                end
                
            end
            
        end
        
        
        function reset(o)
            
            % Make sure the device memory is cleared, and the device mode
            % is set to the correct value.
            if o.currentMode
                o.device.SetCurrentMode();
            else
                o.device.SetVoltageMode();
            end
            %Clear the currently stored data
            if o.downloadMode
                for c=0:o.nrChannels-1
                    o.device.ClearChannelData(c);
                    o.device.ClearSyncData(c);
                end
            else
                % Streaming mode
            end
            o.triggerTime = NaN;
            o.triggerSent = false;
        end
        
        function disconnect(o)
            % Disconnect
            if o.isConnected
                o.device.Disconnect();
            end
        end
        
        
        function setupTriggers(o)
            % Map a single trigger to start all of the channels that are in
            % use this trial. In principle this allows a channel that is
            % not used this trial to keep its values in memory (it won't be
            % triggered), but we don't actually use that; stimulation is
            % defined anew at the start of each trial.
            
            nrTriggers = o.device.GetNumberOfTriggerInputs();  % obtain number of triggers in this STG
            % Initialize everything to zero
            channelMap = NET.createArray('System.UInt32', nrTriggers);
            syncoutMap= NET.createArray('System.UInt32', nrTriggers);
            repeatMap  = NET.createArray('System.UInt32', nrTriggers);
            
            % Now set the one trigger we use
            channelsToTrigger = chan2mask(o,o.channel); % These are the channels for the current trial
            syncoutsToTrigger  =  chan2mask(o,o.syncOutChannel); % These are the channels for the current trial
            channelMap(o.trigger) = channelsToTrigger; % assign all channels to the o.trigger
            syncoutMap(o.trigger) = syncoutsToTrigger;   %
            repeatMap(o.trigger) = 1; % The repeats are defined in downloadStimulus. This should be just 1
            if o.downloadMode
                % In Download mode we set triggers starting at the trigger indicated
                % by the first argument to SetupTrigger. Note the o.trigger-1 : STG is base-0
                o.device.SetupTrigger(o.trigger-1,channelMap,syncoutMap,repeatMap);
                o.triggerSent= false;
                o.triggerTime = NaN;
            else
                % In Streaming mode we set all triggers.
                digoutMap = NET.createArray('System.UInt32', nrTriggers);
                autostart = NET.createArray('System.UInt32', nrTriggers);
                callbackThreshold = NET.createArray('System.UInt32', nrTriggers);
                callbackThreshold(o.trigger) = 50; % 50% of buffer size
                o.device.SetupTrigger(channelMap, syncoutMap, digoutMap, autostart, callbackThreshold);
            end
            
        end
        
        
        function streamStimulus(~)
            %%Not functional
            %              for thisChannel = o.channel
            %                 space = o.device.GetDataQueueSpace(thisChannel-1);
            %                 while space >= 500
            %                 % Calc Sin-Wave (16 bits) lower bits will be removed according resolution
            %                     sinVal = 30000 * sin(2.0 * (1:500) * pi / 1000);
            %                     data = NET.convertArray(sinVal, 'System.Int16');
            %                     o.device.EnqueueData(thisChannel-1, data)
            %                     space = o.device.GetDataQueueSpace(thisChannel-1)
            %                 end
            %               end
            %
        end
        
        function downloadStimulus(o)
            % The main function that sends channel and syncout data to the
            % device. It is called before each trial.            
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not set the stimulation stimulus - device disconnected');
            end
            
            step = 1/o.outputRate; %STG resolution (20 mus)            
            % Define the values of the stimulus
            for thisChannel = o.channel                
                [thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun,thisNrRepeats] = channelParms(o,thisChannel);                
                time = 0:step:(thisDuration/1000-step);
                %% Set the basic stimulus shape
                if ischar(thisFun)
                    switch upper(thisFun)
                        case 'TACS'
                            signal = thisAmplitude*sin(2*pi*thisFrequency*time+thisPhase*pi/180)+thisMean;
                        case 'TDCS'
                            signal = thisMean*ones(size(time));
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
                    valueCode = Mcs.Usb.STG_DestinationEnumNet.channeldata_current;
                else
                    %  Need amplitude in muV
                    scale = 1e3;  % Convert mV to muV                   
                    valueCode = Mcs.Usb.STG_DestinationEnumNet.channeldata_voltage;
                end

                % A block that starts with 0 amplitude and 0 duration and
                % ends with n ampltidude and 0 duration is repeated n
                % times. This is used to repeat sines, or to create a long
                % duration constant stimulus.
                

                values =    [scale*rampUpSignal           0,    scale*signal,               thisNrRepeats,   scale*rampDownSignal];
                duration  = [ones(1,numel(rampUpSignal)), 0,    ones(1,numel(signal)),      0,             ones(1,numel(rampDownSignal))]*(step/1e-6);                        
                syncValue = [ones(1,numel(rampUpSignal)), 0,    ones(1,numel(signal)),      thisNrRepeats,   ones(1,numel(rampDownSignal))];                        
                % Clear channel and send stimulus data to device
                amplitudeNet = NET.convertArray(int32(values), 'System.Int32');
                durationNet  = NET.convertArray(uint64(duration), 'System.UInt64');
                o.device.ClearChannel_PrepareAndSendData(thisChannel-1, amplitudeNet, durationNet,valueCode,true);

                % Add the syncout
                if ~isempty(o.syncOutChannel)                    
                    amplitudeNet = NET.convertArray(int32(syncValue), 'System.Int32');                                  
                    o.device.ClearChannel_PrepareAndSendData(thisChannel-1,amplitudeNet,durationNet,Mcs.Usb.STG_DestinationEnumNet.syncoutdata,true); 
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
        
        %% Streaming mode callback functions. BK could not get these to work,
        % using streamStimulus instead now.
        %         function streamingDataHandler(o,trigger)
        %
        %         end
        %
        %         function streamingErrorHandler(o)
        %             % Called when the streaming buffer generates an error
        %             writeToFeed(o,'Streaming error in STG. Buffer underrun?');
        %         end
        %
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
    end
end