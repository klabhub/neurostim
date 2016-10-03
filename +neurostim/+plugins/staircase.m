classdef staircase < neurostim.plugin
  % Abstract staircase class.
  %
  % This plugin will set a given plugin property before each trial
  % based on the provided criterion function. Typically, this criterion
  % would be linked to a behavior plugin like plugins.nafcResponse.
  %
  % Concrete child classes must define an update() method to
  % implement the desired adaptive staircase behaviour. The update method
  % receives a single argument that is either TRUE or FALSE, reflecting
  % the value of the supplied criterion.

  % 2016-10-03 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties
    plugin;
    property;
%     criterion;
  end
  
  methods
    function s = staircase(c,name,plugin,property,criterion)
      % s = staircase(c,name,plugin,property,func)
      %
      %   c         - handle to cic
      %   name      - name for this staircase object
      %   plugin    - name of the plugin whose property is to be varied
      %   property  - name of the property to be varied
      %   criterion - a function to be evaluated immediately before 
      %               each trial and returning true (correct) or fale
      %               (incorrect)
      
      % call the parent constructor
      s = s@neurostim.plugin(c,name);
      s.listenToEvent({'BEFORETRIAL'});
      
      s.plugin = plugin;
      s.property = property;
%       s.criterion = criterion;
      s.addProperty('criterion',criterion);                
    end
    
%     function beforeExperiment(s,c,evt)
%       % do nothing?
%     end
    
    function beforeTrial(s,c,evt)
      % evaluate criterion and set the new property value...

      v = s.update(s.criterion);
      
      c.(s.plugin).(s.property) = v;
    end

    % abstract method, result = TRUE or FALSE, must return the
    % new property value
    v = update(s,result); % abstract method
    
  end % methods
  
end % classdef
