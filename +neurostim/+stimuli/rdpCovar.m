classdef rdpCovar < neurostim.stimuli.rdp
    
    %Initial version of an RDP with "correlated external noise", intended to
    %evoke corresponding noise correlations in a population code.
    %Not yet for formal use.
    %
    %AM 26/1/17 
    methods (Access = public)
        function o = rdpCovar(c,name)
            o = o@neurostim.stimuli.rdp(c,name); 
            o.addProperty('dotNoiseSD',10,'validate',@isnumeric);
            o.addProperty('corrDistFn',@(d) 0.5*exp(2*(cos(d)-1)),'validate',@(x) isa(x,'function_handle'));
        end
    end
    
    methods (Access=protected)
        function initialiseDots(o,pos)
            % initialises dots in the array positions
            % pos argument is ignored. Not used for this version of rdp
            
            %Check/force some parameters
            o.motionMode = 1;            
            if o.truncateGauss <= 0
                error('The truncateGauss parameter must be greater than zero');
            end  
            o.framesLeft(1:o.nrDots,1) = Inf;
            
            %Assign random strating positions
            o.radius(1:o.nrDots,1) = sqrt(rand(o.nrDots,1).*o.maxRadius.*o.maxRadius);
            randAngle = rand(o.nrDots,1).*360;
            [o.x(1:o.nrDots,1), o.y(1:o.nrDots,1)] = o.setXY(true(o.nrDots,1),randAngle);
            
            %Allocate a mean direction for each dot, drawn NON-RANDOMLY from a truncated gaussian. i.e. symmetric around 0         
            pBounds = normcdf([-o.truncateGauss,o.truncateGauss],0,1);
            dotMu = norminv(linspace(pBounds(1),pBounds(2),o.nrDots),deg2rad(o.direction),deg2rad(o.noiseWidth));
            
            %Specify covariance matrix
            dMu = angle(exp(1j*(dotMu-dotMu(1))));
                        
            %Create correlation matrix
            r = o.corrDistFn(dMu);
            r(1) = 1;
            R = toeplitz(r);
            
            %Convert to covariance matrix based on the requested noise SD
            sigma = repmat(o.dotNoiseSD/180*pi,1,o.nrDots);
            covar = R.*(sigma'*sigma);
            
            %Now draw correlated noise values for each dot
            dotNoise = mvnrnd(zeros(1,o.nrDots),covar);
            
            %Add noise to signal and convert to Cartesian steps
            [o.dx(:,1), o.dy(:,1)] = pol2cart(dotMu+dotNoise,o.speed/o.cic.screen.frameRate);
        end
    end
end