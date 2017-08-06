classdef sqwavGrating < neurostim.stimulus
    % Fills square-wave gratings at specified spatial frequency,
    % face/background color, orientation, on specified area of screen.
    %
    % Adjustable variables:
    %   faceColor - color of face bars.
    %   bgColor - color of background bars.
    %   spatialFreq - spatial frequency of grating in visual-degree.
    %   orientation - orientation of grating in degree 
    %       (0 = vertical; 90 = horizontal; positive = clockwise rotation).
    %   phase - phase of grating, currently only allows 0 or 180
    %       (0 = drawing from faceColor; 180 = drawing from bgColor).
    %   width - width of a rectangular area to fill.
    %   height - height of a rectangular area to fill
    %       (default to full screen).
    
    properties
    end
    
    methods (Access = public)
        function o = sqwavGrating(c,name)
            o = o@neurostim.stimulus(c,name);
            o.addProperty('spatialFreq',1,'validate',@isnumeric);
            o.addProperty('orientation',0,'validate',@isnumeric);
            o.addProperty('phase',0,'validate',@(x) ismember(x,[0 180]));
%             o.addProperty('faceColor',[1 1 1],'validate',@isnumeric);
%             o.addProperty('bgColor',[0 0 0],'validate',@isnumeric); 
            o.addProperty('width',52,'validate',@isnumeric);
            o.addProperty('height',52,'validate',@isnumeric);
            o.addProperty('lum',0,'validate',@isnumeric);
            o.addProperty('chrom',0,'validate',@isnumeric);
            o.addProperty('chromIncrement',0,'validate',@isnumeric);
        end

        function beforeFrame(o)
            borders = [-o.width/2 -o.height/2 o.width/2 o.height/2]; % left, top, right, bottom borders of a rectangular area to fill

            %Compute vertices
            nrBars = ceil((borders(3)-borders(1))*o.spatialFreq*2); % each cycle has 2 bars, face and background
            barWidth = (1/o.spatialFreq)/2;
            switch rem(nrBars,2)
                case 0 % number of bars is even, last bar to draw is background-bar
                    faceLR = borders(1)+(0:(nrBars-1))*barWidth; % left & right borders of facebars
                    bgLR = borders(1)+(1:nrBars)*barWidth; % left & right borders of backgroundbars
                    bgLR(end) = min(borders(1)+ nrBars*barWidth,borders(3));
           
                case 1 % number of bars is odd, last bar to draw is facebar
                    faceLR = borders(1)+(0:nrBars)*barWidth; % left & right borders of facebars
                    faceLR(end) = min(borders(1)+ nrBars*barWidth,borders(3));
                    bgLR = borders(1)+(1:(nrBars-1))*barWidth; % left & right borders of backgroundbars
            end
            
            faceTB = repmat([borders(2) borders(4)],[1 ceil((nrBars)/2)]); % top & bottom borders of both facebars
            bgTB = repmat([borders(2) borders(4)],[1 floor((nrBars)/2)]); % top & bottom borders of backgroundbars
            % convert vertices to a 4 by N matrix. N = number of bars to draw; 4 rows from top to bottom are L, T, R, B, borders. 
            faceBordersTemp = [faceLR; faceTB];
            faceBorders = reshape(faceBordersTemp,[4 ceil(nrBars/2)]);
            bgBordersTemp = [bgLR; bgTB];
            bgBorders = reshape(bgBordersTemp,[4 floor(nrBars/2)]);            

            
            %Draw
            Screen('glRotate',o.window, o.orientation, 0, 0); % rotate grating to called orientation
            
            % choose phase of grating to draw (0 or 180)
            if o.phase == 0 % first bar of each visual cycle has face color
                Screen('FillRect',o.window, o.color, faceBorders);
%                 Screen('FillRect',o.window, 1, bgBorders);
            elseif o.phase == 180 % second bar of each visual cycle has face color
                Screen('FillRect',o.window, o.color, bgBorders);
%                 Screen('FillRect',o.window, 1, faceBorders);
            end
        end
        
        
        function afterFrame(o)
            % clear screen before drawing new stimulus
             Screen('FillRect',o.window,1,[-26 -26 26 26]);
% Screen('FillRect',o.window,[0.33 0.33 0],[-26 -26 26 26]);
        end
        
                
    end
        
end