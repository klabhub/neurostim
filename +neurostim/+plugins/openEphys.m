classdef openEphys < neurostim.plugins.ePhys
    % Neurostim plugin that adds x functions to the Open Ephys GUI. 
    % Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public) 
        createNewDir
        prependText 
        appendText 
        latencyStruct = struct('startAcqLatency', [], 'startMsg', [], 'startRecordLatency', [], ...
            'stopRecordLatency', [], 'stopMsg',[] , 'stopAcqLatency', []);  %structure for storing start/stop latency statistics

    end
    
    methods (Access = public)
        function o = openEphys(c, varargin) 
            %Class constructor
            %Example: o = neurostim.plugins.openEphys(c [,HostAddr] [,StartMsg] [,StopMsg] [,CreateNewDir] [,PrependText] [,AppendText])
            %Optional parameter/value pairs: 
            %HostAddr - TCP address of the machine running Open Ephys. Default is tcp://localhost:5556
            %StartMsg - String to be sent at the start of the experiment. Default is 'Neurostim experiment.'
            %StopMsg - String to be sent at the end of the experiment. Default is 'End of experiment.'
            %CreateNewDir - If true, creates new directory rather than appending data to existing directory. Default is True.
            %PrependText - Specify prefix for the name of the save directory. Default is blank.
            %AppendText - Specify suffix for the name of the save directory. Default is blank.             
            
            %Pre-Initialisation
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
            
            %inputParser defines name-value pair inputs accepted by the constructor
            pin = inputParser;              
            pin.addParameter('CreateNewDir', 1, @(x) assert( x == 0 || x == 1, 'It must be either 1 (true) or 0 (false).'));
            pin.addParameter('PrependText', '', @ischar); 
            pin.addParameter('AppendText', '', @ischar);  
            pin.KeepUnmatched = true; 
            pin.parse(varargin{:});
            
            %Object initialisation
            %Call parent class constructor
            %Pass HostAddr, StartMsg and StopMsg to the parent constructor via the 'Unmatched' property of the input parser.
            o = o@neurostim.plugins.ePhys(c, pin.Unmatched); 
            
            %Post-initialisation
            %Initialise class properties
            o.createNewDir = pin.Results.CreateNewDir; 
            o.prependText = pin.Results.PrependText; 
            o.appendText = pin.Results.AppendText; 
                                   
        end 
    end 
    
    methods (Access = protected)
        function startRecording(o)
            %Start data acquisition and recording.
            %Set connectionStatus flag.
            
            %Generate string command that is used to initiate recording and specify save information  
            request = sprintf('StartRecord CreateNewDir=%i RecDir=%s PrependText=%s AppendText=%s', ...
                o.createNewDir, o.cic.fullPath, o.prependText, o.appendText);
            
            [~, stat1] = zeroMQrr('Send', o.hostAddr, 'StartAcquisition', 1); %Blocking set to 1, waits for response before proceeding. 
                                                                              %Throws error if no response.                                                                                                 
            o.latencyStruct.startAcqLatency(end+1) = stat1.timeResponseReceived - stat1.timeRequestSent;
            
            o.connectionStatus = true; 
                                                                                                       
            [~, stat2] = zeroMQrr('Send', o.hostAddr, request, 1); %Issue command to start recording            
            o.latencyStruct.startRecordLatency(end+1) = stat2.timeResponseReceived - stat2.timeRequestSent;
            
            [~, stat3] = zeroMQrr('Send', o.hostAddr, o.startMsg, 1);
            o.latencyStruct.startMsg(end+1) = stat3.timeResponseReceived - stat3.timeRequestSent; 
        end 
        
        function stopRecording(o) 
            %Stop recording and data acquisition. 
            %Reset connectionStatus flag.
            %Close connection.
            
            [~,stat2] = zeroMQrr('Send', o.hostAddr, o.stopMsg, 1);
            o.latencyStruct.stopMsg(end+1) = stat2.timeResponseReceived - stat2.timeRequestSent;
            
            [~, stat1] = zeroMQrr('Send',o.hostAddr, 'StopRecord', 1);
            o.latencyStruct.stopRecordLatency(end+1) = stat1.timeResponseReceived - stat1.timeRequestSent;
                       
            [~, stat3] =  zeroMQrr('Send',o.hostAddr, 'StopAcquisition', 1); 
            o.latencyStruct.stopAcqLatency(end+1) = stat3.timeResponseReceived - stat3.timeRequestSent;
            
            zeroMQrr('CloseAll'); %closes all open sockets and queue thread
            
            o.connectionStatus = false; 
        end
        
        function startTrial(o)
            %Send string at start of trial 
            zeroMQrr('Send', o.hostAddr, o.trialInfo ,1); 
        end 
        
        function stopTrial(o) 
            %Send string at end of trial
            zeroMQrr('Send', o.hostAddr, o.trialInfo,1); 
        end 
               
    end
    
end
