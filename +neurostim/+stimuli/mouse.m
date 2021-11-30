classdef mouse < neurostim.stimulus
    % Class for receiving a mouse input for PTB.
    %
    % Adjustable variables: 
    % cursorShape - cross: crosshair
    %               arrow: normal mouse arrow
    %               hand: mouse hand
    % 
    % Updates every frame with mouse position (may cause frame drops)
    
    properties (Access=public)
        cursorShape = 'cross';
    end
    
    properties (GetAccess=public,SetAccess=private)
        %% mouse clicked position and x,y coordinates for external use.
        pressed = 0;
        mousex;
        mousey;
    end
    
    properties (Access=public, SetObservable)
        %% logs of mouse trajectory
        trajX;
        trajY;
        trajTime;
    end
    
    methods (Access = public)
        function o = mouse(c,name)
            o = o@neurostim.stimulus(c,name);
             
            %% internally set parameters.
            o.addProperty('clickx',[]);
            o.addProperty('clicky',[]);
            o.addProperty('clickbutton');
            o.addProperty('clicktime',[]);
            o.addProperty('clickNumber',0);
            
        end
        
        function beforeExperiment(o)
           
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
        
        function beforeTrial(o)
            if ~isempty(o.trajX) || ~isempty(o.trajY) || ~isempty(o.trajTime)
                o.trajX = [];
                o.trajY = [];
                o.trajTime = [];
            end
        end
        
        function beforeFrame(o)
            
           [o.mousex,o.mousey,buttons] = c.getMouse();

           if any(buttons)~=0   % if any button is pressed
               o.clickx = o.X;
               o.clicky = o.Y;
               o.clickbutton = buttons;
               o.clicktime = c.trialTime;
               if o.pressed == 0    % check if button was previously pressed
                   o.clickNumber = o.clickNumber + 1;
               end
               o.pressed = 1;   % set button as pressed.
           else o.pressed = 0;
               
           end
        end
        
        function afterFrame(o)
            o.trajX(end+1) = o.mousex;
            o.trajY(end+1) = o.mousey;
        end
        
        
       end
end