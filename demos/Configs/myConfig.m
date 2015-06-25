classdef myConfig < neurostim.cic
    % basic configuration subclass wrapper for Neurostim. Properties inherited
    % from cic.
    
    properties
    end
    
    methods (Access=public)
        
        function o = myConfig()
           o = o@neurostim.cic;
           o.screen.pixels = [0 0 1600 1000];
           o.screen.physical = [50 31.25];
           o.screen.color.background = [0 0 0];
           o.screen.colorMode = 'xyl';
           o.iti = 1000;
           o.trialDuration = Inf;
        end
        
        
    end

end