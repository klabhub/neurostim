classdef noiserasterradialgrid < neurostim.stimuli.noiserasterclut
    %Place holder. This will become a polar grid of luminance noise.
    %Should be able to use a texture map or shadrer to wrap a rectangular
    %texture around the origin?
    
    methods (Access = public)
        function o = noiserasterradialgrid(c,name)

            o = o@neurostim.stimuli.noiserasterclut(c,name);
            
            %User-definable
            o.addProperty('nSectors',8,'validate',@(x) isnumeric(x)); 
            o.addProperty('nRadii',4,'validate',@(x) isnumeric(x));
            
            o.writeToFeed('WARNING: The radial noise stimulus is just testing a concept. Horrible. Do not use');
        end

        function beforeTrial(o)
            
            %The image is specified as a bitmap in which each pixel value is
            %the ID of the random (luminance) variable to be used.
%             imInds = 1:o.nSectors*o.nRadii;
%             o.idImage = reshape(imInds,o.nSectors,o.nRadii);
            
            %*******
            % Set up a shader (maybe?) to wrap the rectangular idImage
            % (drawn in parent class) circularly around the origin, to
            % create a polar grid?
            %Like this? https://www.shadertoy.com/view/XdBSzz
            %***********
            nPixels = o.cic.screen.ypixels;
            x=linspace(-1,1,nPixels);
            [xGrid,yGrid]=meshgrid(x,x);
            [pixTh,pixR]=cart2pol(xGrid,yGrid);
            
            sectBinWidth = 2*pi/o.nSectors;
            sectBins = linspace(sectBinWidth/2,2*pi-sectBinWidth/2,o.nSectors);
            radBinWidth = 1./o.nRadii;
            radBins = linspace(radBinWidth/2,1-radBinWidth/2,o.nRadii);
            
            im=zeros(size(xGrid));
            ind=1;
            for i=1:o.nSectors
                for j=1:o.nRadii
                    inBin = abs(angle(exp(1i*pixTh)./exp(1i*sectBins(i)))) <= sectBinWidth/2;
                    inBin = inBin & abs(pixR-radBins(j)) <= radBinWidth/2;
                    im(inBin) = ind;
                    ind=ind+1;
                end
            end

            o.idImage = im;
            
            %Set up the CLUT and random variable callback functions
            initialise(o);
        end
        

    end % public methods   
end % classdef
