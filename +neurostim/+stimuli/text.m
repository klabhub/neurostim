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
            o.listenToEvent({'BEFOREFRAME','AFTERFRAME'});
            
            % add text properties
            o.addProperty('message','Hello World');
            o.addProperty('font','Times New Roman');
            o.addProperty('textsize', 20);
            o.addProperty('textstyle', 0);
            o.addProperty('textalign','center');
            
        end
        
        function beforeFrame(o,c,evt)
                    % Draw text with the assigned parameters
                    messagetext = double(o.message);
                    
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
                    prevfont = Screen('TextFont', c.window, o.font);
                    prevtextsize = Screen('TextSize', c.window, o.textsize);
                    prevtextstyle = Screen('TextStyle', c.window, style);
                    
                    
                    % aligning text in window
                    [textRect,~] = Screen('TextBounds', c.window, messagetext); % gets text box size
                    
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
                    if o.visible
                        Screen('DrawText', c.window, messagetext, xpos, ypos, o.color);
                    end
                    
                    % restore prevous font/size/style
                    Screen('TextFont', c.window, prevfont);
                    Screen('TextSize', c.window, prevtextsize);
                    Screen('TextStyle', c.window, prevtextstyle);
                   
        end

        
        function afterFrame(o,c,evt)
        end
        
    end
    
end