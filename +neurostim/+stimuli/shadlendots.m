classdef shadlendots < neurostim.stimulus
    % Class for drawing Shadlen dots in PTB.
    % Code taken from Shadlen's dotsX with initial variables from
    % createDotInfo.
    % Adjustable variables:
    %       Coherence - dot coherence (from 0-1)
    %       apertureXYD - aperture coordinates (X,Y) and D (diameter) in
    %             visual degrees
    %       direction (in degrees) - 0 is right.
    %       dotSize - size of dots in pixels
    %       monitorWidth - viewing width of monitor (in cm)
    %             touchscreen is 34, laptop is 32, viewsonic is 38
    %       viewDist - distance from the center of the subject's eyes 
    %             to the monitor (in cm)
    %       maxDotsPerFrame - depends on graphics card
    %       speed - dot speed (10th deg/sec)
    %
    % NB: does this need to be able to take a random number seed for input?
    

    properties
        % properties for calculations (variable names from Shadlen dots
        % (dotsX).
        this_s;
        Lthis;
        loopi;
        Ls;
        ss;
        ndots;
        d_ppd;
        center;
        dxdymultiplier;
    end
    
    
    methods (Access = public)
        function o = shadlendots(name)
            o = o@neurostim.stimulus(name);
            o.listenToEvent({'BEFOREFRAME','AFTERFRAME', 'BEFOREEXPERIMENT'});
            
            % set dot properties (for user adjustment)
            o.addProperty('coherence',0.75);
            o.addProperty('apertureXYD', [0 50 50]); % Aperture in XYD
            o.addProperty('direction',0);
            o.addProperty('dotSize',2);
            o.addProperty('monitorWidth',34);
            o.addProperty('viewDist',50);
            o.addProperty('maxDotsPerFrame',150);
            o.addProperty('speed',50);
            
        end
        
        
        function beforeTrial(o,c,evt)
            
            createinitialdots(o,c);
            
        end
        
        
        function beforeFrame(o,c,evt)
            
            % call calculation function
            dots2Display = calculatedots(o);
            
            % draw dots on Screen
            Screen('DrawDots',c.window,dots2Display,o.dotSize,o.color,o.center(1,1:2));
            
        end

        
        function afterFrame(o,c,evt)
            
            o.ss(o.Lthis, :) = o.this_s;
            
        end

        
        function createinitialdots(o,c)
            % sets all the initial variables needed.
            
            % random number seed
            rseed = sum(100*clock);
            rng(rseed,'v5uniform');
            
            % set initial variables
            o.loopi = 1;
            apD = o.apertureXYD(:,3);
            screenppd = pi * c.position(3) / atan(o.monitorWidth/o.viewDist/2) / 360;            
            
            
            % get monitor refresh rate
            frameDur = Screen('GetFlipInterval',c.window);
            monRefresh = 1 / frameDur;
            
            % Change x,y coordinates to pixels (y is inverted - pos on bottom, neg. on top)
            o.center = [(c.position(3)/2 + o.apertureXYD(:,1)/10*screenppd) (c.position(4)/2 - ...
            o.apertureXYD(:,2)/10*screenppd)]; % where you want the center of the aperture
            o.center(:,3) = o.apertureXYD(:,3)/2/10*screenppd; % add diameter
            o.d_ppd = floor(apD/10 * screenppd);	% size of aperture in pixels
            
            % ndots is the number of dots shown per video frame. Dots will be placed in a 
            % square of the size of aperture.
            o.ndots = min(o.maxDotsPerFrame, ceil(16.7 * apD .* apD * 0.01 / monRefresh));
            
            o.dxdymultiplier = (3/monRefresh);
  
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
            dxdy = repmat((o.speed/10) * (10/o.apertureXYD(:,3)) * o.dxdymultiplier *...
                [cos(pi*o.direction/180.0), -sin(pi*o.direction/180.0)], o.ndots,1);   
            
            % Offset the selected dots
            o.this_s(L,:) = bsxfun(@plus,o.this_s(L,:),dxdy(L,:));

            if sum(~L) > 0
                o.this_s(~L,:) = rand(sum(~L),2);	% get new random locations for the rest
            end

            % Check to see if any positions are greater than 1 or less than 0 which 
            % is out of the square aperture, and replace with a dot along one of the
            % edges opposite from the direction of motion.
            N = sum((o.this_s > 1 | o.this_s < 0),2) ~= 0;

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
            this_x = floor(o.d_ppd * o.this_s);	% pix/ApUnit

            % It assumes that 0 is at the top left, but we want it to be in the 
            % center, so shift the dots up and left, which means adding half of the 
            % aperture size to both the x and y directions.
            dot_show = (this_x - o.d_ppd/2)';

            outCircle = sqrt(dot_show(1,:).^2 + dot_show(2,:).^2) + o.dotSize/2 > o.center(1,3);        
            dots2Display = dot_show;
            dots2Display(:,outCircle) = NaN;
        end
        
    end
    
end