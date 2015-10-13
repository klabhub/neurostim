classdef gui <neurostim.plugin
    % Class to create GUI-like functionality in the PTB window.
    % EXAMPLE:
    % If c is your CIC, add this plugin, then, for instance tell it to
    % display the horizontal eye position, and the x parameter of the
    % fix stimulus. Updated these values each frame (debug only!).
    % c.add(plugins.gui);
    % c.gui.props = 'eye.x';
    % c.gui.props  = 'fix.x';
    % c.gui.updateEachFrame = true;
    %
    % BK - April 2014
    %
    properties (SetAccess =public, GetAccess=public)
        xAlign@char = 'right';          % 'left', or 'right'
        yAlign@char = '';         % center
        spacing@double = 1;             % Space between lines
        nrCharsPerLine@double= 100;      % Number of chars per line
        font@char = 'Courier New';      % Font
        fontSize@double = 15;           % Font size
        positionX;
        positionY;
        paramsBox;
        feedX;
        feedY;
        feedBox;
        mirrorRect;
        mirrorOverlay;
        guiText;
        toleranceColor=[1 1 50];
        
        props ={'file','paradigm','startTimeStr','blockName','nrConditions','condition','nrTrials','trial'}; % List of properties to monitor
        header@char  = '';              % Header to add.
        footer@char  = '';              % Footer to add.
        showKeys@logical = true;        % Show defined keystrokes
        updateEachFrame = false;        % Set to true to update every frame. (Costly; debug purposes only)
    end
    
    properties (SetAccess=protected)
        paramText@char = '';
        currentText@char = ''; %Internal storage for the current display
        keyLegend@char= '';      % Internal storage for the key stroke legend
        guiRect;
        behaviors={};
        tolerances=[];
        toleranceSquare=[];
    end
    
    methods %Set/Get
        function set.props(o,values)
            % By default derived classes add props (not replace)
            if ischar(values);values= {values};end
            if isempty(values)
                o.props= {};
            else
                o.props = cat(2,o.props,values);
            end
        end
        
        function v=get.mirrorRect(o)
            topx = o.cic.mirrorPixels(3)/2;
            topy = 0;
            bottomx = (o.cic.mirrorPixels(3)+topx)/2;
            bottomy=o.cic.mirrorPixels(4)/2;
            v=[topx topy bottomx bottomy];
        end
    end
    
    
    methods (Access = public)
        function o = gui
            % Construct a GUI plugin
            o = o@neurostim.plugin('gui');
            o.listenToEvent({'BEFOREFRAME','AFTERTRIAL','AFTEREXPERIMENT','BEFOREEXPERIMENT','BEFORETRIAL','AFTERFRAME'});
