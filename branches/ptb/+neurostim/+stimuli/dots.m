classdef dots < neurostim.stimulus
    properties
    end
    methods (Access = public)
        function d = dots(name)
            d = d@neurostim.stimulus(name);
            
            d.listenToEvent({'BEFOREFRAME','AFTERFRAME'});
            d.addProperty('CC',[650,512.5]); %CC= Center Coordinates of o.window
            d.addProperty('direction','RIGHT');
            d.addProperty('speed', 5); % dot speed of linear dots (pixels/frame)
            d.addProperty('nDots', 1000); % number of dots
            d.addProperty('width', 5); % width of dot (pixels)
            d.addProperty('fieldSize', 1500); % field size (pixels)
            d.addProperty('coherence', 0.5); 
            d.addProperty('angle', [0,90,180,270]); % heading of linear dots,   90deg = downwards
            d.addProperty('x', d.fieldSize * rand(1,d.coherence*d.nDots)); % initial position
            d.addProperty('y', d.fieldSize * rand(1,d.coherence*d.nDots));
           
          
            
        end
        
        function afterFrame(d,c,evt)
        end
        
        function beforeFrame(d,c,evt)
             switch upper(d.direction)
                 
                 case 'RIGHT'
                        try
                            bdown=0;

                            dx = d.speed * cos(d.angle(1)*pi/180); % x-velocity
                            dy = d.speed * sin(d.angle(1)*pi/180); % y-velocity

                            d.x = mod(d.x+dx,d.fieldSize); % update positions
                            d.y = mod(d.y+dy,d.fieldSize);

                            Screen('DrawDots', d.cic.window, [d.x;d.y], d.width, 255, [0 0], 1);

                        catch

                        disp(lasterr);
                        end  
                        
                 case 'DOWN'
                        try
                            bdown=0;

                            dx = d.speed * cos(d.angle(2)*pi/180); % x-velocity
                            dy = d.speed * sin(d.angle(2)*pi/180); % y-velocity

                            d.x = mod(d.x+dx,d.fieldSize); % update positions
                            d.y = mod(d.y+dy,d.fieldSize);

                            Screen('DrawDots', d.cic.window, [d.x;d.y], d.width, 255, [0 0], 1);

                        catch

                        disp(lasterr);
                        end  
                        
                 case 'LEFT'
                         try
                            bdown=0;

                            dx = d.speed * cos(d.angle(3)*pi/180); % x-velocity
                            dy = d.speed * sin(d.angle(3)*pi/180); % y-velocity

                            d.x = mod(d.x+dx,d.fieldSize); % update positions
                            d.y = mod(d.y+dy,d.fieldSize);

                            Screen('DrawDots', d.cic.window, [d.x;d.y], d.width, 255, [0 0], 1);

                        catch

                        disp(lasterr);
                         end  
                        
                 case 'UP'
                         try
                            bdown=0;

                            dx = d.speed * cos(d.angle(4)*pi/180); % x-velocity
                            dy = d.speed * sin(d.angle(4)*pi/180); % y-velocity

                            d.x = mod(d.x+dx,d.fieldSize); % update positions
                            d.y = mod(d.y+dy,d.fieldSize);

                            Screen('DrawDots', d.cic.window, [d.x;d.y], d.width, 255, [0 0], 1);

                        catch

                        disp(lasterr);
                        end  
                        
             end
        end
    end
end
