classdef gabor < neurostim.stimulus
    % Wrapper class for the (fast) procedural Gabor textures in the PTB.
    % 
    % Adjustable variables (from CreateProcGabor.m):
    % 	orientation - orientation angle in degrees (0-360)
    % 	contrast - amplitude of gabor in intensity units
    % 	phase - the phase of the gabor's sine grating in degrees.
    % 	frequency - gabor's spatial frequency in cycles per pixel
    % 	sigma - spatial constant of gaussian hull function of gabor
    % 	width, height - maximum size of the gabor.
    % 	mask - one of 'GAUSS','CIRCLE','ANNULUS'
    properties (Constant)
        maskTypes = {'GAUSS','CIRCLE','ANNULUS'};
    end
    properties (Access=private)
        texture;
        shader;
        textureRect;
    end
    
    methods
        function o =gabor(c,name)
            o = o@neurostim.stimulus(c,name);
            o.listenToEvent({'BEFOREFRAME','BEFOREEXPERIMENT','AFTERFRAME','BEFORETRIAL'});
            
            %% Base Teture parameters, see CreateProceduralGabor.m for details
            % No need to change unless you want to save texture memory and draw
            % only small Gabors.
            o.addProperty('width',10,'',@isnumeric);
            o.addProperty('height',10,'',@isnumeric);
            
            %%  Gabor parameters
            o.addProperty('orientation',0,[],@isnumeric);
            o.addProperty('contrast',1,[],@isnumeric);
            o.addProperty('phase',0,[],@isnumeric);
            o.addProperty('frequency',0.05,[],@isnumeric);
            o.addProperty('sigma',1,[],@isnumeric); % [Inner Outer] or  [Outer]
            o.addProperty('mask','Gauss','',@(x)(ismember(neurostim.stimuli.gabor.maskTypes,upper(x))));
            
            %% Motion
            o.addProperty('phaseSpeed',0);
            
        end
        
        function beforeExperiment(o,c,evt)
            % Create the procedural texture
            try
                createProcGabor(o);
            catch
                error('Create Procedural Gabor Failed');
            end
        end
        
        
        function beforeTrial(o,c,evt)
            glUseProgram(o.shader);
            glUniform1i(glGetUniformLocation(o.shader, 'mask'),find(ismember(o.maskTypes,upper(o.mask))));
            glUseProgram(0);
        end
        
        function beforeFrame(o,c,evt)
            % Draw the texture with the current parameter settings
            %Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] [,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);
            sourceRect= [];filterMode =[]; textureShader =[]; globalAlpha =[]; specialFlags = 2; % = kPsychDontDoRotation; % Keep defaults
            
            %aux parameters need to have 4xn with n<=8 size
            if numel(o.sigma)==1
                pad = 0;
            else
                pad = [];
            end
            aux = [o.phase, o.frequency, o.sigma, pad; o.contrast 0 0 0]';

            Screen('DrawTexture', c.window, o.texture, sourceRect, o.textureRect, 90+o.orientation, filterMode, globalAlpha, [o.color, o.alpha] , textureShader,specialFlags, aux);

        end
        
        function afterFrame(o,c,evt)
            % Change any or all of the parameters.
            o.phase = o.phase + o.phaseSpeed;
        end
        
    end
    
    methods (Access=private)
        
        function createProcGabor(o)
            % Copied from PTB
            debuglevel = 1;
            % Global GL struct: Will be initialized in the LoadGLSLProgramFromFiles
            global GL;
            % Make sure we have support for shaders, abort otherwise:
            AssertGLSL;
            % Load shader
            p = fileparts(mfilename('fullpath'));
            o.shader = LoadGLSLProgramFromFiles(fullfile(p,'GLSLShaders','gabor'), debuglevel);
            % Setup shader: variables set here cannot change during the
            % experiment.
            glUseProgram(o.shader);
            glUniform2f(glGetUniformLocation(o.shader , 'size'), o.width, o.height);
            glUniform1i(glGetUniformLocation(o.shader , 'rgbColor'), strcmpi(o.cic.screen.colorMode,'RGB'));
            glUniform1i(glGetUniformLocation(o.shader, 'mask'),find(ismember(o.maskTypes,upper(o.mask))));
            % Setup done:
            glUseProgram(0);
            
            % Create a purely virqqtual procedural texture of size width x height virtual pixels.            % Attach the Shader to it to define its appearance:
            o.texture = Screen('SetOpenGLTexture', o.cic.window, [], 0, GL.TEXTURE_RECTANGLE_EXT, o.width, o.height, 1, o.shader);
            % Query and return its bounding rectangle:
            o.textureRect = Screen('Rect', o.texture);
            o.textureRect=CenterRectOnPoint(o.textureRect,0,0);
            
        end
    end
    
end