%             o.on=0;
%             o.duration =Inf;
        end
        function afterFrame(o,c,evt)
            if (o.updateEachFrame)
                updateParams(o,c);
                updateBehavior(o,c);
            end
        end
        
        function beforeExperiment(o,c,evt)
            % Handle beforeExperiment setup
            c.guiOn=true;
            c.mirror=Screen('OpenOffscreenWindow',c.window,c.screen.color.background);
            o.mirrorOverlay=Screen('OpenOffscreenWindow',c.window,[c.screen.color.background 0]);
            
            Screen('BlendFunction', c.mirror, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
            o.guiRect = [c.screen.pixels(3) c.mirrorPixels(2) c.mirrorPixels(3) c.mirrorPixels(4)];
            o.guiText=Screen('OpenOffscreenWindow',c.window,[c.screen.color.background 0]);
            switch (o.xAlign)
                case 'right'
                    o.positionX=(c.screen.pixels(3))*1/2;
                case 'left'
                    o.positionX = c.mirrorPixels(3)/2;
                otherwise
                    o.positionX=(c.screen.pixels(3))*1/2;
            end
            
            switch (o.yAlign)
                case 'center'
                    o.positionY=(c.mirrorPixels(4)-c.mirrorPixels(2));
                otherwise
                    o.positionY=50;
            end
            slack=10;
            o.feedX=c.screen.pixels(3)+slack;
            o.feedY=c.mirrorPixels(4)*.5+slack;
            o.feedBox = [slack c.mirrorPixels(4)/2 c.screen.pixels(3)-slack c.mirrorPixels(4)-slack];
            o.paramsBox = [c.screen.pixels(3)/2 slack c.screen.pixels(3)-slack o.mirrorRect(4)/2-slack];
            o.writeToFeed('Started Experiment \n');
            
        end
        function beforeFrame(o,c,evt)
            % Draw
            Screen('glLoadIdentity', c.onscreenWindow);
            drawParams(o,c);
            drawFeed(o,c);
            drawMirror(o,c);
            Screen('DrawTexture',c.onscreenWindow,c.mirror,c.screen.pixels,o.mirrorRect,[],0);
        end
        
        function beforeTrial(o,c,evt)
            % Update
            updateParams(o,c);
            setupKeyLegend(o,c);
            setupBehavior(o,c);
        end
        
        function afterTrial(o,c,evt)
            updateParams(o,c);
            drawParams(o,c);
            drawFeed(o,c);
            updateBehavior(o,c);
            drawMirror(o,c);
        end
        
        function afterExperiment(o,c,evt)
            updateParams(o,c);
            drawParams(o,c);
            drawFeed(o,c);
        end
        
        
        function writeToFeed(o,text)
            %writeToFeed(o,text)
            % adds a line of text to currentText.
            text=WrapString(text);
            length = strfind(o.currentText,'\n');
            if numel(length)>27
                tmp = numel(strfind(text,'\n'));
                if tmp<=1
                    o.currentText=o.currentText(length(1)+2:end);
                else
                    o.currentText=o.currentText(length(tmp)+2:end);
                end
            end
            o.currentText=[o.currentText text];
        end
        
    end
    
    
    methods (Access =protected)
        
        function setupKeyLegend(o,c)
            b=1;
            for a=c.keyHandlers
                keyName{b} = upper(a{:}.name);
                keyStroke{b}=KbName(c.allKeyStrokes(b));
                keyHelp{b} = c.allKeyHelp{b};
                b=b+1;
            end
            
            for d=1:numel(unique(keyName))
                tmp=unique(keyName);
                tmpName=keyName(strcmp(keyName,tmp{d}));
                tmpStroke = keyStroke(strcmp(keyName,tmp{d}));
                tmpHelp = keyHelp(strcmp(keyName,tmp{d}));
                
                tmpstr=strcat('<',tmpStroke,{'> '},tmpHelp,'\n');
                tmpstring{d}=[tmpName{1},': \n',tmpstr{:} '\n'];
            end
            o.keyLegend = ['Keys: \n\n',tmpstring{:}];
            DrawFormattedText(o.guiText,o.keyLegend,o.positionX,o.feedY,WhiteIndex(c.onscreenWindow));
            Screen('FrameRect',o.guiText,WhiteIndex(c.onscreenWindow),[o.paramsBox' o.feedBox']);
        end
        
        function drawParams(o,c)
            Screen('DrawTexture',c.onscreenWindow,o.guiText,[],o.guiRect);
%             DrawFormattedText(win, tstring [, sx][, sy][, color][, wrapat][, flipHorizontal][, flipVertical][, vSpacing][, righttoleft][, winRect])
        end
        
        function updateParams(o,c)
            % Update the text with the current values of the parameters.
            o.paramText  = o.header;
            for i=1:numel(o.props)
                tmp = getProp(c,o.props{i}); % getProp allows calls like c.(stim.value)
                if isnumeric(tmp)
                    tmp = num2str(tmp);
                elseif islogical(tmp)
                    if (tmp);tmp = 'true';else tmp='false';end
                end
                o.paramText = [o.paramText o.props{i} ': ' tmp '\n'];
            end
            o.paramText=[o.paramText o.footer];
            %draw to offscreen window
            Screen('FillRect',o.guiText,c.screen.color.background,o.paramsBox);
            DrawFormattedText(o.guiText, o.paramText, o.positionX,o.positionY, WhiteIndex(c.onscreenWindow),o.nrCharsPerLine,[],[],o.spacing);
            % The bbox does not seem to fit... add some slack 
            
            %draw key text
            
%           
        end
        

        
        function drawFeed(o,c)
            %drawFeed(o,c)
            % draws the bottom textbox using currentText.
            DrawFormattedText(c.onscreenWindow, o.currentText, o.feedX,o.feedY, WhiteIndex(c.onscreenWindow),o.nrCharsPerLine,[],[],o.spacing);
            
            
        end
        
        function setupBehavior(o,c)
            o.tolerances=[];
            o.toleranceSquare=[];
            for a=1:numel(c.plugins)
               if isa(c.(c.plugins{a}),'neurostim.plugins.behavior') 
                   o.behaviors=[o.behaviors c.plugins{a}];
                   if isa(c.(c.plugins{a}),'neurostim.plugins.fixate')
                       % if is a fixation dot, find the corners of the rect
                       % which the fixation tolerance allows
                       oval=[c.(c.plugins{a}).X-c.(c.plugins{a}).tolerance; c.(c.plugins{a}).Y-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).X+c.(c.plugins{a}).tolerance;c.(c.plugins{a}).Y+c.(c.plugins{a}).tolerance];
                       % convert to pixel dimensions
                       [oval(1,1),oval(2,1)]=c.physical2Pixel(oval(1,1),oval(2,1));
                       [oval(3,1),oval(4,1)]=c.physical2Pixel(oval(3,1),oval(4,1));
                        o.tolerances=[o.tolerances oval];
                   elseif isa(c.(c.plugins{a}),'neurostim.plugins.saccade')
                      % if is a saccade, find the start and end circles
                      oval1=[c.(c.plugins{a}).startX-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).startY-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).startX+c.(c.plugins{a}).tolerance;c.(c.plugins{a}).startY+c.(c.plugins{a}).tolerance];
                      % convert to pixel dimensions
                      [oval1(1,1),oval1(2,1)]=c.physical2Pixel(oval1(1,1),oval1(2,1));
                      [oval1(3,1),oval1(4,1)]=c.physical2Pixel(oval1(3,1),oval1(4,1));
                      oval2=[c.(c.plugins{a}).endX-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endY-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endX+c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endY+c.(c.plugins{a}).tolerance];
                      [oval2(1,1),oval2(2,1)]=c.physical2Pixel(oval2(1,1),oval2(2,1));
                      [oval2(3,1),oval2(4,1)]=c.physical2Pixel(oval2(3,1),oval2(4,1));
                      o.tolerances=[o.tolerances oval1 oval2];
                      % find the rectangle between the two fixation points
                      square = [c.(c.plugins{a}).startX;c.(c.plugins{a}).startY-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endX;c.(c.plugins{a}).endY+c.(c.plugins{a}).tolerance];
                      % convert to pixel dimensions
                      [square(1,1),square(2,1)]=c.physical2Pixel(square(1,1),square(2,1));
                      [square(3,1),square(4,1)]=c.physical2Pixel(square(3,1),square(4,1));
                      if square(3)<square(1)
                          tmp=square(1);
                          square(1)=square(3);
                          square(1)=tmp;
                      end
                      if square(4)<square(2)
                          tmp=square(2);
                          square(2)=square(4);
                          square(4)=tmp;
                      end
                      o.toleranceSquare=[o.toleranceSquare square];
                   end
               end
            end
        end
        
        function drawMirror(o,c)
            %drawBehavior(o,c)
            % draws any behavior tolerance circles.
            Screen('DrawTexture',c.mirror,c.window,[],[],[],0);
            Screen('FillOval',o.mirrorOverlay,[o.toleranceColor],o.tolerances,50);
            if ~isempty(o.toleranceSquare)
                Screen('FillRect',o.mirrorOverlay,[o.toleranceColor],o.toleranceSquare);
            end
            if c.frame>1
                [eyeX eyeY]=c.physical2Pixel(c.eye.x,c.eye.y);
                xsize=30;
                Screen('DrawLines',c.mirror,[-xsize xsize 0 0;0 0 -xsize xsize],5,WhiteIndex(c.onscreenWindow),[eyeX eyeY]);
            end
            Screen('DrawTexture',c.mirror,o.mirrorOverlay,[],[],[],0,0.4);
            

        end
        
        function updateBehavior(o,c)
            %updateBehavior(o,c)
            %updates behavior circles
