classdef gabor < neurostim.stimulus
    % Wrapper class for the (fast) procedural Gabor textures in the PTB.
    % 
    % Adjustable variables (from CreateProcGabor.m):
    % 	orientation - orientation angle in degrees (0-180)
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
            
            
            %% Base Teture parameters, see CreateProceduralGabor.m for details
            % No need to change unless you want to save texture memory and draw
            % only small Gabors.
            o.addProperty('width',10,'validate',@isnumeric);
            o.addProperty('height',10,'validate',@isnumeric);
            
            %%  Gabor parameters
            o.addProperty('orientation',0,'validate',@isnumeric);
            o.addProperty('contrast',1,'validate',@isnumeric);
            o.addProperty('phase',0,'validate',@isnumeric);
            o.addProperty('frequency',0.05,'validate',@isnumeric);
            o.addProperty('sigma',1,'validate',@isnumeric); % [Inner Outer] or  [Outer]
            o.addProperty('mask','Gauss','validate',@(x)(ismember(neurostim.stimuli.gabor.maskTypes,upper(x))));
            
            %% Motion
            o.addProperty('phaseSpeed',0);
            
            %% Special use
            % Set oriMask to n>1 to create a sum of Gabors masking stimulus
            % with little if any orientation contents. oriMask =8 will
            % superimpose 8 gabors with random phase, and equally spaced
            % orientations. oriMask=-8 will randomize the orientations.
            o.addProperty('oriMask',0,'validate',@isnumeric); 
            o.addProperty('phaseOffset',0); % Used internally to randomize phase for the ori mask
            o.addProperty('oriOffset',0); % Used internally to determine the orientation of the mask components
            
        end
        
        function beforeExperiment(o)
            % Create the procedural texture
            try
                createProcGabor(o);
            catch
                error('Create Procedural Gabor Failed');
            end
        end
        
        
        function beforeTrial(o)
            glUseProgram(o.shader);
            glUniform1i(glGetUniformLocation(o.shader, 'mask'),find(ismember(o.maskTypes,upper(o.mask))));
            glUseProgram(0);
            
            if o.oriMask~=0
                n = abs(o.oriMask);                
                o.phaseOffset = 360*rand(1,n); % Always randomized ina n oriMask
                if o.oriMask<0
                    o.oriOffset= 180*rand(1,n); % Random orientations for n<0
                else
                    o.oriOffset= linspace(0,180,n);
                end
            end
            
            
            
        end
        
        function beforeFrame(o)
            % Draw the texture with the current parameter settings
            %Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] [,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);
            sourceRect= [];filterMode =[]; textureShader =[]; globalAlpha =[]; specialFlags = 2; % = kPsychDontDoRotation; % Keep defaults
            
            %aux parameters need to have 4xn with n<=8 size
            oSigma  = o.sigma;
            if numel(oSigma)==1
                oSigma =[oSigma 0];
            end
            oColor = o.color;
            if numel(oColor) ==1
                oColor = [oColor 0 0];% Luminance only spec (probably M16 mode)
            end
            
                       
            if o.oriMask~=0
                % Adjust alpha to overlay Gabors in the oriMask
                n =  abs(o.oriMask);
                o.alpha = 1/n;                
            else
                n=1;
            end
            
            % Draw the Gabor using the GLSL shader
            for i=1:n
                aux = [(o.phase+o.phaseOffset(i)), o.frequency, oSigma; o.contrast 0 0 0]';    
                Screen('DrawTexture', o.window, o.texture, sourceRect, o.textureRect, o.orientation+o.oriOffset(i), filterMode, globalAlpha, [oColor, o.alpha] , textureShader,specialFlags, aux);
            end

        end
        
        function afterFrame(o)
            % Change any or all of the parameters.
            oPhaseSpeed  = o.phaseSpeed;
            if oPhaseSpeed ~=0
                o.phase = o.phase + oPhaseSpeed;
            end
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
            colorModes = {'RGB','XYL','LUM'}; % 1,2,3
            colorMode = find(ismember(o.cic.screen.colorMode,colorModes));
            if isempty(colorMode)
                error(['Gabor does not know how to deal with colormode ' o.cic.screen.colorMode]);
            end
            glUniform1i(glGetUniformLocation(o.shader , 'colorMode'), colorMode);
            glUniform1i(glGetUniformLocation(o.shader, 'mask'),find(ismember(o.maskTypes,upper(o.mask))));
            % Setup done:
            glUseProgram(0);
            
            % Create a purely virtual procedural texture of size width x height virtual pixels.            % Attach the Shader to it to define its appearance:
            o.texture = Screen('SetOpenGLTexture', o.window, [], 0, GL.TEXTURE_RECTANGLE_EXT, o.width, o.height, 1, o.shader);
            % Query and return its bounding rectangle:
            o.textureRect = Screen('Rect', o.texture);
            o.textureRect=CenterRectOnPoint(o.textureRect,0,0);
            
        end
    end
    
end