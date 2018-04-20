classdef openEphys < neurostim.plugins.ePhys
    % Neurostim plugin that adds x functions to the Open Ephys GUI. 
    % Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public) 
        latencyStruct = struct('startAcqLatency', [], 'startMsg', [], 'startRecordLatency', [], 'stopRecordLatency', [], 'stopMsg',[] , 'stopAcqLatency', []);  %structure for storing start/stop latency statistics
                
    end
    
    methods
        function o = openEphys(c, hostAddr) 
            %Constructor - Initialise properties 
            o = o@neurostim.plugins.ePhys(c); 
            o.hostAddr = hostAddr; 
            
            %Check whether zeroMQrr mex file is on the search path
            switch (computer)
                case 'PCWIN64' %Windows 64-bit
                    if exist('zeroMQrr.mexw64', 'file') == 0 
                        fileException = MException('openEphys:missingDependency', 'The mex file zeroMQrr.mexw64 is not on MATLAB''s search path. <a href="https://github.com/open-ephys/plugin-GUI/tree/master/Resources/Matlab">Download</a>'); 
                        throw(fileException)
                    end 
                case 'MACI64' %OS X 64-bit
                    if exist('zeroMQrr.mexmaci64', 'file') == 0 
                        fileException = MException('openEphys:missingDependency', 'The mex file zeroMQrr.mexmaci64 is not on MATLAB''s search path. <a href="https://github.com/open-ephys/plugin-GUI/tree/master/Resources/Matlab">Download</a>'); 
                        throw(fileException)
                    end 
                otherwise 
                        fileException = MException('openEphys:missingDependency', 'Please compile the zeroMQrr mex file for your OS (32-bit or 64-bit)'); 
                        throw(fileException)
            end
            
        end 
    end 
    
    methods
        function o = beforeExperiment(o, varargin) 
            %Start data acquisition and recording.
            %Available function inputs include save file prefix/suffix and an option for creating a new directory.
            %Default values are used if no inputs are provided.
            %Example call: this.beforeExperiment('CreateNewDir', 1, 'PrependText', 'someText', 'AppendText', 'someText')
            
            %inputParser defines name-value pair inputs accepted by the function
            pin = inputParser; 
            pin.addParameter('CreateNewDir', 1, @(x) assert( x == 0 || x == 1, 'It must be either 1 (true) or 0 (false).'));
            pin.addParameter('PrependText', '', @ischar); 
            pin.addParameter('AppendText', '', @ischar);  
            pin.parse(varargin{:});
            
            %Generate string command that initiates recording and specifies save information  
            request = sprintf('StartRecord CreateNewDir=%i RecDir=%s PrependText=%s AppendText=%s', pin.Results.CreateNewDir, o.cic.fullPath, pin.Results.PrependText, pin.Results.AppendText);
            
            [~, stat1] = zeroMQrr('Send', o.hostAddr, 'StartAcquisition', 1); %Blocking set to 1, waits for response before proceeding. 
                                                                              %Throws error if no response.                                                                                                 
            o.latencyStruct.startAcqLatency(end+1) = stat1.timeResponseReceived - stat1.timeRequestSent;
            
            o.connectionStatus = true; 
                                                                                                       
            [~, stat2] = zeroMQrr('Send', o.hostAddr, request, 1); %Issue command to start recording            
            o.latencyStruct.startRecordLatency(end+1) = stat2.timeResponseReceived - stat2.timeRequestSent;
            
            [~, stat3] = zeroMQrr('Send', o.hostAddr, o.startMsg, 1);
            o.latencyStruct.startMsg(end+1) = stat3.timeResponseReceived - stat3.timeRequestSent;                         
        end
        
        function o = afterExperiment(o) 
            %Stop recording and data acquisition. 
                        
            [~, stat1] = zeroMQrr('Send',o.hostAddr, 'StopRecord', 1);
            o.latencyStruct.stopRecordLatency(end+1) = stat1.timeResponseReceived - stat1.timeRequestSent;
            
            [~,stat2] = zeroMQrr('Send', o.hostAddr, o.stopMsg, 1);
            o.latencyStruct.stopMsg(end+1) = stat2.timeResponseReceived - stat2.timeRequestSent;
            
            [~, stat3] =  zeroMQrr('Send',o.hostAddr, 'StopAcquisition', 1); 
            o.latencyStruct.stopAcqLatency(end+1) = stat3.timeResponseReceived - stat3.timeRequestSent;
            
            [~] = zeroMQrr('GetResponses',o.hostAddr,1);
            
            zeroMQrr('CloseThread', o.hostAddr);
            zeroMQrr('CloseAll'); %closes all open sockets and queue thread
            
            o.connectionStatus = false; 
        end
        
        function o = beforeTrial(o)
            beforeTrial@neurostim.plugins.ePhys(o);
            zeroMQrr('Send', o.hostAddr, o.trialInfo ,1); 
        end 
        
        function o = afterTrial(o) 
            afterTrial@neurostim.plugins.ePhys(o); 
            zeroMQrr('Send', o.hostAddr, o.trialInfo,1); 
        end 
               
    end
    
end

% function temp = validateDir(directory)
%     %validator used by inputParser to check whether selected recording directory exists
%     if exist(directory, 'dir') == 7 
%         temp = true;
%     else
%         temp = false;
%     end 
%         
% end 


