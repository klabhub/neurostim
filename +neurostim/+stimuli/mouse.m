classdef mouse < neurostim.stimulus
    % Class for receiving a mouse input for PTB.
    %
    % Inputs: cursorShape - cross: crosshair
    %                       arrow: normal mouse arrow
    %                       hand: mouse hand
    %
    
    
    properties
        mousex;
        mousey;
        cursorShape = 'cross';
    end
    
    methods (Access = public)
        function o = mouse(name)
            o = o@neurostim.stimulus(name);
            
            o.listenToEvent({'BEFOREEXPERIMENT','AFTERFRAME','AFTEREXPERIMENT'})
            
            o.addProperty('clickx',[]);
            o.addProperty('clicky',[]);
            o.addProperty('clickbutton',[]);
            
        end
        
        function beforeExperiment(o,c,evt)
           
            switch lower(o.cursorShape)
                case {'crosshair', 'cross'}
                    ShowCursor('CrossHair');
                case {'arrow','pointer'}
                    ShowCursor('Arrow');
                case 'hand'
                    ShowCursor('Hand');
                case {'clock','hourglass','waiting'}
                    ShowCursor('SandClock');
                case {'4', 'up-down arrow'}
                    ShowCursor(4);
                case {'5', 'left-right arrow'}
                    ShowCursor(5);
                case {'7', 'cancel', 'no'}
                    ShowCursor(7);
            end
            
        end
        
        function afterFrame(o,c,evt)
            
           [o.mousex(end+1),o.mousey(end+1),buttons] = c.getMouse();
           if any(buttons) ~=0
               o.clickx = o.mousex(end);
               o.clicky = o.mousey(end);
               o.clickbutton = buttons;
           end
           
            
        end
        
        function afterExperiment(o,c,evt)
            o.X = o.mousex;
            o.Y = o.mousey;
        end
    end
end