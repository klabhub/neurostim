classdef eyeMovement  < neurostim.behavior.behaviorStateMachine
    
    properties
        x@double;
        y@double;
        
    end
    % State functions
    methods
        function o=eyeMovement
            o.addParameter('x',0);
            o.addParameter('y',0);
            o.addParameter('tolX',0);
            o.addParameter('tolY',0);
            
        end
        
        function freeViewing(o,e)
            if all(abs(e.x-o.x)<o.tolX) && all(abs(e.y-o.y)<o.tolY)
                %Inside window
            else
            end
        end
        function fixating(o,e)
        end
    end
end