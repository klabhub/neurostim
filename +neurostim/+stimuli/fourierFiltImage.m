classdef fourierFiltImage < neurostim.stimuli.computeAcrossFramesThenDraw
    
    properties
        
        %Storage for completed images
        rawImage;               %image to be filtered, in either pixel or frequency domain
        filtImage_pix;          %filtered image in pixel space
        image_freq = [];        %un/filtered image in frequency domain
        
        %Storage for mask
        filter_freq;
        
        %Storage for partial images, mid-way through FFT/iFFT
        bufferHW_freq;
        bufferHW2_freq;
        bufferWH_freq;
        bufferWH2_freq;
        

        
    end
    
    %% OLD
    properties (Access = private)
        initialised = false;
        tex
    end
    
    properties (GetAccess = public, SetAccess = private)
        nSubImages;
        subImageSize;
        isequalMine; %returns tru if two piece-wise FFTs are the "same" as that of fft2. there are tiny tiny differences.
    end
    
    properties (GetAccess = public, SetAccess = protected)
    end
    
    
    properties
        
        %Temporary holding, for partial images in progress
        tmpStoreHW;
        tmpStoreHW2;
        tmpStoreWH;
        tmpStoreWH2;
        nColsInVertSub;
        nRowsInHorzSub;
        ixCol;
        ixRow;
    end
    %%
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
        
        
        function setupTasks(o)
            
            %Create a list of the tasks to be done to create the filtered image.
            tsks = {@makeRawImage,@makeFilter,@fftCols,@fftRows,@filterImage,@ifftCols,@ifftRows,@ifftFinalise,@normaliseImage};
            
            %Make the array of tasks, indicating that they are splittable across frames
            splittable = 1;
            for i=1:numel(tsks)
                o.addTask(func2str(tsks{i}),tsks{i},splittable);
            end
            
            %Set up memory buffers, and separate tasks into ones we can do
            %now, and ones that need to be done beforeFrame()
            %Which of these can we do now?
            isStatic = o.imageIsStatic & o.maskIsStatic;
            fftNeeded = strcmpi(o.imageDomain,'SPACE');
            doNow = [o.imageIsStatic,o.maskIsStatic,isStatic&fftNeeded,isStatic&fftNeeded,isStatic,isStatic,isStatic,isStatic,isStatic];
            doLater = [~o.imageIsStatic,~o.maskIsStatic,~isStatic&fftNeeded,~isStatic&fftNeeded,~isStatic,~isStatic,~isStatic,~isStatic,~isStatic];
            
            %We will pre-allocate memory for all the image matrices needed along the way. What size does it need to be?
            locPropNames = {'rawImage', 'filtImage_pix','image_freq', 'filter_freq', 'bufferHW_freq', 'bufferHW2_freq', 'bufferWH_freq', 'bufferWH2_freq'};
            bufferSz = {o.size,o.size,o.size,o.size,o.size,o.size,fliplr(o.size),fliplr(o.size)};
            isComplex = [~fftNeeded,0,0,1,0,1,1,1,1];
            for i=1:numel(locPropNames)
                o.(locPropNames{i}) = zeros(bufferSz{i});
                if isComplex(i)
                   o.(locPropNames{i}) = complex(o.(locPropNames{i})); 
                end
            end

            %How many columns are there to be done for each of the tasks in o.tasks?
            nColsPerTask = [o.size(2),o.size(2),o.size(2),o.size(1),o.size(2),o.size(2),o.size(1),o.size(1),o.size(2)];

            %Set up each task
            for i=1:numel(o.tasks)
                
                %When should it be done?
                if doNow(i)
                    o.tasks(i).when = 'beforeTrial';
                elseif doLater(i)
                    o.tasks(i).when = 'beforeFrame';
                else
                    o.tasks(i).enabled = 0;
                end
                
                %Allocate memory needed for the task.
                if o.tasks(i).enabled
                    %Indices into the columns. This will get split up during optimization.
                    o.tasks(i).data = 1:nColsPerTask(i);
                end
            end
            
            m=[];
            o.setTaskPlan(m);
        end
        
        function makeRawImage(o,t)
            %Load or construct the raw image
            if isa(o.image,'function_handle')
                %Get the current column indices
                ix = t.data;
                o.rawImage(:,ix) = o.image(o,[o.size(1),numel(ix)]);
            else
                %It's just a matrix.
                o.rawImage = o.image;
            end
        end
        
        function makeFilter(o,t)
            %Load or construct the raw image
            if isa(o.mask,'function_handle')
                %Function returns the filter image in segments,
                %each of o.subImageSize.
                ix = t.data;
                o.filter_freq(:,ix) = o.mask(o,[o.size(1),numel(ix)]);
            else
                %It's just a matrix.
                o.filter_freq = o.mask;
            end
        end
        
        function filterImage(o,~)
            %Apply the mask to the Fourier representation of the image.
            if strcmpi(o.imageDomain,'FREQUENCY')
                o.image_freq = o.rawImage.*o.filter_freq;
            else
                %FFT was done.                
                o.image_freq = o.image_freq.*o.filter_freq;
            end
        end
        
        function fftCols(o,t)
            %Run the FFT on the current sub-Image
            ix = t.data;
            o.bufferHW_freq(:,ix) = fft(o.rawImage(:,ix));
            if t.part==t.nParts
                o.bufferWH_freq = o.bufferHW_freq.';
            end
        end
        
        function fftRows(o,t)
            %Run the FFT on the current sub-Image
            ix = t.data;
            o.bufferWH2_freq(:,ix) = fft(o.bufferWH_freq(:,ix));
            if t.part==t.nParts
                %2D FFT complete. Copy to image.
                o.rawImage = o.bufferWH2_freq.';
            end
        end
        
        function ifftCols(o,t)
            %Run the FFT on the current sub-Image
            ix = t.data;
            o.bufferHW_freq(:,ix) = ifft(o.image_freq(:,ix));
            if t.part==t.nParts
                o.bufferWH_freq = o.bufferHW_freq.';
            end
        end
        
        function ifftRows(o,t)
            %Run the FFT on the current sub-Image
            ix = t.data;
            o.bufferWH2_freq(:,ix) = ifft(o.bufferWH_freq(:,ix));
