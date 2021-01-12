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
        h;
        isSetup = false;
        width_tex
    end
    
    methods (Access = protected)
        function sz = imageSize(o)
            %Size of the image matrix
            %We're obliged to define this function by abstract parent class
            %Size of the idImage matrix. 
            if ~o.isSetup %Done this way so it can be accessed before runtime.
                setupHexGrid(o);
            end
            sz = [o.width_tex,o.width_tex];
        end
    end
    
    methods (Access = public)
        
        function o = noisehexgrid(c,name)
            o = o@neurostim.stimuli.noiseclut(c,name);
            
            o.addProperty('type','TRIANGLE','validate',@(x) any(strcmpi(x,{'RECTANGLE','HEXAGON','TRIANGLE','PARALLELOGRAM'})));
            o.addProperty('hexRadius',0.5,'validate',@(x) validateattributes(x,{'numeric'},{'scalar','nonnegative'}));
            o.addProperty('sz',3,'validate',@(x) validateattributes(x,{'numeric'},{'nonnegative'}));
            o.addProperty('spacing',1,'validate',@(x) validateattributes(x,{'numeric'},{'nonnegative'}));
            if exist('hexGrid.hex','class') ~=8
                error('Could not find the hexGrid package. Clone it from github (https://github.com/SysNeuroHub/hexGrid.git) and add it to your path.');
            end
        end
        
        function beforeTrial(o)
            
            %Calculate the hexagrid
            setupHexGrid(o);
            
            %Assign each pixel to one of the randels
            img = makeImage(o);
            
            % set up the LUT and random variable callback functions
            initialise(o,img);
        end
        
        function setupHexGrid(o)
            
            %These might not yet be set, if this function is called before runtime.
            if isempty(o.ns2p)
                o.p2ns = o.cic.pixel2Physical(1,0)-o.cic.pixel2Physical(0,0);
                o.ns2p = o.cic.physical2Pixel(1,0)-o.cic.physical2Pixel(0,0);
            end
            
            %Create a hex grid of the specified type, in pixel units

            %Hexagon radius is checked to make sure it aligns with pixel grid (will only be true if not rotation applied later)
            r = o.ns2p*o.hexRadius;     %radius to vertex
            r_short = sin(2*pi/3)*r;    %radius to edge horizontally
            r_short = round(r_short);   %Round to nearest pixel
            r = r_short/sin(2*pi/3);    %Convert back to vertex radius
                      
            o.h=hexGrid.layout('type',o.type,'size',o.sz,'radius',r);
            if o.spacing ~=1
                explode(o.h,o.spacing); %Careful: all bets are off for careful pixel checking if this is used
            end
            
            %Get the pixel coordinates of the wire frame
            [xc,yc]=centers(o.h);
            [fx,fy]=wireFrame(o.h); %Hexagon edges
                 %fx = fx+0.5;       
            
                 %Store hex positions in ns units
            o.wireFrame=cat(3,fx,fy)*o.p2ns;
            o.randelX = xc*o.p2ns;
            o.randelY = yc*o.p2ns;
            
            % compute physical size for the index image...
            o.width_tex = 2*ceil(max(abs([fx(:);fy(:)]))); %Even so that midline is boundary b/w two pixels rather than on a pixel.
            o.width = o.width_tex*o.p2ns;
            o.height = o.width;
            
            o.isSetup = true;
        end
        
        
        function beforeFrame(o)
            o.beforeFrame@neurostim.stimuli.noiseclut();
        end
        
    end % public methods
    
    methods (Access = private)
        
        function img = makeImage(o)
            % Assign each pixel to a hexagon or background
            
            %% NEAREST-NEIGHBOUR USING TRIANGULATION METHOD
            % Map each pixel to the nearest hexagon center
            % THIS METHOD ONLY WORKS IF GRID is 2D
            %             dt = delaunayTriangulation(xc(:),yc(:));
            %             [img,dist] = dt.nearestNeighbor(xpx,ypx);
            %           
            
            %% NEAREST-NEIGHBOUR USING INPOLYGON() METHOD
            % IT'S PRETTY SLOW IF THERE ARE MANY HEXAGONS AND MANY PIXELS
            sz = o.width_tex;
            img = ones(sz).*o.BACKGROUND;
            xpx = linspace(-sz/2,sz/2,sz);
            [xpx,ypx] = meshgrid(xpx,xpx);
            xpx = xpx(:);
            ypx = ypx(:);
            inds = 1:numel(img);
            fx = o.wireFrame(:,:,1).*o.ns2p;
            fy = o.wireFrame(:,:,2).*o.ns2p;
            for i=1:o.h.nHexes
                %Find pixels that are in this polygon
                [in,on] = inpolygon(xpx,ypx,fx(i,:),fy(i,:));
                isIn = in|on;
                img(inds(isIn)) = i;
                
                %Remove the found pixels, to prevent re-checking them
                xpx(isIn) = []; ypx(isIn) = [];
                inds(isIn) = [];
            end
            
        end
        
    end % private methods
    
    methods (Static)
        function sz = nRandelsToSize(gridType,n)
            %Helper function to return a sz vector for a desired number of randels
            switch upper(gridType)
                case 'TRIANGLE'
                    %This is a "triangular number". I don't know the
                    %formula, so doing a stupid little trick here for now.
                    %Fix later.
                    if ~ismember(n,((1:1000).^2+(1:1000))/2)
                        error(['Not possible to make a triangle with ' num2str(n) ' randels']);
                    end
                    
                    sz = 0;
                    while n>0
                        sz=sz+1;
                        n = n-sz;
                    end
                    
                case 'RECTANGLE'
                    sz = sqrt(n);
                    if mod(sz,1)
                        error('Sqrt(N) must be an integer');
                    end
                    sz = [sz,sz]; 
                    
                case 'PARALLELOGRAM'
                    %Not implemented yet
                    
                case 'HEXAGON'
                    %Not implemented yet
                    
            end
            
        end
    end
end % classdef
