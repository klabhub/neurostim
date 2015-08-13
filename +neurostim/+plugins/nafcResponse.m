classdef nafcResponse < neurostim.plugins.behavior
   % Behavior subclass for receiving a n-alternative forced choice response from
   % keyboard input for PTB.
   %
   % Inputs:
   % stimName - name of stimulus to watch for checking the variable (string).
   % var - variable to check for response (string).
   % correctResponse - this is a cell array of functions (input as strings) that indicates a
   %        correct response for each keypress. Default returns the key name.
   % keyLabel - Cell array of strings which are the labels for the keys declared
   %        above; in the same order. These are logged in o.responseLabel when the key is
   %        pressed.
    
    
    
    
   properties
   end
   
   methods (Access = public)
       function o = nafcResponse(name)
            o = o@neurostim.plugins.behavior(name); 
            o.continuous = false;
            o.listenToEvent('BEFORETRIAL');
            o.addProperty('stimName','');
            o.addProperty('var','');
            o.addProperty('correctResponse',{});
            o.addProperty('keyLabel',{});
            o.addProperty('keys',{'a'});
            o.addProperty('response',[]);
            o.addProperty('responseLabel',[]);
            
       end
       
       function beforeTrial(o,c,evt)
           beforeTrial@neurostim.plugins.behavior(o,c,evt);
           % checks for errors.
           if ~isempty(o.correctResponse) && (max(size(o.keys)) ~= max(size(o.correctResponse)))
               error('nafcResponse: The number of keys is not the same as the number of key response functions.');
           end
           if ~isempty(o.keyLabel) && (max(size(o.keys)) ~=max(size(o.keyLabel)))
               error('nafcResponse: The number of keylabels is not the same as the number of keys.');
           end
           
           % add key listener for all keys.
           for i = 1:max(size(o.keys))
               if ~ismember(KbName(o.keys{i}),c.allKeyStrokes)
                o.listenToKeyStroke(o.keys{i},o.keyLabel{i});
               end
           end
           
       end
       
       function data = validateBehavior(o)
          data = o.on;
       end

       
       function keyboard(o,key,time)
           % Generic keyboard handler
           for i = 1:max(size(o.keys))  % runs through each key in the array
               if strcmpi(key,o.keys{i}) % compares key pressed with key array
                   o.on = true;
                   o.responseLabel = o.keyLabel{i}; % saves the keyLabel in a variable (logged)
                   a = o.cic.(o.stimName).(o.var);  % retrieves the value of the variable to be checked
                   if isempty(o.correctResponse)    % default case, saves key pressed as response
                       o.response = key;
                   else 
                       b = str2func(o.correctResponse{i});
                       o.response = b(a);    % evaluates function and saves result as response
                   end
               end
           end
       end
          
   end
   
    
    
    
    
    
end