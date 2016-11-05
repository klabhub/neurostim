classdef trialData < event.EventData
    properties
        conditionName@char;
        
    end
    methods
        function o = trialData(name)
            o.conditionName = name;
        end
    end
end