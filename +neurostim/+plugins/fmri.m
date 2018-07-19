classdef fmri < neurostim.plugin
    % fMRI plugin that pauses an experiment at the start until a specified
    % number of triggers has been recorded. During the scan the plugin
    % only logs the incoming triggers.
    %
    
    methods
        function o = fmri(c)
            o = o@neurostim.plugin(c,'fmri');
            o.addProperty('scanNr',0);
            o.addProperty('preTriggers',10);
            o.addProperty('trigger',0);
            o.addProperty('triggerKey','t');
            
            o.addKey('t');
            
        end
        
        function beforeExperiment(o)
            answer=[];
            while (isempty(answer))
                DrawFormattedText(o.cic.window,'Which scan number is about to start?' ,'center','center',o.cic.screen.color.text);
                Screen('Flip',o.cic.window);
                disp('*****************************************')
                commandwindow;
                answer = input('Which scan number is about to start (for logging purposes)?');
            end
            o.scanNr =answer;
        end
        
        function beforeTrial(o)
            % The goal here is to wait until the pre-triggers have been
            % received (to start at steady-state magnetization). This code
            % interacts directly with PTB Screen and other functionality
            % which is not recommended in general (but necessary here).
            if o.cic.trial==1
                % Wait until the requested pre triggers have been recorded
                DrawFormattedText(o.cic.window,'Start the scanner now ...' ,'center','center',o.cic.screen.color.text);
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
                        DrawFormattedText(o.cic.window,txt,'center','center',o.cic.screen.color.text);
                    end
                    Screen('Flip',o.cic.window);
                end
                Screen('Flip',o.cic.window);
            end
        end
        
        % Catch trigger keys. Could be extended with generic user
        % responses.
        function keyboard(o,key)
            switch upper(key)
                case 'T'
                    o.trigger = o.trigger+1;
            end
        end
    end
end