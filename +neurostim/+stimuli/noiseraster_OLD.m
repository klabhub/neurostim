classdef noiseraster_OLD < neurostim.stimulus

    %
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

            global GL;
            
            %Update the raster luminance values
            o.update();
            
            % After drawing, we can discard the noise texture.
            width = o.width;
            height = o.height;
            win = o.window;
          
            %o.vals = (o.vals-min(o.vals(:)))./(max(o.vals(:))-min(o.vals(:)));
            
            if 1
                %Use Screen('DrawTexture')
                rect = [-width/2 -height/2 width/2 height/2];
                tex=Screen('MakeTexture', win, o.vals);
                Screen('DrawTexture', win, tex, [], rect, [], 0);
            else
                % Use openGl directly
                tex=Screen('MakeTexture', win, o.vals');
                %tex=Screen('MakeTexture', win, o.vals',[],1);      %Special flag to force GL_TEXTURE_2D type
                [gltex, gltextarget] = Screen('GetOpenGLTexture', win, tex);
                
                % Begin OpenGL rendering into onscreen window again:
                Screen('BeginOpenGL', win, 1);	%1 needed to preserve the existing stimulus transformations
                
                % Enable texture mapping for this type of textures...
                glEnable(gltextarget);
                
                % Bind our texture, so it gets applied to all following objects:
                glBindTexture(gltextarget, gltex);
                
                glTexParameteri(gltextarget, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
                glTexParameteri(gltextarget, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
                
                %Filtering
                glTexParameteri(gltextarget, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
                glTexParameteri(gltextarget, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
                
                if gltextarget==GL.TEXTURE_RECTANGLE
                    texWidth = o.size(2); %Texel coordinates used
                    texHeight = o.size(1);
                else
                    texWidth = 1.0; %Normalised texel coordinates used
                    texHeight = 1.0;
                end
                
                glBegin(GL.QUAD);
                glTexCoord2f(0.0, 0.0);                 glVertex3f(0.0, 0.0, 0.0);
                glTexCoord2f(0.0, texHeight);           glVertex3f(0.0, height, 0.0);
                glTexCoord2f(texWidth, texHeight);      glVertex3f(width, height, 0.0);
                glTexCoord2f(texWidth, 0.0);            glVertex3f(width, 0.0, 0.0);
                glEnd();
                
                Screen('EndOpenGL', win);
            end
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
