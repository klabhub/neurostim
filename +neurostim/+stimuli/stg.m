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
    %   This will do anodal stimulation on the first channel (together with its
    %   return) and cathodal on the second.
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
    %  Currently a 10 second long 10 Hz sine is downloaded in full to the
    %  device. This can take time. Using continuous mode or repeats would
    %  be a better way to do this. Not that hard to implement... just
    %  change the setup Trigger funcion to include the repeats.
    %
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
        nrRepeatsPerTrigger=1; % 1 for now
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
        end
        
        function beforeFrame(o)
            % Send a start trigger to the device for channels that have not
            % been triggered yet.
            if ~o.downloadMode
                streamStimulus(o);
            end
            % If we got here, the stimulus is supposed to turn on. Send the
            % trigger
            if ~o.triggerSent
                start(o);
            end
        end
        
        function afterTrial(o)
            % Send a stop signal
            if o.triggerSent
                stop(o);
            end
        end
        
        function afterExperiment(o)
            % Discconnect from the device.
            stop(o);
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
                    o.device  = Mcs.Usb.CStg200xDownloadNet; % Use download mode
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
            % Clear the currently stored data
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
            % use this trial
            
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
            repeatMap(o.trigger) = o.nrRepeatsPerTrigger;
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
        
        
        function streamStimulus(o)
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
            fractionUsed =0;
            
            
            
            % Send the values and the duration of each sample to the device
            for thisChannel = o.channel
                
                [thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun] = channelParms(o,thisChannel);
                
                time = 0:step:thisDuration/1000;
                %% Set the basic stimulus shape
                if ischar(thisFun)
                    switch upper(thisFun)
                        case 'TACS'
                            values = thisAmplitude*sin(2*pi*thisFrequency*time+thisPhase*pi/180)+thisMean;
                        case 'TDCS'
                            values = thisMean*ones(size(time));
                        case 'TRNS'
                            error('NIY')
                        otherwise
                            error(o.cic,'STOPEXPERIMENT',['Unknown MCS/STG stimulation function: ' fun]);
                    end
                elseif isa(thisFun,'function_handle')
                    % User-specified function handle.
                    values = thisFun(time,o);
                    if numel(values) ~=numel(time)
                        error(o.cic,'STOPEXPERIMENT','The stimulus function returns an incorrect number of time points');
                    end
                end
                
                %% Add ramp if requested
                if o.rampUp+o.rampDown>o.duration
                    error(o.cic,'STOPEXPERIMENT','Combined ramp-up and ramp-down durations exceed total stimulus duration');
                end
                ramp = ones(size(time));
                if ~isempty(o.rampUp) && o.rampUp>0
                    stepsInRamp= round((neurostim.stimuli.stg.expandSingleton(o.rampUp,thisChannel)/1000)/step);
                    ramp(1:stepsInRamp) = linspace(0,1,stepsInRamp);
                end
                if ~isempty(o.rampDown) && o.rampDown>0
                    stepsInRamp= round((neurostim.stimuli.stg.expandSingleton(o.rampDown,thisChannel)/1000)/step);
                    ramp(end-stepsInRamp+1:end) = linspace(1,0,stepsInRamp);
                end
                values = values.*ramp;
                
                %% Convert to DAC values
                if o.currentMode
                    maxValue = o.range.current(thisChannel); % The range for this channel in milliamps
                else
                    maxValue = o.range.voltage(thisChannel); % The range for this channel millivolts
                end
                
                absValues = abs(values);
                isNegative = values<0;
                if any(absValues>maxValue)
                    error(o.cic,'STOPEXPERIMENT',['The requested stimulation values are out of range (' num2str(maxValue) ')']);
                end
                % Convert to 12 bit values scaled to the range (maxValue).
                adValues = uint16(round((2^12-1)*absValues/maxValue));
                % Specify the sign wiith bit #12
                adValues(isNegative) = adValues(isNegative)+8192;
                
                % Check how much memory this uses - 2 bytes for value, 8 for
                % duration
                fractionUsed = fractionUsed + numel(adValues)*(2+8)/o.totalMemory;
                o.device.SendChannelData(thisChannel-1,adValues,uint64(step*1e6*ones(size(time))));
                if ~isempty(o.syncOutChannel)
                    o.device.ClearSyncData(neurostim.stimuli.stg.expandSingleton(o.syncOutChannel,thisChannel)-1);
                    o.device.SendSyncData(neurostim.stimuli.stg.expandSingleton(o.syncOutChannel,thisChannel)-1,uint16(1),1e3*thisDuration);
                end
                
            end
            
            %% Checking actual memory would be better but status does not seem to reflect overruns
            % accurately, so let's just warn for now.
            if fractionUsed>1
                error(o.cic,'STOPEXPERIMENT','The MCS/STG does not have enough memory for these stimuli');
            elseif fractionUsed>0.5
                writeToFeed(o,['The stimulus uses ' num2str(round(fractionUsed*100)) '% of the total memory. This can work, but it is a lot... and if you have other stimulation channels too, you could run into trouble..']);
            end
        end
        
        function [thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun] = channelParms(o,channel)
            % Channel is 1:nrChannels
            ix = find(o.channel == channel);
            thisDuration = neurostim.stimuli.stg.expandSingleton(o.duration,ix);
            thisAmplitude = neurostim.stimuli.stg.expandSingleton(o.amplitude,ix);
            thisFrequency = neurostim.stimuli.stg.expandSingleton(o.frequency,ix);
            thisPhase = neurostim.stimuli.stg.expandSingleton(o.phase,ix);
            thisMean = neurostim.stimuli.stg.expandSingleton(o.mean,ix);
            thisFun = neurostim.stimuli.stg.expandSingleton(o.fun,ix);
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