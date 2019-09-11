classdef fourierFiltImage < neurostim.stimuli.computeAcrossFramesThenDraw
    
    properties (Access = private)
        initialised = false;
        tex
    end
    
    properties (GetAccess = public, SetAccess = private)
        nSubImages;
        subImageSize;
        isequalMine
    end
    
    properties (GetAccess = public, SetAccess = protected)
    end
    
    properties
        rawImage;           %in pixel space
        rawImage_freq = []; %raw image in frequency domain
        filtImage;          %filtered image in pixel space
        filtImage_freq = [];%filtered image in frequency domain
        locMask = [];
        tmpStore = [];      %Temporary holding, for partial images in progress
        tmpStore2 = [];
    end
    
    methods (Access = public)
        function o = fourierFiltImage(c,name)
            
            o = o@neurostim.stimuli.computeAcrossFramesThenDraw(c,name);
            
            %User-definable
            o.addProperty('image',@randImage); %A string path to an image file, an image matrix, or a function handle that returns an image
            o.addProperty('imageDomain','SPACE','validate',@(x) any(strcmpi(x,{'SPACE','FREQUENCY'})));
            o.addProperty('imageIsStatic',false);   %if true, image is computed once in beforeTrial() and never again. Otherwise, every frame
            o.addProperty('mask',eye(5));
            o.addProperty('maskIsStatic',false);
            o.addProperty('size',[100,200]);
            o.addProperty('width',10);
            o.addProperty('height',10);
            o.writeToFeed('Warning: this is a new stimulus and has not been tested.');
            
            o.isequalMine = @neurostim.stimuli.fourierFiltImage.isFFTequal;
        end
        
        function beforeTrial(o)
            
            %First, do some housekeeping upstairs
            beforeTrial@neurostim.stimuli.computeAcrossFramesThenDraw(o);
            
            %Create a list of the tasks to be done to create the filtered image.
            tasks = {@makeRawImage,@makeFilter,@fftCols,@fftRows,@filterImage,@ifftCols,@ifftRows};
            
            %Which of these can we do now?
            isStatic = o.imageIsStatic & o.maskIsStatic;
            fftNeeded = strcmpi(o.imageDomain,'SPACE');
            doNowTasks = tasks([o.imageIsStatic,o.maskIsStatic,isStatic&fftNeeded,isStatic&fftNeeded,isStatic,isStatic,isStatic]);
            doLaterTasks = tasks([~o.imageIsStatic,~o.maskIsStatic,fftNeeded,fftNeeded,~isStatic,~isStatic,~isStatic]);
            
            %How many segments will the image be broken into?
            if isStatic
                o.nSubImages = 1;
                o.subImageSize = o.size;
            else
                o.nSubImages = o.bigFrameInterval;
                o.subImageSize = [o.size(1),o.size(2)/o.bigFrameInterval];
            end
            
            %Run the tasks that can be done now
            cellfun(@(fun) fun(o),doNowTasks);
            
            %Tell the parent class which ones we need to do on the fly
            o.addBeforeFrameTask(doLaterTasks);
            
        end
        
        function afterBigFrame(o)
           
           %Clear image stores
           if ~o.imageIsStatic
               [o.rawImage,o.rawImage_freq] = deal([]);
           end
           
           if ~o.maskIsStatic
               o.locMask = [];
           end
        end
        
        function done = makeRawImage(o)
            %Load or construct the raw image
            %
            %
            if ischar(o.image)
                %TODO: Load it from a file.
                error('Not yet supported');
            elseif isa(o.image,'function_handle')
                %Function returns the image and a done flag
                %Function should return the image in segments,
                %each of o.subImageSize.
                o.rawImage(:,:,o.curTaskIter) = o.image(o); %Using pages for FFT later
                done = o.curTaskIter==o.nSubImages;
            else
                %It's just a matrix.
                o.rawImage = o.image;
                done = true;
            end
        end
        
        function done = makeFilter(o)
            %Load or construct the raw image
            if isa(o.mask,'function_handle')
                %Function returns the filter image in segments,
                %each of o.subImageSize.
                o.locMask = horzcat(o.locMask,o.mask(o));
                done = o.curTaskIter==o.nSubImages;
            else
                %It's just a matrix.
                o.locMask = o.mask;
                done = true;
            end
        end
        
        function done = fftCols(o)
            
            %Run the FFT on the current sub-Image
            o.tmpStore = vertcat(o.tmpStore,fft(o.rawImage(:,:,o.curTaskIter)).');
            done = o.curTaskIter==o.nSubImages;
        end
        
        function done = fftRows(o)
            
            %On first run, organise the matrix
            if o.curTaskIter==1
                o.tmpStore = reshape(o.tmpStore,o.size(2),o.size(1)/o.nSubImages,o.nSubImages);
            end
            
            %Run the FFT on the current sub-Image
            o.rawImage_freq = vertcat(o.rawImage_freq,fft(o.tmpStore(:,:,o.curTaskIter)).');
            done = o.curTaskIter==o.nSubImages;
            if done
                o.tmpStore = [];
            end
        end
        
        function done = ifftCols(o)
            %Run the FFT on the current sub-Image
            if o.curTaskIter==1
                o.filtImage_freq = reshape(o.filtImage_freq,o.size(1),o.size(2)/o.nSubImages,o.nSubImages);
            end
            im=ifft(o.filtImage_freq(:,:,o.curTaskIter)).';
            o.tmpStore = vertcat(o.tmpStore,im);
            done = o.curTaskIter==o.nSubImages;
        end
        
        function done = ifftRows(o)
            
            %On first run, organise the matrix
            if o.curTaskIter==1
                o.tmpStore2 = reshape(o.tmpStore,o.size(2),o.size(1)/o.nSubImages,o.nSubImages);
                o.tmpStore = [];
            end
            
            %Run the FFT on the current sub-Image
            im = ifft(o.tmpStore2(:,:,o.curTaskIter)).';
            o.tmpStore = vertcat(o.tmpStore,im);
            done = o.curTaskIter==o.nSubImages;
            if done
                o.filtImage = abs(o.tmpStore); %abs here because tmpStore is still a complex number, because we can't use the "symmetric" flag that ifft2() has, which returns a double
                o.tmpStore = [];
                
%                 figure;
%                 subplot(1,3,1);
%                 imagesc(o.comparisonImage); colormap('gray'); colorbar;
%                 subplot(1,3,2);
%                 imagesc(o.filtImage);colormap('gray');colorbar;
%                 subplot(1,3,3);
%                 imagesc(o.filtImage-o.comparisonImage);colormap('gray');colorbar;
                
            end
        end
        
        function done = filterImage(o)
            %Apply the mask to the Fourier representation of the image.
            o.filtImage_freq = o.rawImage_freq.*o.locMask;          
            done = true;
        end
        
        function scratchPad(o)
            nPix = 2^8;
            %Method 2 - piecewise FFT
            w = nPix*1.5;
            h = nPix;
            
            %Create a random image
            image = rand(h,w);
            fftFun = @fft;
            a = fftFun(image).';
            b = fftFun(a).';
            
            c = fft(fft(image).').';
            d = fft2(image);
            
            %How many sections will we split the image (column-wise)
            nPieces = 4;
            
            %Split it, using third dimension as pages
            splitImage = reshape(image,h,w/nPieces,nPieces);
            
            %Step 1 (cols)
            ft_col = [];
            for i=1:nPieces
                ft_col = vertcat(ft_col,fftFun(splitImage(:,:,i)).');
            end
            
            splitImage = reshape(ft_col,w,h/nPieces,nPieces);
            %Step 2 (rows)
            ft = [];
            for i=1:nPieces
                ft = vertcat(ft,fftFun(splitImage(:,:,i)).');
            end
            
            isequal(ft,b)
        end
        
        function beforeBigFrame(o)
            contrast = 0.25;
            im = zscore(o.filtImage,[],'all')*contrast + 0.5;
            im = min(im,1);
            im = max(im,0);
            
            if ~isempty(o.tex)
                Screen('Close', o.tex);
            end
            %Assign image to a texture
            o.tex = Screen('MakeTexture',o.window,im*255);
        end
        
        function draw(o)
            rect = [-o.width/2,-o.height/2,o.width/2,o.height/2];
            Screen('DrawTexture',o.window,o.tex,[],rect,[],1);
        end
        
        function beforeLittleFrame(o)
            if o.static
                %Nothing to do.
                o.bigFrameReady = true;
                return;
            end
            
            %Calculate a proportion of image
            
            nCol /nLittleFrames/4
        end
        
        function im = randImage(o)
            im = rand(o.subImageSize);
        end
        
    end % public methods
    
    
    methods (Access = protected)
        
        
        %         end
    end % protected methods
    
    methods (Access = private)
        
    end
    
    methods (Static)
        function out = isFFTequal(a,b)
            %isequal was returning 0 because of machine precision mismatch
            this = max(abs(a(:))-abs(b(:)))<0.0000001;
            that = max(circ_dist(angle(a(:)),angle(b(:)))) < 0.000001;
            out = this & that;
        end
    end
end % classdef