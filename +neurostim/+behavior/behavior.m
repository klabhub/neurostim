classdef behavior <  neurostim.plugin 
    
    properties
        stateMachine@neurostim.behavior.behaviorStateMachine; 
        everyFrame@logical =true;
        
    end
    
    
    %% Standard plugin member functions
    methods
        function beforeExperiment(o)
        end
        
        
        function beforeTrial(o)
            
        end
        
        function beforeFrame(o)
            if o.everyFrame               
                handleEvent(o.stateMachine);
            end
        end
        
        function afterFrame(o)
        end
        
        function afterTrial(o)
        end
        function afterExperiment(o)
        end
    end
    
    
end