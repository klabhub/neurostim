classdef pixxResponse < neurostim.behaviors.keyResponse
    % Behavior subclass for receiving a ResponsePixx button box response.
    % To allow easy swapping with a regular keyboard this inherits most functionality 
    % from keyResponse and has the same states and usage.
    %
    %% States:
    % WAITING       - each trial starts in this state
    %               - key presses before .from are ignored (keep WAITING)
    %               ->FAIL if the wrong key is pressed
    %               ->SUCCESS if the correct key is pressed 
    %               ->FAIL if t>o.to 
    %
    %% Parameters:
    % keys         - cell array of key characters: {'r','g','b','y','w'} - the keys correspond to the colors of the buttons
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
    % BK - July 2018
    
    properties (Constant)
        NRBUTTONS = 5;
        NRSAMPLES = 1000;
        BASEADDRESS= 12e6;
        keyToButtonMapper = {'r','y','g','b','w'}; % The red key is 1, yellow is 2, etc.
    end
    properties (SetAccess=protected)
        startedLogger@logical = false;
    end
    
    methods (Access = public)
        function o = pixxResponse(c,name)
            o = o@neurostim.behaviors.keyResponse(c,name);            
            o.addProperty('intensity',0.5);
            o.addProperty('lit',false(1,o.NRBUTTONS));
            o.addProperty('startLogTime',NaN);
            o.addProperty('stopLogTime',NaN);            
            o.addProperty('timeCalibration',struct);
            o.addProperty('button',[]); % Log raw single-button presses
            o.beforeTrialState = @o.waiting;
        end
        
        function beforeFrame(o)
            % Reset/start the logger.
            if ~o.isOn;return;end
            
            % Start the VPIXX button logger and turn on lights as requested
            if ~o.startedLogger 
                if islogical(o.lit)
                    litLogic = o.lit;
                elseif isnumeric(o.lit) && all(o.lit>0 & o.lit <= o.NRBUTTONS)
                    litLogic = zeros(1, o.NRBUTTONS);
                    litLogic(o.lit) =true;
                else
                    error('.lit must be a logical or an index ');
                end
                o.startLogTime = ResponsePixx('StartNow', true,litLogic,o.intensity); % Clear log
                o.startedLogger = true;
            end
            
            
            % Calll parent beforeFrame (to simulate responses and to call
            % the behavior class beforeFrame as well to generate events that 
            % do not depend on the keyboard)
            beforeFrame@neurostim.behaviors.keyResponse(o);
        end
        
        
        function afterTrial(o)
            o.stopLogTime = ResponsePixx('StopNow',true);
        end
        
        function beforeExperiment(o)
            ResponsePixx('Close');
            ResponsePixx('Open',o.NRSAMPLES,o.BASEADDRESS,o.NRBUTTONS);
            beforeExperiment@neurostim.behavior(o); % Call initialization code in behavior (but skip the one in keyResponse)           
        end
        
        function afterExperiment(o)
            %Re-calibrate time and re-time the pressedButton events
            % After this, the time returned by parameter.get for the
            % pressedButton events will be the time that the buttonPress
            % occurred as measured by datapixx, but in terms of the PTB
            % clock
            [v] = get(o.prms.button,'withDataOnly',true);
            if ~isempty(v)
                vpxxT = v(:,end); % Last column has BoxTime
                [ptbT, sd, ratio] = PsychDataPixx('BoxsecsToGetsecs', vpxxT);
                o.timeCalibration = struct('sd',sd,'ratio',ratio); % Store just in case.
                replaceLog(o.prms.button,num2cell(v,2),1000*ptbT'); % ms
            end
            ResponsePixx('Close');
        end
       
    end
    methods (Access=protected)
        % This function is called by behavior.beforeFrame which will send out
        % events to the states. 
        function e=getEvent(o)        
            [buttonStates, transitionTimesSecs, ~] = ResponsePixx('GetLoggedResponses');
            [tIx,buttonNr] = find(buttonStates);
            nrPressed = numel(buttonNr);   
            % Unless there is a key press in the pixx, we'll return a NOOP
            % event , which will not be sent out to the state.
            e = neurostim.event(neurostim.event.NOOP);            
            if nrPressed ==0
                % nothing to
            elseif nrPressed ==1                
                %Have a button press. Map it to a key in the o.keys
                key = o.keyToButtonMapper{buttonNr};
                if ismember(key,o.keys)
                    e = keyToEvent(o,key);
                else
                    o.writeFeed(['Subject pressed the ' key ' button. Ignored for behavior, but logged.']); 
                end
                o.button = [buttonNr transitionTimesSecs(tIx)]; % Store button and the time in DPixx time
            else
               o.writeFeed(['Subject pressed ' num2str(nrPressed) ' buttons. Ignored.']);                
            end           
        end
        
    end
    
end