classdef ePhys < neurostim.plugin
    %Generic class for electrophysiology acquisition systems e.g. Blackrock Centrale, Open Ephys GUI
    %Detailed explanation goes here
    
    properties (Access = public) 
        fakeConnection@logical = false;
        startMsg
        stopMsg
    end
    
    properties (SetAccess = protected, GetAccess = public)         
        connectionStatus@logical = false;        
        trialInfo 
    end     
    
    methods (Access = public)
        
        function o = ePhys(c, varargin) 
            
            %Object initialization
            %Call parent class constructor
            o = o@neurostim.plugin(c,'ePhys'); 
            
            %Post-initialisation
            %Initialise class properties
            o.addProperty('hostAddr', 'tcp://localhost:5556', 'validate', @ischar);
            o.addProperty('useMCC', true, 'validate', @islogical) ; 
            o.addProperty('mccChannel', [], 'validate', @isnumeric);
            o.addProperty('clockTime', []); 
            
            pin = inputParser;
            pin.addParameter('HostAddr', 'tcp://localhost:5556', @ischar);
            pin.addParameter('StartMsg', 'Neurostim experiment', @ischar); 
            pin.addParameter('StopMsg', 'End of experiment', @ischar);
            pin.parse(varargin{:})
            
            o.hostAddr = pin.Results.HostAddr; 
            o.startMsg = pin.Results.StartMsg; 
            o.stopMsg = pin.Results.StopMsg; 
        end 

        %Automatically called by cic.run()
        function beforeExperiment(o) 
            o.startRecording(); 
        end 
        
        function beforeTrial(o) 
            o.trialInfo = ['Start_T' num2str(o.cic.trial) '_C' num2str(o.cic.condition)];
            startTrial(o);
            %Send a second trial marker, through digital I/O box (Measurement Computing)
            if o.useMCC
                o.cic.mcc.digitalOut(o,o.mccChannel,1);
            end
        end 
        
        function afterExperiment(o)            
            stopRecording(o);
        end 
        
        function afterTrial(o) 
            o.trialInfo = ['Trial' num2str(o.cic.trial) 'complete'];
            stopTrial(o);
            %Send a second trial marker, through digital I/O box (Measurement Computing)
            if o.useMCC
                o.cic.mcc.digitalOut(o,o.mccChannel,0);
            end
        end 
    end
    
    methods (Access = protected) 
        
        function startRecording(~)
            %Defined in child class
            %The following actions should be specified here:
            %Start acquisition/recording, set connectionStatus flag, send exerpiment start message 
        end
        
        function stopRecording(~)
            %Defined in child class
            %The following actions should be specified here:
            %Stop recording/acquisition, reset connectionStatus flag, send experiment end message
        end 
        
        function startTrial(~)
            %Defined in child class
            %Indicate the start of a trial with a string
        end 
        
        function stopTrial(~)
            %Defined in child class
            %Indicate the end of a trial with a string
        end
            
    end 
    
end

