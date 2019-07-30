classdef (Abstract) clutImage < neurostim.stimulus
    
    %TODO: clean up this help text, and unify across all child classes.
    %see noiseGridDemo.m for examples of usage in experiment script, and noiseClut.m and noisegrid.m for examples of an implemented child stimulus class.
    %Child class should, in beforeTrial(), set the values for ixImage and CLUT and then call
    %prep() of parent class to prepare the openGL textures and shaders that do the work.
    
    properties (Access=public)
        clut;
        optimiseForSpeed = true;    %Turns off some error checking (e.g. that RGB vals are valid)
    end
    
    properties (Access = protected)
        p2ns;
        ns2p;
    end
    properties (SetAccess=private)
        nClutColors = 16;
        colorModeIndex = [];                                %Which mode are we using? 1, 2, or 3
        nChans;                                             %How many channels are provided in the CLUT matrix?        
    end

        
    properties (Constant)
        BACKGROUND=0;
    end
    
    properties (Access=private)
        isSetup = false;
        isPrepped = false;
        tex
        luttex_gl
        luttex_ptb
        remapshader
        clutFormat
        pvtClut
        pvtClutLastNonZeroEntry
        lutTexSz
        floatPrecision
        maxTexSz
        allColorModes = {'RGB','LINLUT','XYL','LUM'};       %Display color modes
    end
    
    properties (Dependent)
        size
        colorMode
    end
    
    methods (Abstract, Access = protected)
        %Sub-classes must define a method to return the size of the texture matrix as [h,w], as used in ones(), rand() etc.
        %Done this way so it can be accessed before runtime.
        sz = imageSize(o)
    end
    
    methods
        function v = get.size(o)
            v = imageSize(o);
        end
        
        function v = get.colorMode(o)
            v = o.allColorModes{o.colorModeIndex};
        end
    end
    
    methods (Access = public)
        function o = clutImage(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('width',o.cic.screen.height);
            o.addProperty('height',o.cic.screen.height);
            o.addProperty('ixImage',[]);
            o.addProperty('alphaMask',[]);
            
            %Make sure openGL stuff is available
            AssertOpenGL;
        end
        
        function beforeExperiment(o)
            %Can be overloaded in child class (but if so, must still call setup())
            setup(o);
        end
        
        function afterTrial(o)
            cleanUp(o);
        end
        
        function delete(o)
            cleanUp(o);
        end
    end
    
    methods (Access = protected)
        function setup(o)
            global GL;
            AssertGLSL;
            
            info = Screen('GetWindowInfo', o.cic.mainWindow);
            if info.GLSupportsTexturesUpToBpc >= 32
                % full 32 bit single precision float texture
                o.floatPrecision = 2; % nClutColors < 2^32
            elseif info.GLSupportsTexturesUpToBpc >= 16
                % no 32 bit textures... use 16 bit 'half-float' texture
                o.floatPrecision = 1; % nClutColors < 2^16
            else
                % no support for >8 bit textures at all... use 8 bit texture?
                o.floatPrecision = 0; % nClutColors < 2^8
            end
            
            %What is the maximum number of texels along a single dimension?
            o.maxTexSz = double(glGetIntegerv(GL.MAX_TEXTURE_SIZE));
            
            % Make sure GLSL and pixelshaders are supported on first call:
            extensions = glGetString(GL.EXTENSIONS);
            if isempty(findstr(extensions, 'GL_ARB_fragment_shader'))
                % No fragment shaders: This is a no go!
                error('Sorry, this function does not work on your graphics hardware due to lack of sufficient support for fragment shaders.');
            end
            
            % Load our fragment shader for clut blit operations:
            shaderFile = fullfile(o.cic.dirs.root,'+neurostim','+stimuli','GLSLShaders','clutImage.frag.txt');
            o.remapshader = LoadGLSLProgramFromFiles(shaderFile);
            
            %Store pixel to ns transform factors for convenience
            o.p2ns = o.cic.pixel2Physical(1,0)-o.cic.pixel2Physical(0,0);
            o.ns2p = o.cic.physical2Pixel(1,0)-o.cic.physical2Pixel(0,0);
            
            %Check which color mode we are using
            colMod = o.cic.screen.colorMode;
            o.colorModeIndex = find(ismember(o.allColorModes,colMod));
            if isempty(o.colorModeIndex)
                error(['glllutimage does not know how to deal with colormode ' colMod]);
            end
            
            %Store the allowable formats for the clut texture
            o.isSetup = true;
        end
        
        function prep(o)
            
            %Check that everything is ready to go
            if ~o.isSetup, error('You must call o.setup() in your beforeExperiment() function'); end
            
            %Prepare the texture for the index image
            makeImageTex(o);
            
            %Make sure CLUT has the right size, value range etc.
            checkCLUT(o)
            
            %Prepare the texture for the CLUT
            makeCLUTtex(o);
            
            o.isPrepped = true;
        end
        
        function draw(o)
            global GL;
            
            % draw the texture...
            width = o.width;
            height = o.height;
            rect = [-width/2 -height/2 width/2 height/2];
            
            % we have to bind our textures (the lut texture and the image
            % texture) to the texture units where we told the shader to
            % expect them... i.e., 0 for the image texture, and 1 for the
            % lut texture.
            %
            % first make texture unit 1 the active texture unit...
            glActiveTexture(GL.TEXTURE0 + 1); % texture unit 1 is for the lut texture
            
            % ... and bind lut texture.
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT,o.luttex_gl);
            
            % now make texture unit 0 the active texture unit
            glActiveTexture(GL.TEXTURE0); % texture unit 0 is for the image texture
            
            % ... and bind the image texture.
            %             tex = Screen('GetOpenGLTexture',o.window,o.tex);
            %             glBindTexture(GL.TEXTURE_RECTANGLE_EXT,tex);
            
            % actually, we don't need to bind the texture, Screen('DrawTexture',...)
            % will do that (I think), we just need to make sure texture unit 0 is
            % the active texture unit before calling Screen(), so the image texture
            % gets bound where our shader expects it to be... i.e., texture unit 0
            
            Screen('DrawTexture', o.window, o.tex, [], rect, 0, 0, [], [], o.remapshader);
            
            % FIXME: for maximum robustness, I guess we should 'unbind' the
            %        textures here... we don't want some other sloppy
            %        plugin to accidently mess with our textures!
        end
        
        function setImage(o,ixImage)
            %ixImage should be a m x n image matrix of indices into the CLUT
            o.ixImage  = ixImage;
            o.nClutColors = max(ixImage(:));

        end
        
        function updateCLUTtex(o)
            
            global GL;
                        
            locClut = o.clut(:);
            
            %RGB validitiy check removed for speed
            if ~o.optimiseForSpeed && (any(locClut < 0) || any(locClut > 1))
                % lut values out of range
                error('At least one value in newclut is outside the range from 0 to 1!');
            end
            
            %Over-write the old values
            o.pvtClut(1:o.pvtClutLastNonZeroEntry) = locClut; %in-place memory usage for better performance
            
            % copy clut to the lut texture
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.luttex_gl);
            glTexSubImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, 0, 0, o.lutTexSz(1), o.lutTexSz(2), o.clutFormat, GL.FLOAT, single(o.pvtClut));
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);
            
        end
        
        function im = defaultImage(o,nGridElements)
            
            if nargin < 2
                nGridElements = 16;
            end
            
            %This function should be overloaded in child class
            %Making a sample image here
            [width, height]=Screen('WindowSize', o.window);
            s=floor(min(width, height)/2)-1;
            sz = s*2+1;
            n = floor(sqrt(nGridElements));
            tmp = reshape(1:n*n,n,n);
            im = kron(tmp,ones(ceil(sz/n))); % was floor()?
        end
        
        function clut = defaultCLUT(o)
            % Example CLUT with linear ramp of greyscale, one channel only.
            clut=linspace(0,1,o.nClutColors);
        end
        
        function cleanUp(o)
            o.clut = [];
            o.isPrepped = false;
            o.luttex_gl = [];
            o.luttex_ptb = [];
        end
    end
    
    methods (Access = private)
        function makeImageTex(o)
            
            %Check that an image has been set
            if isempty(o.ixImage)
                error('You should define your image (using setImage(o,ixImage)) before calling o.prep().');
            end
            
            %The image can contain zeros for where background luminance should be used (i.e. alpha should also equal zero).
            %So, enforce that here by setting alpha.
            im = flipud(o.ixImage); %Flipping here means it appears on screen as it would with imagesc(o.ixImage)
            isNullPixel = im(:,:,1)==o.BACKGROUND;
            im(isNullPixel) = NaN;
            
            %How big will the clut need to be? Make it the minimum square
            %that has enough entries (because the CLUT is stored in 2D internally anyway)
            lutSz = ceil(sqrt(o.nClutColors));
            lutSz = [lutSz,lutSz];
            
            imRGB = zeros([size(im),4]);
            [imRGB(:,:,1),imRGB(:,:,2)] = ind2sub(lutSz,im);
            imRGB = imRGB - 1; % because shader operations are zero based
            
            %Apply the alpha mask
            if isempty(o.alphaMask)
                o.alphaMask = ones(size(im));
            end
            
            %Make sure that mask and image are same size (because one could be varied across trials)
            if ~isequal(size(o.alphaMask),size(im))
                error('gllutimage and alphaMask are not the same size.');
            end
            
            %Set alpha to 0 for image indices equal to background (i.e. background),
            o.alphaMask(isNullPixel) = 0;
            
            %Set the mask.
            imRGB(:,:,4) = o.alphaMask;
            o.lutTexSz = lutSz; % [width,height] of the lut texture
            
            o.tex=Screen('MakeTexture', o.window, imRGB, [], [], o.floatPrecision);
        end
        
        function checkCLUT(o)
            
            locClut = o.clut;
            
            if isempty(locClut)
                error('You should define your clut (o.clut) before calling o.prep().');
            end
            
            %How many channels are specified in the CLUT? Should be  1 (GL.LUMINANCE), 2 (GL.LUMINANCE_ALPHA), 3 (GL.RGB), or 4 (GL.RGBA)
            sz = size(locClut);
            o.nChans = sz(1);

            %Make sure that the number of channels in the clut is compatible with the current display color mode.           
            checkNumClutChannels(o)
            
            %Check that the number of supplied clut entries matches that implied by the image
            if sz(2) < o.nClutColors
                error(['One or more color indices in the image is larger than the number of entries in the CLUT (', num2str(sz(2)),')',]);
            end
            
            %Check that CLUT values are in the expected range.
            if (any(locClut(:) < 0) || any(locClut(:) > 1))
                error('One or more values in o.clut are outside the range (0 to 1)');
            end
        end
        
        function makeCLUTtex(o)
            global GL;
            
            %Set up the texture.
            glUseProgram(o.remapshader);
            
            shader_image = glGetUniformLocation(o.remapshader, 'Image');
            shader_clut  = glGetUniformLocation(o.remapshader, 'clut');
            
            glUniform1i(shader_image, 0); % % texture unit 0 is for the image texture
            glUniform1i(shader_clut, 1); % texture unit 1 is for the lut texture
            
            glUseProgram(0);                       
                        
            %The texture will contain more entries than we are actually
            %using. Create the full clut column vector here
            o.pvtClut = zeros(o.nChans*prod(o.lutTexSz),1);
            o.pvtClutLastNonZeroEntry = o.nChans*o.nClutColors;
            o.pvtClut(1:o.pvtClutLastNonZeroEntry) = o.clut(:);
                        
            % create the lut texture
            o.luttex_ptb = Screen('MakeTexture',o.window,0);
            o.luttex_gl = Screen('GetOpenGLTexture',o.window,o.luttex_ptb);
            
            % what is the format of the clut data array? Need to let openGL know.                        
            formats = [GL.LUMINANCE, GL.LUMINANCE_ALPHA, GL.RGB, GL.RGBA];
            o.clutFormat = formats(o.nChans);
            
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.luttex_gl);
            glTexImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, GL.RGBA, o.lutTexSz(1), o.lutTexSz(2), 0, o.clutFormat, GL.FLOAT, single(o.pvtClut));
            
            % Make sure we use nearest neighbour sampling:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            
            % And that we clamp to edge:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_S, GL.CLAMP);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_T, GL.CLAMP);
            
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);
        end
        
        function checkNumClutChannels(o)
            %Some color modes require us to specify a certain number of
            %channels. Check that here.
            nCh = o.nChans;
            okNumChansPerMode = {1:4,1:4,3:4,1:2};  %for 'RGB','LINLUT','XYL','LUM'
            allOK = ismember(nCh,okNumChansPerMode{o.colorModeIndex}) & ismember(nCh,1:4);
            if ~allOK
                error(['CLUT contains the wrong number of color channels (', num2str(nCh),').  See help for clutImage.m']);
            end
        end
    end
    
end