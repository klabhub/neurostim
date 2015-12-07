classdef liquid < neurostim.plugins.feedback
    %Plugin to deliver liquid reward to animals. See parent class for
    %usage.
    
    properties
        mccChannel = 1;
        mcc = [];
    end
    
    methods (Access=public)
        function o=liquid(name)
            o=o@neurostim.plugins.feedback(name);
            o.listenToEvent('BEFOREEXPERIMENT');
        end
        
        function beforeExperiment(o,c,evt)
            
            %Check that the MCC plugin is added.
            o.mcc = pluginsByClass(c,'neurostim.plugins.mcc');
            if numel(o.mcc)==1
                o.mcc = o.mcc{1};
            else
                error('Liquid reward added but no MCC plugin added (or, more than one added - currently not supported)');
            end
        end
    end
    
    methods (Access=protected)
 
        function deliver(o,item)
            % Responds by calling the MCC plugin to activate liquid reward.
            % This currently uses the timer() function for duration, which
            % may be inaccurate or interrupt time-sensitive functions.
            if ~isempty(o.mcc)
                o.mcc.digitalOut(o.mccChannel,true,item.duration);
            else
                disp(['Liquid reward would be given now (' num2str(item.duration) 'ms)']);
            end
        end
    end
end