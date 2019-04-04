classdef (Abstract) gllutimage < neurostim.stimulus
    
    %Child class should, in beforeTrial(), set the values for idImage and CLUT and then call
    %prep() of parent class to prepare the openGL textures and shaders that do the work.
    
    properties (Access=public)
        idImage;
        clut;
        optimiseForSpeed = true;    %Turns off some error checking (e.g. that RGB vals are valid)
    end
    
    properties (Access = protected)
        nChans = 1;
        p2ns;
        ns2p;
    end
    properties (SetAccess=private)
        nClutColors = 16;
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
        zeroPad
        lutTexSz
        floatPrecision
        maxTexSz
    end
    
    properties (Dependent)
        size
    end
    
    methods (Abstract, Access = protected)
        %Sub-classes must define a method to return the size of the texture matrix as [h,w], as used in ones(), rand() etc.
        sz = imageSize(o)
    end
    
    methods
        function v = get.size(o)
            v = imageSize(o);
        end
    end
    
    methods (Access = public)
        function o = gllutimage(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('width',o.cic.screen.height);
            o.addProperty('height',o.cic.screen.height);
            o.addProperty('alphaMask',[]);
            
            %Make sure openGL stuff is available
            AssertOpenGL;
        end
        
        function beforeExperiment(o)
            %Usually to be overloaded in child class (but if so, must still call setup())
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
            shaderFile = fullfile(o.cic.dirs.root,'+neurostim','+stimuli','GLSLShaders','noiseclut.frag.txt');
            o.remapshader = LoadGLSLProgramFromFiles(shaderFile);
            
            o.isSetup = true;
            
            %Store pixel to ns transform factors for convenience
            o.p2ns = o.cic.pixel2Physical(1,0)-o.cic.pixel2Physical(0,0);
            o.ns2p = o.cic.physical2Pixel(1,0)-o.cic.physical2Pixel(0,0);
        end
        
        function prep(o)
            
            %Check that everything is ready to go
            if ~o.isSetup
                error('You must call o.setup() in your beforeExperiment() function');
            end
            
            %Check that an image has been set
            if isempty(o.idImage)
                error('You should define your image (o.idImage) before calling o.prep().');
            end
            
            %Prepare the texture for the index image
            makeImageTex(o);
            
            if isempty(o.clut)
                error('You should define your clut (o.clut) before calling o.prep().');
            end
            
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
        
        function setImage(o,idImage)
            %idImage should be a m x n matrix of luminance values
            idImage = flipud(idImage);
            o.nClutColors = max(idImage(:));
            o.idImage = idImage;
        end
        
        function updateCLUT(o)
            
            global GL;
            
            %RGB validitiy check removed for speed
            %             % range check
            if ~o.optimiseForSpeed && (any(o.clut < 0) || any(o.clut > 255))
                % lut values out of range
                error('At least one value in newclut is outside the range from 0 to 255!');
            end
            
            % cast clut to uint8...
            paddedClut = vertcat(uint8(o.clut(:)),o.zeroPad);
            
            % copy clut to the lut texture
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.luttex_gl);
            glTexSubImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, 0, 0, o.lutTexSz(1), o.lutTexSz(2), o.clutFormat, GL.UNSIGNED_BYTE, paddedClut);
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
            %This function should be overloaded in child class
            % initialise CLUT with linear ramp of greyscale
            vals=linspace(0,255,o.nClutColors);
            clut = repmat(vals,o.nChans,1);
        end
  
        function cleanUp(o)
            o.idImage = [];
            o.clut = [];
            o.isPrepped = false;
            o.luttex_gl = [];
            o.luttex_ptb = [];
        end
    end
    
    methods (Access = private)
        function makeImageTex(o)
            
            %The image can contain zeros for where background luminance should be used (i.e. alpha should also equal zero).
            %So, enforce that here by setting alpha.
            im = o.idImage;
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
        
        function makeCLUTtex(o)
            global GL;
            
            glUseProgram(o.remapshader);
            
            shader_image = glGetUniformLocation(o.remapshader, 'Image');
            shader_clut  = glGetUniformLocation(o.remapshader, 'clut');
            
            glUniform1i(shader_image, 0); % % texture unit 0 is for the image texture
            glUniform1i(shader_clut, 1); % texture unit 1 is for the lut texture
            
            glUseProgram(0);
            
            % cast clut to uint8()
            o.zeroPad = uint8(zeros(o.nChans*(prod(o.lutTexSz)-o.nClutColors),1)); %Pre-computed for speed (to use horxcat rather than indexing)
            paddedClut = vertcat(uint8(o.clut(:)),o.zeroPad);
            
            % create the lut texture
            o.luttex_ptb = Screen('MakeTexture',o.window,0);
            o.luttex_gl = Screen('GetOpenGLTexture',o.window,o.luttex_ptb);
            
            % setup sampling etc.
            if o.nChans == 1
                o.clutFormat = GL.LUMINANCE;
            elseif o.nChans == 3
                o.clutFormat = GL.RGB;
            end
            
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.luttex_gl);
            glTexImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, GL.RGBA, o.lutTexSz(1), o.lutTexSz(2), 0, o.clutFormat, GL.UNSIGNED_BYTE, paddedClut);
            
            % Make sure we use nearest neighbour sampling:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            
            % And that we clamp to edge:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_S, GL.CLAMP);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_T, GL.CLAMP);
            
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);
        end
    end
end