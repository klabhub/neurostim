classdef  parm <handle
    properties
        name@char;  % Name of this parameter
        log@cell;   % Previous values assigned to this parm.
        T@double;   % Time at which the previous values were assigned        
    end
    methods 
        function o = parm(n)
            o.name = n;
            o.log = {};
            o.T = [];             
        end
        
        function value(o)
            
        end
    end
    
    
end