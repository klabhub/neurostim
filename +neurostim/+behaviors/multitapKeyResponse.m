classdef multitapKeyResponse < neurostim.behaviors.keyResponse
    % Behavior subclass for receiving keyboard responses. 
    % Derives fom the (single)  keyResponse behavior and is used to receive multiple taps of a single key during the trial. 
    % The first press is used to determine correct/incorrect
    % Only subsequent presses of the same key are counted within the time window specified by .maximumRT2
    % final output is the answer counts to determine success or fail.
    % 
    %
    %% States:
    % WAITING       - each trial starts in this state    
    %               ->INCORRECT if the wrong key is pressed
    %               ->CORRECT if the correct key is pressed 
    %               ->FAIL if no key is pressed at o.to or afterTrial
    %               
    % CORRECT       ->SUCCESS if t> o.to
    %               ->SUCCES if afterTrial
    %
    % INCORRECT     ->FAIL if t>o.to or afterTrial
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
    % keyCount      - number of times the key has been pressed (default NaN)
    % maximumRT2    - time to collect keypresses after first press
    %
    %
    % failEndsTrial  - set to true to end the trial immediately after an incorrect response
    % successEndsTrial - set to true to end the trial immediately after a correct response
    %
    % BK July 2018
    
    methods (Access = public)
        function o = multitapKeyResponse(c,name)
            o = o@neurostim.behaviors.keyResponse(c,name);            
            o.addProperty('keyCount',NaN,'validate',@isnumeric); % Log of the keys that were pressed (as an index into o.keys). Initialize with NaN to always return something (to allow checking its value)
            o.addProperty('maximumRT2',500,'validate',@isnumeric);  % Any subsequent key presses must be received this long after the first key is pressed.
            o.beforeTrialState = @o.waiting;
        end
        
        %% States
    
        
        % Waiting for first correct/incorrect response
        function waiting(o,t,e)
            if e.isAfterTrial; transition(o,@o.fail,e);end % if still in this state-> fail
            if ~e.isRegular ;return;end % No Entry/exit needed.         
            
            %Guards
            tooLate = t>o.to;            
            correct = e.correct;                       
            
            if tooLate
                transition(o,@o.fail,e);  %No key received this trial
            elseif ~isempty(correct)
                o.keyCount = 1;
                o.to = o.cic.trialTime + o.maximumRT2;  % update time
                if correct
                    transition(o,@o.correctAnswer,e);
                else             
                    transition(o,@o.incorrectAnswer,e);                
                end
            end
        end
        
        function correctAnswer(o,t,e) % now count keypresses
            if e.isAfterTrial;transition(o,@o.success,e);end % if still in this state-> success
            if ~e.isRegular ;return;end % No Entry/exit needed.                
            done= t>o.to;
            correct = e.correct;
            if correct, o.keyCount = o.keyCount+1; end
            if done
                transition(o,@o.success,e);

            end            
        end
        
        function incorrectAnswer(o,t,e)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail
            if ~e.isRegular ;return;end % No Entry/exit needed.                
            done= t>o.to;
            correct = e.correct;
            if ~correct, o.keyCount = o.keyCount+1; end
            if done
                transition(o,@o.fail,e);
            end
        end
    end
end