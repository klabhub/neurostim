classdef gllutimageChildDemo < neurostim.stimuli.gllutimage
   
    properties

    end
    
    methods (Access = public)
        function o = gllutimageChildDemo(c,name)
            o = o@neurostim.stimuli.gllutimage(c,name);
            o.addProperty('nGridElements',16);
        end
       
        function beforeExperiment(o)
            setup(o);
        end
        
        function beforeTrial(o)
            
           %Set o.idImage here. Here, we use a demo image
            %o.idImage = something
            
           defaultImage(o,o.nGridElements);
           
           %Apply a Gaussian envelope.
           d = size(o.idImage,1);
           g = normpdf(1:d,d/2,d/8);
           g = g./max(g);
           [g1,g2]=meshgrid(g,g);
           o.alphaMask =  g1.*g2;
           
           %Index of zero in idImage means to use background luminance.
           %This will overrise alpha mask for those pixels.
           o.idImage(o.alphaMask>0.9)=o.BACKGROUND;
           
           %Set clut here
            %Initialise CLUT with luminance ramp.
           defaultCLUT(o);
            
           %Now prepare textures and shaders
           o.prep(); 
        end
        
        function beforeFrame(o)
            glLoadIdentity();
             
            %Cyecle the CLUT
            if ~mod(o.frame,round(100/o.nClutColors)+1)
                o.clut = circshift(o.clut,-1,2);
            end
            
            %Allow parent to update its mapping texture
            updateCLUT(o);
            
            %Draw the texture
            o.draw();
        end
        
        function afterTrial(o)
            o.cleanUp();
        end
    end
end