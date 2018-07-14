classdef fixate  < neurostim.behaviors.eyeMovement
    % This state machine defines two new states:
    % FREEVEIWING - each trial starts here
    %              -> FIXATING when the eye moves inside the window
    %              ->FAIL  if t>t.from
    % FIXATING    -> FAIL if eye moves outside the window before t.to
    %             -> SUCCESS if eye is still inside the window at or after t.to  
    %% STATE DIAGRAM:
    % FREEVIEWING ---(isInWindow)?--->   FIXATING --- (~isInWindow)? --> FAIL 
    %       |                               |
    %     (t>from)? --> FAIL               t>to? ---> SUCCESS   
    %
    % Note that **even before t< o.from**, the eye has to remain 
    % in the window once it is in there (no in-and-out privileges)
    %
    %% Parameters (inherited from eyeMovement):
    % 
    % X,Y,  - fixation position 
    % tolerance - width/height of the square tolerance window around X,Y
    % invert - invert the definition : eye position outside the tolerance is
    %           considered good, inside is bad.
    %
    % BK - July 2018
    
    % State functions
    methods
        
        function o=fixate(c,name)
            o = o@neurostim.behaviors.eyeMovement(c,name);   
            o.beforeExperimentState = @o.freeViewing; % Initial state at the start of the experiment
            o.beforeTrialState      = @o.freeViewing; % Initial state at the start of each trial            
        end
        
        function freeViewing(o,t,e)
            % Free viewing has two transitions, either to fail (if we reach
            % the timeout), or to fixating (if the eye is in the window)
            if ~e.isRegular ;return;end % No Entry/exit needed.
            if t>o.from               
                transition(o,@o.fail);
            elseif isInWindow(o,e)
                transition(o,@o.fixating);            
            end
        end
        
        
       function fixating(o,t,e)
         	if ~e.isRegular ;return;end % No Entry/exit needed.
            if isInWindow(o,e)
                if t>o.to
                    transition(o,@o.success);
                end
            else
                transition(o,@o.fail);
            end
        end
    end
  
end