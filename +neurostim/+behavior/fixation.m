classdef fixation  < neurostim.behavior.eyeMovement
    % This state machine defines two new states:
    % freeViewing (set as the initial state)
    % fixating   (reached when the eye moves inside the window)
    % and it inherits two of the standard states;
    % success (reached if the eye is still in the window at o.off time 
    % fail (reached when the eye leaves the window before the .off time, or 
    %       if it never reaches the window at all)
    %
    
    
    % State functions
    methods
        
        function o=fixation(c,name)
            o = o@neurostim.behavior.eyeMovement(c,name);   
            o.initialState = @o.freeViewing; % Initial state at the start of the trial
        end
        
        function freeViewing(o,e)
            % Free viewing has two transitions, either to fail (if we reach
            % the timeout), or to fixating (if the eye is in the window)
            if isTimeout(o,e)               
                transition(o,@o.fail);
            elseif isInWindow(o,e)
                transition(o,@o.fixating);            
            end
        end
        
        
       function fixating(o,e)
            if isInWindow(o,e)
                if isTimeout(o,e)
                    transition(o,@o.success);
                end
            else
                transition(o,@o.fail);
            end
        end
    end
  
end