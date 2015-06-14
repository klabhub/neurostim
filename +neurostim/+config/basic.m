classdef basic < neurostim.config
    % example config subclass for Neurostim/PTB. All parameters can be
    % set in the constructor.
    
   properties
   end
   
   methods
       
       function o = basic
           o = o@neurostim.config;
           o.pixels = [0 0 1600 1000];
           o.color.background = [0 0 0];
           o.colorMode = 'xyl';
           o.iti = 1000;
           o.trialDuration = Inf;
       end
       
   end
    
    
    
    
end