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

   methods (Access = public)
       function o = nafcResponse(name)
            o = o@neurostim.plugins.behavior(name); 
            o.continuous = false;
            o.listenToEvent('BEFORETRIAL');
            o.addProperty('keyLabels',{},'',@iscellstr);
            o.addProperty('keys',{},'',@iscellstr);
            o.addProperty('correctKey',[],'',@isnumeric);
            o.addProperty('correct',false,[],[],'private');
            o.addProperty('pressedInd',[],[],[],'private');
            o.addProperty('pressedKey',[],[],[],'private');
            o.listenToEvent('BEFOREEXPERIMENT');
       end
       

       function beforeExperiment(o,c,evt)
           
           if isempty(o.keyLabels)
               o.keyLabels = o.keys;
           end
           
           % checks for errors.
           if numel(o.keys)~=numel(o.keyLabels)
               error('nafcResponse: The number of keylabels does not match the number of keys.');
           end
           
           % Add key listener for all keys.
           for i = 1:numel(o.keys)
                o.addKey(o.keys{i},@responseHandler,o.keyLabels{i});
           end
       end
   end
   
   methods (Access=protected)
       
       function inProgress = validateBehavior(o)
          inProgress = o.inProgress;
       end
       
       function responseHandler(o,key)
           
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
       end
          
   end  
end