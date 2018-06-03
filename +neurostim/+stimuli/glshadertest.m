classdef glshadertest < neurostim.stimulus
    properties
        tex
        black
        clut
        mogl
        nRandels
        nChans
        zeroPad
        lutTexSz
    end
    
    
    methods (Access = public)
        function o = glshadertest(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('optimiseForSpeed',true); %Turns off some error checking (e.g. that RGB vals are valid)
        end
        
        function beforeExperiment(o)
            global GL;
            
            % This script calls Psychtoolbox commands available only in OpenGL-based
            % versions of the Psychtoolbox. (So far, the OS X Psychtoolbox is the
            % only OpenGL-base Psychtoolbox.)  The Psychtoolbox command AssertPsychOpenGL will issue
            % an error message if someone tries to execute this script on a computer without
            % an OpenGL Psychtoolbox
            AssertOpenGL;
            
            info = Screen('GetWindowInfo', o.cic.mainWindow);
            if info.GLSupportsTexturesUpToBpc >= 32
              % full 32 bit single precision float texture
              floatPrecision = 2; % nRandels < 2^32
            elseif info.GLSupportsTexturesUpToBpc >= 16
              % no 32 bit textures... use 16 bit 'half-float' texture
              floatPrecision = 1; % nRandels < 2^16
            else
              % no support for >8 bit textures at all... use 8 bit texture?
              floatPrecision = 0; % nRandels < 2^8 
            end
            
            maxTexSz = double(glGetIntegerv(GL.MAX_TEXTURE_SIZE));
            
            % %The ID image is set here
            [width, height]=Screen('WindowSize', o.window);
            s=floor(min(width, height)/2)-1;
            sz = s*2+1;
%             idImage = repmat(round(linspace(0,o.nRandels - 1,sz)),round(sz),1);

            % alternate idImage
            n = floor(sqrt(o.nRandels));
            tmp = reshape(0:n*n-1,n,n);
            idImage = kron(tmp,ones(ceil(sz/n))); % was floor()?

            % work around texture size limit...
            lutTexSz = [o.nRandels, 1];
            
            if o.nRandels > maxTexSz
              lutTexSz = [maxTexSz, ceil(max(idImage(:))./maxTexSz)+1];
            end
            
            o.nChans = 3;
            idImage_ = zeros([size(idImage),o.nChans]); % GL.RGA?
              
            [idImage_(:,:,1),idImage_(:,:,2)] = ind2sub(lutTexSz,idImage);
            idImage_(:,:,2) = idImage_(:,:,2)-1; % note: zero based
            
            o.lutTexSz = lutTexSz; % [width,height] of the lut texture
           
            o.tex=Screen('MakeTexture', o.window, idImage_, [], [], floatPrecision);
            
            % initialise CLUT with linear ramp of greyscale
            vals=linspace(0,255,o.nRandels);
            o.clut = repmat(vals,o.nChans,1);
            o.zeroPad = uint8(zeros(o.nChans*(prod(o.lutTexSz)-o.nRandels),1)); %Pre-computed for speed (to use horxcat rather than indexing)
        end
        
        function beforeTrial(o)
            initalisemoglClut(o)
        end
        
        function initalisemoglClut(o)
            global GL;
            
            % Make sure GLSL and pixelshaders are supported on first call:
            AssertGLSL;
            extensions = glGetString(GL.EXTENSIONS);
            if isempty(findstr(extensions, 'GL_ARB_fragment_shader'))
                % No fragment shaders: This is a no go!
                error('moglClutBlit: Sorry, this function does not work on your graphics hardware due to lack of sufficient support for fragment shaders.');
            end
            
            % Load our fragment shader for clut blit operations:
            shaderFile = fullfile(o.cic.dirs.root,'+neurostim','+stimuli','GLSLShaders','noiserasterclut.frag.txt');
            
            o.mogl.remapshader = LoadGLSLProgramFromFiles(shaderFile);

            glUseProgram(o.mogl.remapshader);
            
            shader_image = glGetUniformLocation(o.mogl.remapshader, 'Image');
            shader_clut  = glGetUniformLocation(o.mogl.remapshader, 'clut');
            
            glUniform1i(shader_image, 0);
            glUniform1i(shader_clut, 1);
            
            glUseProgram(0);
            
            % cast clut to uint8()
%             linClut = uint8(reshape(o.clut,1,[]));
            paddedClut = vertcat(uint8(o.clut(:)),o.zeroPad);
            
            % create the lut texture
            o.mogl.luttex = glGenTextures(1);
            
            % setup sampling etc.
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.mogl.luttex);
            glTexImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, GL.RGBA, o.lutTexSz(1), o.lutTexSz(2), 0, GL.RGB, GL.UNSIGNED_BYTE, paddedClut);
            
            % Make sure we use nearest neighbour sampling:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            
            % And that we clamp to edge:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_S, GL.CLAMP);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_T, GL.CLAMP);
            
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);
        end
        
        
        
        function beforeFrame(o)
            glLoadIdentity();
                   
            % update o.clut
            if ~mod(o.frame,round(100/o.nRandels)+1)
                o.clut = circshift(o.clut,-1,2);
                %o.clut = reshape(repmat(ones(1,o.nRandels),o.nChans,1),[],1);
                %o.clut = circshift(o.clut,-o.nChans,2);
%                 o.clut = repmat(rand(1,o.nRandels)*255,3,1); % <-- with nRandels > ~1k, this gives an old skool analog tv vibe
            end
            
            % copy o.clut to the lut [texture]
            moglUpdate(o);

            % draw the texture... 
            Screen('DrawTexture', o.window, o.tex, [], [], 0, 0, [], [], o.mogl.remapshader);
        end
        
        function moglUpdate(o)
            
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
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.mogl.luttex);
            glTexSubImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, 0, 0, o.lutTexSz(1), o.lutTexSz(2), GL.RGB, GL.UNSIGNED_BYTE, paddedClut);            
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);
        end
        
        function afterExperiment(o)
            
            % Disable CLUT blitter. This needs to be done before the call to
            %             % Screen('CloseAll')!
            %             moglClutBlit;
            
        end
        
    end
end