classdef shadlendots < neurostim.stimulus
    % Class for drawing Shadlen dots in PTB.
    % Code taken from Shadlen's dotsX with initial variables from
    % createDotInfo.
    % Adjustable variables:
    %       coherence - dot coherence (from 0-1)
    %       apertureD - aperture diameter in set units.
    %       direction (in degrees) - 0 is right.
    %       dotSize - size of dots in pixels
    %       maxDotsPerFrame - depends on graphics card
    %       speed - dot speed 
    %

    properties
        % properties for calculations (variable names from Shadlen dots
        % (dotsX).
        this_s;
        Lthis;
        loopi;
        Ls;
        ss;
        ndots;
        center;
        dxdymultiplier;
        dots2Display;
    end
    
    
    methods (Access = public)
        function o = shadlendots(name)
            o = o@neurostim.stimulus(name);
            o.listenToEvent({'BEFOREFRAME','AFTERFRAME'});
            
            % set dot properties (for user adjustment)
            o.addProperty('coherence',0.75,'',@(x)x<=1&&x>=0);
            o.addProperty('apertureD', 50,'',@isnumeric); % Diameter of the aperture
            o.addProperty('direction',0,'',@isnumeric);
            o.addProperty('dotSize',2,'',@isnumeric);
            o.addProperty('maxDotsPerFrame',150,'',@isnumeric);
            o.addProperty('speed',10,'',@isnumeric);
            
        end
        
        
        function beforeTrial(o,c,evt)
            
            % create all dots
            createinitialdots(o,c);
            
            % call calculation function
            o.dots2Display = calculatedots(o);
            
        end
        
        
        function beforeFrame(o,c,evt)
            % draw dots on Screen
            Screen('DrawDots',c.window,o.dots2Display,o.dotSize,o.color);
            
        end

        
        function afterFrame(o,c,evt)
            
            o.ss(o.Lthis, :) = o.this_s;
            
            % calculate dots' new positions
            o.dots2Display = calculatedots(o);
        end

        
        function createinitialdots(o,c)
            % sets all the initial variables needed.
            
            % set initial variables
            o.loopi = 1;
            apD = o.apertureD;
            
            % Change x,y coordinates to pixels (y is inverted - pos on bottom, neg. on top)
            o.center = [0 0];% where you want the center of the aperture
            o.center(:,3) = apD; % add diameter
            
            % ndots is the number of dots shown per video frame. Dots will be placed in a 
            % square of the size of aperture.
            o.ndots = min(o.maxDotsPerFrame, ceil(16.7 * apD .* apD * c.screen.pixels(3)/c.screen.physical(1) * 0.01 / c.screen.frameRate));
            
            o.dxdymultiplier = (3/c.screen.frameRate);
  
            o.ss = rand(o.ndots*3, 2); % array of dot positions raw [x,y]

            % Divide dots into three sets
            o.Ls = cumsum(ones(o.ndots,3)) + repmat([0 o.ndots o.ndots*2], ... 
                o.ndots, 1);
        end
        
        
        function dots2Display = calculatedots(o)
            % calculates all the dot positions for display.
            
            % Lthis has the dot positions from 3 frames ago, which is what is then
            o.Lthis = o.Ls(:,o.loopi);

            % Moved in the current loop. This is a matrix of random numbers - starting 
            % positions of dots not moving coherently.
             o.this_s = o.ss(o.Lthis,:);
            % Update the loop pointer
            o.loopi = o.loopi+1;

            if o.loopi == 4,
                o.loopi = 1;
            end

            % Compute new locations, how many dots move coherently
            L = rand(o.ndots,1) < o.coherence;
            dxdy = repmat((o.speed/10).* (10/o.apertureD).* o.dxdymultiplier.*...
                [cos(pi.*o.direction/180.0), -sin(pi.*o.direction/180.0)], o.ndots,1);   
            
            % Offset the selected dots
            o.this_s(L,:) = bsxfun(@plus,o.this_s(L,:),dxdy(L,:));

            if sum(~L) > 0
                o.this_s(~L,:) = rand(sum(~L),2);	% get new random locations for the rest
            end

            % Check to see if any positions are greater than 1 or less than 0 which 
            % is out of the square aperture, and replace with a dot along one of the
            % edges opposite from the direction of motion.
            N = sum((abs(o.this_s) > 1 | abs(o.this_s) < 0),2) ~= 0;

            if sum(N) > 0
                xdir = sin(pi*o.direction/180.0);
                ydir = cos(pi*o.direction/180.0);
                % Flip a weighted coin to see which edge to put the replaced dots
                if rand < abs(xdir)/(abs(xdir) + abs(ydir))
                    o.this_s(N,:) = [rand(sum(N),1),(xdir > 0)*ones(sum(N),1)];
                else
                    o.this_s(N,:) = [(ydir < 0)*ones(sum(N),1),rand(sum(N),1)];
                end
            end

            % Convert for plot
            this_x = o.apertureD*o.this_s;	% pix/ApUnit

            % It assumes that 0 is at the top left, but we want it to be in the 
            % center, so shift the dots up and left, which means adding half of the 
            % aperture size to both the x and y directions.
            dot_show = (this_x - o.apertureD/2)';

            outCircle = sqrt(dot_show(1,:).^2 + dot_show(2,:).^2) + o.dotSize/2 > (o.center(1,3)/2);        
            dots2Display = dot_show;
            dots2Display(:,outCircle) = NaN;
        end
        
    end
    
end