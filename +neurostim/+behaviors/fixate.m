classdef fixate  < neurostim.behaviors.eyeMovement
    % This state machine defines two new states:
    % FREEVEIWING - each trial starts here
    %              -> FIXATING when the eye moves inside the window
    %              ->FAIL  if t>t.from
    %               ->FAIL afterTrial
    % FIXATING    -> FAIL if eye moves outside the window before t.to
    %             -> SUCCESS if eye is still inside the window at or after t.to  
    %             ->SUUCCSS afterTrial
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
        % In the constructor, a behavior must define the beforeTrialState -
        % the state where each trial will start.
        function o=fixate(c,name)
            o = o@neurostim.behaviors.eyeMovement(c,name);   
            o.beforeTrialState      = @o.freeViewing; % Initial state at the start of each trial            
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
            if t>o.from  % guard 1             
                transition(o,@o.fail,e);
            elseif isInWindow(o,e)  % guard 2
                transition(o,@o.fixating,e);  %Note that there is no restriction on t so fixation can start any time  after t.on (which is when the behavior starts running)           
            end
        end
        
       % A second state.  Note that there is no if(fixating) code; the only
       % time that this code is called is when the state is 'fixating'. We
       % only have to look forward (where to transition to), it does not
       % matter where we came from.
       function fixating(o,t,e)
            if e.isAfterTrial;transition(o,@o.success,e);end % if still in this state-> success
         	if ~e.isRegular ;return;end % No Entry/exit needed.
            % Guards 
            inside  = isInWindow(o,e);
            complete = t>=o.to;
            % Transitions
            if ~inside 
                transition(o,@o.fail,e);
            elseif complete
                 transition(o,@o.success,e);                
            end
        end
    end
 
end