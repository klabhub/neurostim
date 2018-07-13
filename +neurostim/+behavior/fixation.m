classdef fixation  < neurostim.behavior.behaviorStateMachine
    
    properties
        x=0;
        y=0;
        tolX =1;
        tolY=1;
    end
    % State functions
    methods
        function o=fixation
%             o.addParameter('x',0);
%             o.addParameter('y',0);
%             o.addParameter('tolX',0);
%             o.addParameter('tolY',0);
            o.currentState = @o.freeViewing;
            
        end
        
        function freeViewing(o,e)
            if isInside(o,e)
                transition(o,@o.fixating);
            else
            end
        end
        
        function fixating(o,e)
            if isInside(o,e)
            else
                transition(o,@o.endTrial);
            end
        end
    end
    
    methods (Access=protected)
        function value= isInside(o,e)
              value= all(abs(e.x-o.x)<o.tolX) && all(abs(e.y-o.y)<o.tolY);
        end
    end
end