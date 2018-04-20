classdef ePhys < neurostim.plugin
    %Generic class for electrophysiology acquisition systems e.g. Blackrock Centrale, Open Ephys GUI
    %   Detailed explanation goes here
    
    properties (SetAccess = private, GetAccess = public)
        trialInfo 
    end
    
    properties (SetAccess = protected, GetAccess = public) 
        hostAddr = 'tcp://localhost:5556'; %IP address of the machine acquiring data, and the TCP port.
        
    end 
    
    methods
        function o = ePhys(c) 
            o = o@neurostim.plugin(c,'ePhys'); 
            o.addProperty('connectionStatus', false, 'validate', @islogical);             
            o.addProperty('startMsg', 'Neurostim experiment', 'validate', @ischar);
            o.addProperty('stopMsg', 'Experiment complete', 'validate', @ischar); 
            
        end 
        
        function beforeExperiment(o) %called by cic
            %Placeholder function to be overridden with the following actions. 
            %Establish connection and start acquisition/recording. 
            %Set connectionStatus flag upon sucessful connection. 
            %Send message that marks start of experiment.
        end 
        
        function beforeTrial(o) 
            o.trialInfo = ['Start_T' num2str(o.cic.trial) '_C' num2str(o.cic.condition)];
        end 
        
        function afterExperiment(o) 
            %Placeholder function to be overriden with the following actions.
            %Stop recording/acquisition and close connection.
            %Reset connectionStatus flag.
            %Send message that marks end of experiment.
        end 
        
        function afterTrial(o) 
            o.trialInfo = ['Trial' num2str(o.cic.trial) 'complete'];
        end 
    end
    
end

