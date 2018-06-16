classdef mcs < neurostim.stimulus
    % Plugin used to communicate with the MultiChannel Systems Stimulator
    % (e.g. STG40002).
    %
    % Constructing the stimulus object will find currently connected MCS
    % devices on the USB ports. The connection/initialization of the device
    % happens in the beforeExperiment() function; device parameters cannot
    % be changed after that.
    %
    % Users can specify arbitrary stimulation patterns by providing a
    % function that takes time in secondss as input and returns current in
    % milliamps (or voltage in millivolts in voltage mode).
    %
    % *** IMPORTANT *** 
    % [channels]  should always be specified in base-1: Channel 1 is the
    % first channel. 
    % [currents] in user functions should always be defined in mA (and user
    % accessible functions in this object return current measures in mA).
    % [voltage] in user functiosn should always be defined in mV (and user
    % accessible functions in this object return voltage measures in mV).
    % 
    % BK - June 2018
    
    properties (SetAccess = protected)
        device =[]; % handle to the device, once connected.
        assembly=[]; % The .Net assembly
        deviceList;  % List of all devices on USB
        deviceListEntry; % The device in the list that we will connect to (the first one, currently)
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
            o.addProperty('mode','current');%,@(x) (ischar(x) && ismember(x,{'voltage','current'})));
           % o.addProperty('autoReset',false);%,@islogical); - not used.
            
           % Load the relevant NET assembly
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
        end
        
        function beforeExperiment(o)
            % Connect to the device, and clear its memory to get a clean start..
            connect(o);
        end
        
        function afterExperiment(o)
            % Discconnect from the device.
            disconnect(o);
        end
         
        
        function setStimulus(o,fun,start,stop,channel,syncOutChannel)
            % Specify a function fun that takes time in seconds as its
            % input and returns the current in ***milliamps***, or the voltage in
            % ***millivolts***.
            % INPUT
            %  o - STG/MCS  plugin
            % fun - function handle  - takes a vector of times in seconds as its input
            % and returns milliamps or millivolts. 
            % start - Start time in seconds
            % stop  - stop time in seconds
            % channel - a single channel number (base -1)
            % syncChannel - Specify a channel that will send a syncout
            % signal  (optional).            
            if nargin < 6
                syncOutChannel = [];
            end

            if ~o.isConnected 
                error(o.cic,'STOPEXPERIMENT','Could not set the stimulation stimulus  -device disconnected'); 
            end
            if numel(channel)~=1 || channel > o.nrChannels  || channel <1
                error(o.cic,'STOPEXPERIMENT','Please use base-1 channel convention to specify stimulation (one channel at a time)');
            end
                
            if ~isempty(syncOutChannel) && (numel(syncOutChannel)>1 || syncOutChannel > o.nrSyncOutChannels  || syncOutChannel <1)
                error(o.cic,'STOPEXPERIMENT','Please use base-1 syncOut cchannel convention to specify stimulation (one channel only)');
            end
               
            step = 1/o.outputRate; %STG resolution (usually 20 mus)
            time = start:step:stop;
            values = fun(time);
            if numel(values) ~=numel(time)
                error(o.cic,'STOPEXPERIMENT','The stimulus function returns an incorrect number of time points');
            end
            
            maxValue = o.range.(o.mode)(channel); % The range for this channel in milliamps or millivolts
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
            o.device.ClearChannelData(channel-1);
            duration = uint64(step*1e6*ones(size(time)));
            
            % Check that we have enough memory - 2 bytes for value, 8 for
            % duration
            fractionUsed = numel(adValues)*(2+8)/o.totalMemory;
            
            if fractionUsed>1
                error(o.cic,'STOPEXPERIMENT',['The MCS/STG does not have enough memory for the stimulus on channel ' num2str(channel) ]);
            elseif fractionUsed>0.5
                writeToFeed(o,['The stimulus for channel ' num2str(channel) ' uses ' num2str(round(fractionUsed*100)) '% of the total memory. This can work, but it is a lot... and if you have other stimulation channels too, you could run into trouble..']);                
            end
            
            o.device.SendChannelData(channel-1,adValues,duration)
            
            if ~isempty(syncOutChannel)
                 o.device.ClearSyncData(syncOutChannel-1);
                 syncDuration = 1e6*(stop-start);
                 o.device.SendSyncData(syncOutChannel-1,uint16(1),syncDuration);                           
            end            
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
            end
        end
        function stop(o,channels)
            % Stop these channels from continuing. 
            % Channels should be a vector of base-1 channel numbers.
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT','Could not stop MCS. Device not connected');
            else
                o.device.SendStop(chan2mask(o,channels))
            end
        end
           
        function connect(o)
            % Connect to the device and setup the device object to wwork in
            % STG Download mode.
            o.device  = Mcs.Usb.CStg200xDownloadNet(); % Use download mode
            o.device.Connect(o.deviceListEntry);
            if ~o.isConnected
                error(o.cic,'STOPEXPERIMENT',['Could not connect to the ' o.product ' MCS device']);
            end
                
            o.device.DisableMultiFileMode(); % Triggers are assigned to channels, not segments.
            o.device.SetOutputRate(uint32(o.outputRate));
            if strcmpi(o.mode,'CURRENT')
                o.device.SetCurrentMode();
            else
                o.device.SetVoltageMode();
            end
            
%         Not clear what this does.    if o.autoReset
%                 % Only for download mode...
%                 o.device.EnableAutoReset();
%             else
%                 o.device.DisableAutoReset();
%             end
            
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
    end
end