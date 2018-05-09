classdef noiseraster < neurostim.stimulus
    % Stimulus class to present random noise rasters (e.g. for white-noise analysis).
    % Luminance noise values are drawn from built-in probaility distributions or returned by a user-defined function.
    % Argument specification is based on that of the jitter() plugin (though custom function specification is slightly different... TODO: unify this and jitter())
    % Each pixel is an independent random variable. For co-variation, do it manually through custom distribution function.
    %
    % By default, luminance values are NOT logged because of potential memory load.
    % However, the state of the RNG on each frame is logged, allowing offline reconstruction.
    % There is some over-head there. Logging can also be switched off entirely.
    % This approach to rng is inefficient: it would be better to have a
    % separate RNG stream for this stimulus. CIC would need to act as RNG server.
    %
    %
    %   Settable properties:
    %
    %   size            - dimensionality of the raster matrix, as used in rand(),ones() etc.
    %   parms           - parameters for the N-parameter pdf, as an N-length cell array (see RANDOM)
    %   distribution    - the name of a built-in pdf [default = 'uniform'], or a handle to a custom function, f(o), which takes the plugin as a the lone argument)
    %   bounds          - 2-element vector specifying lower and upper bounds to truncate the distribution (default = [], i.e., unbounded). Bounds cannot be Inf.
    %   width           - width on screen (screen units)
    %   hight           - height on screen (screen units)
    %   logType         - What should be logged? All luminance values, RNG state (for offline reconstruction), or nothing?
    %   signal          - A matrix of values that is added to the noise (e.g. for detection task)
    %  
    %  TODO:
    %       (1) Allow specification of update frequency. Currently new vals
    %       every frame.
    %       (2) Provide a reconstruction tool for offline analysis
    
    properties (Access = private)
        callback@function_handle;   %Handle of function for returning luminance values on each frame
        rng;        %Pointer to the global RNG stream
    end
    
    % dependent properties, calculated on the fly...
    properties (Dependent, SetAccess = private, GetAccess = public)
        
    end
    
    properties (SetAccess = private, GetAccess = public)
        vals@double; %Raster pixel luminance values
    end
    
    methods % set/get dependent properties
        
    end
    
    methods (Access = public)
        function o = noiseraster(c,name)

            o = o@neurostim.stimulus(c,name);
            
            %User-definable
            o.addProperty('size',[10 20],'validate',@(x) isnumeric(x) & ndims(x)==2); %#ok<ISMAT>
            o.addProperty('parms',{0 255},'validate',@(x) iscell(x));
            o.addProperty('distribution','uniform','validate',@(x) isa(x,'function_handle') | any(strcmpi(x,makedist))); %Check against the list of known distributions
            o.addProperty('bounds',[], 'validate',@(x) isempty(x) || (numel(x)==2 && ~any(isinf(x)) && diff(x) > 0));
            o.addProperty('width',20);
            o.addProperty('height',10);
            o.addProperty('logType','RNGSTATE', 'validate',@(x) any(strcmpi(x,{'RNGSTATE','VALUES','NONE'})));
            o.addProperty('signal',[],'validate',@isnumeric); %Luminance values to add to noise matrix.
            
            %Internal use
            o.addProperty('probObj',[]);
            o.addProperty('rngState',[]);
            o.addProperty('rngAlgorithm',[]);
            o.addProperty('values',[]); %For logging luminance values, if requested
            
            o.writeToFeed('Warning: this is a new stimulus and has not been tested.');
        end
        
        function beforeTrial(o)
            
            %Set up a callback function, used to population the noise raster with luminance values
            dist = o.distribution;
            
            if isa(dist,'function_handle')                
                %User-defined function. Function must receive the noiseraster plugin as its sole argument
                o.callback = dist;
                
            elseif ischar(dist) && strcmpi(dist,'1ofN')                
                %Picking a value from a pre-defined list
                o.callback = @oneOfN;
                
            elseif ischar(dist) && any(strcmpi(dist,makedist))                
                %Using Matlab's built-in probability distributions
                o.callback = @(o) random(o.probObj,o.size);
                
                %Create a probability distribution object
                pd = makedist(o.distribution,o.parms{:});
                
                %Truncate the distribution, if requested
                if ~isempty(o.bounds)
                    pd = truncate(pd,o.bounds(1),o.bounds(2));
                end
                
                %Store object
                o.probObj = pd;
            end
            
            %Store the RNG state. 
            s = RandStream.getGlobalStream;
            o.rng = s; 
        end
        
        function beforeFrame(o)
            
            %Update the raster luminance values
            o.update();
            
            % After drawing, we can discard the noise texture.
            width = o.width;
            height = o.height;
            win = o.window;
            rect = [-width/2 -height/2 width/2 height/2];
            tex=Screen('MakeTexture', win, o.vals);
            Screen('DrawTexture', win, tex, [], rect, [], 0);
            Screen('Close', tex);
        end
    end % public methods
    
    methods (Access = protected)
        
        function o = update(o)

            %Temporarily set the rng to not use full precision, to favour speed
            s = o.rng;
            s.FullPrecision = false;
            
            %Log the state of the RNG, if requested
            if strcmpi(o.logType,'RNGSTATE')
                %Allows re-construction offline. see https://au.mathworks.com/help/matlab/ref/randstream.html
                o.rngState = s.State;
                o.rngAlgorithm = s.Type;
            end
            
            %Update the values in the raster
            o.vals = o.callback(o);
            
            %Log the raster luminance values, if requested (use only for small memory loads)
            if strcmpi(o.logType,'VALUES')
                o.values = o.vals;
            end
            
            %Add in the signal
            sig = o.signal;
            if ~isempty(sig)
                o.vals = o.vals + sig;
            end
            
            %Restore precision
            o.rng.FullPrecision = true;
        end
    end % protected methods
    
    methods (Access = private)
        function vals = oneOfN(o)
            % Convenience function to pick from a set of values with equal probability.
            sz = o.size;
            n = prod(sz);
            vals = randsample(cell2mat(o.parms),n,true);
            vals = reshape(vals,sz);
        end
    end
end % classdef
