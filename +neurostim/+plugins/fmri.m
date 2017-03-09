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
            
            o.addKey('t',@(x,key) keyboard(x,key))
            o.listenToEvent('BEFOREEXPERIMENT');
        end
               
        function beforeExperiment(o,~,~)
            %answer = input('Which scan number is about to start?');
            
            % Wait until the requested pre triggers have been recorded
            while o.trigger <= o.preTriggers
                WaitSecs(0.5);
                DrawFormattedText(o.cic.window,['Waiting for another ' num2str(o.preTriggers-o.trigger) ' triggers from the scanner'],'center','center',o.cic.screen.color.text);
                Screen('Flip',o.c.window);
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