classdef release < neurostim.plugins.behavior
    % Behavioral plugin which monitors touch pad/bar
    % release - behavioural plugin which sets on = true when the mcc value is
    % low (monkey is not holding)
    %
    
    properties
        mcc = [];
    end
    
    methods (Access=public)
        function o=release(c,name)
            o=o@neurostim.plugins.behavior(c,name);
            o.addProperty('mccChannel',1);
            o.listenToEvent('BEFOREEXPERIMENT');
            o.continuous = true;
        end
        
        function beforeExperiment(o,c,evt)
            
            %Check that the MCC plugin is added.
            o.mcc = pluginsByClass(c,'mcc');
            if numel(o.mcc)==1
                o.mcc = o.mcc{1};
            else
                o.cic.error('STOPEXPERIMENT','The hold plugin requires an MCC plug-in. None (or more than one) detected)');
            end
            
            o.mcc.map('DIGITAL',o.mccChannel,'isRelease', 'AFTERFRAME')
        end
        
    end
    
    methods (Access=protected)
        function inProgress = validateBehavior(o)
            % validateBehavior returns o.on = true when behavior passes all checks.
            inProgress = ~logical(o.mcc.isRelease);
        end
    end
    
end