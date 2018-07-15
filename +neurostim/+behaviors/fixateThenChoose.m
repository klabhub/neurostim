classdef fixateThenChoose < neurostim.behaviors.fixate
   % Fixate a fixation point first, then make a saccade to a choice annulus.
   % This behavior inherits from fixate and adds new states. 
   % FREEVEIWING - each trial starts here
    %              -> FIXATING when the eye moves inside the window
    %              ->FAIL  if t>t.from
    % FIXATING    -> FAIL if eye moves outside the window before t.to or
    %                       does not reach CHOOSE before o.choiceFrom
    %             -> CHOOSE  if eye moves to the choice targets between
    %                   t.to and t.choiceFrom.
    % CHOOSE     -> FAIL if the eye leaves the first choice sooner than o.chooseDuration
    %            -> SUCCESS if the eye is still withion o.tolerance of the
    %            choice after o.choiseDuration.
    % Note that **even before t< o.from**, the eye has to remain 
    % in the window once it is in there (no in-and-out privileges)
  
   
   properties (Access=private)
   end
   
   methods
       function o=fixateThenChoose(c,name)
           o=o@neurostim.behaviors.fixate(c,name);
           % Add some properties that are needed only in this behavior
           o.addProperty('radius',5); % Radius of the choice annulus
           o.addPreoperty('angles',[]); % A vector of angles that are allowed. 
           o.addProperty('choiceFrom',0);  % Choice dot must have been reach at this time.           
           o.addProperty('choiceDuration',300);  % choice dot must be fixated this long 
           o.addProperty('choice',[]); % Log of choices
           o.addProperty('correctFun',''); 
           
           
           o.beforeTrialState = @o.freeViewing;
       end       
   end
   
   methods
        % Define the fixation state by coding all its transitions
        function fixating(o,t,e)            
            if ~e.isRegular;return;end % regular only - no entry/exit
            if t>o.to 
                if t <o.choiceFrom
                    % Still ok to move into choice
                    if isInAnnulus(o,e)
                        transition(o,@o.choose);                    
                    else
                        % Slacktime to make the saccade - stay in fixating
                        % state for now.
                    end
                else
                    transition(o,@o.fail);
                end                    
            elseif isInWindow(o,e)
                % Stay in fixating state
            else % Fixation break
                transition(o,@o.fail);
            end
        end
            
        % Define the choose state by coding all its transitions            
        function choose(o,t,e)            
            if ~e.isRegular;return;end % regular only - no entry/exit
            if isInAnnulus(o,e)
                if stateDuration(o,t,'choose')>= o.choiceDuration
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
       
        % Dertermine whether the eye is on a choice target. 
        % Users specify a radius and (optionally) a set of allowed angles
        % an empty set of angles means that the choice can be anywhere in
        % the annulus (continuous choice)
        function [v,targetIx] = isInAnnulus(o,e) 
            % Check that the eye is on the annlus within tolerance 
            v  = abs(hypot(e.X - o.X,e.Y- o.Y)-o.radius) < o.tolerance;
            nrAngles =numel(o.angles);
            if nrAngles>0 && v        
                targetIx = find(norm([cosd(o.angles(:)') sind(o.angles(:)')] -repmat([e.X e.Y],[nrAngles 1]))<o.tolerance);
                v = ~isempty(targetIx) && v;
            end
            if o.invert
               v = ~v;
           end
        end
       
    end
    
end