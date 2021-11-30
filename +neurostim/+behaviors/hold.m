classdef hold < neurostim.behavior
    % Behavioural plugin to require the HOLD or RELEASE of an external
    % button/touchbar/device. Really, it just monitors a
    % DIGITAL line of the MCC for a required state (high or low bit), so it's
    % a generic plugin to listen to the MCC .
    %
    % Assuming a hardware configuration in which the bit goes HIGH when
    % a touchbar/button is pressed, the plugin defaults to a HOLD
    % behaviour. To require a RELEASE, set "invert" to true.
    %
    % NOTHOLDING    - Each trial starts here
    %               -> FAIL if bit remains low at o.from
    %               -> HOLDING if bit goes high
    %               ->FAIL afterTrial
    % HOLDING       -> NOTHOLDING if bit goes low before o.from
    %               -> FAIL if bit goes low after o.from but before o.to
    %               ->SUCCESS if bit is still high at o.to
    %               ->SUCCESS afterTrial
    % Parameters:
    % from,to:      must hold between from and to
    % mccChannel:   the DIGITAL channel to monitor [default = 1]
    % invert:       set to true to software-invert the bit value.
    
    properties
        mcc = [];
    end
    
    methods (Access=public)
        function o=hold(c,name)
            o=o@neurostim.behavior(c,name);
            o.addProperty('invert',false);
            o.addProperty('mccChannel',1);
            o.beforeTrialState   = @o.notHolding;
        end
        
        function beforeExperiment(o)
            %Check that the MCC plugin is added.
            o.mcc = pluginsByClass(o.cic,'mcc');
            if numel(o.mcc)~=1
                o.cic.error('STOPEXPERIMENT','The hold plugin requires an MCC plug-in. None (or more than one) detected)');
            end
            o.mcc.map('DIGITAL',o.mccChannel,'isHigh', 'AFTERFRAME');
        end
        
        %The get event fucntion gets the information from the MCC
        function  e = getEvent(o)
            % By convention a high bit on the mccChannel is considered a
            % HOLD.
            e= neurostim.event;
            e.isBitHigh = o.mcc.isHigh;
        end
        
        %% States
        function holding(o,t,e)
            if e.isAfterTrial;transition(o,@o.success,e);end % if still in this state-> success
            if ~e.isRegular ;return;end % No Entry/exit needed.
            % Guards
            isHold = isBitHigh(o,e);
            longEnough = t>o.to;
            notYetRequired = t<o.from;
            % Transitions
            if isHold  && longEnough
                transition(o,@o.success,e);
            elseif ~isHold && notYetRequired
                % Allow releases before from time
                transition(o,@o.notHolding,e);
            elseif ~isHold
                transition(o,@o.fail,e);
            end
        end
        
        function notHolding(o,t,e)
            if e.isAfterTrial;transition(o,@o.fail,e);end % if still in this state-> fail
            if ~e.isRegular ;return;end % No Entry/exit needed.
            %Guards
            isHold = isBitHigh(o,e);
            holdRequired = t>o.to;
            % Transitions
            if isHold
                transition(o,@o.holding,e);
            elseif holdRequired
                transition(o,@o.fail,e);                
            end
        end
        
    end
    
    methods (Access=protected)
        function value = isBitHigh(o,e)
            value = e.isBitHigh;
            if o.invert; value= ~value;end
        end
    end
    
end