%             o.tolerances=[];
%             o.toleranceSquare=[];
            for a=o.behaviors
                if isa(c.(a{:}),'neurostim.plugins.fixate')
                    
                    oval=[c.(a{:}).X-c.(a{:}).tolerance; c.(a{:}).Y-c.(a{:}).tolerance;c.(a{:}).X+c.(a{:}).tolerance;c.(a{:}).Y+c.(a{:}).tolerance];
                    
                    o.tolerances=[o.tolerances oval];
                elseif isa(c.(a{:}),'neurostim.plugins.saccade')
                    oval1=[c.(a{:}).startX-c.(a{:}).tolerance; c.(a{:}).startY-c.(a{:}).tolerance;c.(a{:}).startX+c.(a{:}).tolerance;c.(a{:}).startY+c.(a{:}).tolerance];
                    oval2=[c.(a{:}).endX-c.(a{:}).tolerance; c.(a{:}).endY-c.(a{:}).tolerance;c.(a{:}).endX+c.(a{:}).tolerance;c.(a{:}).endY+c.(a{:}).tolerance];
                    o.tolerances=[o.tolerances oval1 oval2];
                    square=[c.(a{:}).startX;c.(a{:}).startY;c.(a{:}).endX;c.(a{:}).endY];
                    o.toleranceSquare=[o.toleranceSquare square];
                end
            end
        end
    end
end