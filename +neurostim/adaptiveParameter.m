classdef (Abstract) adaptiveParameter
  % Abstract Adaptive parameter class.
  %
  % This class captures functionality needed to create staircases, quest,
  % or even random changes to plugin/stimulus properties across trials.
  %
  % The user provides a trialResult (usually a function) that is evaluated at
  % the end of the trial and it is passed to the update function of
  % this class. Typically, this criterion would be linked to a behavior plugin like plugins.nafcResponse.
  %  (e.g. subject answered correctly, the criterion evaluates
  % to true , and this is used in a staircase adaptive parm to update the
  % staircase).
 %
  % Concrete child classes must define an update() method to
  % implement the desired adaptive behaviour. The update method
  % receives a single argument that is either TRUE or FALSE, reflecting
  % the value of the supplied trialResult.

  % 2016-10-05 - Shaun L. Cloherty <s.cloherty@ieee.org>
  % BK - updated to make generic adaptive

  properties
    plugin;     % The plugin/stimulus whose property will be changed by this adaptive object
    property; % The property that will be changed by this adaptive object  
    trialResult; % Function that returns the result of a trial, used to update the adapter.
    acrtive@logical; 
  end
  
  methods
    function s = adaptive(plugin,property,trialResult)
      % s = adaptive(plugin,property,trialResult)
      %
      %   c         - handle to cic
      %   name      - name for this adaptive object
      %   plugin    - name of the plugin whose property is to be varied
      %   property  - name of the property to be varied
      %   trialResult - a function to be evaluated at the end of each trial and returning true (correct) or fale
      %               (incorrect)
      %   active    - true/false, enabling or disabling adaptive updates
    
      s.plugin = plugin;
      s.property = property;
      s.trialResult = trialResult;
      s.active = true;
    end
    
  end % methods
  
  methods (Abstract)
    update(s,result);  % update internal representations.
    [m,s,v] = threshold(s); % Return current threshold, an estimate of its varince, and the parameter values used so far
  end
  
end % classdef
