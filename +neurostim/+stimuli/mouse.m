classdef mouse < neurostim.stimulus
    % Class for receiving a mouse input for PTB.
    %
    % Inputs: cursorShape - cross: crosshair
    %                       arrow: normal mouse arrow
    %                       hand: mouse hand
    %
    % Updates every frame with mouse position (may cause frame drops)
    
    properties (Access=public)
        mousex;
        mousey;
        cursorShape = 'cross';
        time;
        pressed = 0;
    end
    
    properties (Access=public, SetObservable)
        trajX;
        trajY;
        trajTime;
    end
    
    methods (Access = public)
        function o = mouse(name)
            o = o@neurostim.stimulus(name);
            
            o.listenToEvent({'BEFOREEXPERIMENT','BEFOREFRAME','AFTERFRAME','BEFORETRIAL','AFTERTRIAL'})
            
            o.addProperty('clickx',[]);
            o.addProperty('clicky',[]);
            o.addProperty('clickbutton',[]);
            o.addProperty('clicktime',[]);
            o.addProperty('clickNumber',0);
            
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
        
        function beforeTrial(o,c,evt)
            if ~isempty(o.trajX) || ~isempty(o.trajY) || ~isempty(o.trajTime)
                o.trajX = [];
                o.trajY = [];
                o.trajTime = [];
            end
        end
        
        function beforeFrame(o,c,evt)
            
           [o.mousex,o.mousey,buttons] = c.getMouse();
           o.time = GetSecs;

           if any(buttons)~=0   % if any button is pressed
               o.clickx = o.X;
               o.clicky = o.Y;
               o.clickbutton = buttons;
               o.clicktime = o.time;
               if o.pressed == 0    % check if button was previously pressed
                   o.clickNumber = o.clickNumber + 1;
               end
               o.pressed = 1;   % set button as pressed.
           else o.pressed = 0;
               
           end
        end
        
        function afterFrame(o,c,evt)
            o.trajX(end+1) = o.mousex;
            o.trajY(end+1) = o.mousey;
            o.trajTime(end+1) = o.time;
        end
        
        
        
        
        function afterTrial(o,c,evt)
            o.addPostSet('trajX',[]);
            o.addPostSet('trajY',[]);
            o.addPostSet('trajTime',[]);
            o.removeListener('trajX');
            o.removeListener('trajY');
            o.removeListener('trajTime');
        end
    end
end