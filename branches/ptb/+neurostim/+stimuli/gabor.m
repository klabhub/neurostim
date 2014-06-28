classdef gabor < neurostim.stimulus
    % Wrapper class for the (fast) procedural Gabor textures in the PTB.
    %
    properties
        texture;
        textureRect;
        
    end
    
    methods
        function o =gabor(name)
            o = o@neurostim.stimulus(name);
            o.listenToEvent({'BEFOREFRAME','BEFOREEXPERIMENT','AFTERFRAME'});
            
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
        function beforeFrame(o,c,evt)
                    % Draw the texture with the current parameter settings
                    %Screen('DrawTexture', windowPointer, texturePointer [,sourceRect] [,destinationRect] [,rotationAngle] [, filterMode] [, globalAlpha] [, modulateColor] [, textureShader] [, specialFlags] [, auxParameters]);
                    sourceRect= [];filterMode =[]; textureShader =[]; globalAlpha =[]; specialFlags = 2; % = kPsychDontDoRotation; % Keep defaults
                    destinationRect=CenterRectOnPoint(o.textureRect, o.X, o.Y);                    
                    Screen('DrawTexture', c.window, o.texture, sourceRect, destinationRect, o.orientation, filterMode, globalAlpha, [o.color, o.luminance 0] , textureShader,specialFlags, [o.phase, o.frequency, o.sigma, o.peakLuminance]);
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
            % Load symmetric support shader 
            p = fileparts(mfilename('fullpath'));
            gaborShader = LoadGLSLProgramFromFiles(fullfile(p,'GLSLShaders','gabor'), debuglevel);
            % Setup shader:
            glUseProgram(gaborShader);
            % Set the 'Center' parameter to the center position of the gabor image 
            %patch [tw/2, th/2]:
            glUniform2f(glGetUniformLocation(gaborShader, 'center'), o.xPixels/2, o.yPixels/2);                        
            glUniform1i(glGetUniformLocation(gaborShader, 'rgbColor'), strcmpi(o.cic.colorMode,'RGB'));                        
            % Setup done:
            glUseProgram(0);
            % Create a purely virtual procedural texture 'gaborid' of size width x height virtual pixels.
            % Attach the GaborShader to it to define its appearance:
            o.texture = Screen('SetOpenGLTexture', o.cic.window, [], 0, GL.TEXTURE_RECTANGLE_EXT, o.xPixels, o.yPixels, 1, gaborShader);
            % Query and return its bounding rectangle:
            o.textureRect = Screen('Rect', o.texture);    
        end
    end
    
end