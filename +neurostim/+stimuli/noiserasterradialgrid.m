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
        end

        function beforeTrial(o)
            
            %The image is specified as a bitmap in which each pixel value is
            %the ID of the random (luminance) variable to be used.
            imInds = 1:o.nSectors*o.nRadii;
            o.idImage = reshape(imInds,o.nSectors,o.nRadii);
            
            %*******
            % Set up a shader (maybe?) to wrap the rectangular idImage
            % (drawn in parent class) circularly around the origin, to
            % create a polar grid?
            %Like this? https://www.shadertoy.com/view/XdBSzz
            %***********
            
            %Set up the CLUT and random variable callback functions
            initialise(o);
        end
        

    end % public methods   
end % classdef
