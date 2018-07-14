classdef choiceAnnulus < neurostim.behaviors.fixate
   % Fixate a fixation point first, then make a saccade to a choice annulus.
   
   
   properties (Access=private)
   end
   
   methods
       function o=choiceAnnulus(c,name)
           o=o@neurostim.behaviors.fixate(c,name);
           o.addProperty('radius',5);
           o.addProperty('choiceFrom',0);
           o.addProperty('choiceDuration',300);
           
           o.beforeExperimentState = @o.freeViewing;
           o.beforeTrialState = @o.freeViewing;
       end       
   end
   
   methods
       % The fixating state means the eye is at X Y within tolerance.
       
        function fixating(o,t,e)            
            if t>o.to 
                if isInAnnulus(o,e)
                    transition(o,@o.choice);
                    
                elseif t< o.choiceFrom
                    % Slacktime to make the saccade - stay in fixating
                    % state for now.
                else
                    transition(o,@o.fail);
                end                    
            elseif isInWindow(o,e)
                % Stay in fixating state
            else % Fixation break
                transition(o,@o.fail);
            end
        end
            
            
        function choice(o,t,e)            
            if isInAnnulus(o,e)
                if stateDuration(o,t,'choice')>= o.choiceDuration
                    transition(o,@o.success);
                else
                    % Stay
                end
            else
                transition(o,@o.fail);
            end                
        end
        
        
   end
   
   methods (Access=protected)
       
        % Dertermine whether the eye is (anywhere) within an annulus. Useful for saccades to a choice circle.
        function value = isInAnnulus(o,e)               
            value  = abs(hypot(e.X - o.X,e.Y- o.Y)-o.radius) < o.tolerance;
            if o.invert
               value = ~value;
           end
        end
       
    end
    
end