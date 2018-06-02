classdef glshadertest < neurostim.stimulus
    properties
        tex
        black
        newLUT
        clut
        mogl
        nRandels
    end
    
    
    methods (Access = public)
        function o = glshadertest(c,name)
            o = o@neurostim.stimulus(c,name);
        end
        
        function beforeExperiment(o)
            
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
            
            % %The ID image is set here
            [width, height]=Screen('WindowSize', o.window);
            s=floor(min(width, height)/2)-1;
            sz = s*2+1;
%             idImage = repmat(round(linspace(0,o.nRandels - 1,sz)),round(sz),1);

            % alternate idImage
            n = floor(sqrt(o.nRandels));
            tmp = reshape(0:n*n-1,n,n);
            idImage = kron(tmp,ones(floor(sz/n)));
            
            o.tex=Screen('MakeTexture', o.window, idImage, [], [], floatPrecision);
            
            o.newLUT = zeros(o.nRandels,3);
            vals=linspace(0,255,o.nRandels);
            for i=0:(o.nRandels - 1)
                o.newLUT(i+1, :)=[vals(i+1) vals(i+1) vals(i+1)];
            end
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
            % Assign proper texture units for input image and clut:
            shader_image = glGetUniformLocation(o.mogl.remapshader, 'Image');
            shader_clut  = glGetUniformLocation(o.mogl.remapshader, 'clut');
%             shader_nRandels  = glGetUniformLocation(o.mogl.remapshader, 'nRandels');
            
            glUniform1i(shader_image, 0);
            glUniform1i(shader_clut, 1);
%             glUniform1f(shader_nRandels, single(o.nRandels-1));
            glUseProgram(0);
            
            % Build a gray-ramp as texture:
            o.clut = uint8(zeros(1, o.nRandels*3));
            for i=0:(o.nRandels - 1)
                o.clut(1 + i*3 + 0)= i;
                o.clut(1 + i*3 + 1)= i;
                o.clut(1 + i*3 + 2)= i;
            end
            
            % Select the 2nd texture unit (unit 1) for setup:
            glActiveTexture(GL.TEXTURE1);
            o.mogl.luttex = glGenTextures(1);
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.mogl.luttex);
            glTexImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, GL.RGBA, o.nRandels, 1, 0, GL.RGB, GL.UNSIGNED_BYTE, o.clut);
            
            % Make sure we use nearest neighbour sampling:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            
            % And that we clamp to edge:
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_S, GL.CLAMP);
            glTexParameteri(GL.TEXTURE_RECTANGLE_EXT, GL.TEXTURE_WRAP_T, GL.CLAMP);
            
            % Default CLUT setup done: Switch back to texture unit 0:
            glActiveTexture(GL.TEXTURE0);
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
            
            % Perform blit of our image, applying newLUT as clut:
            moglUpdate(o);

        end
        
        function moglUpdate(o)
            
            global GL;
            newclut = o.newLUT;
            
            % Select the 2nd texture unit (unit 1) for setup:
            glActiveTexture(GL.TEXTURE1);
            % Bind our clut texture to it:
            glBindTexture(GL.TEXTURE_RECTANGLE_EXT, o.mogl.luttex);
            
            
            % Size check:
            if size(newclut,1)~=o.nRandels || size(newclut, 2)~=3
                % Invalid or missing clut:
                error('newclut of wrong size (must be o.nRandels rows by 3 columns) provided!');
            end
            
            % Range check:
            if ~isempty(find(newclut < 0)) || ~isempty(find(newclut > 255))
                % Clut values out of range:
                error('At least one value in newclut is not in required range 0 to (o.nRandels - 1)!');
            end
            
            % Cast to integer and update our 'clut' array with new clut:
            o.clut(1:3:end-2)= uint8(newclut(:, 1) + 0.5); %seems to me (Adam) that the 0.5 shouldn't be here. This makes it from 1 to 255. shouldn't it be 0 to 255?
            o.clut(2:3:end-1)= uint8(newclut(:, 2) + 0.5);
            o.clut(3:3:end-0)= uint8(newclut(:, 3) + 0.5);
            
            % Upload new clut:
            glTexSubImage2D(GL.TEXTURE_RECTANGLE_EXT, 0, 0, 0, o.nRandels, 1, GL.RGB, GL.UNSIGNED_BYTE, o.clut);
            
            
            % Switch back to texunit 0 - the primary one:
            glActiveTexture(GL.TEXTURE0);
            
            
            % New style: Needs Screen-MEX update to fix a bug in Screen before it can be used!
            Screen('DrawTexture', o.window, o.tex, [], [], 0, 0, [], [], o.mogl.remapshader);
            
        end
        function afterExperiment(o)
            
            % Disable CLUT blitter. This needs to be done before the call to
            %             % Screen('CloseAll')!
            %             moglClutBlit;
            
        end
        
    end
end