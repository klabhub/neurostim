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
    %               ->FAIL if the time in this state is longer than
    %               o.maximumRT or afterTrial
    %
    %% Parameters:
    % keys         - cell array of key characters, e.g. {'a','z'}
    % correctFun   - function that returns the index (into 'keys') of the correct key. Usually a function of some stimulus parameter(s).
    % from         - key press accepted from this time onward, and the
    %                   maximumRT is measured from this point 
    % maximumRT     - key press allowed until this time
    %
    % simWhen       - time when a simulated key press will be generated (Defaults  to empty; never)
    % simWhat       - simulated response (given at simWhen)
    %
    % failEndsTrial  - set to true to end the trial immediately after an incorrect response
    % successEndsTrial - set to true to end the trial immediately after a correct response
    %
    % BK July 2018
    properties
       simKeySent; 
    end
    methods (Access = public)
        function o = keyResponse(c,name)
            o = o@neurostim.behavior(c,name);
            o.addProperty('keys',{},'validate',@iscellstr); % User provided list of keys
            o.addProperty('correctFun',[]); %User provided function that evaluates to the correct key index on each trial
            o.addProperty('correct',[],'validate',@islogical); % Log of the correctness of each keypress
            o.addProperty('keyIx',NaN,'validate',@isnumeric); % Log of the keys that were pressed (as an index into o.keys). Initialize with NaN to always return something (to allow checking its value)
            o.addProperty('maximumRT',1000,'validate',@isnumeric);  % A key must have been received this long after the waiting state starts.
            o.addProperty('simWhen',[]);
            o.addProperty('simWhat',[]);
            
            o.beforeTrialState = @o.waiting;
        end
        
        
        function beforeExperiment(o)
            % Add key listener for each key on the subject keyboard
            for i = 1:numel(o.keys)
                o.addKey(o.keys{i},o.keys{i},true); % True= isSubject
            end
            beforeExperiment@neurostim.behavior(o);
        end
        
        function  e =getEvent(~)
            e= neurostim.event; % Event without key - used to process time.
        end
        
        function beforeFrame(o)
            % The base behavior class checks events and passes them to the
            % state in this function. The keyResponse class does this in the
            % keyboard event handler. But for consistency and to allow
            % derived classes to rely on a frame-loop calling of the state
            % functions, we implement 
            
            
            % A simulated observer (useful to test paradigms and develop
            % analysis code).
            if ~isempty(o.simWhen) && ~o.simKeySent && (o.cic.trialTime>o.simWhen)
                keyboard(o,o.keys{o.simWhat});
                o.simKeySent = true;                
            end
            
            beforeFrame@neurostim.behavior(o);
        end
        
        function beforeTrial(o)
            o.simKeySent = false;
            beforeTrial@neurostim.behavior(o);
        end
        
        % Ths keyboard event handler (also plays the role that getEvent
        % plays in the base class).
        function keyboard(o,key)            
            %Check that we're in time window
            t = o.cic.trialTime;            
            on = t >= o.from && t <= o.to;
            if ~on; return;end % ignore
            
            e = keyToEvent(o,key);
            % Send to state.
            o.currentState(t,e);            
        end
        
        function e= keyToEvent(o,key)

            % Evaluate and log key correctness
            keyIx = find(strcmpi(key,o.keys));
            o.keyIx = keyIx; %Log the index of the pressed key
            if isempty(o.correctFun)
                thisIsCorrect = true;
            else
                thisIsCorrect = keyIx ==o.correctFun;
            end
            o.correct = thisIsCorrect; %Log it for easy analysis
            
            % Package as a regular event to pass to the state.
            e = neurostim.event(neurostim.event.REGULAR);
            e.key =key;
            e.keyNr =keyIx;
            e.correct = thisIsCorrect;                
        end
    end
    %% States
    methods
        
        % Waiting for a *single* correct/incorrect response
        function waiting(o,t,e)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail
            if ~e.isRegular ;return;end % No Entry/exit needed.         
            %Guards
            
            tooLate = (o.cic.trialTime-o.from)>o.maximumRT;
            noKey = isempty(e.key); % hack - checek whether this is a real key press or just passage of time
            correct = e.correct;                       
                        
            if tooLate                   
                transition(o,@o.fail,e);  %No key received this trial                 
            elseif ~noKey 
                if correct
                    transition(o,@o.success,e);
                else             
                    transition(o,@o.fail,e);                
                end
            end
        end
      
      
    end
end