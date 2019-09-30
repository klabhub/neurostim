classdef multiKeyResponse < neurostim.behaviors.keyResponse
    % Behavior subclass for receiving keyboard responses. Derives fom the 
    % (single)  keyResponse behavior and is used to receive multiple responses 
    % per trial that allow the subject to change their mind during the trial. 
    % The final answer counts to determine success or fail.
    % 
    %
    %% States:
    % WAITING       - each trial starts in this state    
    %               ->INCORRECT if the wrong key is pressed
    %               ->CORRECT if the correct key is pressed 
    %               ->FAIL if no key is pressed at o.to or afterTrial
    %               
    % CORRECT       ->INCORRECT if the wrong key is pressed.
    %               ->SUCCESS if t> o.to
    %               ->SUCCES if afterTrial
    %
    % INCORRECT      ->CORRECT if the correct key is pressed
    %               ->FAIL if t>o.to or afterTrial
    %                
    %
    %% Parameters: 
    % keys         - cell array of key characters, e.g. {'a','z'}
    % correctFun   - function that returns the index (into 'keys') of the correct key. Usually a function of some stimulus parameter(s).
    % from          - key press allowed from this time onward
    % to          - key press accepted until this time
    %
    % simWhen       - time when a simulated key press will be generated (Defaults  to empty; never)
    % simWhat       - simulated response (given at simWhen)
    %
    % failEndsTrial  - set to true to end the trial immediately after an incorrect response
    % successEndsTrial - set to true to end the trial immediately after a correct response
    %
    % BK July 2018
    
    methods (Access = public)
        function o = multiKeyResponse(c,name)
            o = o@neurostim.behaviors.keyResponse(c,name);            
            o.beforeTrialState = @o.waiting;
        end
        
        %% States
    
        
        % Waiting for a *single* correct/incorrect response
        function waiting(o,t,e)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail
            if ~e.isRegular ;return;end % No Entry/exit needed.         
            %Guards
            tooLate = t>o.to;            
            correct = e.correct;                       
            
            if tooLate 
                transition(o,@o.fail,e);  %No key received this trial
            elseif ~isempty(correct)
                if correct
                    transition(o,@o.correctAnswer,e);
                else             
                    transition(o,@o.incorrectAnswer,e);                
                end
            end
        end
        
        function correctAnswer(o,t,e)
            if e.isAfterTrial;transition(o,@o.success,e);end % if still in this state-> success
            if ~e.isRegular ;return;end % No Entry/exit needed.                
            done= t>o.to;
            correct = e.correct;
            if done
                transition(o,@o.success,e);
            elseif ~correct
                transition(o,@o.incorrectAnswer,e);
            end            
        end
        
        function incorrectAnswer(o,t,e)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail
            if ~e.isRegular ;return;end % No Entry/exit needed.                
            done= t>o.to;
            correct = e.correct;
            if done
                transition(o,@o.fail,e);
            elseif correct
                transition(o,@o.correctAnswer,e);
            end
        end
    end
end