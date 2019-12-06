classdef fixate  < neurostim.behaviors.eyeMovement
    % This state machine defines two new states:
    %
    % FREEVIEWING - each trial starts here
    %             -> FIXATING when the eye moves inside the window
    %             -> FAIL if t > t.from
    %             -> FAIL afterTrial
    % FIXATING    -> FREEVIEWING if eye moves outside the window before o.grace
    %             -> FAIL if eye moves outside the window after o.grace and before t.to
    %             -> SUCCESS if eye is still inside the window at or after t.to
    %             -> SUCCESS afterTrial
    % 
    % Eye position can enter and leave the fixation window within the grace
    % period without penalty, i.e., if the subject breaks fixation within
    % the grace period we return to the FREEVIEWING state.
    %
    % By default, the grace period is 0 ms and the eye has to remain 
    % in the window once it is in there (i.e., **even for t < o.from**,
    % no in-and-out privileges).
    %
    % Parameters (inherited from eyeMovement):
    % 
    %   X,Y         - fixation position.
    %   tolerance   - radius/tolerance of the fixation window around X,Y.
    %   invert      - invert the definition: eye position must remain outside the
    %                 window for o.from < t < o.to.
    %   allowBlinks - ignore blinks.
    %
    % Parameters (specific to this behavior):
    %
    %   grace       - can break fixation within grace (ms) without penalty (default: 0 ms).
    %
    % BK - July 2018
    
    properties (Dependent)
       isFreeViewing;
       isFixating;
    end
    
    % State functions
    methods
        % In the constructor, a behavior must define the beforeTrialState -
        % the state where each trial will start.
        function o = fixate(c,name)
            o = o@neurostim.behaviors.eyeMovement(c,name);
            
            o.addProperty('grace',0,'validate',@isnumeric);
            
            o.beforeTrialState = @o.freeViewing; % Initial state at the start of each trial            
        end
        
        %% States
        % Each state is a member function that takes trial time (t) and an
        % event (e) as its input. The function inspects the event or the
        % time and then decides whether a transition to a new state is in
        % order
        % In addition to regular events (e.isRegular) states also receive
        % events that signal that a state is about to begin (e.isEntry) or
        % end (e.isExit). By checking for these events, the state can do
        % some setup - most states don't have to do anything. 
        function freeViewing(o,t,e)
            % Free viewing has two transitions, either to fail (if we reach
            % the time when the subject shoudl have been fisating (o.from)), 
            % or to fixating (if the eye is in the window)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail

            if ~e.isRegular ;return;end % Ignroe Entry/exit events.
            
            if t > o.from  % guard 1             
                transition(o,@o.fail,e);     
            else
                [inside,isAllowedBlink] = isInWindow(o,e);  % guard 2
                if isAllowedBlink
                    % Stay in free viewing
                elseif inside
                    transition(o,@o.fixating,e);  % Note that there is no restriction on t so fixation can start any time after t.on (which is when the behavior starts running)                               
                end
            end
        end
        
        % A second state.  Note that there is no if(fixating) code; the only
        % time that this code is called is when the state is 'fixating'. We
        % only have to look forward (where to transition to), it does not
        % matter where we came from.
        function fixating(o,t,e)
            if e.isAfterTrial; transition(o,@o.success,e); end % if still in this state-> success

            if ~e.isRegular; return; end % No Entry/exit needed.
           
            % Guards
            [inside,isAllowedBlink] = isInWindow(o,e);
            complete = t >= o.to;
           
            % Transitions
            if complete
                transition(o,@o.success,e);
            elseif isAllowedBlink
                % OK stay in fixating state
            elseif ~inside
                if o.duration < o.grace
                    remove(o.iStartTime,o.stateName); % clear FIXATING startTime
                    transition(o,@o.freeViewing,e); % return to FREEVIEWING, no penalty
                else
                    transition(o,@o.fail,e);
                end
            end
        end
       
    end % methods
    
    methods % get methods
        function v = get.isFreeViewing(o)
          v = strcmpi(o.stateName,'FREEVIEWING');
        end

        function v = get.isFixating(o)
            v = strcmpi(o.stateName,'FIXATING');
        end
    end
  
end % classdef