classdef nafcResponse < neurostim.plugins.behavior
    % Behavior subclass for receiving a nafc keyboard response.
    %
    % Set:
    % keys -        cell array of key characters, e.g. {'a','z'}
    % keyLabel -    cell array of strings which are the labels for the keys declared
    %               above; in the same order. These are logged in o.responseLabel when the key is
    %               pressed.
    % correctKey -  function that returns the index (into 'keys') of the correct key. Usually a function of some stimulus parameter(s).
    % 
    
    properties
        responded@logical=false;
    end

   methods (Access = public)
       function o = nafcResponse(c,name)
            o = o@neurostim.plugins.behavior(c,name); 
            o.continuous = false;            
            o.addProperty('keyLabels',{},'validate',@iscellstr);
            o.addProperty('keys',{},'validate',@iscellstr);
            o.addProperty('correctKey',[],'validate',@isnumeric);
            o.addProperty('correct',false);
            o.addProperty('pressedInd',[]);
            o.addProperty('pressedKey',[]);
            o.addProperty('oncePerTrial',false);
            
       end
       
       function beforeTrial(o)            
           beforeTrial@neurostim.plugins.behavior(o); % Call parent
           o.responded = false;   % Update responded for this trial
       end

       function beforeExperiment(o)
           
           if isempty(o.keyLabels)
               o.keyLabels = o.keys;
           end
           
           % checks for errors.
           if numel(o.keys)~=numel(o.keyLabels)
               error('nafcResponse: The number of keylabels does not match the number of keys.');
           end
           
           % Add key listener for all keys.
           for i = 1:numel(o.keys)
                o.addKey(o.keys{i},o.keyLabels{i});
           end
       end
       
       
       function keyboard(o,key)           
           if o.enabled && (~o.responded || ~o.oncePerTrial)
               %Which key was pressed (index, and label)
               o.pressedInd = find(strcmpi(key,o.keys));
               o.pressedKey = o.keyLabels{o.pressedInd};

               %Is the response correct?
               if ~isempty(o.correctKey)
                   o.correct = o.pressedInd == o.correctKey;
               else
                   %No correctness function specified. Probably using as subjective measurement (e.g. PSE)
                   o.correct = true;
               end

               %Set flag so that behaviour class detects completion next frame
               o.inProgress = true;   
               o.responded = true;
           end
       end
       
   end
   
   methods (Access=protected)
       
       function inProgress = validate(o)
          inProgress = o.inProgress;
       end              
          
   end  
end