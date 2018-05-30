classdef (Abstract) noiserasterclut < neurostim.stimulus
    % Abstract stimulus class to present random noise rasters (e.g. for white-noise analysis).
    % Luminance noise values are drawn from built-in probaility distributions or returned by a user-defined function.
    % Argument specification is based on that of the jitter() plugin (though custom function specification is slightly different... TODO: unify this and jitter())
    % Each pixel is an independent random variable.
    %
    % By default, luminance values are NOT logged because of potential memory load.
    % However, the state of the RNG on each frame is logged, allowing offline reconstruction.
    % There is some over-head there. Logging can also be switched off entirely.
    %
    %
    %   Settable properties:
    %
    %   parms           - parameters for the N-parameter pdf, as an N-length cell array (see RANDOM)
    %   distribution    - the name of a built-in pdf [default = 'uniform'], or a handle to a custom function, f(o), which takes the plugin as a the lone argument)
    %   bounds          - 2-element vector specifying lower and upper bounds to truncate the distribution (default = [], i.e., unbounded). Bounds cannot be Inf.
    %   width           - width on screen (screen units)
    %   hight           - height on screen (screen units)
    %   logType         - What should be logged? All luminance values, RNG state (for offline reconstruction), or nothing?
    %   signal          - A matrix of values that is added to the noise (e.g. for detection task)
    %  
    %  TODO:
    %       (1) Allow specification of update frequency. Currently new vals every frame.
    %       (2) Add co-variance matrix for presenting correlated noise.
    %       (3) Provide a reconstruction tool for offline analysis
    %       (4) This approach to rng is inefficient: it would be better to have a separate RNG stream for this stimulus. CIC would need to act as RNG server?
    
    properties (Access = private)
        callback@function_handle;   %Handle of function for returning luminance values on each frame
        rng;        %Pointer to the global RNG stream
        clutLength;
    end
    
    properties (Constant)
        BACKGROUND = 0;
    end
    
    % dependent properties, calculated on the fly...
    properties (Dependent, SetAccess = private, GetAccess = public)
       
    end
    
    properties (SetAccess = private, GetAccess = public)
        lumImage@double; %Raster pixel luminance values
        clut;
        clutImage;
    end

    methods % set/get dependent properties

    end
    
    methods (Access = public)
        function o = noiserasterclut(c,name)

            o = o@neurostim.stimulus(c,name);
            
            %User-definable
            o.addProperty('parms',{0 255},'validate',@(x) iscell(x));
            o.addProperty('distribution','uniform','validate',@(x) isa(x,'function_handle') | any(strcmpi(x,makedist))); %Check against the list of known distributions
            o.addProperty('bounds',[], 'validate',@(x) isempty(x) || (numel(x)==2 && ~any(isinf(x)) && diff(x) > 0));
            o.addProperty('logType','RNGSTATE', 'validate',@(x) any(strcmpi(x,{'RNGSTATE','VALUES','NONE'})));
            o.addProperty('signal',[],'validate',@isnumeric); %Luminance values to add to noise matrix.
            o.addProperty('width',20);
            o.addProperty('height',10);
            
            %Internal variables for clut
            o.addProperty('idImage',[]);

            %Internal use for logging of luminance values
            o.addProperty('probObj',[]);
            o.addProperty('rngState',[]);
            o.addProperty('rngAlgorithm',[]);
            o.addProperty('clutVals',[]); %For logging luminance values, if requested

            
            o.writeToFeed('Warning: this is a new stimulus and has not been tested.');
            
        end

        function initialise(o)
            
            %The image is specified as a bitmap of arbitrary IDs for random variables.
            %This allows a child class to allocate a fixed ID to a location in the stimulus,
            %even if that location is perhaps not present on a given trial.
            %A function is provided, idImageToClutImage(), to convert the
            %image of IDs into an image of indices into the random
            %variables stored for that trial.
            %IDs must be integers greater than zero. Pixels with an ID==0
            %are set to the background luminance.
            
            %Flip it upside down to align it with neurostim coordinates
            o.idImage = flipud(o.idImage);
            
            %Convert the image of arbitrary random variable indices to clut indices (i.e. random variables)
            o.clutImage = o.idImageToClutImage(o.idImage);
            
            %How long will the CLUT be?
            o.clutLength = max(o.clutImage(:));
            o.clut = zeros(1,o.clutLength);
            o.clut(1) = o.cic.screen.color.background(1)*256; %0 in the idImage codes for background colour.

            %Set up a callback function, used to population the noise clut with luminance values
            dist = o.distribution;
            
            if isa(dist,'function_handle')                
                %User-defined function. Function must receive the noiseraster plugin as its sole argument
                o.callback = dist;
                
            elseif ischar(dist) && strcmpi(dist,'1ofN')                
                %Picking a value from a pre-defined list
                o.callback = @oneOfN;
                
            elseif ischar(dist) && any(strcmpi(dist,makedist))                
                %Using Matlab's built-in probability distributions
                o.callback = @(o) random(o.probObj,1,o.clutLength-1);
                
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
            tex=Screen('MakeTexture', win, o.lumImage);
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
            
            %Update the values in the clut
            o.clut(2:end) = o.callback(o);
            
            %Log the clut luminance values, if requested (use only for small memory loads)
            if strcmpi(o.logType,'VALUES')
                o.clutVals = o.clut;
            end
            
            %Create the luminance image            
            o.lumImage = o.clut(o.clutImage); %Plus 1 because first entry in CLUT is the background, coded as -1 in clutImage
            
            %Add in the signal
            sig = o.signal;
            if ~isempty(sig)
                o.lumImage = o.lumImage + sig;
            end
            
            %Restore precision
            o.rng.FullPrecision = true;
        end
        

    end % protected methods
    
    methods (Access = private)
        function vals = oneOfN(o)
            % Convenience function to pick from a set of values with equal probability.
            vals = randsample(cell2mat(o.parms),o.clutLength-1,true);
            vals = reshape(vals,sz);
        end
    end
    
    methods (Static)
        function clutImage = idImageToClutImage(idImage)
            
            %Which indices are in the image? [excluding background]
            [unqInds,~,clutImage] = unique(idImage);
            
            %If no image pixels are to be background, will need to increment all indices by 1
            if unqInds(1)~=0
                clutImage = clutImage + 1;
            end
            
            %Restore original size
            clutImage = reshape(clutImage,size(idImage));
        end
    end
end % classdef
