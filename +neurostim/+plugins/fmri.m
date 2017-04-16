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
            
            o.addKey('t',@(x,key) keyboard(x,key));
            
        end
        
        function beforeExperiment(o)
            answer=[];
            while (isempty(answer))
                DrawFormattedText(o.cic.window,'Which scan number is about to start?' ,'center','center',o.cic.screen.color.text);
                Screen('Flip',o.cic.window);
                disp('*****************************************')
                answer = input('Which scan number is about to start?');
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
                while o.trigger < o.preTriggers
                    WaitSecs(0.1);
                    o.cic.KbQueueCheck;
                    DrawFormattedText(o.cic.window,['Waiting for another ' num2str(o.preTriggers-o.trigger) ' triggers from the scanner'],'center','center',o.cic.screen.color.text);
                    Screen('Flip',o.cic.window);
                end
            end
        end
        
        % Catch trigger keys. Could be extended with generic user
        % responses.
        function keyboard(o,key,~)
            switch upper(key)
                case 'T'
                    o.trigger = o.trigger+1;
            end
        end
    end
end