%             if t.part==t.nParts
%                 %2D FFT complete. Copy to image.
%                 o.filtImage_pix = real(o.bufferWH2_freq.');
%                 
%                 %                 figure;
%                 %                 subplot(1,3,1);
%                 %                 imagesc(o.comparisonImage); colormap('gray'); colorbar;
%                 %                 subplot(1,3,2);
%                 %                 imagesc(o.filtImage);colormap('gray');colorbar;
%                 %                 subplot(1,3,3);
%                 %                 imagesc(o.filtImage-o.comparisonImage);colormap('gray');colorbar;
%                 
%             end            
        end
        
        function ifftFinalise(o,t)
            %2D iFFT complete. Transpose and make real.
            ix = t.data;
            o.filtImage_pix(ix,:)  = real(o.bufferWH2_freq(:,ix).'); %We're indexing into first dimension here... this is slower, but I think it's necessary (or a later transpose on whole image)
        end
        
        function normaliseImage(o,t)
            %Apply contrast and clip to monitor range
            contrast = 0.1;
            sd = 9.9501e-04;
            
            ix = t.data;
            im=contrast*o.filtImage_pix(:,ix)/sd+0.5;
            
            im(im<0) = 0;
            im(im>1) = 1;
            im = im*255;
            o.filtImage_pix(:,ix) = im;
        end
        
        function beforeBigFrame(o)
            
                if ~isempty(o.tex)
                    Screen('Close', o.tex);
                end
                %             %Assign image to a texture

            o.tex = Screen('MakeTexture',o.window,o.filtImage_pix);
            %imagesc(flipud(im)); colormap('gray'); axis image;
        end
        
        function draw(o)
            rect = [-o.width/2,-o.height/2,o.width/2,o.height/2];
            Screen('DrawTexture',o.window,o.tex,[],rect,[],1);
        end
        
        function im = randImage(o,sz)
            %Gaussian white noise.
            im = exp(1j*2*pi*rand(sz)); %This gives random phases
        end
        
        function afterBigFrame(o)
            

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