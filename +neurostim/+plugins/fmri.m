classdef fmri < neurostim.plugin
    % fMRI plugin that pauses an experiment at the start until a specified
    % number of triggers has been recorded. During the scan the plugin
    % only logs the incoming triggers.
    %
    properties
        lastTrigger = -Inf;
    end
    methods
        function o = fmri(c)
            o = o@neurostim.plugin(c,'fmri');
            o.addProperty('scanNr',[]);
            o.addProperty('preTriggers',10);
            o.addProperty('trigger',0);
            o.addProperty('triggerKey','t');
            o.addProperty('triggersComplete',[]);
            o.addProperty('maxTriggerTime',inf); % If no Triggers for x s, the experiment ends
            o.addKey('t');
            
        end
        
        function beforeExperiment(o)
            if isempty(o.scanNr) || o.scanNr ==0
                answer=[];
                while (isempty(answer))
                    o.cic.drawFormattedText('Which scan number is about to start?');
                    Screen('Flip',o.cic.window);
                    disp('*****************************************')
                    commandwindow;
                    answer = input('Which scan number is about to start (for logging purposes)?');
                end
                o.scanNr =answer;
            end
        end
        
        function beforeTrial(o)
            % The goal here is to wait until the pre-triggers have been
            % received (to start at steady-state magnetization). This code
            % interacts directly with PTB Screen and other functionality
            % which is not recommended in general (but necessary here).
            if o.cic.trial==1
                % Wait until the requested pre triggers have been recorded
                o.cic.drawFormattedText('Start the scanner now ...');
                Screen('Flip',o.cic.window);
                % Wait until the first trigger has been received
                while o.trigger ==0
                    WaitSecs(0.1);
                    o.cic.KbQueueCheck;
                end
                while o.trigger < o.preTriggers
                    WaitSecs(0.1);
                    o.cic.KbQueueCheck;
                    if o.trigger < o.preTriggers
                        txt = ['Waiting for ' num2str(o.preTriggers-o.trigger) ' more triggers from the scanner'];
                        o.cic.drawFormattedText(txt);
                    end
                    Screen('Flip',o.cic.window);
                end
                o.triggersComplete = true;
                Screen('Flip',o.cic.window);
            end
        end
        
        function afterTrial(o)
            maxDelay = o.maxTriggerTime;
            if maxDelay > 0 && ~isinf(maxDelay)
                delta = o.cic.clockTime - o.lastTrigger;
                if delta > maxDelay *1000
                    % More than 2 maximumTR durations have gone by since
                    % the last trigger was received. This means the scanner
                    % stopped. End the experiment
                    o.writeToFeed(['Scanner stopped ' num2str(delta/1000) 's ago. Experiment done.']);
                    endExperiment(o.cic);
                end
            end
        end
        
        % Catch trigger keys. Could be extended with generic user
        % responses.
        function keyboard(o,key)
            switch upper(key)
                case 'T'
                    o.trigger = o.trigger+1;
                    o.lastTrigger = o.cic.clockTime;
            end
        end
    end
end