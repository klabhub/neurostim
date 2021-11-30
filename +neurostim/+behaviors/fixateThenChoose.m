classdef fixateThenChoose < neurostim.behaviors.fixate
    % Fixate a fixation point first, then make a saccade to a
    % choice annulus.
    %
    % This behavior inherits from fixate and adds two new states.
    %
    % FREEVIEWING - each trial starts here
    %             -> FAIL if t > t.from
    %             -> FAIL afterTrial
    %             -> FIXATING when the eye moves inside the window
    % FIXATING    -> FAIL if eye moves outside the window after o.grace but
    %                before o.to
    %             -> FAIL if we're still here after o.timeout
    %             -> FAIL afterTrial
    %             -> FREEVIEWING if eye moves outside the window within the
    %                grace period
    %             -> INFLIGHT if eye moves outside the window after o.to
    % INFLIGHT    -> FAIL if we're still here after o.saccadeDuration
    %             -> FAIL afterTrial
    %             -> CHOOSE if the eye enters the choice window within
    %                o.saccadeDuration
    % CHOOSE      -> FAIL if the eye leaves the first choice within o.choiceDuration
    %             -> FAIL afterTrial
    %             -> FAIL if the eye is within o.choiceTolerance of the
    %                choice for atleast o.choiceDuration and the choice was incorrect
    %             -> SUCCESS if the eye is within o.choiceTolerance of the
    %                choice for atleast o.choiceDuration and the choice was correct
    %
    % Eye position can enter and leave the fixation window within the grace
    % period without penalty, i.e., if the subject breaks fixation within
    % the grace period we return to the FREEVIEWING state.
    %
    % By default, the grace period is 0 ms and the eye must remain within
    % the window once it is in there (i.e., even *before* o.from).
        
    properties (Access=private)
    end
    
    properties (Dependent)
        targetXY; % Computed from .angles
        
        isInFlight;
        isChoosing;
    end
    
    methods
        function o = fixateThenChoose(c,name)
            o = o@neurostim.behaviors.fixate(c,name);
            
            % add some properties that are needed only in this behavior
            o.addProperty('radius',5); % Radius of the choice annulus
            o.addProperty('angles',[]); % A vector of angles that are allowed.
            
            o.addProperty('timeout',Inf,'validate',@isnumeric); % max. delay for initiating a choice
       
            o.addProperty('saccadeDuration',0);  % Choice dot must have been reached within this slack time.
       
            o.addProperty('choiceTolerance',[]);  % choice tolerance
            o.addProperty('choiceDuration',300);  % choice dot must be fixated this long
            o.addProperty('choice',[]); % Log of choices (XY coordinates)
            o.addProperty('choiceIx',[]); % Log of choices (index into angles)
            
            o.addProperty('correctFun',''); %Function returns the currently correct choice as an index into o.angles
            o.addProperty('correct',[]); % Log of correctness
            
            o.beforeTrialState = @o.freeViewing;
        end
        
        % Define the FIXATING state by coding all its transitions
        function fixating(o,t,e)
            if e.isAfterTrial
                % FAIL if still here at trial end
                transition(o,@o.fail,e);
            end
            
            if ~e.isRegular; return; end % regular only - no entry/exit
            
            % Guards
            oTo = o.to;
            fixDone = t >= oTo;
            [inFix,isAllowedBlink] = isInWindow(o,e);
            
            if isAllowedBlink
                % wait for the blink to end
                return
            end
                       
            if o.duration > o.timeout
                % FAIL, taking too long
                transition(o,@o.fail,e);
                return
            end
            
            if inFix
                % wait until we leave the window (or timeout)
                return
            end
            
            % if we end up here, eye has left the window...
            
            if o.duration < o.grace
              remove(o.iStartTime,o.stateName); % clear FIXATING startTime
              transition(o,@o.freeViewing,e); % return to FREEVIEWING, no penalty
              return
            end
            
            if ~fixDone
                % FAIL, broke fixation
                transition(o,@o.fail,e);
            else
                % INFLIGHT
                transition(o,@o.inFlight,e);
            end
            
        end
        
        % define a new INFLIGHT state
        function inFlight(o,t,e)
            % INFLIGHT has two transitions:
            %  -> FAIL if we're still here after o.saccadeDuration
            %  -> CHOOSE if the mouse enters the choice window before o.grace
       
            if e.isAfterTrial
              % FAIL if still here at trial end
              transition(o,@o.fail,e);
            end

            if ~e.isRegular; return; end % ignore entry/exit events
       
            overdue = o.duration > o.saccadeDuration;
            onTarget = isInAnnulus(o,e,o.choiceTolerance);
       
            if overdue && ~onTarget
              % FAIL, taking too long
              transition(o,@o.fail,e);
              return
            end
       
            if onTarget
              % CHOOSE
              transition(o,@o.choose,e);
              return
            end
        end
        
        % Define the CHOOSE state by coding all its transitions
        function choose(o,t,e)
            if e.isEntry
                % First time entering the Choose state.
                oAngles = o.angles;
                if numel(oAngles) == 0
                    choiceXY = [e.X e.Y]; % Store the choice as the eye position within the annulus that lead to the transition to choose
                    choiceIx = NaN;
                    thisIsCorrect = true; % TODO - not sure how to do this for a continuous response... return an angle from correctFun?
                else
                    % Store the nearest target position as the choice
                    [choiceIx,choiceXY] = matchingTarget(o,[e.X,e.Y],o.choiceTolerance);
                    if isempty(o.correctFun)
                        thisIsCorrect = true;
                    else
                        thisIsCorrect = choiceIx == o.correctFun;
                    end
                end
                % Log the results of the choice
                o.correct = thisIsCorrect;
                o.choiceIx = choiceIx;
                o.choice  = choiceXY;
                return; % Done with setup/entry code
            end % regular only - no exit
            
            if e.isAfterTrial
                % FAIL if still here at trial end
                %
                % TODO - not sure about this... previously, afterTrial wasn't handled at all
                transition(o,@o.fail,e);
            end
            
            if ~e.isRegular; return; end % Not handling exit events
            
            % Guards
            [inChoice,isAllowedBlink] = isInWindow(o,e,o.choice,o.choiceTolerance); % Check that we're still in the window around the original choice
            choiceComplete = o.duration >= o.choiceDuration;
            isCorrect = o.correct;
            
            % All transitions
            if isAllowedBlink
                % No change in state
            elseif choiceComplete
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
        function [inside,targetIx,isAllowedBlink] = isInAnnulus(o,e,tol)
            targetIx = [];
            if ~e.valid
                isAllowedBlink = o.allowBlinks;
                inside = false;
            else
                isAllowedBlink =false;
                % Check that the eye is on the annlus within tolerance
                nin = nargin;
                if nin < 3 || isempty(tol)
                    tol = o.tolerance;
                end
                
                inside  = abs(hypot(e.X - o.X,e.Y- o.Y)-o.radius) < tol;
                nrAngles = numel(o.angles);
                if nrAngles > 0 && inside
                    targetIx = matchingTarget(o,[e.X,e.Y]);
                    inside = ~isempty(targetIx) && inside;
                end
                
                if o.invert
                    inside = ~inside;
                end
            end
        end
        
        function [targetIx,XY] = matchingTarget(o,eyeXY,tol)
            % Find the nearest target in o.angles that is within tolerance
            % from the specified X Y a position
            
            nin = nargin;
            if nin < 3 || isempty(tol)
                tol = o.tolerance;
            end
            
            oTargetXY = o.targetXY;
            nrAngles = size(oTargetXY,1);
            dv = oTargetXY - repmat(eyeXY,[nrAngles 1]);
            d = sqrt(sum(dv.^2,2));
            targetIx = find(d < tol);
            XY = oTargetXY(targetIx,:);
        end
    end
    
    methods % get methods  
        function v = get.targetXY(o)
            if isempty(o.angles)
                v = [];
            else
                v = o.radius*[cosd(o.angles(:)), sind(o.angles(:))];
            end
        end

        function v = get.isInFlight(o)
            v = strcmpi(o.stateName,'INFLIGHT');
        end
     
        function v = get.isChoosing(o)
            v = strcmpi(o.stateName,'CHOOSE');
        end
    end
    
end