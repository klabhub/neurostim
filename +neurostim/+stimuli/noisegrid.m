classdef noisegrid < neurostim.stimuli.noiseclut
    % TODO: clean up this help text, and unify across all child classes.    
    % Stimulus class to present random noise rasters (e.g. for white-noise analysis).
    % Luminance noise values are drawn from built-in probaility distributions or returned by a user-defined function.
    % Argument specification is based on that of the jitter() plugin (though custom function specification is slightly different... TODO: unify this and jitter())
    % Each pixel is an independent random variable.
    %
    % By default, luminance values are NOT logged because of potential memory load.
    % However, the state of the RNG on each frame is logged, allowing offline reconstruction.
    % There is some over-head there. Logging can also be switched off entirely.
    % This approach to rng is inefficient: it would be better to have a
    % separate RNG stream for this stimulus. CIC would need to act as RNG server.
    % 
    %
    %   Settable properties:
    %   sampleFun       - the name of a built-in distribution [default = 'uniform', see Matlab's makedist() for list of supported pdfs], or a handle to a custom function, f(o), which takes the plugin as a the lone argument)
    %   size_h,size_v   - dimensionality of the raster matrix
    %   parms           - parameters for the N-parameter pdf, as an N-length cell array (see RANDOM)    
    %   bounds          - 2-element vector specifying lower and upper bounds to truncate the distribution (default = [], i.e., unbounded). Bounds cannot be Inf.
    %   width           - width on screen (screen units)
    %   height          - height on screen (screen units)
    %   logType         - What should be logged? All luminance values, RNG state (for offline reconstruction), or nothing?
    %
    % See also noiseGridDemo, noiseRadialGridDemo, neurostim.stimuli.noiseclut, neurostim.stimuli.noiseradialgrid, neurostim.stimuli.noisehexgrid
    
    methods (Access = protected)

        function sz = imageSize(o)
            %Dimensionality of the image matrix 
            %We're obliged to define this function by abstract parent class
            sz = [o.size_h,o.size_w];
        end
    end
    
    methods (Access = public)
        function o = noisegrid(c,name)
            
            o = o@neurostim.stimuli.noiseclut(c,name);
            
            %User-definable
            o.addProperty('size_w',20,'validate',@(x) isnumeric(x) & ndims(x)==2); %#ok<ISMAT>
            o.addProperty('size_h',10,'validate',@(x) isnumeric(x) & ndims(x)==2); %#ok<ISMAT>
        end 
        
        function beforeTrial(o)
            
            %The image is specified as a bitmap in which each pixel value is
            %the ID of the random (luminance) variable to be used.
            imInds = 1:prod(o.size);
            im = reshape(imInds,o.size(1),o.size(2));
            
            %Set up the CLUT and random variable callback functions
            initialise(o,im);

        end
        
        function [clutVals,ixImage] = reconstructStimulus(o,varargin)
            
            p=inputParser;
            p.KeepUnmatched = true;
            p.addParameter('rect',[]); %[left top right bottom]
            p.parse(varargin{:});
            p = p.Results;
            
             rect = p.rect;
            if ~isempty(rect)
                
                assert(rect(1)<rect(3));
                assert(rect(2)>rect(4));
             
                width = o.width;
                height = o.height;
                nx = o.size_w;
                ny = o.size_h;
                
                %from analyais/noisegrid.getRandelCoords
                 rx = linspace(-0.5, 0.5,nx)*width*(1 - 1/nx);
                 ry = linspace( 0.5,-0.5,ny)*height*(1 - 1/ny);
           
                [~,xPixRange(1)] = min(abs(rx - rect(1)));%left
                [~,xPixRange(2)] = min(abs(rx - rect(3)));%right
                [~,yPixRange(1)] = min(abs(ry - rect(2)));%top
                [~,yPixRange(2)] = min(abs(ry - rect(4)));%bottom
                
%                 rx = rx(yPixRange(1):yPixRange(2), xPixRange(1):xPixRange(2));
%                 ry = ry(yPixRange(1):yPixRange(2), xPixRange(1):xPixRange(2));
                
                [XRANGE, YRANGE] = meshgrid(xPixRange(1):xPixRange(2), ...
                    yPixRange(1):yPixRange(2));
                randelMask = sub2ind([ny nx], YRANGE(:), XRANGE(:));
            else
                randelMask = [];
            end
            
            %               [clutVals,ixImage] = o@neurostim.stimuli.noiseclut.reconstructStimulus(o,...
            %                   'randelMask',randelMask);
            [clutVals, ixImage] = reconstructStimulus@neurostim.stimuli.noiseclut(...
                o,'randelMask',randelMask);
           
%            for ii = 1:numel(o.cic)
%                 [clut_, img{ii}] = o.cic(ii).noise.reconstructStimulus(...
%                     'randelMask',randelMask); % all trials
%                 
%                 clut{ii} = cellfun(@(x) 2*squeeze(x) - 1.0,clut_,'UniformOutput',false); % make clut zero mean [-1,0,+1]
%            end
%             
%            clutVals = cat(2,clut{:});
%             ixImage = cat(1,img{:})';
            
        end
 
    end % public methods
end % classdef
