classdef hexNoise < neurostim.stimuli.noiserasterclut
  % Stimulus class to present white noise on a hexagonal grid.
  
  % 2018-06-05 - Shaun L. Cloherty <s.cloherty@ieee.org>

  methods (Access = public)
    
    function o = hexNoise(c,name)
      o = o@neurostim.stimuli.noiserasterclut(c,name);

      o.addProperty('hexSz',1,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','positive'}));

%       
%       o.addProperty('innerRad',5,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','positive'}));
%       o.addProperty('outerRad',10,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','positive'}));
% 
%       o.addProperty('nTiles',5,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','positive'}));
    end
  
    function beforeTrial(o)
      % compute index image...
      t0 = tic();
      img = o.hexgrid();
      fprintf(1,'%.3fms to compute %i hexagons...\n',toc(t0)*1e3,max(img(:)));     
      
      % set up the LUT and random variable callback functions
      initialise(o,img);
    end
    
  end % public methods
  
  methods (Access = private)
    
    function img = hexgrid(o)
      % compute hexagonal grid image
      
      % compute hexagon centres (in screen units)
      t0 = tic();

      % distance between centres
      dy = (o.hexSz/2)*(4/sqrt(5));
      dx = dy*(2/sqrt(5));
      
      nx = ceil((o.width./dx)/2);
      ny = ceil((o.height./dy)/2);
      
      x = -nx:nx;
      y = -ny:ny;
      
      [xx,yy] = meshgrid(x,y);

      yy = dy.*(yy + 0.5.*mod(xx,2));
      xx = dx.*xx;

      % convert to pixels
%       [xx,yy] = o.cic.physical2Pixel(xx,yy);
      xscale = o.cic.screen.xpixels./o.cic.screen.width;
      yscale = o.cic.screen.ypixels./o.cic.screen.height;
      
      xx = round(xx.*xscale);
      yy = round(yy.*yscale);
      
      % initialize the image... 
      xsz = round(o.width.*xscale); % size in pixels
      ysz = round(o.height.*yscale);
      
      [xpx,ypx] = meshgrid([0:xsz]-xsz/2,[0:ysz]-ysz/2);

% %       % binhex... or compute nearest vertex
% %       dx = bsxfun(@minus,xpx(:),xx(:)');
% %       dy = bsxfun(@minus,ypx(:),yy(:)');
% % 
% %       dr = sqrt(dx.^2 + dy.^2);
% % 
% %       [~,idx] = min(dr,[],2);
 
      fprintf(1,'%.3fms to compute the centres...\n',toc(t0)*1e3);
      
      dt = delaunayTriangulation(xx(:),yy(:));
      idx = dt.nearestNeighbor(xpx(:),ypx(:));

      [~,~,idx] = unique(idx); % <-- necessary?
 
      % reshape to form the image
      img = reshape(idx,size(xpx));
%       figure
%       imagesc(img);
    end
    
  end % private methods
  
end % classdef
