classdef responsePixx < neurostim.plugins.behavior
    % Behavior subclass for receiving a ResponsePixx keyboard response.
    %
    %
    
    properties (Constant)
        NRBUTTONS = 5;
        NRSAMPLES = 1000;
        BASEADDRESS= 12e6;
        RED =1;
        YELLOW=2;
        GREEN=3;
        BLUE =4;
        WHITE=5;
    end
    properties (SetAccess=protected)
        responded@logical=false;
        startedLogger@logical = false;      
    end
    
    methods (Access = public)
        function o = responsePixx(c)
            o = o@neurostim.plugins.behavior(c,'responsePixx');
            o.continuous = false;            
            o.addProperty('intensity',0.5);
            o.addProperty('lit',false(1,o.NRBUTTONS));
            o.addProperty('startLogTime',NaN);
            o.addProperty('stopLogTime',NaN);            
            o.addProperty('correctButtons',[]);
            o.addProperty('pressedButton',[]);   
            o.addProperty('allowedButtons',[]);   
            o.addProperty('correct',[]);            
        end
        
        function beforeFrame(o)
            if ~o.startedLogger && o.enabled
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
        end
        
        function beforeTrial(o)
            beforeTrial@neurostim.plugins.behavior(o); % Call parent                        
            o.responded = false;   % Update responded for this trial
            o.inProgress = false;
            o.startedLogger = false;
        end
        
        function afterTrial(o)
            o.stopLogTime = ResponsePixx('StopNow',true);
        end
        
        function beforeExperiment(o)
            ResponsePixx('Close');
            ResponsePixx('Open',o.NRSAMPLES,o.BASEADDRESS,o.NRBUTTONS);            
        end
        
        function afterExperiment(o)
            %Re-calibrate time and re-time the pressedButton events 
            [v,tr,t,te] = get(o.prms.pressedButton,'withDataOnly',true);
            vpxxT = v(:,end); % Last column has BoxTime
            [ptbT, sd, ratio] = PsychDataPixx('BoxsecsToGetsecs', vpxxT);            
            replaceLog(o.prms.pressedButton,num2cell(v,2),1000*ptbT'); % ms
            ResponsePixx('Close');
        end                                
        
    end
    
    methods (Access=protected)
        
        function sample(o,~)
            if ~o.responded % Allow only once per trial
                [buttonStates, transitionTimesSecs, ~] = ResponsePixx('GetLoggedResponses');
                [tIx,buttonNr] = find(buttonStates);
                ab =o.allowedButtons;
                if ~isempty(buttonNr) && (isempty(ab) || ismember(buttonNr,ab)) 
                    if numel(buttonNr)>1
                        % more than one button pressed...
                        disp('More than one button...')
                    else
                        o.pressedButton = [buttonNr transitionTimesSecs(tIx)]; % Store button and the time in DPixx time
                    end
                    cb = o.correctButtons;
                    if ~isempty(cb)
                        o.correct = ismember(buttonNr,cb);
                    else
                        %No correctness function specified. Probably using as subjective measurement (e.g. PSE)
                        o.correct = true;
                    end
                    %Set flag so that behaviour class detects completion next frame
                    o.inProgress = true;
                    o.responded = true;                  
                end
            end
        end
        
        function ok = validate(o)
            ok  = o.inProgress;
        end
        
    end
end