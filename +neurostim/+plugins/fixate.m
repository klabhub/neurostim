classdef fixate < neurostim.plugins.behavior
   % Behavioral plugin which monitors fixation on a point.
   %
   % A fixate object o behaves as follows:
   %
   % In continuous mode (o.continuous = true; the default), o.success
   % is set to true when eye position comes within o.tolerance of the 
   % fixation point (o.X,o.Y) within o.from (ms) and remains there
   % until o.to (ms).
   %
   % In discrete mode (o.continuous = false), o.success is set to true
   % as soon as the eye position comes within o.tolerance of the
   % fixation point (o.X,o.Y).
   properties (Access=private)
   end
   
   methods
       function o=fixate(c,name)
           o=o@neurostim.plugins.behavior(c,name);
           o.addProperty('X',0,'validate',@isnumeric); % X,Y,Z - the position of a target for the behaviour (e.g. fixation point)
           o.addProperty('Y',0,'validate',@isnumeric);
           o.addProperty('Z',0,'validate',@isnumeric);
           o.addProperty('tolerance',1,'validate',@isnumeric);
           o.continuous = true;
           if isfield(c,'eye')
               warning(c,'No eye data in CIC. This behavior control is unlikely to work');
           end
       end
       
   end
   
   methods (Access=protected)
       function inProgress = validate(o)
           % validate returns true when eye position is within
           % tolerance of (X,Y).
           inProgress = sqrt((o.cic.eye.x-o.X)^2+(o.cic.eye.y-o.Y)^2)<=o.tolerance;
       end
   end
    
end