classdef mat < neurostim.output
    % save data as .mat file; this simply saves the 'c' workspace variable.
   
    properties
    end
    
    methods
        function o = mat
            o = o@neurostim.output;
            
        end
        
        
        function saveFile(o,c)
            save(o.filename,'c');
        end
    end
    
end