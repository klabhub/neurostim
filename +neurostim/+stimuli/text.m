classdef text < neurostim.stimulus
    % Class for text presentation in PTB.
    % Adjustable variables:
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
        antialiasing = 1;
    end
    
    methods
        function o = set.antialiasing(o,value)
            if value ~= Screen('Preference','TextRenderer')
                warning('Text antialiasing not set to screen antialiasing')
            end
            o.antialiasing = value;
        end
    end
    
    methods (Access = public)
        function o = text(c,name)
            o = o@neurostim.stimulus(c,name);
            o.listenToEvent({'BEFOREFRAME','AFTERTRIAL','AFTEREXPERIMENT'});
            
            % add text properties
            o.addProperty('message','Hello World','validate',@ischar);
            o.addProperty('font','Courier New','validate',@ischar);
            o.addProperty('textsize', 20,'validate',@isnumeric);
            o.addProperty('textstyle', 0,'validate',@(x)(any(ismember(x,[0 1 2 4])) || any(ismember(lower(x),{'normal','bold','italic','underline'}))));
            o.addProperty('textalign','center','validate',@(x)ismember(upper(x),{'CENTER','CENTRE','C','LEFT','L','RIGHT','R'}));
            o.X = 0;
            o.Y = 0;
            
        end
        
        
        function beforeFrame(o,c,evt)
                    % Draw text with the assigned parameters
                     % determine text style variable for 'TextStyle'
                     if isempty(o.message); return;end
                    if o.antialiasing
                       Screen('glLoadIdentity', c.window); 
                       Screen('glRotate',c.window,o.angle,o.rx,o.ry,o.rz);
                       % fix X and Y to be in pixels (clipping occurs at
                       % negative numbers under high quality text rendering)
                       [X,Y] = c.physical2Pixel(o.X,o.Y);
                       textsize = o.textsize;
                    else
                        Screen('glScale',c.window,1,-1);
                        X = o.X;
                        Y = o.Y;
                        textsize = round(o.textsize*c.screen.width/c.screen.xpixels);
                    end

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
                    
%                     change font/size/style
                    Screen('TextFont', c.window, o.font);
                    Screen('TextSize', c.window, textsize);
                    Screen('TextStyle', c.window, style);
                    
                    
                    
                    [textRect] = Screen('TextBounds',c.window,o.message);
                    % aligning text in window
                    switch lower(o.textalign)
                        case {'center','centre','c'}
                            if o.antialiasing
                                xpos = X - textRect(3)/2;
                                ypos = Y - textRect(4)/2;
                            else
                                xpos = -textRect(3)/2;
                                ypos = -textRect(4)/2;
                            end
                        case {'left','l'}
                            if o.antialiasing
                                xpos = X;
                                ypos = X - textRect(4)/2;
                            else
                                xpos = X;
                                ypos = - textRect(4)/2;
                            end
                        case {'right','r'}
                            if o.antialiasing
                                xpos = X - textRect(3);
                                ypos = -textRect(4)/2;
                            else
                                xpos = -textRect(3);
                                ypos = -textRect(4)/2;
                            end
                        otherwise
                            xpos = X;
                            ypos = Y;
                    end
                   
                    % draw text to Screen
                    DrawFormattedText(c.window,o.message,xpos,ypos,o.color);
        end
        
        function afterTrial(o,c,evt)
            c.restoreTextPrefs;
        end
        
        function afterExperiment(o,c,evt)
            c.restoreTextPrefs;
        end
    end
    
end