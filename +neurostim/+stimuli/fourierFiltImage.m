classdef fourierFiltImage < neurostim.stimuli.computeAcrossFramesThenDraw
    
    %TEMP STORES CURRENTLY NOT BEING USED WELL. THEY CHANGE CLASSES FROM
    %double<=>complex. Fix it so that they never change. Faster execution.
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
        pvtMask = [];

        
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
            doLaterTasks = tasks([~o.imageIsStatic,~o.maskIsStatic,~isStatic&fftNeeded,~isStatic&fftNeeded,~isStatic,~isStatic,~isStatic]);
            
            %How many segments will the image be broken into?
            if isStatic
                o.nSubImages = 1;
                o.subImageSize = o.size;
            else
                o.nSubImages = o.bigFrameInterval;
                o.subImageSize = [o.size(1),o.size(2)/o.bigFrameInterval];
            end
            o.nColsInVertSub = o.size(2)/o.nSubImages;
            o.nRowsInHorzSub = o.size(1)/o.nSubImages;
            
            %Pre-allocate buffers used for computation, allowing in-place
            %allocation and hopefully faster processing.
            [o.tmpStoreHW,o.tmpStoreHW2] = deal(complex(zeros(o.size)));
            [o.tmpStoreWH,o.tmpStoreWH2] = deal(complex(zeros(fliplr(o.size))));
            
            %Pre-compute the linear indices needed across iterative image construction
            for i=1:o.nSubImages
                o.ixCol{i} = (1:o.nColsInVertSub)+(i-1)*o.nColsInVertSub;
                o.ixRow{i} = (1:o.nRowsInHorzSub)+(i-1)*o.nRowsInHorzSub;
            end            
     
            %Run the tasks that can be done now
            cellfun(@(fun) fun(o),doNowTasks);
            
            %Tell the parent class which ones we need to do on the fly
            o.addBeforeFrameTask(doLaterTasks);
            
        end
        
        function afterBigFrame(o)
           
           %Clear image stores
%            if ~o.imageIsStatic
%                [o.rawImage,o.rawImage_freq] = deal([]);
%            end
%            
%            if ~o.maskIsStatic
%                o.pvtMask = [];
%            end
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
                curIter = o.curTaskIter;
                o.tmpStoreHW(:,o.ixCol{curIter}) = o.image(o);
                done = curIter==o.nSubImages;
            else
                %It's just a matrix.
                o.tmpStoreHW = o.image;
                done = true;
            end
        end
        
        function done = makeFilter(o)
            %Load or construct the raw image
            if isa(o.mask,'function_handle')
                %Function returns the filter image in segments,
                %each of o.subImageSize.
                o.pvtMask = horzcat(o.pvtMask,o.mask(o));
                done = o.curTaskIter==o.nSubImages;
            else
                %It's just a matrix.
                o.pvtMask = o.mask;
                done = true;
            end
        end
        
        function done = fftCols(o)
            
            %This function operates on image parts that are of size equal
            %to [o.size(1),o.size(2)/o.nSubImages]
            
            %Run the FFT on the current sub-Image
            curIter = o.curTaskIter;
            ix = o.ixCol{curIter};
            o.tmpStoreHW2(:,ix) = fft(o.tmpStoreHW(:,ix));
            done = curIter==o.nSubImages;
            if done
                o.tmpStoreWH = o.tmpStoreHW2.';
            end
        end
        
        function done = fftRows(o)
            
            %This function operates on image parts that are of size equal
            %to [o.size(2),o.size(1)/o.nSubImages]            
                        
            %Run the FFT on the current sub-Image
            curIter = o.curTaskIter;
            ix = o.ixRow{curIter};
            o.tmpStoreWH2(:,ix) = fft(o.tmpStoreWH(:,ix));

            %o.tmpStore = vertcat(o.tmpStore,fft(o.rawImage(:,:,o.curTaskIter)).');
            done = curIter==o.nSubImages;

            if done
                o.tmpStoreHW = o.tmpStoreWH2.';
            end
        end
        
        function done = ifftCols(o)
            %Run the iFFT on the current sub-Image
            curIter = o.curTaskIter;
            ix = o.ixCol{curIter};
            o.tmpStoreHW2(:,ix) = ifft(o.tmpStoreHW(:,ix));
            done = curIter==o.nSubImages;
            if done
                o.tmpStoreWH = o.tmpStoreHW2.';
            end
        end
        
        function done = ifftRows(o)
                       
            %Run the iFFT on the current sub-Image
            curIter = o.curTaskIter;
            ix = o.ixRow{curIter};
            o.tmpStoreWH2(:,ix) = ifft(o.tmpStoreWH(:,ix));
            done = curIter==o.nSubImages;
            
            if done
                %2D FFT complete. Copy to image.
                o.filtImage = real(o.tmpStoreWH2.');
            end
            
%             
%                             figure;
%                             subplot(1,3,1);
%                             imagesc(o.comparisonImage); colormap('gray'); colorbar;
%                             subplot(1,3,2);
%                             imagesc(o.filtImage);colormap('gray');colorbar;
%                             subplot(1,3,3);
%                             imagesc(o.filtImage-o.comparisonImage);colormap('gray');colorbar;
            
            
        end
        
        function done = filterImage(o)
            %Apply the mask to the Fourier representation of the image.
            o.tmpStoreHW = o.tmpStoreHW.*o.pvtMask;          
            done = true;
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
        
        function im = randImage(o)
            %Gaussian white noise.
            im = exp(1j*2*pi*rand(o.subImageSize)); %This gives random phases
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