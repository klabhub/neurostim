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
           o.addProperty('invert',false,'validate',@isnumeric); %Behavior is complete when NOT looking at this point.
           o.continuous = true;
           o.sampleEvent = '';
           if isfield(c,'eye')
               warning(c,'No eye data in CIC. This behavior control is unlikely to work');
           end
       end
       
   end
   
   methods (Access=protected)
       function inProgress = validate(o)
           % validate returns true when eye position is within tolerance of (X,Y).
           %
           %This code just evalutes this: sqrt((o.cic.eye.x-o.X)^2+(o.cic.eye.y-o.Y)^2)<=o.tolerance
           %but it checks X first because it's faster than evaluating o.cic.Y too if not needed
           inProgress = false;
           tol = o.tolerance;
           dx = o.cic.eye.x-o.X; 
           if dx < tol
               inProgress = sqrt(dx^2+(o.cic.eye.y-o.Y)^2)<=tol;
           end
           
           %If inverted, say whether we are NOT fixating now.
           if o.invert
               inProgress = ~inProgress;
           end
           
           if inProgress && ~o.continuous
               o.outcome = 'COMPLETE';
               o.success=true;
           end
             
       end
   end
    
end