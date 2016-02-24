classdef fmri < neurostim.plugin        
    methods
        function o = fmri(c)
            o = o@neurostim.plugin(c,'fmri');
            o.addProperty('scanNr',0);
            o.addProperty('preTriggers',10);
            o.addProperty('trigger',0);
            o.addProperty('triggerKey','t');
            
            o.listenToKeyStroke('t','trigger')
            o.listenToEvent('BEFOREEXPERIMENT');
        end
               
        % Catch trigger keys. Could be extended with generic user
        % responses.
        function keyboard(o,key,~)
            switch upper(key)
                case 'T'
                o.trigger = o.trigger+1;
                if (o.trigger==o.preTriggers)
                    % Set beginExperiment flag. 
                    disp('FMRI PLUGIN Starting now')
                end
            end
        end
        function events(o,~,evt)
            switch upper(evt.EventName)
                case 'BEFOREEXPERIMENT'
                    % Get an integer scan number from the user
      
            end
        end
        
    end
end