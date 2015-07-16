classdef fixate < neurostim.plugins.behavior
    % fixate - behavioural plugin which sets on = true when the fixation
    % point (X,Y) +/- tolerance has been fixated on for length dur (ms).
   properties (Access=private)
   end
   
   methods
       function o=fixate(name)
           o=o@neurostim.plugins.behavior(name);
           o.continuous = true;
       end
       
       
       function on = checkBehavior(o)
           % checkBehavior returns o.on = true when behavior passes all
           % checks.
           on = sqrt((o.cic.eye.x-o.X)^2+(o.cic.eye.y-o.Y)^2)<=o.tolerance;
           
       end
   end
    
end