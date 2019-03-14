classdef noisehexgrid < neurostim.stimuli.noiseclut
    % Stimulus class to present noise in grid of tesselated hexagons
    % Supports many grid outline shapes, including rectangle, triangle,
    % parallelogram, and hexagon
    %
    % Settable properties:
    %
    %   type        - 'RECTANGLE','HEXAGON','TRIANGLE', or 'PARALLELOGRAM'
    %   hexRadius   - radius of each hexagon (default: 10),
    %   size        - the number of hexagon along one dimension (the meaning
    %                differs across shape type. You'll need to try it out)
    %   spacing     - Control the gap between hexagons in the grid. (no gap
    %                   by default). spacing > 1 is a gap. spacing < 1 is
    %                   overlap.
    %
    % 2018-06-05 - Shaun L. Cloherty <s.cloherty@ieee.org>
    % 2019-07-03 - Adam Morris
    % See also noiseGridDemo, noiseRadialGridDemo, neurostim.stimuli.noiseclut, neurostim.stimuli.noiseradialgrid, neurostim.stimuli.noisehexgrid
  
    
    properties
        debug = false;
    end
    
    methods (Access = public)
        
        function o = noisehexgrid(c,name)
            o = o@neurostim.stimuli.noiseclut(c,name);
            
            o.addProperty('type','HEXAGON','validate',@(x) any(strcmpi(x,{'RECTANGLE','HEXAGON','TRIANGLE','PARALLELOGRAM'})));
            o.addProperty('hexRadius',0.5,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','nonnegative'}));
            o.addProperty('size',12,'validate',@(x) validateattributes(x,{'numeric'},{'nonnegative'}));
            o.addProperty('spacing',1,'validate',@(x) validateattributes(x,{'numeric'},{'nonnegative'}));
            if exist('hexGrid.hex','class') ~=8
                error('Could not find the hexGrid package. Clone it from github (https://github.com/SysNeuroHub/hexGrid.git) and add it to your path before using neurostim.plugins.psyBayes');
            end
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
            o.beforeFrame@neurostim.stimuli.noiseclut();
            
%             if o.debug
%                 Screen('DrawDots',o.window,[o.randelX(:), o.randelY(:)]',1,[0.6,1.0,0.6]);
%                 
%                 rect = kron([o.innerRad,o.outerRad],[-1,-1,1,1]');
%                 color = [1.0, 0.0, 0.0, 0.1; 0.0, 0.0, 1.0, 0.1]';
%                 Screen('FillOval', o.window,color,rect);
%             end
        end
        
    end % public methods
    
    methods (Access = private)
        
        function [img,xc,yc] = hexgrid(o)
            % compute hexagonal grid image
       
            % convert to pixels
            xscale = o.cic.screen.xpixels./o.cic.screen.width;
            %yscale = o.cic.screen.ypixels./o.cic.screen.height;
            
            
            %Create a hex grid of the specified type
            h=hexGrid.layout('type',o.type,'size',o.size,'radius',xscale*o.hexRadius);
            if o.spacing ~=1
                explode(h,o.spacing);
            end

            %Get the pixel coordinates of the wire frame
            [xc,yc]=centers(h);
            [fx,fy]=wireFrame(h); %Hexagon edges

            %How many pixels do I need for the image?
            sz = 2*ceil(max(abs([fx(:);fy(:)]))); %CHECK THIS.... HOW BIG SHOULD IT BE?
            [xpx,ypx] = meshgrid((0:sz)-sz/2,(0:sz)-sz/2);
            xpx = xpx(:);
            ypx = ypx(:);
                     
            % Assign each pixel to a hexagon or background
            
            %% NEAREST-NEIGHBOUR USING TRIANGULATION METHOD
            %Map each pixel to the nearest hexagon center
% THIS METHOD ONLY WORKS IF GRID is 2D
%             dt = delaunayTriangulation(xc(:),yc(:));
%             [img,dist] = dt.nearestNeighbor(xpx,ypx);
%             
%             %Set pixels outside of the grid to background colour
%             notInMap = dist>h.radius;
%             inMap = dist <= (0.5*sqrt(3)*h.radius);            
%             img(notInMap) = o.BACKGROUND;
%             inds = 1:numel(img);
%             done = notInMap | inMap;
%             xpx(done) = [];
%             ypx(done) = [];
%             inds(done) = [];
%             
%             %Check the remaining, ambiguous pixels          
%             for i=1:h.nHexes
%                 %Find pixels thta are in this polygon
%                 [in,on] = inpolygon(xpx,ypx,fx(i,:),fy(i,:));
%                 these = in|on;
%                 img(inds(these)) = i;
%                 
%                 %Remove the found pixels, to prevent re-checking them
%                 xpx(these) = []; ypx(these) = []; inds(these) = [];
%             end
%             img(inds) = o.BACKGROUND;
          
            %%  USING INPOLYGON()
            % USING THIS INSTEAD. IT'S PRETTY SLOW IF THERE ARE MANY HEXAGONS AND MANY PIXELS
            img = ones(size(xpx)).*o.BACKGROUND;
           
            xpx = xpx(:);
            ypx = ypx(:);
            inds = 1:numel(img);
            
            for i=1:h.nHexes
                %Find pixels that are in this polygon
                [in,on] = inpolygon(xpx,ypx,fx(i,:),fy(i,:));
                isIn = in|on; 
                img(inds(isIn)) = i;
                
                %Remove the found pixels, to prevent re-checking them
                xpx(isIn) = []; ypx(isIn) = [];
                inds(isIn) = [];
            end

            
            %% reshape to form the image
            img = reshape(img,sz+1,sz+1);
            
            %Store hex positions in ns units
            fx=fx';
            fy=fy';
            o.wireFrame = [fx(:),fy(:)]./xscale; %Not yet used for anything.
            xc = xc./xscale;
            yc = yc./xscale;
        end
        
    end % private methods
    
end % classdef
