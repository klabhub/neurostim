classdef text < neurostim.stimulus
    % Class for text presentation in PTB.
    % variables:
    %   message: text to message on screen
    %   font: font for presentation
    %   textsize: size of text (pt)
    %   textstyle: style of text (supported: normal, bold, italic,
    %       underline)
    %   textalign: horizontal alignment of text given x,y position (supported: 
    %       center, left, right)
    %       - vertical alignment is default centered around y.
    %
    % NB: Currently reverts font style/size to previous after stimulus
    % draw.
    %
    
    properties
    end
    
    
    methods (Access = public)
        function o = text(name)
            o = o@neurostim.stimulus(name);
            o.listenToEvent({'BEFOREFRAME','BEFOREEXPERIMENT','AFTERTRIAL','AFTEREXPERIMENT'});
            
            % add text properties
            o.addProperty('message','Hello World');
            o.addProperty('font','Courier New');
            o.addProperty('textsize', 20);
            o.addProperty('textstyle', 0);
            o.addProperty('textalign','center');
        end
        
        function beforeExperiment(o,c,evt)
           scale = c.screen.physical(1)/c.screen.pixels(3);
           o.scale.x = scale;
           o.scale.y = -scale;
        end
        
        function beforeFrame(o,c,evt)
                    % Draw text with the assigned parameters
%                     messagetext = double(o.message);
                    % determine text style variable for 'TextStyle'
                    switch lower(o.textstyle)
                        case {'normal',0}
                            style = 0;
                        case {'bold','b'}
                            style = 1;
                        case {'italic','i'}
                            style = 2;
                        case {'underline','u'}
                            style = 4;
                        otherwise
                            style = 0;
                    end
                    
                    % change font/size/style
                    Screen('TextFont', c.window, o.font);
                    Screen('TextSize', c.window, o.textsize);
                    Screen('TextStyle', c.window, style);
                    
                    [textRect] = Screen('TextBounds',c.window,o.message);
                    % aligning text in window
                    switch lower(o.textalign)
                        case {'center','centre','c'}
                            xpos = o.X - textRect(3)/2;
                            ypos = o.Y - textRect(4)/2;
                        case {'left','l'}
                            xpos = o.X;
                            ypos = o.Y - textRect(4)/2;
                        case {'right','r'}
                            xpos = o.X - textRect(3);
                            ypos = o.Y - textRect(4)/2;
                        otherwise
                            xpos = o.X;
                            ypos = o.Y;
                    end
                    
                    % draw text to Screen
                    Screen('DrawText', c.window, o.message, xpos, ypos, o.color);
                   
        end
        
        function afterTrial(o,c,evt)
            
            c.restoreTextPrefs;
        end
        
        function afterExperiment(o,c,evt)
            c.restoreTextPrefs;
            
        end
    end
    
end