classdef noiserasterradialhex < neurostim.stimuli.noiserasterclut
    % Stimulus class to present noise on a (radial) hexagonal grid.
    %
    % Settable properties:
    %
    %   innerRad        - radius of the inner clear aperturer (default: 0; no clear aperture),
    %   outerRad        - radius of the noise field (default: 10),
    %   nTiles   - the number of tiles between innerRad and outerRad (default: 10),
    %
    %   note: when rendering the noise field, tiles extend from innerRad to
    %         outerRad, both rounded *up* to the nearest multiple of the tile
    %         size/center separation, where
    %
    %           size = (outerRad-innerRad)/nTiles
    %
    % See also neurostim.stimuli.noiserasterclut
    
    % 2018-06-05 - Shaun L. Cloherty <s.cloherty@ieee.org>
    
    properties
        debug = false;
    end
    
    methods (Access = public)
        
        function o = noiserasterradialhex(c,name)
            o = o@neurostim.stimuli.noiserasterclut(c,name);
            
            o.addProperty('type','RECTANGLE','validate',@(x) any(strcmpi(x,{'RECTANGLE','HEXAGON','TRIANGLE','PARALLELOGRAM'})));
            o.addProperty('hexRadius',0.5,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','nonnegative'}));
            o.addProperty('nRadii',12,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','nonnegative'}));
        end
        
        function beforeTrial(o)
            % compute index image...
            [img,o.randelX,o.randelY] = o.hexgrid();
            
            % compute physical size for the index image...
            sz = size(img);
            sz = (o.cic.pixel2Physical(sz(1),sz(2))-o.cic.pixel2Physical(1,1));
            o.width = sz;
            o.height = sz;
            
            % set up the LUT and random variable callback functions
            initialise(o,img);
        end
        
        function beforeFrame(o)
            o.beforeFrame@neurostim.stimuli.noiserasterclut();
            
            if o.debug
                Screen('DrawDots',o.window,[o.randelX(:), o.randelY(:)]',1,[0.6,1.0,0.6]);
                
                rect = kron([o.innerRad,o.outerRad],[-1,-1,1,1]');
                color = [1.0, 0.0, 0.0, 0.1; 0.0, 0.0, 1.0, 0.1]';
                Screen('FillOval', o.window,color,rect);
            end
        end
        
    end % public methods
    
    methods (Access = private)
        
        function [img,xc,yc] = hexgrid(o)
            % compute hexagonal grid image
%             
%             sz = (o.outerRad-o.innerRad)/(o.nTiles-1);
%             
%             %
%             % compute hexagon centres (in screen units)
%             %
%             
%             % distance between centres
%             dc = sz; %(sz/2)*(4/sqrt(5));
%             
%             dy = dc; % vert. spacing (centre to centre)
%             dx = dc*(2/sqrt(5)); % horiz. spacing
%             
%             n = ceil(o.outerRad/dx)+1; % +1 to be sure?
%             
%             [xc,yc] = meshgrid(-n:n,-n:n);
%             
%             yc = dy.*(yc + 0.5.*mod(xc,2));
%             xc = dx.*xc;
%             
%             
%             xc = xc(:);
%             xc = xc(:);
%             yc = yc(:);
%             
%             % tiles to mask...
%             [~,r] = cart2pol(xc,yc);
%             %       mask = find((r < (o.innerRad)) | (r > (o.outerRad)));
%             mask = find((r < ceil(o.innerRad/dc)*dc) | (r > ceil(o.outerRad/dc)*dc));
%             
            % convert to pixels
            xscale = o.cic.screen.xpixels./o.cic.screen.width;
            yscale = o.cic.screen.ypixels./o.cic.screen.height;
%             
%             xx = round(xc.*xscale);
%             yy = round(yc.*yscale);
%             
%             %
%             % initialize the index image...
%             %
%             xsz = round((o.outerRad+sz)*xscale)*2 + 1; % size in pixels (FIXME: odd?)
%             ysz = round((o.outerRad+sz)*yscale)*2 + 1;
%             xsz = 500;
%             ysz = 500;
%             [xpx,ypx] = meshgrid([0:xsz]-xsz/2,[0:ysz]-ysz/2);
            
            % 
            % binhex... i.e., compute nearest tile center (vertex) for each pixel
            %
            
            h=hexGrid.layout;
            h.radius = xscale*o.hexRadius;
            hexagon(h,o.nRadii);
            [xc,yc]=centers(h);
            
            %How many pixels do I need for the image?
            [fx,fy]=wireFrame(h); %Hexagon edges
            sz = 2*ceil(max(abs([fx(:);fy(:)])));
            [xpx,ypx] = meshgrid([0:sz]-sz/2,[0:sz]-sz/2);
            xpx = xpx(:);
            ypx = ypx(:);
            tic
            %Map each pixel to the nearest hexagon center
            dt = delaunayTriangulation(xc(:),yc(:));
            [img,dist] = dt.nearestNeighbor(xpx,ypx);
            
            %Set pixels outside of the grid to background colour
            notInMap = dist>h.radius;
            inMap = dist <= (0.5*sqrt(3)*h.radius);            
            img(notInMap) = o.BACKGROUND;
            inds = 1:numel(img);
            done = notInMap | inMap;
            xpx(done) = [];
            ypx(done) = [];
            inds(done) = [];
            
            %Check the remaining, ambiguous pixels          
            for i=1:h.nHexes
                %Find pixels thta are in this polygon
                [in,on] = inpolygon(xpx,ypx,fx(i,:),fy(i,:));
                these = in|on;
                img(inds(these)) = i;
                
                %Remove the found pixels, to prevent re-checking them
                xpx(these) = []; ypx(these) = []; inds(these) = [];
            end
            img(inds) = o.BACKGROUND;
          toc
%             
%             img = ones(size(xpx)).*o.BACKGROUND;
%            
%             xpx = xpx(:);
%             ypx = ypx(:);
%             inds = 1:numel(img);
%             tic
%             for i=1:h.nHexes
%                 %Find pixels thta are in this polygon
%                 [in,on] = inpolygon(xpx,ypx,fx(i,:),fy(i,:));
%                 img(inds(in|on)) = i;
%                 
%                 %Remove the found pixels, to prevent re-checking them
%                 xpx(in) = []; ypx(in) = [];
%                 inds(in) = [];
%             end
%             toc
            
            

%             % mask...
%             idx(ismember(idx,mask)) = 0;
%             [~,~,idx] = unique(idx);
%             idx = max(idx - 1,0);
%             idx(idx == 0) = o.BACKGROUND;
            
            % reshape to form the image
            img = reshape(img,sz+1,sz+1);
        end
        
    end % private methods
    
end % classdef
