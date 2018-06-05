classdef noiserasterradialgrid < neurostim.stimuli.noiserasterclut

    properties (Dependent)
        size
    end
    
    methods
        function sz = get.size(o)
            %Size of the idImage matrix. Done this way so it can be accessed before runtime.
            sz = 2*(o.cic.physical2Pixel(o.outerRad,0)-o.cic.physical2Pixel(0,0));
            sz = [sz sz];
        end
    end
    
    methods (Access = public)
        function o = noiserasterradialgrid(c,name)

            o = o@neurostim.stimuli.noiserasterclut(c,name);
            
            %User-definable
            o.addProperty('nWedges',40,'validate',@(x) isnumeric(x)); 
            o.addProperty('nRadii',8,'validate',@(x) isnumeric(x));
            o.addProperty('innerRad',5,'validate',@(x) isnumeric(x) & x >= 0);
            o.addProperty('outerRad',10,'validate',@(x) isnumeric(x) & x >= 0);           
     end

        function beforeTrial(o)
            
            %Use the full pixel resolution available.
            nPixels = o.size;
            x=linspace(-1,1,nPixels(1));
            [xGrid,yGrid]=meshgrid(x,x);
            
            %Calculations here are in normalised coordinates
            inner = o.innerRad./o.outerRad;
            outer = 1;
            o.width = o.outerRad*2;
            o.height = o.outerRad*2;
            
            %Get the polar angle and radius of each texel
            [pixTh,pixR]=cart2pol(xGrid,yGrid);
            
            %Assign an integer ID to wedges
            wedgeBinWidth = 2*pi/o.nWedges;
            radBins = linspace(inner,outer,o.nRadii+1);
            
            [~,~,thSub]=histcounts(pixTh,'binWidth',wedgeBinWidth);
            [~,~,radSub]=histcounts(pixR,radBins);
            
            thSub(thSub==0)=NaN;
            radSub(radSub==0)=NaN;
            im = sub2ind([o.nWedges,o.nRadii],thSub,radSub);
            im(isnan(im))=o.BACKGROUND;
           
            %Set up the CLUT and random variable callback functions
            initialise(o,im);
        end
    end % public methods   
end % classdef
