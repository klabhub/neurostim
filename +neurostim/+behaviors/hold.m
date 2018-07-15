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
    % Each trial starts in the NOTHOLDING state, and transitions either to
    % FAIL if the bit remains low until t>from, or into HOLDING if the bit
    % goes high before o.from.
    % Once in the HOLDING state, the state becomes either a FAIL if the bar is
    % released between o.from and o.to, a SUCCESS if it is released after
    % o.to, or back to HOLDING if released before o.from.
    % 
    %% STATE DIAGRAM
    %                   |-----(isBitHigh)?---
    %                   v                   |
    % NOTHOLDING ---(isHolding)?--->   HOLDING--- (~isHolding)? --> FAIL 
    %       |                               |
    %     (t>from)? --> FAIL               t>to? ---> SUCCESS   
    %
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
            if ~e.isRegular ;return;end % No Entry/exit needed.
            if isBitHigh(o,e)
                if t>t.to
                    transition(o,@o.success);
                %else
                    %stay in holding state
                end
            else
                if t <t.from   
                    % Allow releases before from time
                    transition(o,@o.notHolding);
                else                    
                    transition(o,@o.fail);                
                end
            end
        end
        
        function notHolding(o,t,e)
            if ~e.isRegular ;return;end % No Entry/exit needed.
            if isBitHigh(o,e)
                transition(o,@o.holding);
            else
                if t>o.from
                    transition(o,@o.fail);
                %else
                %   stay in not-holding state.
                end                    
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