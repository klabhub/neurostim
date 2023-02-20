classdef openEphys < neurostim.plugins.ePhys
    % Plugin for interacting with the Open Ephys GUI via tcp/ip
    %
    % Example usage:
    %
    %   o = neurostim.plugins.openEphys(c, 'oephys' [,HostAddr] [,RecDir] [,StartMsg] [,StopMsg] [,CreateNewDir] [,PrependText] [,AppendText])
    %
    % Optional parameters may be specified via name-value pairs:
    %
    %   HostAddr - IP address of the machine running Open Ephys (e.g., 'tcp://localhost:5556'; default: '')
    %   RecDir - Directory used for saving OpenEphys generated continuous, spike and event files. 
    %   StartMsg - String to be sent at the start of the experiment.
    %   StopMsg - String to be sent at the end of the experiment.
    %   CreateNewDir - 0 = append to existing directory, 1 = create a new directory (default: 1, create new)
    %   PrependText - Specify prefix for the name of the save directory.
    %   AppendText - Specify suffix for the name of the save directory.
    
    methods (Access = public)
        function o = openEphys(c,name,varargin) 
          
            % Check whether zeroMQrr mex file is on the search path
            switch (computer)
                case 'PCWIN64' %Windows 64-bit
                    if exist('zeroMQrr.mexw64', 'file') == 0 
                        fileException = MException('openEphys:missingDependency', 'The mex file zeroMQrr.mexw64 is not on MATLAB''s search path. <a href="https://github.com/open-ephys/plugin-GUI/tree/master/Resources/Matlab">Download</a>'); 
                        throw(fileException)
                    elseif exist('libzmq-v120-mt-4_0_4.dll', 'file') == 0 
                        fileException = MException('openEphys:missingDependency', 'The library file libzmq-v120-mt-4_0_4.dll is not on MATLAB''s search path. <a href="https://github.com/open-ephys/plugin-GUI/tree/master/Resources/Matlab">Download</a>');
                        throw(fileException)
                    end
                    
                case {'GLNX86','GLNXA64'}
                    if exist('zeroMQrr.mexa64','file') ~= 3
                        fileException = MException('openEphys:missingDependency', 'The mex file zeroMQrr.mexa64 is not on MATLAB''s search path. <a href="https://github.com/open-ephys/plugin-GUI/tree/master/Resources/Matlab">Download</a>'); 
                        throw(fileException)
                    end
                
                case 'MACI64' % OS X 64-bit
                    if exist('zeroMQrr.mexmaci64', 'file') == 0 
                        fileException = MException('openEphys:missingDependency', 'The mex file zeroMQrr.mexmaci64 is not on MATLAB''s search path. <a href="https://github.com/open-ephys/plugin-GUI/tree/master/Resources/Matlab">Download</a>'); 
                        throw(fileException)
                    elseif exist('libzmq-v120-mt-4_0_4.dll', 'file') == 0 
                        fileException = MException('openEphys:missingDependency', 'The library file libzmq-v120-mt-4_0_4.dll is not on MATLAB''s search path. <a href="https://github.com/open-ephys/plugin-GUI/tree/master/Resources/Matlab">Download</a>');
                        throw(fileException)
                    end
                    
                otherwise 
                        fileException = MException('openEphys:missingDependency', 'Please compile the zeroMQrr mex file for your OS (32-bit or 64-bit)'); 
                        throw(fileException)
            end
            
            % parse arguments
            pin = inputParser;     
            pin.KeepUnmatched = true; 

            pin.addParameter('CreateNewDir', 1, @(x) assert( x == 0 || x == 1, 'It must be either 1 (true) or 0 (false).'));
            pin.addParameter('RecDir', '', @ischar); % save path on the open ephys computer
            pin.addParameter('PrependText', '', @ischar); 
            pin.addParameter('AppendText', '', @ischar);
            pin.addParameter('startDelay',0, @isnumeric);
            
            pin.parse(varargin{:});
            
            args = pin.Results;
            %
            
            % Call parent class constructor
            % Pass HostAddr, StartMsg and StopMsg to the parent constructor via the 'Unmatched' property of the input parser.
            o = o@neurostim.plugins.ePhys(c,name,pin.Unmatched); 
            
            % Post-initialisation
            % Initialise class properties
            o.addProperty('createNewDir',args.CreateNewDir,'validate',@isnumeric);
            o.addProperty('recDir',args.RecDir,'validate',@ischar); 
            o.addProperty('prependText',args.PrependText,'validate',@ischar); 
            o.addProperty('appendText',args.AppendText,'validate',@ischar);                                   
            o.addProperty('startDelay',args.startDelay,'validate',@isnumeric);
        end
        
        function sendMessage(o,msg)
            % send a message to open ephys            
            if ~iscell(msg)
              msg = {msg};
            end
            
            for ii = 1:numel(msg)
              zeroMQrr('Send', o.hostAddr, msg{ii}, 1); % when blocking is set to 1, waits for response before proceeding and throws error if timeout
            end
        end
    end 
    
    methods (Access = protected)
        function startRecording(o)
            % Start data acquisition and recording.
            % Set connectionStatus flag.
            
            sendMessage(o,'StartAcquisition');
            o.connectionStatus = true; % <-- FIXME: is this used/useful for anything?
            
            if o.startDelay>0
                pause(o.startDelay);
            end
            
            % Generate command string that is used to initiate recording and specify save information  
            request = sprintf('StartRecord CreateNewDir=%i RecDir=%s PrependText=%s AppendText=%s', ...
                o.createNewDir, o.recDir, o.prependText, o.appendText);
                                                                                                       
            sendMessage(o,request); % Issue command to start recording            
        end 
        
        function stopRecording(o) 
            % Stop recording and data acquisition. 
            % Reset connectionStatus flag.
            
            sendMessage(o,'StopRecord');
                       
            sendMessage(o,'StopAcquisition');
            
%            zeroMQrr('CloseAll'); %closes all open sockets and queue thread...closes connection
%            before queue has been processed 

            o.connectionStatus = false; 
        end
        
%         function startTrial(o)
%             %Send string at start of trial 
%             zeroMQrr('Send', o.hostAddr, o.trialInfo ,0); 
%         end 
%         
%         function stopTrial(o) 
%             %Send string at end of trial
%             zeroMQrr('Send', o.hostAddr, o.trialInfo,0); 
%         end 
               
    end
    
end
