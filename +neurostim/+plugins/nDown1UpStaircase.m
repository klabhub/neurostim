classdef nDown1UpStaircase < neurostim.plugins.staircase
  % Plugin class to implement a weighted (or transformed)
  % fixed-step-size (FSS) N-down-1-up staircase.
  %
  %   s = stimuli.gabor(c,'gabor'); % stimulus object
  %    :
  %    :
  %   b = plugins.nafcResponse(c,'choice'); % behaviour object
  %    :
  %    :
  %   t = plugins.nDown1UpStaircase(c,'staircase','gabor','contrast','@choice.success  & choice.correct',...); % staircase object
  %
  % The supplied criterion function must return TRUE or FALSE. Typically,
  % this criterion function is linked to a behavioural response (e.g.,
  % with TRUE indicating 'yes' in a yes/no experiment or 'correct' in a
  % forced choice experiment). The criterion function is evaluated before
  % every trial and the property value is updated accordingly.
  %
  % Required arguments, specified as name-value pairs, are:
  %
  %   n       - number of correct responses before decrementing the
  %             property value (default: 1)
  %   min     - minimum property value (default: NaN)
  %   max     - maximum property value (default: NaN)
  %   delta   - fixed step size
  %   weights - 1x2 vector of weights [up,down] applied to delta when
  %             incrementing or decrementing the property value
  %             (default: [1.0,1.0])
  %
  % For some practical recommendations on the design of efficient and
  % trustworthy FSS staircases, see:
  %
  %   M.A. Garcia-Perez, (1998), Forced-choice staircases with fixed
  %   step sizes: asymptotic and small-sample properties. Vision Res.
  %   38(12):1861-81.
  
  % 2016-10-05 - Shaun L. Cloherty <s.cloherty@ieee.og>
  
  properties (Access = private)
    cnt = -1; % 'correct' counter
  end
  
  properties (Access = public)
    n@double;

    min@double;
    max@double;

    delta@double;

    weights@double; % 1x2, [up, down]
  end
  
  methods
    function s = nDown1UpStaircase(c,name,plugin,property,criterion,varargin)
      % call the parent constructor
      s = s@neurostim.plugins.staircase(c,name,plugin,property,criterion);

      p = inputParser;                             
      p.KeepUnmatched = true;
      p.addParameter('n',1, @(x) validateattributes(x,{'double'},{'numel',1}));
      p.addParameter('min',NaN, @(x) validateattributes(x,{'double'},{'numel',1}));
      p.addParameter('max',NaN, @(x) validateattributes(x,{'double'},{'numel',1}));
      p.addParameter('delta',0, @(x) validateattributes(x,{'double'},{'numel',1}));
      p.addParameter('weights',[1.0, 1.0], @(x) validateattributes(x,{'double'},{'numel',2}));
            
      p.parse(varargin{:});

      s.n = p.Results.n;
      s.min = p.Results.min;
      s.max = p.Results.max;
      s.delta = p.Results.delta;
      s.weights = p.Results.weights;
    end
    
    function v = update(s,result)
      % calculate and return the updated property value

      % current value
      v = s.cic.(s.plugin).(s.property);
      
      if result
        % increment correct count
        s.cnt = s.cnt + 1;

        if s.cnt >= s.n
          % decrement value
          v = nanmax(v - s.weights(2)*s.delta,s.min);
        end
        
        return
      end
        
      % reset correct count
      s.cnt = 0;

      % increment value
      v = nanmin(v + s.weights(1)*s.delta,s.max);
    end
    
  end % methods
  
end % classdef
  