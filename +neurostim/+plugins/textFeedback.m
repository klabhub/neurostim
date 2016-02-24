classdef textFeedback < neurostim.plugins.feedback
    % Plugin to deliver on screen text feedback.
    properties
        msg@neurostim.stimuli.text; 
    end
    
    
    methods (Access=public)
        function o=textFeedback(c,name)
            o=o@neurostim.plugins.feedback(c,name);
           % o.listenToEvent('BEFOREEXPERIMENT');   
            o.msg =neurostim.stimuli.text(c,'textFeedbackMessage');
            o.msg.message = '';
        end
        
       
    end
    
    methods (Access=protected)        
        function chAdd(o,varargin)
            % This is called from feedback.add only, there the standard
            % parts of the item have already been added to the class. 
            % Here we just add the sound specific arts.
            p=inputParser;  
            p.StructExpand = true; % The parent class passes as a struct
            p.addParameter('text',[],@ischar);     %Waveform data, filename (wav), or label for known (built-in) file (e.g. 'correct')
            p.parse(varargin{:});
            %Store the text 
            o.addProperty(['item', num2str(o.nItems) 'text'],p.Results.text);
        end
    end
    
    methods (Access=public)
        
    end
    
    methods (Access=protected)
         
        function deliver(o,itemNr)
            o.msg.message = o.(['item' num2str(itemNr) 'text']);   
            o.msg.message
        end
 end
        
    
    
end