classdef keyResponse < neurostim.behavior
    % Behavior subclass for receiving keyboard responses.
    % This behavior class is used to receive a single response per trial,
    % allowing multiple resposnes requires a separate class.
    %
    % Key presses before .from and after .to are ignored entirely (i.e. not
    % logged). Key presses between .from and .to are logged, and change the
    % state to succes or fail depending on correctFun 
    %
    %% States:
    % WAITING       - each trial starts in this state
    %               - key presses before .from are ignored (keep WAITING)
    %               ->FAIL if the wrong key is pressed
    %               ->SUCCESS if the correct key is pressed 
    %               ->FAIL if t>o.to 
    %
    %% Parameters:
    % keys         - cell array of key characters, e.g. {'a','z'}
    % correctFun   - function that returns the index (into 'keys') of the correct key. Usually a function of some stimulus parameter(s).
    % from          - key press allowed from this time onward
    % to          - key press allowed until this time
    %
    % simWhen       - time when a simulated key press will be generated (Defaults  to empty; never)
    % simWhat       - simulated response (given at simWhen)
    %
    % failEndsTrial  - set to true to end the trial immediately after an incorrect response
    % successEndsTrial - set to true to end the trial immediately after a correct response
    %
    % BK July 2018
    
    methods (Access = public)
        function o = keyResponse(c,name)
            o = o@neurostim.behavior(c,name);
            o.addProperty('keys',{},'validate',@iscellstr); % User provided list of keys
            o.addProperty('correctFun',[]); %User provided function that evaluates to the correct key index on each trial
            o.addProperty('correct',[],'validate',@islogical); % Log of the correctness of each keypress
            o.addProperty('keyIx',[],'validate',@isnumeric); % Log of the keys that were pressed (as an index into o.keys)
            
            o.addProperty('simWhen','');
            o.addProperty('simWhat','');
            
            o.beforeExperimentState = @o.waiting;
            o.beforeTrialState = @o.waiting;
        end
        
        
        function beforeExperiment(o)
            % Add key listener for each key on the subject keyboard
            for i = 1:numel(o.keys)
                o.addKey(o.keys{i},o.keys{i},true); % True= isSubject
            end
        end
        
        function  e =getEvent(~)
            % This function is not necessary for a keyboard as the events are generated
            % and passed to the state in the keyboard function (truly
            % event-based, rather than in the frame loop).
            e= struct; % Return empty struct
        end
        
        function beforeFrame(o)
            % The base behavior class checks events and passes them to the
            % state in this function. The keyResponse class does this in the
            % keyboard event handler.
            
            % A simulated observer (useful to test paradigms and develop
            % analysis code).
            if ~isempty(o.simWhen)
                if o.cic.trialTime>o.simWhen
                    keyboard(o,o.keys{o.simWhat});
                end
            end
        end
        
        % Ths keyboard event handler (also plays the role that getEvent
        % plays in the base class).
        function keyboard(o,key)
            
            %Check that we're in teh response window
            t = o.cic.trialTime;            
            on = t >= o.from && t <= o.to;
            if ~on; return;end
            
            % Evaluate and log key correctness
            keyNr = find(strcmpi(key,o.keys));
            o.keyNr = keyNr; %Log the index of the pressed key
            if isempty(o.correctFun)
                thisIsCorrect = true;
            else
                thisIsCorrect = keyNr ==o.correctFun;
            end
            o.corect = thisIsCorect; %Log it for easy analysis
            
            % Package as an event to pass to the state.
            e.key =key;
            e.keyNr =keyNr;
            e.correct = thisIsCorrect;            
            o.currentState(o,t,e);
            
        end
    end
    %% States
    methods
        
        % Waiting for a single correct/incorrect response
        function waiting(o,t,e)
            if t>t.to
                % a call from endTrial to clean up
                transition(o,@o.fail);  %No key received this trial
            else
                if e.correct
                    transition(o,@o.success);
                else
                    transition(o,@o.fail);
                end
            end
        end
    end
end