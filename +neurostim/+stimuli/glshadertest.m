classdef glshadertest < neurostim.stimulus
    properties
        tex
        black
        newLUT
        clut
        mogl
        nRandels
        
        lutTexSz
    end
    
    
    methods (Access = public)
        function o = glshadertest(c,name)
            o = o@neurostim.stimulus(c,name);
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
            
            idImage_ = zeros([size(idImage),3]); % GL.RGA?
              
            [idImage_(:,:,1),idImage_(:,:,2)] = ind2sub(lutTexSz,idImage);
            idImage_(:,:,2) = idImage_(:,:,2)-1; % note: zero based
            
            o.lutTexSz = lutTexSz; % [width,height] of the lut texture
           
            o.tex=Screen('MakeTexture', o.window, idImage_, [], [], floatPrecision);
            
%             o.newLUT = zeros(o.nRandels,3);
            vals=linspace(0,255,o.nRandels);
            o.newLUT = repmat(vals(:),1,3); % nRandels x 3
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
            
            o.clut = uint8(zeros(1,prod(o.lutTexSz)*3));
            
            % create the lut texture
            o.mogl.luttex = glGenTextures(1);
            
            % setup sampling etc.
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.mogl.luttex);
            glTexImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, GL.RGBA, o.lutTexSz(1), o.lutTexSz(2), 0, GL.RGB, GL.UNSIGNED_BYTE, o.clut);
            
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
                   
            % Animation by CLUT color cycling loop:
            
            % Shift/Cycle all LUT entries: Entry 3 -> 2, 4 -> 3, 5 ->4 , ... ,
            % 256 -> 255, 2 -> 256, ... we just leave slot 1 alone, it defines
            % the DAC output values for the background.
            
            if ~mod(o.frame,round(100/o.nRandels)+1)
                o.newLUT = circshift(o.newLUT,-1,1);
%                 o.newLUT = repmat(rand(o.nRandels,1)*255,1,3); % <-- with nRandels > ~1k, this gives an old skool analog tv vibe
                
%                 backupLUT=o.newLUT(1, :);
%                 o.newLUT(1:(o.nRandels - 1), :)=o.newLUT(2:o.nRandels, :);
%                 o.newLUT(o.nRandels, :)=backupLUT;
            end
            
            % copy o.newLUT to the lut [texture]
            moglUpdate(o);

            % draw the texture... 
            Screen('DrawTexture', o.window, o.tex, [], [], 0, 0, [], [], o.mogl.remapshader);
        end
        
        function moglUpdate(o)
            
            global GL;
            newclut = o.newLUT;
                        
            % size check
            if size(newclut,1) ~= o.nRandels || size(newclut,2) ~= 3
                % invalid or missing lut
                error('newclut of wrong size (must be o.nRandels rows by 3 columns) provided!');
            end
            
            % range check
            if any(newclut(:) < 0) || any(newclut(:) > 255)
                % lut values out of range
                error('At least one value in newclut is outside the range from 0 to (o.nRandels - 1)!');
            end
            
            % copy newclut to clut, casting to uint8...
            o.clut(1:numel(newclut)) = uint8(newclut');
            
            % copy clut to the lut texture
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.mogl.luttex);

            glTexSubImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, 0, 0, o.lutTexSz(1), o.lutTexSz(2), GL.RGB, GL.UNSIGNED_BYTE, o.clut);            
            
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, 0);
        end
        
        function afterExperiment(o)
            
            % Disable CLUT blitter. This needs to be done before the call to
            %             % Screen('CloseAll')!
            %             moglClutBlit;
            
        end
        
    end
end