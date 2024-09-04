classdef convPoly < neurostim.stimulus
    % Draws an equilateral convex polygon with variable sides.
    % Equilateral convex polygon (e.g. triangle, square, pentagon, hexagon
    % etc.). Can also create a circle if "nSides" is set to a large number.
    % Alternatively, can supply a set of arbitrary vertices to pass to
    % PTB's FillPoly/FramePoly
    %
    % Adjustable variables:
    %   radius - in physical size.
    %   nSides - number of sides.
    %   filled - true or false.
    %   linewidth - only for unfilled polygon, in pixels.
    %
    % The 'color' can be modulated sinusoidally using the following
    % parameters:  color =  o.color*(1+amplitude*sind(phase+360*time*frequency/1000)
    %  frequency = sinusoidal flicker frequency in Hz  [0].
    %  phase - phase of the flicker in degrees. [0]
    % amplitude - amplitude of the flicker.  [Default is 0: no flicker]
    % 
    % Calculating the new color from the paramets on each frame is a time
    % consuming operation (reading the parameters mainly). So if you know
    % that the parameters do not change with in a trial, you can pre-compute the
    % sinusoid before the trial by setting preCalc to true. [Default is
    % false]
    %
    properties
        colorPerFrame;
        nrFramesPreCalc;
    end
    
    methods (Access = public)
        function o = convPoly(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('radius',3,'validate',@isnumeric);
            o.addProperty('nSides',5,'validate',@isnumeric);
            o.addProperty('filled',true,'validate',@islogical);
            o.addProperty('linewidth',10,'validate',@isnumeric); %Used only for unfilled polygon.
            o.addProperty('vx',[],'validate',@isnumeric);        %If specified, these overrule the radius,nSides etc.
            o.addProperty('vy',[],'validate',@isnumeric);
            
            %Properties for flickering the stimulus
            o.addProperty('flickerMode',"NONE"); %"NONE", "MULT" (amplitude is used as a contrast :o.color*(1+amplitude),"ADD" (amplitude is used as o.color + amplitude)
            o.addProperty('frequency',0,'validate',@isnumeric); % Hz
            o.addProperty('phase',0,'validate',@isnumeric); % degrees
            o.addProperty('amplitude',0,'validate',@isnumeric); %o.color is the mean,
            o.addProperty('flashFrames',0,'validate',@isnumeric);
            o.addProperty('preCalc',false);
        end
        
        function beforeTrial(o)
            if o.preCalc  
                if o.flickerMode =="NONE" || o.frequency==0
                    o.nrFramesPreCalc =1;
                else
                    o.nrFramesPreCalc=  round(o.cic.screen.frameRate/o.frequency);
                    if abs(o.nrFramesPreCalc -o.cic.screen.frameRate/o.frequency)/o.nrFramesPreCalc >0.05
                        writeToFeed(o,sprintf('ConvPoly: flicker frequency %f does not quite fit...rounding artefacts?',o.frequency));
                    end
                end
                 t = repmat((0:(o.nrFramesPreCalc-1))'/o.cic.screen.frameRate,[1 size(o.color,2)]);     
                if o.flashFrames>0
                    flash = (t<=o.flashFrames/o.cic.screen.frameRate);
                else
                    flash =1;
                end
                o.colorPerFrame =  repmat(o.color,[size(t,1) 1]); % Background
                if o.flickerMode =="MULT"
                    o.colorPerFrame =  o.colorPerFrame.* (1+flash*o.amplitude.*sind(o.phase + 360*t*o.frequency));                                
                elseif o.flickerMode =="ADD"
                    o.colorPerFrame =   o.colorPerFrame + (flash*o.amplitude.*sind(o.phase + 360*t*o.frequency));                                
                elseif o.flickerMode =="NONE" 
                    % Nothing to do
                else
                    error("Unknown flicker mode %s\n",o.flickerMode)
                end
            end
        end
        
        
        function beforeFrame(o)
            if isempty(o.vx) || isempty(o.vy) 
                % Compute vertices
                th = linspace(0,2*pi,o.nSides+1);
                [vx,vy] = pol2cart(th,o.radius);
            else
                % Use supplied verticies
                vx = o.vx;
                vy = o.vy;
            end
            
            if o.flickerMode ~="NONE"
                % Use sinusoidal flicker
                if o.preCalc
                    ix = mod(o.frame-1,o.nrFramesPreCalc)+1;
                    thisColor = o.colorPerFrame(ix,:);
                else
                    if o.flashFrames>0
                        flash = (o.frame <=o.flashFrames);
                    else
                        flash =1;
                    end
                    if o.flickerMode =="MULT"
                        thisColor  = o.color * (1+flash*o.amplitude*sind(o.phase + 360*o.time*(o.frequency/1000)));                    
                    elseif o.flickerMode == "ADD"
                        thisColor  = o.color +flash*o.amplitude*sind(o.phase + 360*o.time*(o.frequency/1000));                    
                    else
                         error("Unknown flicker mode %s\n",o.flickerMode);
                    end
                end
            else
                thisColor = o.color;
            end
            
            %Draw
            if o.filled
                Screen('FillPoly',o.window, thisColor,[vx(:),vy(:)],1);
            else
                Screen('FramePoly',o.window, thisColor,[vx(:),vy(:)],o.linewidth);
            end
        end
    end
end