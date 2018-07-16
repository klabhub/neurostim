classdef fixateThenChoose < neurostim.behaviors.fixate
   % Fixate a fixation point first, then make a saccade to a choice annulus.
   % This behavior inherits from fixate and adds new states. 
   % FREEVEIWING - each trial starts here
    %              -> FIXATING when the eye moves inside the window
    %              ->FAIL  if t>t.from
    %               ->FAIL afterTrial
    % FIXATING    -> FAIL if eye moves outside the window before t.to or
    %                       does not reach CHOOSE before o.choiceFrom
    %             -> CHOOSE  if eye moves to the choice targets between
    %                   t.to and t.choiceFrom.
    %               ->FAIL afterTrial
    % CHOOSE     -> FAIL if the eye leaves the first choice sooner than o.chooseDuration
    %            -> SUCCESS if the eye is still withion o.tolerance of the
    %            choice after o.choiseDuration and the choice was correct.
    %             -> SUCCESS if afterTrial and correct choice
    % Note that **even before t< o.from**, the eye has to remain 
    % in the window once it is in there (no in-and-out privileges)
  
   
   properties (Access=private)
   end
   
   properties (Dependent)
       targetXY; % Computed from .angles       
   end
   
   
   methods
       function v = get.targetXY(o)
           if isempty(o.angles)
               v = [];
           else
               v = o.radius*[cosd(o.angles(:)), sind(o.angles(:))];
           end
       end
   end
   methods
       function o=fixateThenChoose(c,name)
           o=o@neurostim.behaviors.fixate(c,name);
           % Add some properties that are needed only in this behavior
           o.addProperty('radius',5); % Radius of the choice annulus
           o.addProperty('angles',[]); % A vector of angles that are allowed. 
           o.addProperty('saccadeDuration',0);  % Choice dot must have been reached within this slack time.           
           o.addProperty('choiceDuration',300);  % choice dot must be fixated this long 
           o.addProperty('choice',[]); % Log of choices (XY coordinates)
           o.addProperty('choiceIx',[]); % Log of choices (index into angles)
           o.addProperty('correctFun',''); %Function returns the currently correct choice as an index into o.angles
           o.addProperty('correct',[]); % Log of correctness
           
           
           o.beforeTrialState = @o.freeViewing;
       end       
   end
   
   methods
        % Define the fixation state by coding all its transitions
        function fixating(o,t,e)   
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail
            if ~e.isRegular;return;end % regular only - no entry/exit
            % Guards
            oTo = o.to;
            fixDone = t>oTo;
            inChoice = isInAnnulus(o,e);
            inFix   =isInWindow(o,e);
            choiceShouldHaveStarted = t > oTo + o.saccadeDuration;
            
            if (~fixDone && ~inFix) || (choiceShouldHaveStarted && ~inChoice)
                transition(o,@o.fail,e);
            elseif fixDone && inChoice
                transition(o,@o.choose,e);                                
            end
        end
            
        % Define the choose state by coding all its transitions            
        function choose(o,t,e) 
             if e.isEntry
                % First time entering the Choose state.                 
                oAngles = o.angles;
                if numel(oAngles)==0
                    choiceXY = [e.X e.Y]; % Store the choice as the eye position within the annulus that lead to the transition to choose
                    choiceIx = NaN;
                    thisIsCorrect = true; % TODO - not sure how to do this for a continuous response... return an angle from correctFun?
                else
                    % Store the nearest target position as the choice
                    [choiceIx,choiceXY] =matchingTarget(o,[e.X,e.Y]);
                    if isempty(o.correctFun)
                        thisIsCorrect = true;
                    else
                        thisIsCorrect = choiceIx ==o.correctFun;
                    end
                end                
                % Log the results of the choice
                o.correct = thisIsCorrect; 
                o.choiceIx = choiceIx;
                o.choice  = choiceXY;
                return; %Done with setup/entry code
            end % regular only - no exit
            
            % Guards
            inChoice = isInWindow(o,e,o.choice); % Check that we're still in the window around the original choice
            choiceComplete = o.duration >= o.choiceDuration;
            isCorrect = o.correct;
            % All transitions
            if choiceComplete || e.isAfterTrial
                if inChoice && isCorrect
                    transition(o,@o.success,e);                
                else
                    transition(o,@o.fail,e);                
                end
            elseif ~inChoice
                transition(o,@o.fail,e);
            end                
        end        
   end
   
   methods 
       
        % Dertermine whether the eye is on a choice target. 
        % Users specify a radius and (optionally) a set of allowed angles
        % an empty set of angles means that the choice can be anywhere in
        % the annulus (continuous choice)
        function [v,targetIx] = isInAnnulus(o,e) 
            % Check that the eye is on the annlus within tolerance 
            v  = abs(hypot(e.X - o.X,e.Y- o.Y)-o.radius) < o.tolerance;          
            nrAngles =numel(o.angles);
            if nrAngles>0 && v   
                targetIx = matchingTarget(o,[e.X,e.Y]);
                v = ~isempty(targetIx) && v;
            end
            if o.invert
               v = ~v;
           end
        end
        
        function [targetIx,XY] = matchingTarget(o,eyeXY)
            % Find the nearest target in o.angles that is within tolerance
            % from the specified X Y a position
                oTargetXY = o.targetXY;
                nrAngles= size(oTargetXY,1);
                dv = oTargetXY -repmat(eyeXY,[nrAngles 1]);
                d = sqrt(sum(dv.^2,2));
                targetIx = find(d<o.tolerance);
                XY = oTargetXY(targetIx,:);
        end       
    end
    
end