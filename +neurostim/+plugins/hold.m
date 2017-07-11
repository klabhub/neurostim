classdef hold < neurostim.plugins.behavior
    % Behavioural plugin to require the HOLD or RELEASE of an external
    % button/touchbar/device. Really, it just monitors a
    % DIGITAL line of the MCC for a required state (high or low bit), so it's
    % a generic plugin to listen to an external device.
    %
    % Assuming a hardware configuration in which the bit goes HIGH when
    % a touchbar/button is pressed, the plugin defaults to a HOLD
    % behaviour. To require a RELEASE, set "invert" to true.
    %
    % Parameters:
    %
    % mccChannel:   the DIGITAL channel to monitor [default = 1]
    % invert:       set to true to software-invert the bit value. 

    properties
        mcc = [];
    end
    
    methods (Access=public)
        function o=hold(c,name)
            o=o@neurostim.plugins.behavior(c,name);
            o.addProperty('invert',false);
            o.addProperty('mccChannel',1);
            
            o.continuous = true;
        end
        
        function beforeExperiment(o)
            
            %Check that the MCC plugin is added.
            o.mcc = pluginsByClass(o.cic,'mcc');
            if numel(o.mcc)~=1                
                o.cic.error('STOPEXPERIMENT','The hold plugin requires an MCC plug-in. None (or more than one) detected)');
            end
            
            o.mcc.map('DIGITAL',o.mccChannel,'isHolding', 'AFTERFRAME')
        end
        
    end
    
    methods (Access=protected)
        function inProgress = validate(o)
            % validate returns o.on = true when behavior passes all checks.
            inProgress = logical(o.mcc.isHolding)~=o.invert;
        end
    end
    
end