classdef saccade < neurostim.behaviors.fixate
    % Behavior that enforces a fixation->saccade->fixation sequence
    % By inheriting from behaviors.fixate we only have to define two
    % additional states. 
    %% States:
    % FREEVEIWING - each trial starts here
    %              -> FIXATING when the eye moves inside the window (X,Y)
    %              ->FAIL  if t>t.from
    % FIXATING    -> FAIL if eye is still inside the window after o.to or
    %                   outside the window before o.to
    %             -> INFLIGHT if eye moves outside the window after o.to 
    % INFLIGHT     -> FAIL if t > saccadeLate   
    %             -> ONTARGET  if inside the target window (endX,endY)
    % ONTARGET    -> SUCCESS if inside target for o.targetDuration 
    %             -> FAIL if outside target before o.targetDuration
    %
    %% Parameters
    % X,Y = (first) fixation position
    % targetX,targetY = target positions (multiple allowed).

        
    
    methods
        function o=saccade(c,name,varargin)
            o=o@neurostim.behaviors.fixate(c,name);
            
            o.addProperty('targetX',[5 -5],'validate',@isnumeric);   % end possibilities - calculated as an OR
            o.addProperty('targetY',[5 5],'validate',@(x) isnumeric(x) && all(size(x)==size(o.endX)));
            o.addProperty('saccadeDuration',150,'validate',@isnumeric);
            o.addProperty('targetDuration',150,'validate',@isnumeric);   
            o.beforeTrialState = @o.freeViewing; 
        end
        
        
        function fixating(o,t,e)
            if ~e.isRegular ;return;end % No Entry/exit needed.
         
            if t>o.to 
                if isInWindow(o,e)
                    transition(o,@o.fail);
                else                
                    transition(o,@o.inFlight);
                end
            else
                if ~isInWindow(o,e)
                    transition(o,@o.fail);
                %else - stay in state
                end
            end
        end
        
        function inFlight(o,t,e)
              if ~e.isRegular ;return;end % No Entry/exit needed.
         
            if isInWindow(o,e,o.targetX,o.targetY)
                transition(o,@o.onTarget);
            elseif stateDuration(o,t,'INFLIGHT') > o.saccadeDuration
                transition(o,@o.fail);                
            end
        end
        
        
        function onTarget(o,t,e)
            if ~e.isRegular ;return;end % No Entry/exit needed.
         
            if stateDuration(o,t,'ONTARGET') >= o.targetDuration
                transition(o,@o.success);
            elseif ~isInWindow(o,e,o.targetX,o.targetY)
                %Left the window prematurely
                transition(o,@o.fail);
            end                
        end
        
        
    end
    
    
    
end