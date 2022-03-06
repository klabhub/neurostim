classdef (Abstract) dots < neurostim.stimulus
  % Abstract class for drawing dots.
  %
  % The class constructor can be called with a number of arguments:
  %
  %   size       - dot size (pixels)
  %   speed      - dot speed (pixels/frame),
  %   direction  - degrees
  %   numDots    - number of dots
  %   lifetime   - limit of dot lifetime (frames)
  %   minRadius  - minimum radius of aperture (pixels; not implemented yet)
  %   maxRadius  - maximum radius of aperture (pixels)
  %   position   - aperture position (x,y; pixels)
  %   colour     - dot colour (RGB)
    
  % 2022-03-05 - Shaun L. Cloherty <s.cloherty@ieee.org>
  %
  % note: ported from my marmoview @dotsbase class.
  
%   properties (Access = public)
%     speed         % pixels/s
%     direction     % deg.
%     numDots
%     lifetime      % dot lifetime (frames)
% 
%     maxRadius@double; % maximum radius (pixels)        
%   end
    
  properties (GetAccess = public, SetAccess = protected)
    % cartessian coordinates (relative to o.position)
    x; % x coords (pixels)
    y; % y coords (pixels)
    
    % cartesian displacements
    dx; % pixels per frame?
    dy; % pixels per frame?
     
    % frames remaining (for limited lifetime dots)
    framesLeft;
  end
      
  methods (Access = public)
    function o = dots(c,name,varargin)
      % Properties:
      %
      %   type - dot 'type' (default: 1, see Psychtoolbox dot types below)
      %   size - dot diameter(s) (pixels; default: 5)
      %   position - ?
      %
      %   lifetime - dot lifetime (frames; default: Inf)
      %
      %   aperture - aperture shape ('CIRC' or 'RECT')
      %   apertureParms - aperture parameters (see below)
      %
      % Aperture shapes and their parameters:
      %
      %   Shape   Desc.           Parms
      %   ------  --------------  -----
      %   'CIRC'  Circle          [radius]
      %   'RECT'  Rectangle       [width, height]
      %   'POLY'  Convex polygon  [radius, nsides]
      %
      % Psychtoolbox dot types:
      % 
      %   0 - square dots
      %   1 - round, anit-aliased dots (favour performance)
      %   2 - round, anti-aliased dots (favour quality)
      %   3 - round, anti-aliased dots (built-in shader)
      %   4 - square dots (built-in shader)

      o = o@neurostim.stimulus(c,name);
            
      o.addProperty('type',1); % round, anit-aliased dots (favour performance)
      o.addProperty('size',5); % diameter(s) (pixels)
      o.addProperty('position',[0,0]); 

      o.addProperty('nrDots',100);

      o.addProperty('lifetime',Inf);

      o.addProperty('aperture','CIRC','validate',@(x)(ismember(upper(x),{'CIRC','RECT'})))      
      o.addProperty('apertureParms',[100]);

      % values logged for debug/reconstruction only  
      o.addProperty('rngState',[]); % logged at the start of each trial
      o.addProperty('xyVals',[]);   % logged at the end of each trial
            
      % snag a dedicated RNG stream
      % (to ensure it is protected for stimulus reconstruction offline)
      addRNGstream(o);
    end
        
    function beforeTrial(o)
      % switch to our own random stream
      s = RandStream.setGlobalStream(o.rng);

      % log the RNG state
      o.rngState = o.rng.State;

      o.initDots(true(o.nrDots,1));
      
      % initialise frame counts for limited lifetime dots
      if o.lifetime ~= Inf
        o.framesLeft = randi(o.lifetime,o.nrDots,1);
      else
        o.framesLeft = inf(o.nrDots,1);
      end

      % restore global random stream
      RandStream.setGlobalStream(s);
    end
    
    function afterTrial(o)
      o.xyVals = [o.x(:),o.y(:)];
    end

    function beforeFrame(o)
      o.drawDots();
    end
        
    function afterFrame(o)
      % decrement frame counters
      o.framesLeft = o.framesLeft - 1;

      % update dot positions
      o.moveDots(); % <-- provided by the derived class? maybe not...
    end
    
    % initialize position (x,y) and [frame] displacement (dx,dy) for each dot
    function initDots(o,ix)
      % initialises dots in the array positions indicated by ix

      % set frame counts
      o.framesLeft(ix) = o.lifetime;

      % randomize starting positions
      n = nnz(ix);

      switch upper(o.aperture)
        case 'CIRC'
          rmax = o.apertureParms(1); % max radius

          r = sqrt(rand(n,1).*rmax.*rmax);
          th = rand(n,1).*360;

          o.x(ix,1) = r.*cosd(th);
          o.y(ix,1) = r.*sind(th);
        case 'RECT'
          width = o.apertureParms(1);
          height = o.apertureParms(2);

          o.x(ix,1) = (rand(n,1)-0.5)*width;
          o.y(ix,1) = (rand(n,1)-0.5)*height; % upside down?
        otherwise
          ;
      end

      o.dx(ix,1) = 0;
      o.dy(ix,1) = 0;
    end

    function moveDots(o)
      % calculate future position (linear motion)
      o.x = o.x + o.dx;
      o.y = o.y + o.dy;
      
      switch upper(o.aperture)
        case 'CIRC'
          rmax = o.apertureParms(1); % max radius

          r = sqrt(o.x.^2 + o.y.^2);
          ix = find(r > rmax); % dots that have exited the aperture
               
          if any(ix)
            % (re-)place the dots on the other side of the aperture
            [th,~] = cart2pol(o.dx(ix),o.dy(ix));
            [xr,yr] = o.rotateXY(o.x(ix),o.y(ix),-1*th);
            chordLength = 2*sqrt(rmax^2 - yr.^2);
            xr = xr - chordLength;
            [o.x(ix,1), o.y(ix,1)] = o.rotateXY(xr,yr,th);

            o.x(ix,1) = o.x(ix,1) + o.dx(ix,1);
            o.y(ix,1) = o.y(ix,1) + o.dy(ix,1);
          end
        case 'RECT'
          width = o.apertureParms(1);
          height = o.apertureParms(2);

          % calculate verticies...
          vx = [-0.5, 0.5, 0.5, -0.5]*width;
          vy = [0.5, 0.5, -0.5, -0.5]*height;

          ix = ~o.npnpoly(o.x,o.y,[vx(:),vy(:)]); % dots that have exited the aperture

          if any(ix)
            % (re-)place the dots on the other side of the aperture
            [o.x(ix,1),o.y(ix,1)] = o.npopoly(o.x(ix,1),o.y(ix,1),[vx(:),vy(:)]);
          end
        otherwise
          error('Unknown aperture %s.',o.aperture);
      end

      ix = o.framesLeft == 0; % dots that have exceeded their lifetime
      
      if ~any(ix)
        return
      end

      % switch to our own random stream
      s = RandStream.setGlobalStream(o.rng);

      % (re-)place dots randomly within the aperture
      o.initDots(ix);

      % restore global random stream
      RandStream.setGlobalStream(s);
    end
    
    function drawDots(o)      
      Screen('DrawDots',o.window, [o.x(:), o.y(:)]', o.size, o.color, o.position, o.type);
    end
    
  end % public methods
  
  methods (Static)
    function [xnew,ynew] = rotateXY(x,y,th)
      % rotate (x,y) by angle th

      n = length(th);
      
      xnew = zeros([n,1]);
      ynew = zeros([n,1]);
      
      for ii = 1:n
        % calculate rotation matrix
        R = [cos(th(ii)) -sin(th(ii)); ...
             sin(th(ii))  cos(th(ii))];

        tmp = R * [x(ii), y(ii)]';
        xnew(ii) = tmp(1,:);
        ynew(ii) = tmp(2,:);
      end
    end

    function v = pnpoly(x,y,vert)
      % true for (x,y) inside the polygon defined by vert
      %
      % c.f. https://en.wikipedia.org/wiki/Point_in_polygon#Ray_casting_algorithm

      % this is based on W. Randolph Franklin's C implementation
      % see https://wrf.ecse.rpi.edu/Research/Short_Notes/pnpoly.html
      n = size(vert,1);

      v = false;

      p2 = vert(1,:);
      for ii = 1:n
        p1 = p2;
        p2 = vert(mod(ii,n)+1,:);

        xint = (y-p1(2))*(p2(1)-p1(1))/(p2(2)-p1(2)) + p1(1);

        if ((p1(2) > y) ~= (p2(2) > y)) && (x <= xint)
          v = ~v;
        end
      end
    end

    function v = npnpoly(x,y,vert)
      % c.f. pnpoly(), but for n points (x,y)     
      v = arrayfun(@(x,y) neurostim.stimuli.dots.pnpoly(x,y,vert),x,y);
    end

    function [ox,oy] = popoly(x,y,vert)
      % find the point opposite (x,y) on the boundary of the polygon defined by vert

      n = size(vert,1);

      Q = [x,y];

      nvec = [-y, x]; % normal to the line from (0,0) to (x,y)

      p2 = vert(1,:);
      for ii = 1:n
        p1 = p2;
        p2 = vert(mod(ii,n)+1,:);

        if (nvec*p1') * (nvec*p2') > 0
          % edge lies entirely on one side of the line
          continue
        end

        if nvec*p1' == 0
          % p1 lies on the line
          if norm(p1 - [x,y]) > norm(Q - [x,y])
            Q = p1;
          end

          if nvec*p2' == 0
            % p2 lies on the line too!
            if norm(p2 - [x,y]) > norm(Q - [x,y])
              Q = p2;
            end
          end

          continue
        end

        % (nvec*p1')*(nvec*p2') < 0... edge crosses the line, find the intercept

        xx = det([ 0, x; p2(1)*p1(2) - p2(2)*p1(1), p2(1)-p1(1)]) / ...
             det([-y, x; p1(2)-p2(2), p2(1)-p1(1)]);

        yy = det([-y, 0; p1(2)-p2(2), p2(1)*p1(2)-p2(2)*p1(1)]) / ...
             det([-y, x; p1(2)-p2(2), p2(1)-p1(1)]);

        if norm([xx,yy] - [x,y]) > norm(Q - [x,y])
          Q = [xx, yy];
        end
      end

      ox = Q(1);
      oy = Q(2);
    end

    function [ox,oy] = npopoly(x,y,vert)
      % c.f. popoly(), but for n points (x,y)
      [ox,oy] = arrayfun(@(x,y) neurostim.stimuli.dots.popoly(x,y,vert),x,y);
    end

  end % static methods

end % classdef
