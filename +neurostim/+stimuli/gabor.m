classdef gabor < neurostim.stimulus
    % Wrapper class for the (fast) procedural Gabor textures in the PTB.
    %
    properties (Constant)
        maskTypes = {'GAUSS','CIRCLE'};
    end
    properties
        texture;
        shader;
        textureRect;
    end
    
    methods
        function o =gabor(name)
            o = o@neurostim.stimulus(name);
            o.listenToEvent({'BEFOREFRAME','BEFOREEXPERIMENT','AFTERFRAME','BEFORETRIAL'});
            
            %% Base Teture parameters, see CreateProceduralGabor.m for details
            % No need to change unless you want to save texture memory and draw
            % only small Gabors.
            o.addProperty('xPixels',128);
            o.addProperty('yPixels',128);
            
            %%  Gabor parameters
            o.addProperty('orientation',0);
            o.addProperty('peakLuminance',70);
            o.addProperty('phase',0);
            o.addProperty('frequency',0.05);
            o.addProperty('sigma',50);
            o.addProperty('mask','Gauss');%,@(x)(ismember(gabor.maskTypes,upper(x))));            
            
            %% Motion
            o.addProperty('phaseSpeed',0);
            
        end
        
        function beforeExperiment(o,c,evt)
                    % Create the procedural texture
                    try
                        createProcGabor(o);                    
                    catch
                    	keyboard;
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
                    alpha= 0;  %Not used
                    destinationRect=CenterRectOnPoint(o.textureRect, o.X, o.Y);                    
                    Screen('DrawTexture', c.window, o.texture, sourceRect, destinationRect, o.orientation, filterMode, globalAlpha, [o.color, o.luminance alpha] , textureShader,specialFlags, [o.phase, o.frequency, o.sigma, o.peakLuminance]);
        end
        
        function afterFrame(o,c,evt)
                    % Change any or all of the parameters.
                    o.phase = o.phase + o.phaseSpeed;                         
        end
        
    end
    
    methods 
        
        function createProcGabor(o)
            % Shamelessly copied from PTB 
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
            glUniform2f(glGetUniformLocation(o.shader , 'size'), o.xPixels, o.yPixels);                        
            glUniform1i(glGetUniformLocation(o.shader , 'rgbColor'), strcmpi(o.cic.colorMode,'RGB'));                        
            glUniform1i(glGetUniformLocation(o.shader, 'mask'),find(ismember(o.maskTypes,upper(o.mask))));                        
            % Setup done:
            glUseProgram(0);
            
            % Create a purely virtual procedural texture of size width x height virtual pixels.            % Attach the Shader to it to define its appearance:
            o.texture = Screen('SetOpenGLTexture', o.cic.window, [], 0, GL.TEXTURE_RECTANGLE_EXT, o.xPixels, o.yPixels, 1, o.shader);
            % Query and return its bounding rectangle:
            o.textureRect = Screen('Rect', o.texture);    
        end
    end
    
end