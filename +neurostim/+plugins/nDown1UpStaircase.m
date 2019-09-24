classdef nDown1UpStaircase < neurostim.plugins.adaptive
    %Class to implement a weighted (or transformed)
    % fixed-step-size (FSS) N-down-1-up staircase.
    %
    %  Usage: see adaptiveDemo
    %
    % For some practical recommendations on the design of efficient and
    % trustworthy FSS staircases, see:
    %
    %   M.A. Garcia-Perez, (1998), Forced-choice staircases with fixed
    %   step sizes: asymptotic and small-sample properties. Vision Res.
    %   38(12):1861-81.
    
    % 2016-10-05 - Shaun L. Cloherty <s.cloherty@ieee.og>
    % 11/2016 - Modified by BK to match neurostim.adaptive framework
    
    properties (Access = private)
        cnt = -1; % 'correct' counter
        value = []; % Current value, initialized in constructor 
    end
    
    properties (Access = public)
        n@double;
        min@double;
        max@double;
        delta@double;
        weights@double; % 1x2, [up, down]
    end
    
    methods
        function o = nDown1UpStaircase(c,trialResult,startValue,varargin)
            % This constructor takes three required arguments :
            % c  -  handle to CIC
            % trialResult -  a NS function string that evaluates to true
            % (correct) or false (incorrect) at the end of a trial.
            % startValue - start value of the parameter in this staircase.
            %
            % Further required arguments, specified as name-value pairs, define the staircase procedure:
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
            p = inputParser;
            p.KeepUnmatched = true;
            p.addParameter('n',1, @(x) validateattributes(x,{'double'},{'numel',1}));
            p.addParameter('min',NaN, @(x) validateattributes(x,{'double'},{'numel',1}));
            p.addParameter('max',NaN, @(x) validateattributes(x,{'double'},{'numel',1}));
            p.addParameter('delta',0, @(x) validateattributes(x,{'double'},{'numel',1}));
            p.addParameter('weights',[1.0, 1.0], @(x) validateattributes(x,{'double'},{'numel',2}));            
            p.parse(varargin{:});
            
                        
            % call the parent constructor
            o = o@neurostim.plugins.adaptive(c,trialResult);
            o.n = p.Results.n;
            o.min = p.Results.min;
            o.max = p.Results.max;
            o.delta = p.Results.delta;
            o.weights = p.Results.weights;                     
            o.value = startValue;
        end
        
        function update(o,correct)
            % calculate and return the updated property value
            
            % current value
            v = o.getValue; 
            if correct
                % increment correct count
                o.cnt = o.cnt + 1;                
                if o.cnt >= o.n
                    % decrement value
                    o.value = nanmax(v - o.weights(2)*o.delta,o.min);
                end
            else
                % reset correct count
                o.cnt = 0;            
                % increment value
                o.value = nanmin(v + o.weights(1)*o.delta,o.max);
            end            
        end
        
        function v= getAdaptValue(o)
            % Return the current, internally stored, value
            v= o.value;
        end  
    end % methods
    
end % classdef
