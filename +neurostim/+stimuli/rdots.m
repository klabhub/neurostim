classdef rdots < neurostim.stimuli.dots

  properties (Access = private)
    initialized = false;

    cnt;  % callback counter (incremented each time the callback function is called)
  end

  properties (GetAccess = public, SetAccess = private)
    callback; % function handle for returning dot directions
  end

  methods
    function o = rdots(c,name,varargin)
      o = o@neurostim.stimuli.dots(c,name);
      
      o.addProperty('direction',0); % deg.
      o.addProperty('speed',5); % deg./s

      % sampling distribution (see makedist for details)
      o.addProperty('sampleFun','uniform');
      o.addProperty('sampleParms',{'lower',-30,'upper',30});
      o.addProperty('sampleBounds',[]);

      % values logged for debug/reconstruction only      
      o.addProperty('callbackCnt',0);
    end

    function initDots(o,ix)
      % initialises dots in the array positions indicated by ix

      initDots@neurostim.stimuli.dots(o,ix); % randomly positions the dots

      assert(o.initialized,'Sampling function callback has not been initialized!')

      n = nnz(ix);

      % sample direction for each dot
      direction = o.direction + o.callback(n);
      o.cnt = o.cnt + 1;
            
      % set dot directions (converting to Cartesian steps)
      [o.dx(ix,1), o.dy(ix,1)] = pol2cart(direction.*(pi/180),o.speed/o.cic.screen.frameRate);
    end
    
    function beforeTrial(o)
      o.setup(o.sampleFun,o.sampleParms,o.sampleBounds);

      beforeTrial@neurostim.stimuli.dots(o);
    end

    function afterTrial(o)
      afterTrial@neurostim.stimuli.dots(o);

      % log the callback counter
      o.callbackCnt = o.cnt

      o.initialized = false;
    end
  end % public methods

  methods (Access = protected)
    function setup(o,fcn,parms,bounds)
      % setup sampling function
      
      assert(any(strcmpi(fcn,makedist)),'Unknown distribution %s.',fcn);

      if ~iscell(parms)
        parms = num2cell(parms(:)');
      end

      % create a probability distribution object
      pd = makedist(fcn,parms{:});
                    
      % truncate (if requested)
      if ~isempty(bounds)
        pd = truncate(pd,bounds(1),bounds(2));
      end
                    
      % create function handle
      o.callback = @(n) random(pd,1,n); % returns n samples from pd
      o.cnt = 0;

      o.initialized = true;
    end
  end
end