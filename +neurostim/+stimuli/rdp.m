classdef rdp < neurostim.stimulus
    % Class for drawing a random dot pattern in the PTB.
    % Code from nsLLDots2 and modified for MATLAB.
    %
    % Adjustable variables:
    %   size - dotsize (px)
    %   coordSystem - 0: polar
    %                 1: cartesian
    %   speed / direction - dot speed and direction (deg) (if using polar coordinates)
    %   xspeed / yspeed - dot speed in directions x and y (if using cartesian coordinates)
    %   nrDots - number of dots
    %   coherence - dot coherence (0-1)
    %   motionMode - 0: spiral
    %                1: linear
    %   noiseMode - 0: proportion
    %               1: distribution
    %   noiseDist - 0: gaussian
    %               1: uniform
    %   noiseWidth - width of gaussian/uniform noise.
    %   lifetime - lifetime of dots (in frames)
    %   maxRadius - maximum radius of aperture (px)
    %   position - center position of aperture (X,Y pixel coordinates)
    %   dwellTime - parameter for dwelling on frame; e.g. dwellTime = 2
    %       moves twice as fast.
    
    
    properties (Access=protected)
        x;
        y;
        dx;
        dy;
        dR;
        dphi;
        radius;
        phiOffset;
        framesLeft;
    end
    
    properties
        deleteMe = 10;
    end
    
    methods (Access = public)
        function o = rdp(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('size',5,'validate',@isnumeric);
            o.addProperty('maxRadius',100,'validate',@isnumeric);
            o.addProperty('speed',5,'validate',@isnumeric);
            o.addProperty('xspeed',0,'validate',@isnumeric);
            o.addProperty('yspeed',0,'validate',@isnumeric);
            o.addProperty('direction',0,'validate',@isnumeric);
            o.addProperty('nrDots',100,'validate',@isnumeric);
            o.addProperty('coherence',0.5,'validate',@(x)x<=1&&x>=0);
            o.addProperty('motionMode',1,'validate',@(x)x==0||x==1);      %Spiral, linear
            o.addProperty('lifetime',50,'validate',@isnumeric);
            o.addProperty('dwellTime',1,'validate',@isnumeric);
            o.addProperty('coordSystem',0,'validate',@(x)x==0||x==1);
            o.addProperty('noiseMode',0,'validate',@(x)x==0||x==1);       % coherence, distribution
            o.addProperty('noiseDist',0,'validate',@(x)x==0||x==1);       % gaussian, uniform
            o.addProperty('noiseWidth',50,'validate',@isnumeric);
            o.addProperty('truncateGauss',-1,'validate',@isnumeric);
        end
        
        
        function beforeTrial(o)
            
            % overrule one of the velocity vectors based on coord system
            if o.coordSystem == 1
                [o.direction, o.speed] = cart2pol(o.xspeed, o.yspeed);
            else
                [o.xspeed, o.yspeed] = pol2cart((o.direction.*pi./180), o.speed);
            end
            
            initialiseDots(o,true(o.nrDots,1));
            
            % initialise dots' lifetime
            if o.lifetime ~= Inf
                o.framesLeft = randi(o.lifetime,o.nrDots,1);
            else
                o.framesLeft = ones(o.nrDots,1).*Inf;
            end
        end
        
        
        function beforeFrame(o)
            Screen('DrawDots',o.window, [o.x o.y]', o.size, o.color);
        end
        
        
        function afterFrame(o)
            
            % reduce lifetime by 1
            if o.noiseMode ~= 1
                o.framesLeft = o.framesLeft - 1;
            end
            if o.coordSystem == 1
                [o.direction, o.speed] = cart2pol(o.xspeed, o.yspeed);
            else
                [o.xspeed, o.yspeed] = pol2cart((o.direction.*pi./180), o.speed);
            end
            moveDots(o);
            
            
        end
    end
    
    methods (Access=protected)
        % Methods only for personal use
        
        function [xnew, ynew] = rotateXY(o,xprev,yprev,arg)
            % rotates vectors xprev and yprev by angle arg and outputs new
            % values in xnew and ynew.
            
            % create a matrix with all rotation matrices in a column
            if max(size(xprev))==1
                R=[cos(arg) -sin(arg);sin(arg) cos(arg)];
                xynew=R*[xprev;yprev];
                xnew=xynew(1);
                ynew=xynew(2);
            else
                for a=1:max(size(xprev))
                    R=[cos(arg(a)) -sin(arg(a));sin(arg(a)) cos(arg(a))];
                    xynew=R*[xprev(a);yprev(a)];
                    xnew(a,1)=xynew(1);
                    ynew(a,1)=xynew(2);
                end
            end
        end
        
        
        function initialiseDots(o,pos)
            % initialises dots in the array positions given by logical
            % array pos.
            nnzpos=nnz(pos);
            o.framesLeft(pos,1) = o.lifetime;
            o.radius(pos,1) = sqrt(rand(nnzpos,1).*o.maxRadius.*o.maxRadius);
            randAngle = rand(o.nrDots,1).*360;
            tmp=ceil(o.coherence*o.nrDots);
            switch o.motionMode
                case 0 % spiral
                    
                    o.phiOffset(pos,1) = randAngle(pos);
                    
                    if tmp>=1 && any(pos(1:tmp))
                        o.dR(pos(1:tmp),1) = o.xspeed/o.cic.screen.frameRate;
                        o.dphi(pos(1:tmp),1) = o.xspeed/o.cic.screen.frameRate;
                    end
                    if o.coherence == 0 || (o.coherence ~= 1 && any(pos(tmp:end)))
                        index = find(pos)>=o.coherence*o.nrDots;
                        o.dR(index,1) = -o.xspeed/o.cic.screen.frameRate;
                        o.dphi(index,1)=-o.yspeed/o.cic.screen.frameRate;
                    end
                    
                    [o.x(pos,1), o.y(pos,1)] = o.setXY(pos,randAngle);
                    
                    
                case 1  % linear
                    [o.x(pos,1), o.y(pos,1)] = o.setXY(pos,randAngle);
                    
                    switch o.noiseMode
                        case 0 %proportion
                            
                            if (tmp)>=1 && any(pos(1:tmp))
                                o.dx(pos(1:tmp),1) = o.xspeed./o.cic.screen.frameRate;
                                o.dy(pos(1:tmp),1) = o.yspeed./o.cic.screen.frameRate;
                            end
                            
                            if o.coherence==1
                                return;
                            end
                            if o.coherence == 0 || any(pos(tmp:end))
                                index = find(pos)>=o.coherence*o.nrDots;
                                randAngle(index) = rand(nnz(index),1).*360;
                                o.dx(index,1) = cosd(randAngle(index)).*o.speed/o.cic.screen.frameRate;
                                o.dy(index,1) = sind(randAngle(index)).*o.speed/o.cic.screen.frameRate;
                            end
                            
                            
                        case 1 %distribution
                            switch o.noiseDist
                                case 0  %gaussian
                                    randAngle = o.noiseWidth.*randn(nnz(pos),1);
                                    if o.truncateGauss ~= -1
                                        a = abs(randAngle/o.noiseWidth)>o.truncateGauss;
                                        while max(a)
                                            randAngle(a) = o.noiseWidth.*randn(sum(a),1);
                                            a = abs(randAngle/o.noiseWidth)>o.truncateGauss;
                                        end
                                    end
                                case 1 %uniform
                                    randAngle = rand(nnz(pos),1).*o.noiseWidth - repmat(o.noiseWidth/2, nnz(pos),1);
                                otherwise
                                    error('Unknown noiseDist');
                            end
                            
                            randAngle = o.direction + randAngle;
                            [o.dx(pos,1), o.dy(pos,1)] = pol2cart(randAngle.*(pi./180),o.speed/o.cic.screen.frameRate);
                        otherwise
                            error('Unknown noiseMode');
                            
                    end
                otherwise
                    error('Unknown motionMode');
            end
        end
        
        function [x,y]=setXY(o,pos,randAngle)
            x=o.radius(pos).*cosd(randAngle(pos));
            y=o.radius(pos).*sind(randAngle(pos));
        end
        
        
        function moveDots(o)
            
            %warp - move dots outside aperture
            
            %Work with a local copy (faster than repeated "gets" on NS params)
            dwellTime = o.dwellTime;
            maxRadius = o.maxRadius;
            
            switch o.motionMode
                case 1 %linear

                    % calculates future position
                    futureX = o.x+dwellTime.*o.dx;
                    futureY = o.y+dwellTime.*o.dy;
                    futureRad = sqrt(futureX.^2 + futureY.^2);
                    tmp=futureRad>maxRadius;
                    if any(tmp)   % if any new dots are outside the max radius
                        % move dots
                        [dotDir,~] = cart2pol(o.dx(tmp),o.dy(tmp));
                        [xr, yr] = rotateXY(o,o.x(tmp),o.y(tmp),-dotDir);
                        chordLength = 2*sqrt(maxRadius^2 - yr.^2);
                        xr = xr - chordLength;
                        [o.x(tmp), o.y(tmp)] = rotateXY(o,xr,yr,dotDir);
                    end
                    
                case 0 %spiral
                    temp1 = o.dR>0 & (o.radius+dwellTime.*o.dR)>maxRadius;
                    temp2 = o.dR<0 & (o.radius+dwellTime.*o.dR)<0;
                    
                    if (any(temp1) || any(temp2))   % if any dots are outside the max radius or below 0
                        % position new dots randomly
                        nsMax = max(-1*o.dR(temp1 | temp2), 0);
                        nsMin = min(maxRadius, maxRadius - o.dR(temp1 | temp2));
                        o.radius(temp1 | temp2) = nsMax + (nsMin - nsMax).*rand(size(nsMax));
                    end
                    
            end
            
            % move dots
            if any(~o.framesLeft)
                initialiseDots(o,~o.framesLeft);
            end
            
            switch o.motionMode
                case 0 %spiral
                    o.phiOffset = o.phiOffset + o.dwellTime.*o.dphi;
                    o.radius = o.radius + dwellTime.*o.dR;
                    o.x = o.radius.*cosd(o.phiOffset);
                    o.y = o.radius.*sind(o.phiOffset);
                    
                case 1  %linear
                    o.x = o.x + dwellTime.*o.dx;
                    o.y = o.y + dwellTime.*o.dy;
            end
        end
        
        
        
    end
    
    
end