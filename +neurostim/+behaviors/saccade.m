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
    %             -> FAIL afterTrial
    % INFLIGHT     -> FAIL if in this state longer than o.saccadeDuration                   
    %             -> ONTARGET  if inside the target window (targetX,targetY)
    %             -> FAIL if afterTrial
    % ONTARGET    -> SUCCESS if inside target for o.targetDuration 
    %             -> FAIL if outside target before o.targetDuration
    %             -> SUCCESS if afterTrial
    %% Parameters
    % X,Y = (first) fixation position
    % from,to = required fixation at the XY starting fixation
    % targetX,targetY = target positions (multiple allowed).
    % saccadeDuration - the maximum duration of the saccade. The target must be acquired at o.to+o.saccadeDuration 
    % targetDuration  - the time that the target should be fixated    
    %
    % BK - July 2018
    methods
        function o=saccade(c,name,varargin)
            o=o@neurostim.behaviors.fixate(c,name);            
            o.addProperty('targetX',[5 -5],'validate',@isnumeric);   % end possibilities - calculated as an OR
            o.addProperty('targetY',[5 5],'validate',@(x) isnumeric(x) && all(size(x)==size(o.targetX)));
            o.addProperty('saccadeDuration',250,'validate',@isnumeric);
            o.addProperty('targetDuration',150,'validate',@isnumeric);   
            o.beforeTrialState = @o.freeViewing; 
        end
        
        
        function fixating(o,t,e)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail          
            if ~e.isRegular ;return;end % No Entry/exit needed. 
            % Setup the logical variables (guard conditions) that we need 
            % to decide whether to transition.
            % For efficiency reasons, every member variable (e.g. o.to) is
            % read only once (these variables could require the evaluation
            % of multiple functions behind the scenes)
            oTo= o.to;
            afterTo = t>oTo;
            saccadeMustHaveCompleted  = t>oTo+o.saccadeDuration;
            inside = isInWindow(o,e);
            % With these guards, code the three possible transitions listed
            % in the description above
            if saccadeMustHaveCompleted && inside
                transition(o,@o.fail,e);  % Transition to the fail state. Pass the event that lead to this transition
            elseif afterTo && ~inside                
                transition(o,@o.inFlight,e);% Transition to the inFlight state. Pass the event that lead to this transition
            elseif ~afterTo && ~inside
                transition(o,@o.fail,e);% Transition to the fail state. Pass the event that lead to this transition
            end
        end
        
        function inFlight(o,t,e)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail          
            if ~e.isRegular ;return;end % No Entry/exit needed
            % Define guard conditions
             insideTarget=isInWindow(o,e,[o.targetX,o.targetY]);
             inflighTooLong = o.duration > o.saccadeDuration;                       
             % Code transitions
             if insideTarget
                transition(o,@o.onTarget,e);
            elseif inflighTooLong 
                transition(o,@o.fail,e);                
            end
        end
        
        
        function onTarget(o,t,e)
            if e.isAfterTrial;transition(o,@o.success,e);end % if still in this state-> success          
            if ~e.isRegular ;return;end % No Entry/exit needed.
            %Define guard conditions            
            longEnough  = o.duration >= o.targetDuration;
            brokeTargetFixation = ~isInWindow(o,e,[o.targetX,o.targetY]);            
            % Code transitions
            if longEnough
                transition(o,@o.success,e);
            elseif brokeTargetFixation                
                transition(o,@o.fail,e);
            end                
        end
        
        
    end
    
    
    
end