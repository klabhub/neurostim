classdef fixateAnnulus < neurostim.plugins.behavior
   % Behavioral plugin which checks that the subject is looking
   % somewhere (anywhere) within an annulus. Useful for saccades to a choice circle.
   % The annulus is centered on [o.X,o.Y]
   properties (Access=private)
   end
   
   methods
       function o=fixateAnnulus(c,name)
           o=o@neurostim.plugins.behavior(c,name);
           o.addProperty('X',0,'validate',@isnumeric); % X,Y,Z - the position of a target for the behaviour (e.g. fixation point)
           o.addProperty('Y',0,'validate',@isnumeric);
           o.addProperty('Z',0,'validate',@isnumeric);
           o.addProperty('radius',5);
           o.addProperty('tolerance',1,'validate',@isnumeric);
           o.continuous = true;
           o.sampleEvent = '';
           if isfield(c,'eye')
               warning(c,'No eye data in CIC. This behavior control is unlikely to work');
           end
       end
       
   end
   
   methods (Access=protected)
       function inProgress = validate(o)
           tol = o.tolerance;
           inProgress = abs(hypot(o.cic.eye.x - o.X,o.cic.eye.y - o.Y)-o.radius) < tol;
       end
   end
    
end