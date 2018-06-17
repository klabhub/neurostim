classdef mcs < neurostim.stimulus
    % Plugin used to communicate with the MultiChannel Systems Stimulator
    % (e.g. STG40002).
    %
    % Constructing the stimulus object will find currently connected MCS
    % devices on the USB ports. The connection/initialization of the device
    % happens in the beforeExperiment() function; device parameters cannot
    % be changed after that.
    %
    %
    % *** IMPORTANT ***
    % [channels]  should always be specified in base-1: Channel 1 is the
    % first channel.
    % [currents] in user functions should always be defined in mA (and user
    % accessible functions in this object return current measures in mA).
    % [voltage] in user functiosn should always be defined in mV (and user
    % accessible functions in this object return voltage measures in mV).
    %
    % To define stimulation parameters, set the following parameters:
    % fun -  This can be a stimulation mode ('tDCS', 'tACS','tRNS') or a
    % function handle  that takes a vector of times in milliseconds as its
    % first input, and the stg object as its second input  (so that you can
    % use its properties as set in the "current" trial to modify the output
    % of the function.) The output of the function should be a vector of
    % currents/voltges in milliamps or millivolts with a length that matches
    % its first input argument (i.e. the time vector).
    %
    % duration - duration of stimulation [ms]
    % channel - a single channel number (base -1)
    % syncOutChannel - Specify a channel that will send a syncout
    % signal  (optional, base-1).
    %
    % mean - mean value of current/voltage [mA/mV]
    % frequency -  frequency of sinusoidal tACS [Hz]
    % amplitude - amplitude of sinusoid [mA/mV]
    % phase   -  phase of sine [degrees]
    % rampUp  - duration of linear ramp-up [ms]
    % rampDown - duration of linear ramp-down [ms]
    %
    % Each of these parameters can be specified as a scalar (thus applying
    % to all channels equally) or as a vector with a different entry for
    % each channel. For 'fun', use a cell array with one element per
    % channel.
    %
    % EXAMPLE
    %
    % stg.channel = [1 2];
    % stg.fun  = 'tDCS'
    % stg.mean = [1 -1]
    % will do anodal stimulation on the first channel (together with its
    % return) and cathodal on the second.
    %
    % BK - June 2018
    
    properties (SetAccess = protected)
        device =[]; % handle to the device, once connected.
        assembly=[]; % The .Net assembly
        deviceList;  % List of all devices on USB
        deviceListEntry; % The device in the list that we will connect to (the first one, currently)
        channelData;  % Cell array with the data last sent to each channel
        channelTriggered; % Last trigger time of each channel
    end
    
    properties (Dependent =true)
        nrChannels;
        nrSyncOutChannels;
        range;
        resolution; % resolution per channel in mV and mA.
        totalMemory; % in bytes.
        isConnected; % Boolean
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
    end
    
    methods
        
        function delete(o)
            % Destructor; disconnect and cleanup the .NET objects
            disconnect(o);
            delete(o.deviceList);
            delete(o.device);
        end
        
        function o = mcs(c,name)
            % Constructor. Only a name needs to be provided. This will
            % link to the first device that is found on the USB port and
            % retrieve its properties. A connection is not yet established.
            % Once this is done, properties such as outputRate, mode can be
            % set, before connecting.
            %
            if nargin <2
                name = 'mcs';
            end
            o = o@neurostim.stimulus(c,name);
            % Read-only properties
            o.addProperty('deviceName','');
            o.addProperty('path','');
            o.addProperty('hwVersion','');
            o.addProperty('manufacturer','');
            o.addProperty('product','');
            o.addProperty('serialNumber','');
            
            % Read/write properties.
            o.addProperty('outputRate',50000);
            o.addProperty('currentMode',true);
            
            
            
            %% Load the relevant NET assembly
            here = mfilename('fullpath');
            switch computer
                case 'PCWIN64'
                    o.assembly = NET.addAssembly([here '\McsUsbNet.dll']);
                otherwise
                    error(['Sorry, the MCS .NET libraries are not available on your platform: ' computer]);
            end
            
            % Search devices.
            o.deviceList = Mcs.Usb.CMcsUsbListNet();
            nrDevices =  o.deviceList.GetNumberOfDevices();
            if nrDevices >1
                % For now just warn - selection could be added.
                warning(o,'Found more than one MCS device; using the first one');
            end
            
            % Initialize the selected device
            % This does not work, probably because the .NET array is not
            % correct.
            %             args = NET.createArray('Mcs.Usb.DeviceIdNet',1); % NEt Array of 1
            %             args.Set(0,deviceListEntry.DeviceId);
            %             o.deviceList.Initialize(args);
            % Becuase we only use a single device, we can just initialize
            % all devices of the STG kind for now:
            o.deviceList.Initialize(Mcs.Usb.DeviceEnumNet.MCS_STG_DEVICE);
            % This has to be done after initialization.
            o.deviceListEntry    = o.deviceList.GetUsbListEntry(0);
            % Get some of its properties to store
            o.deviceName = char(  o.deviceListEntry.DeviceName);
            o.path  = char(  o.deviceListEntry.DevicePath);
            o.hwVersion = char(  o.deviceListEntry.HwVersion);
            o.manufacturer = char(  o.deviceListEntry.Manufacturer);
            o.product = char(  o.deviceListEntry.Product);
            o.serialNumber  = char(  o.deviceListEntry.SerialNumber);
            
            %% Connect now so that we get the nrChannels
            connect(o);
            
            % Stimulation properties
            o.addProperty('fun','tDCS','validate',@(x) (isa(x,'function_handle') || (ischar(x) && ismember(x,{'tDCS','tACS','tRNS'}))));
            o.addProperty('channel',1,'validate',@(x) (isnumeric(x) && all(x>= 1 & x <= o.nrChannels)));
            o.addProperty('syncOutChannel',[],'validate',@(x) (isnumeric(x) && all( x>= 1 & x <= o.nrSyncOutChannels)));
            o.addProperty('mean',zeros(1,o.nrChannels),'validate',@isnumeric);
            o.addProperty('frequency',zeros(1,o.nrChannels),'validate',@isnumeric);
            o.addProperty('amplitude',zeros(1,o.nrChannels),'validate',@isnumeric);
            o.addProperty('phase',zeros(1,o.nrChannels),'validate',@isnumeric);
            o.addProperty('rampUp',zeros(1,o.nrChannels),'validate',@isnumeric);
            o.addProperty('rampDown',zeros(1,o.nrChannels),'validate',@isnumeric);
            o.addProperty('itiOff',true(1,o.nrChannels),'validate',@islogical);
            o.addProperty('triggerSent',true(1,o.nrChannels),'validate',@islogical); % Keeps track of when the triggers to start stim were sent.
            o.addProperty('persistent',false(1,o.nrChannels),'validate',@islogical); % Persistent means that it can last longer than a trial
            o.addProperty('enabled',true(1,o.nrChannels),'validate',@islogical); % 
            NRPARMS =8;
            o.channelData = cell(o.nrChannels,NRPARMS);
            [o.channelData{:,1}] = deal(NaN); % Hack; first duration is Nan.
            o.channelTriggered = -inf(1,o.nrChannels);
        end
        
        function beforeExperiment(o)
            % Connect to the device, and clear its memory to get a clean start..
            connect(o);
        end
        
        function beforeTrial(o)
            
            sendStimulus(o);
            
            
        end
        
        function beforeFrame(o)            
            start(o,intersect(find(~o.triggerSent),o.channel));
        end
        
        function afterFrame(o)
        end
        
        function afterTrial(o)
        end
        
        function afterExperiment(o)
            % Discconnect from the device.
            disconnect(o);
        end
        
        
        
    end
    
    
    methods (Access=public)
        function mask = chan2mask(o,channels)
            % Convert an array of  base-1 channel number to a channel bit mask
            if any(channels>o.nrChannels | channels<1)
                error(o.cic,['MCS Channels should be between 1 and ' num2str(o.nrChannels)]);
            end
            mask = uint32(0);
            for c= channels
                mask = bitor(mask,bitset(mask,c));
            end
        end
        
        function start(o,channels)
            % Trigger the stimulation on the specified list of channels.
            % The channels shoudl be a vector of (base -1) channel numbers
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not start MCS. Device not connected'); %#ok<*CTPCT>
            else
                o.device.SendStart(chan2mask(o,channels))
                o.triggerSent(channels) = true;
                o.channelTriggered(channels) = GetSecs;
            end
        end
        function stop(o,channels)
            % Stop these channels from continuing.
            % Channels should be a vector of base-1 channel numbers.
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not stop MCS. Device not connected');
            else
                o.device.SendStop(chan2mask(o,channels))
                o.triggerSent(channels) = false;
            end
        end
        
        function connect(o)
            % Connect to the device and setup the device object to wwork in
            % STG Download mode.
            if ~o.isConnected
                o.device  = Mcs.Usb.CStg200xDownloadNet(); % Use download mode
                o.device.Connect(o.deviceListEntry);
                if ~o.isConnected
                    error(o.cic,'STOPEXPERIMENT',['Could not connect to the ' o.product ' MCS device']);
                end
                o.device.DisableMultiFileMode(); % Triggers are assigned to channels, not segments.
            end
            reset(o);
        end
        
        
        function reset(o)
            % Make sure the device memory is cleared, and the device mode
            % is set to the current value.
            o.device.SetOutputRate(uint32(o.outputRate));
            if o.currentMode
                o.device.SetCurrentMode();
            else
                o.device.SetVoltageMode();
            end
            % Clear the currently stored data
            for c=0:o.nrChannels-1
                o.device.ClearChannelData(c);
                o.device.ClearSyncData(c);
            end
        end
        
        function disconnect(o)
            % Disconnect
            if o.isConnected
                o.device.Disconnect();
            end
        end
        
        
        function sendStimulus(o)
            % The main function that sends channel and syncout data to the
            % device.
            
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not set the stimulation stimulus  -device disconnected');
            end
            
            step = 1/o.outputRate; %STG resolution (usually 20 mus)            
            fractionUsed =0;            
            for channelCntr = 1:numel(o.channel)
                thisChannel = o.channel(channelCntr);
                [thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun,thisPersistent,thisEnabled,thisChanged] = channelParms(o,thisChannel);
                if thisPersistent
                    % This is a stimulus that persists across trials
                    if thisChanged
                        % Check whether the time for a change is ok, warn
                        % if not, but execute in either case
                        plannedDuration = o.channelData{thisChannel,1};
                        tooEarly = GetSecs - (o.channelTriggered(thisChannel)+plannedDuration/1000);
                        if isnan(tooEarly) || tooEarly >0
                            % OK. reached the planned duration
                        else
                            writeToFeed(o,['Stimulation was changed before it terminated...' num2str(tooEarly) 's'])
                        end
                    else % Nothing changed for this persisting stimulus, nothing to do, let it keep running
                        continue;
                    end
                else
                    %this is a non-persisting stimulus. Regardless of
                    %whether it was done, we'll start with a fresh
                    %sendChannelData.
                end
                
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
                ramp = ones(size(time));
                if ~isempty(o.rampUp)
                    stepsInRamp= round((neurostim.stimuli.mcs.expandSingleton(o.rampUp,channelCntr)/1000)/step);
                    ramp(1:stepsInRamp) = linspace(0,1,stepsInRamp);
                end
                
                if ~isempty(o.rampDown)
                    stepsInRamp= round((neurostim.stimuli.mcs.expandSingleton(o.rampDown,channelCntr)/1000)/step);
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
                % Send the values and the duration of each sample to the device
                o.device.ClearChannelData(thisChannel-1);
                
                % Check how much memory this uses - 2 bytes for value, 8 for
                % duration
                fractionUsed = fractionUsed + numel(adValues)*(2+8)/o.totalMemory;
                o.device.SendChannelData(thisChannel-1,adValues,uint64(step*1e6*ones(size(time))))
                % bookkeeping                
                o.channelData(thisChannel,:) = {thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun,thisPersistent,thisEnabled};
                o.triggerSent(thisChannel) = false;
                
                if ~isempty(o.syncOutChannel)
                    o.device.ClearSyncData(neurostim.stimuli.mcs.expandSingleton(o.syncOutChannel,channelCntr)-1);
                    o.device.SendSyncData(neurostim.stimuli.mcs.expandSingleton(o.syncOutChannel,channelCntr)-1,uint16(1),1e3*thisDuration);
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
        
        function [thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun,thisPersistent,thisEnabled,thisChanged] = channelParms(o,channel)
            ix = find(o.channel == channel);
            thisDuration = neurostim.stimuli.mcs.expandSingleton(o.duration,ix);
            thisAmplitude = neurostim.stimuli.mcs.expandSingleton(o.amplitude,ix);
            thisFrequency = neurostim.stimuli.mcs.expandSingleton(o.frequency,ix);
            thisPhase = neurostim.stimuli.mcs.expandSingleton(o.phase,ix);
            thisMean = neurostim.stimuli.mcs.expandSingleton(o.mean,ix);
            thisFun = neurostim.stimuli.mcs.expandSingleton(o.fun,ix);
            thisPersistent = neurostim.stimuli.mcs.expandSingleton(o.persistent,ix);
            thisEnabled = neurostim.stimuli.mcs.expandSingleton(o.enabled,ix);
            if numel(o.channelData) < channel || isnan(o.channelData{channel,1})
                thisChanged = true;
            else
                thisChanged = ~isequaln(o.channelData(channel,:),{thisDuration,thisAmplitude,thisFrequency,thisPhase,thisMean,thisFun,thisPersistent,thisEnabled});
            end
            
            
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
    end
end