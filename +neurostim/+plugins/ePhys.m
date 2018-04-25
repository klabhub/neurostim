classdef ePhys < neurostim.plugin
    %Generic class for electrophysiology acquisition systems e.g. Blackrock Centrale, Open Ephys GUI
    %Detailed explanation goes here
          
    properties (SetAccess = protected, GetAccess = public)         
        connectionStatus@logical = false;
        fakeConnection@logical = false;
        startMsg@char = 'Neurostim experiment'; 
        stopMsg@char = 'End of experiment';
        trialInfo 
    end      
    
    methods (Access = public)
        
        function o = ePhys(c) 
            o = o@neurostim.plugin(c,'ePhys'); 
            o.addProperty('hostAddr', 'tcp://localhost:5556', 'validate', @ischar, 'SetAccess', 'protected', 'GetAccess', 'public');
            o.addProperty('useMCC', true, 'validate', @islogical) ; 
            o.addProperty('mccChannel', [], 'validate', @isnumeric);
            o.addProperty('clockTime', []); 
            
        end 

        %Automatically called by cic.run()
        function beforeExperiment(o) 
            o.startRecording(); 
        end 
        
        function beforeTrial(o) 
            startTrial(o); 
        end 
        
        function afterExperiment(o) 
            stopRecording(o);
        end 
        
        function afterTrial(o) 
            stopTrial(o); 
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

