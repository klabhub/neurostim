classdef openEphys
    % Neurostim plugin that adds x functions to the Open Ephys GUI. 
    % Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public) 
        hostAddr %IP address of the machine running Open Ephys GUI, and the TCP port.
                 %hostAddr will be abstracted
        latencyStruct %structure for storing start/stop latency statistics
    end
    
    methods
        function o=openEphys(hostAddr) 
            %Constructor - Initialise properties 
            
            o.hostAddr = hostAddr;
            o.latencyStruct = struct('startAcqLatency', [], 'startRecordLatency', [], 'stopRecordLatency', [], 'stopAcqLatency', []); 
        end 
    end 
    
    methods
        function o = beforeExperiment(o, varargin) 
            %Start data acquisition, recording, etc...
            %Accepts name-value pairs as inputs.
            %Available inputs include save directory, save file prefix/suffix, and a message that flags the start of recording.
            %Default values are used if no inputs are provided.
            %Example call: this.beforeExperiment('CreateNewDir', 1, 'RecDir', ...,'PrependText', 'someText')
            
            %inputParser defines accepted name-value pairs 
            pin = inputParser; 
            pin.addParameter('CreateNewDir', 1, @(x) assert( x == 0 || x == 1, 'It must be either 1 (true) or 0 (false).'));
            pin.addParameter('RecDir', 'C:\', @validateDir);
            pin.addParameter('PrependText', '', @ischar); 
            pin.addParameter('AppendText', '', @ischar); 
            pin.addParameter('StartMessage', '', @ischar); 
            pin.parse(varargin{:});
            
            request = sprintf('StartRecord CreateNewDir=%i RecDir=%s PrependText=%s AppendText=%s', pin.Results.CreateNewDir, pin.Results.RecDir, pin.Results.PrependText, pin.Results.AppendText);
            
            %Blocking set to 1, waits for response before proceeding. 
            %Throws error if no response.
            [~ , stats] = zeroMQrr('Send', o.hostAddr, 'StartAcquisition', 1);
            o.latencyStruct.startAcqLatency(end+1) = stats.timeRequestSent - stats.timeResponseReceived;
            
            zeroMQrr('Send', o.hostAddr, pin.Results.StartMessage, 1);
            
            [~, stats] = zeroMQrr('Send', o.hostAddr, request, 1); 
            o.latencyStruct.startRecordLatency(end+1) = stats.timeRequestSent - stats.timeResponseReceived;  
        end
        
        function o = afterExperiment(o, varargin) 
            %stop data acquisition, recording, etc... 
            %User can specify a string that flags the end of recording.
            %E.g. this.afterExperiment('StopMessage', 'someText')
            
            pin = inputParser; 
            pin.addParameter('StopMessage', '', @ischar);
            pin.parse(varargin{:});
            
            [~, stats] = zeroMQrr('Send',o.hostAddr, 'StopRecord', 1);
            o.latencyStruct.stopRecordLatency(end+1) = stats.timeRequestSent - stats.timeResponseReceived;
            
            zeroMQrr('Send', o.hostAddr, pin.Results.StopMessage, 1);
            
            [~, stats] = zeroMQrr('Send',o.hostAddr, 'StopAcquisition', 1); 
            o.latencyStruct.stopAcqLatency(end+1) = stats.timeRequestSent - stats.timeResponseReceived;
            
            zeroMQrr('CloseAll'); %closes all open sockets and queue thread
        end 
        
    end
    
end

function temp = validateDir(directory)
    %validator used by inputParser to check whether selected recording directory exists
    if exist(directory, 'dir') == 7 
        temp = true;
    else
        temp = false;
    end 
        
end 


