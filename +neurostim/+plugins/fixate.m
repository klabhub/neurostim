classdef fixate < neurostim.plugins.behavior
    % Behavioral plugin which monitors fixation on a point.
    % fixate - behavioural plugin which sets on = true when the fixation
    % point (X,Y) +/- tolerance has been fixated on for length dur (ms).
   properties (Access=private)
   end
   
   methods
       function o=fixate(c,name)
           o=o@neurostim.plugins.behavior(c,name);
           o.addProperty('X',0,[],@isnumeric);                 %X,Y,Z - the position of a target for the behaviour (e.g. fixation point)
           o.addProperty('Y',0,[],@isnumeric);
           o.addProperty('Z',0,[],@isnumeric);
           o.addProperty('tolerance',1,[],@isnumeric);
           o.continuous = true;
           if isfield(c,'eye')
               warning(c,'No eye data in CIC. This behavior control is unlikely to work');
           end
       end
       
   end
   
   methods (Access=protected)
       function inProgress = validateBehavior(o)
           % validateBehavior returns o.on = true when behavior passes all checks.
           inProgress = sqrt((o.cic.eye.x-o.X)^2+(o.cic.eye.y-o.Y)^2)<=o.tolerance;
       end
   end
    
end