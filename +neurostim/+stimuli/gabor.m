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
    % 	mask - one of 'GAUSS','CIRCLE','ANNULUS', 'GAUSS3' (truncated at 3
    % 	sigma)
    %   phaseSpeed - the drift of the grating in degrees per frame
    %   color - mean color in space and time (default: cic.screen.color.background)
    %
    % Flicker settings (this moduldates the *amplitude* of the sine wave in
    % the gabor)
    %
    % flickerMode = 'none','sine','square',sineconctrast, squarecontrast.
    %                   In the sine/square modes pixels change polarity
    %                   (~contrast*sin(t)) in the sinecontrast/sinesquare
    %                   modes, the pixels keep their polarity and only the
    %                   Michelson contrasts of the sine changes
    %                   (~contrast(1+sin(t)))
    % flickerFrequency = in Hz
    % flickerPhaseOffset = starting  phase of the flicker modulation.
    %
    %
    %  This stimulus can also draw the sum of multiple gabors. You can
    %  choose the number and whether to randomize the phase. 
    % multiGaborsN  = Must be 10 or less. 
    % multiGaborsPhaseRand = Boolean to use random phase for each of the
    % N.(Default is false, which corresponds to zero phase offset between
    % the different components).
    % multiGaborsOriRand =  Boolean to use random orientaiton for each of
    % the N. Default is false, which corresponds to linearly spaced oris
    % between 0 and 180.
    
    % NP - 2021-01-19 - changed handling of phase (input variable) and
    % spatialPhase (private variable). `phase` now controls starting phase
    % of grating 
    
    properties (Constant)
        maskTypes = {'GAUSS','CIRCLE','ANNULUS','GAUSS3','GAUSS2D'};
        flickerTypes = {'NONE','SINE','SQUARE','SINECONTRAST','SQUARECONTRAST'};
    end
    properties (Access=private)
        texture;
        shader;
        textureRect;
        flickerPhase=0; % frame-by-frame , current phase: not logged explicitly
        spatialPhase=0; % frame-by-frame , current phase: not logged explicitly
    end
   
    
    methods (Static)
        function v = tfToPhaseSpeed(tf,framerate)
            % Convert temporal frequency in Hz to appropriate phase speed.
            v = 2*pi*framerate*tf;
        end
        function v = phaseSpeedToTf(sp)
            v = sp/(2*pi*framerate);
        end        
    end
    
    methods
        function o =gabor(c,name)
            o = o@neurostim.stimulus(c,name);
            
            o.color = o.cic.screen.color.background;
            
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
            
            %% Flicker 
            o.addProperty('flickerMode','NONE','validate',@(x)(ismember(neurostim.stimuli.gabor.flickerTypes,upper(x))));            
            o.addProperty('flickerFrequency',0,'validate',@isnumeric);
            o.addProperty('flickerPhaseOffset',0,'validate',@isnumeric);
            
            %% Special use
            % Set o.multiGaborsN to n>1 to create a sum of Gabors masking stimulus
            % with little if any orientation contents. o.multiGaborsN =8 will
            % superimpose 8 gabors with random phase, and equally spaced
            % orientations. 
            o.addProperty('multiGaborsN',0,'validate',@isnumeric);
            o.addProperty('multiGaborsPhaseRand',false,'validate',@islogical);
            o.addProperty('multiGaborsOriRand',false,'validate',@islogical);         
            o.addProperty('multiGaborsPhaseOffset',zeros(1,10)); % Used internally to randomize phase for the ori mask
            o.addProperty('multiGaborsOriOffset',zeros(1,10)); % Used internally to determine the orientation of the mask components
            
        end
        
        function beforeExperiment(o)
            % Create the procedural texture
            try
                createProcGabor(o);
            catch me
                error('Create Procedural Gabor Failed (%s)',me.message);
            end
        end
        
        
        function beforeTrial(o)
            
            o.spatialPhase = o.phase; % user-defined initial phase

            if o.multiGaborsN~=0              
                if o.multiGaborsN>10
                    error('Max 10 gabors in a multi gabor');
                end
                if o.multiGaborsPhaseRand 
                    o.multiGaborsPhaseOffset = 360*rand(1,o.multiGaborsN); % 
                else
                    o.multiGaborsPhaseOffset = zeros(1,o.multiGaborsN);    
                end
                if o.multiGaborsOriRand
                    o.multiGaborsOriOffset= 180*rand(1,o.multiGaborsN); % Random orientations for n<0
                else
                    o.multiGaborsOriOffset= linspace(0,180,o.multiGaborsN);
                end                
            end
            
            % Pass information that does not change during the trial to the
            % shader.
            glUseProgram(o.shader);
            glUniform1i(glGetUniformLocation(o.shader, 'mask'),find(ismember(o.maskTypes,upper(o.mask))));
            glUniform1i(glGetUniformLocation(o.shader, 'flickerMode'),find(ismember(o.flickerTypes,upper(o.flickerMode))));           
            glUniform1i(glGetUniformLocation(o.shader, 'multiGaborsN'),max(1,o.multiGaborsN)); % At least 1 so that a single Gabor is drawn
            glUniform1fv(glGetUniformLocation(o.shader, 'multiGaborsPhaseOffset'),numel(o.multiGaborsPhaseOffset),o.multiGaborsPhaseOffset);
            glUniform1fv(glGetUniformLocation(o.shader, 'multiGaborsOriOffset'),numel(o.multiGaborsOriOffset),o.multiGaborsOriOffset);
            glUseProgram(0);                        
            
        end
        
        function beforeFrame(o)
            % Draw the texture with the current parameter settings
            %Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] [,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);
            sourceRect= [];filterMode =[]; textureShader =[]; globalAlpha =[]; specialFlags = kPsychDontDoRotation; % Keep defaults
            
            %aux parameters need to have 4xn with n<=8 size
            oSigma  = +o.sigma;
            if numel(oSigma)==1
                oSigma =[oSigma 0];
            end
            oColor = +o.color;
            if numel(oColor) ==1
                oColor = [oColor 0 0];% Luminance only spec (probably M16 mode)
            end
            
                                            
            % Draw the Gabor using the GLSL shader            
            aux = [+o.spatialPhase, +o.frequency, oSigma; +o.contrast +o.flickerPhase 0 0]';    
            Screen('DrawTexture', o.window, o.texture, sourceRect, o.textureRect, +o.orientation, filterMode, globalAlpha, oColor , textureShader,specialFlags, aux);            
       
        end
        
        function afterFrame(o)
            % Change any or all of the parameters.
            if o.phaseSpeed ~=0
                o.spatialPhase = o.spatialPhase + o.phaseSpeed; % increment phase
            end            
            if  o.flickerFrequency~=0
                o.flickerPhase = mod(o.flickerPhaseOffset + (o.time -0)*2*pi*o.flickerFrequency/1000,2*pi);
            end
        end
    end
    
    methods (Access=private)
        
        function createProcGabor(o)
            % Copied from PTB
            debuglevel = 0;
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
            colorModes = {'RGB','XYL','LUM','LINLUT'}; % 1,2,3,4
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
            o.textureRect= [-o.width -o.height o.width o.height]./2;
            
        end
    end
    
end