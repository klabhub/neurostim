classdef fixate  < neurostim.behaviors.eyeMovement
    % This state machine defines two new states:
    % freeViewing (set as the initial state)
    % fixating   (reached when the eye moves inside the window)
    % and it inherits two of the standard states;
    % success (reached if the eye is still in the window at o.to time 
    % fail (reached when the eye leaves the window before the .from time, or 
    %       if it never reaches the window at all)
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
            if t>o.from               
                transition(o,@o.fail);
            elseif isInWindow(o,e)
                transition(o,@o.fixating);            
            end
        end
        
        
       function fixating(o,t,e)
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