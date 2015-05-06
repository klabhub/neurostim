classdef rdp < neurostim.stimulus
    % Class for drawing a random dot pattern in the PTB.
    % Code from nsLLDots2 and modified for Matlab.
    %
    % Adjustable variables:
    %   size - dotsize (px)
    %   maxRadius - maximum radius of aperture (px)
    %   speed / direction - dot speed and direction (if using polar coordinates)
    %   xspeed / yspeed - dot speed (if using cartesian coordinates)
    %   nrDots - number of dots
    %   coherence - dot coherence
    %   motionMode - 0: spiral
    %                1: linear
    %   noiseMode - 0: proportion
    %               1: distribution
    %   noiseDist - 0: gaussian
    %               1: uniform
    
    
    properties
        x;
        y;
        dx;
        dy;
        dR;
        dphi;
        radius;
        phiOffset;
        framesLeft;
        stayPut;
        framerate;
        truncateGauss = -1;
    end
    
    methods (Access = public)
        function o = rdp(name)
            o = o@neurostim.stimulus(name); 
            o.listenToEvent({'BEFOREFRAME','AFTERFRAME','BEFORETRIAL'});
            o.listenToKeyStroke('p');
            o.addProperty('size',5);
            o.addProperty('maxRadius',100);
            o.addProperty('speed',25);
            o.addProperty('xspeed',0);
            o.addProperty('yspeed',0);
            o.addProperty('direction',0);
            o.addProperty('nrDots',100);
            o.addProperty('coherence',0.5);
            o.addProperty('motionMode',1);      %Spiral, linear
            o.addProperty('lifetime',50);
            o.addProperty('dwellTime',1);
            o.addProperty('coordSystem',2);
            o.addProperty('noiseMode',0);       % proportion, distribution
            o.addProperty('noiseDist',0);       % gaussian, uniform
            o.addProperty('noiseWidth',50);
            
          
        end
        
        
        function beforeTrial(o,c,evt)
            
            frameDur = Screen('GetFlipInterval',c.window);
            o.framerate = 1/frameDur;
            
            % overrule one of the velocity vectors based on coord system
            if o.coordSystem == 1
                [o.direction, o.speed] = cart2pol(o.xspeed, o.yspeed);
            else
                [o.xspeed, o.yspeed] = pol2cart((o.direction.*pi./180), o.speed);
            end
            
            initialiseDots(o,true(o.nrDots,1));
            
            % initialise dots
            o.framesLeft = randi(o.lifetime,o.nrDots,1);  
            
            
            
        end
        
        
        function beforeFrame(o,c,evt)
            
        Screen('DrawDots',c.window, [o.x o.y]', o.size, o.color, [c.position(3)/2 c.position(4)/2]);

        end
        
        
        function afterFrame(o,c,evt)

            % reduce lifetime by 1
            if ~isequal(o.noiseMode,'distribution') || o.noiseMode ~= 1 || ~isequal(o.noiseMode,'dist')
                o.framesLeft = o.framesLeft - 1;
            end
            
            moveDots(o);
            

        end
    
        
        
        
        function [xnew, ynew] = rotateXY(o,xprev,yprev,arg)
            % rotates vectors xprev and yprev by angle arg and outputs new
            % values in xnew and ynew.
            
            R = [cos(arg) -sin(arg) sin(arg) cos(arg)];
            % create a matrix with all rotation matrices in a column
            R2 = zeros(2*max(size(xprev)),2);
            R2(1:2:end) = R(:,1:2);
            R2(2:2:end) = R(:,3:4);
            
            % create a diagonal matrix of zeros with rotation matrices
            % along the diagonal
            R = mat2cell(R2,2*ones(max(size(xprev)),1),2);
            R = blkdiag(R{:});
            
            xyprev = reshape([xprev(:) yprev(:)]',2*size(xprev,1),[]);
            
            xynew = R*xyprev;
            
            xnew = xynew(1:2:end);
            ynew = xynew(2:2:end);
            
        end
        
        function initialiseDots(o,pos)
            % initialises dots in the array positions given by logical
            % array pos.
            

            
            
            o.stayPut(pos,1) = o.dwellTime;
            o.framesLeft(pos,1) = o.lifetime;
            o.radius(pos,1) = (sqrt(rand(nnz(pos),1).*o.maxRadius.*o.maxRadius));
            
            randAngle = rand(o.nrDots,1).*360;
%             index = ones(size(o.nrDots));
            
            switch o.motionMode
                case {0, lower('spiral')} % spiral
                    
                    o.phiOffset(pos,1) = randAngle(pos);
                    
                    if (ceil(o.coherence*o.nrDots)-1)>=1 && any(pos(1:ceil(o.coherence*o.nrDots)))
                        o.dR(pos(1:ceil(o.coherence*o.nrDots)),1) = o.xspeed/o.framerate;
                        o.dphi(pos(1:ceil(o.coherence*o.nrDots)),1) = o.xspeed/o.framerate;
                    end
                    if o.coherence == 0 || (o.coherence ~= 1 && any(pos(ceil(o.coherence*o.nrDots):end)))
                        index = find(pos)>=o.coherence*o.nrDots;
                        o.dR(index,1) = -o.xspeed/o.framerate;
                        o.dphi(index,1)=-o.yspeed/o.framerate;
                    end
                    
                    o.x(pos,1) = o.radius(pos).*cosd(randAngle(pos));
                    o.y(pos,1) = o.radius(pos).*sind(randAngle(pos));
                    
                    
                case {1, lower('linear')}  % linear
                    o.x(pos,1) = o.radius(pos).*cosd(randAngle(pos));
                    o.y(pos,1) = o.radius(pos).*sind(randAngle(pos));
                    
                    switch o.noiseMode
                        case {0, lower('proportion'), lower('prop')} %proportion
                            
                            if (ceil(o.coherence*o.nrDots))>=1 && any(pos(1:ceil(o.coherence*o.nrDots)))
                               o.dx(pos(1:ceil(o.coherence*o.nrDots)),1) = o.xspeed/o.framerate;
                               o.dy(pos(1:ceil(o.coherence*o.nrDots)),1) = o.yspeed/o.framerate;
                            end
                            
                            if o.coherence == 0 || (o.coherence ~= 1 && any(pos(ceil(o.coherence*o.nrDots):end)))
                               index = find(pos)>=o.coherence*o.nrDots;
                               randAngle(index) = rand(nnz(index),1).*360;
                               o.dx(index,1) = cosd(randAngle(index)).*o.speed/o.framerate;
                               o.dy(index,1) = sind(randAngle(index)).*o.speed/o.framerate;
                            end
                            
                            
                        case {1, lower('distribution'), lower('dist')} %distribution
                            switch o.noiseDist
                                case {0, lower('gaussian'), lower('gauss')}  %gaussian
                                    randAngle = o.noiseWidth.*randn(nnz(pos),1);
                                    if o.truncateGauss ~= -1
                                        a = abs(randAngle/o.noiseWidth)>o.truncateGauss;
                                        while max(a)
                                        randAngle(a) = o.noiseWidth.*randn(sum(a),1);
                                        a = abs(randAngle/o.noiseWidth)>o.truncateGauss;
                                        end
                                    end
                                case {1, lower('uniform')} %uniform
                                    randAngle = rand(nnz(pos),1).*o.noiseWidth - repmat(o.noiseWidth/2, nnz(pos),1);
                                otherwise
                                    error('unknown')
                            end
                            
                            randAngle = o.direction + randAngle;
                            [o.dx(pos), o.dy(pos)] = pol2cart(randAngle.*(pi./180),o.speed/o.framerate);
                    
                            
                            
                            
                    end
            end
        end
    
        
        function moveDots(o)
            
            %warp - move dots outside aperture
            switch o.motionMode
                case {1, lower('linear')} %linear
                    futureX = o.x+o.dwellTime.*o.dx;
                    futureY = o.y+o.dwellTime.*o.dy;
                    
                    futureRad = sqrt(futureX.^2 + futureY.^2);
                    if any(futureRad>o.maxRadius)
                        [dotDir,~] = cart2pol(o.dx(~~(futureRad>o.maxRadius)),o.dy(~~(futureRad>o.maxRadius)));

                        [xr, yr] = rotateXY(o,o.x(~~(futureRad>o.maxRadius)),o.y(~~(futureRad>o.maxRadius)),-dotDir);
                        chordLength = 2*sqrt(o.maxRadius^2 - yr.^2);
                        xr = xr - chordLength;
                        [o.x(~~(futureRad>o.maxRadius)), o.y(~~(futureRad>o.maxRadius))] = rotateXY(o,xr,yr,dotDir);
                        
                    end
                case {0, lower('spiral')} %spiral
                    temp1 = o.dR>0 & (o.radius+o.dwellTime.*o.dR)>o.maxRadius;
                    temp2 = o.dR<0 & (o.radius+o.dwellTime.*o.dR)<0;
                    if (any(temp1) || any(temp2))
                        nsMax = max(-1*o.dR(temp1 | temp2), 0);
                        nsMin = min(o.maxRadius, o.maxRadius - o.dR(temp1 | temp2));
                        o.radius(temp1 | temp2) = nsMax + (nsMin - nsMax).*rand(size(nsMax));
                            
                    end
            
            end
            
            %move dots
            if any(~o.framesLeft)
                initialiseDots(o,~o.framesLeft);
            end
            
            switch o.motionMode
                case {0, lower('spiral')} %spiral
                    o.phiOffset = o.phiOffset + o.dwellTime.*o.dphi;
                    o.radius = o.radius + o.dwellTime.*o.dR;
                    o.x = o.radius.*cosd(o.phiOffset);
                    o.y = o.radius.*sind(o.phiOffset);
                    
                case {1, lower('linear')}  %linear
                    o.x = o.x + o.dwellTime.*o.dx;
                    o.y = o.y + o.dwellTime.*o.dy;
            end
        end
            
    
    end
    
    
end