classdef (Abstract) ePhys < neurostim.plugin
    % Abstract base class for electrophysiology acquisition systems e.g. Blackrock Central, Open Ephys GUI
    
    properties (Access = public) 
        fakeConnection@logical = false;
        
        startMsg;
        stopMsg;
    end
    
    properties (SetAccess = protected, GetAccess = public)         
        connectionStatus@logical = false;
        
        trialInfo;
    end
    
    methods (Access = public)        
        function o = ePhys(c,name,varargin) 
            % Call parent class constructor
            o = o@neurostim.plugin(c,name);

            % parse arguments...
            pin = inputParser;
            pin.addParameter('hostAddr', '', @ischar);
            pin.addParameter('startMsg', '', @(x) ischar(x) || iscell(x)); 
            pin.addParameter('stopMsg', '', @(x) ischar(x) || iscell(x));
            pin.parse(varargin{:})
            
            args = pin.Results;
            %
            
            o.startMsg = args.startMsg; 
            o.stopMsg = args.stopMsg; 

            o.addProperty('hostAddr', args.hostAddr, 'validate', @ischar);
            
            o.addProperty('useMCC', false, 'validate', @islogical) ; 
            o.addProperty('mccChannel', 1, 'validate', @isnumeric); %Channel B (1) is set to output

            o.addProperty('clockTime', []); % FIXME: never set?
        end 
               
        function beforeExperiment(o)
            if isempty(o.startMsg)
                % by default, we match the messages logged by the eyelink plugin
                o.startMsg = { ...
                  sprintf('RECORDED BY %s',o.cic.experiment), ... % <-- o.cic.experiment is only set at run time
                  sprintf('NEUROSTIM FILE %s',o.cic.fullFile)};
            end
                        
            o.startRecording();
            
            sendMessage(o,o.startMsg);
            
            % I think mixing and matching the role of mccChannel is a bad
            % idea... it should indicate start/end of the experiment or
            % start/end of a trial, not both...
%             if o.useMCC
%                 o.cic.mcc.digitalOut(o.mccChannel,uint8(1));
%                 o.cic.mcc.digitalOut(o.mccChannel,uint8(0));
%             end
        end 
        
        function beforeTrial(o)
            if isempty(o.trialInfo)
                % again, by default, match the messages logged by the eyelink plugin
                msg = {sprintf('TR:%i',o.cic.trial);
                       sprintf('TRIALID %d-%d',o.cic.condition,o.cic.trial)};
            else
                msg = o.trialInfo;
            end
            
            sendMessage(o,msg);

            % Send a second trial marker, through digital I/O box (Measurement Computing)
            if o.useMCC
                o.cic.mcc.digitalOut(o.mccChannel,uint8(1));
                o.cic.mcc.digitalOut(o.mccChannel,uint8(0));
            end
        end 
        
        function afterExperiment(o)
            if ~isempty(o.stopMsg)
              sendMessage(o,o.stopMsg);
            end
            
            stopRecording(o);  
          
%             if o.useMCC
%                 o.cic.mcc.digitalOut(o.mccChannel,uint8(1));
%                 o.cic.mcc.digitalOut(o.mccChannel,uint8(0));
%             end
        end 
        
        function afterTrial(o)
            if ~isempty(o.trialInfo)
              sendMessage(o,o.trialInfo);
            end

            % Send a second trial marker, through digital I/O box (Measurement Computing)
            if o.useMCC
                o.cic.mcc.digitalOut(o.mccChannel,uint8(1));
                o.cic.mcc.digitalOut(o.mccChannel,uint8(0));
            end
        end 
    end

    methods (Abstract, Access = public)
        sendMessage(o,msg); % sends a message to the ephys device (to be recorded in the ephys data file)
    end
    
    methods (Abstract, Access = protected)
        % The following actions should be performed here:
        % Start acquisition/recording, set connectionStatus flag, send experiment start message
        startRecording(o);

        % The following actions should be performed here:
        % Stop recording/acquisition, reset connectionStatus flag, send experiment end message
        stopRecording(o)
        
%         function startTrial(~)
%             % NOP 
%             % Indicate the start of a trial with a string
%         end 
%         
%         function stopTrial(~)
%             % NOP 
%             % Indicate the end of a trial with a string
%         end        
    end 
    
end

