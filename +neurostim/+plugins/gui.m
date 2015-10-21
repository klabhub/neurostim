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
        nrCharsPerLine@double= 50;      % Number of chars per line
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
        guiFeed;
        guiFeedBack;
        behaviors={};
        tolerances=[];
        toleranceSquare=[];
        textHeight;
        feedBottom=0;
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
            o.guiFeed=Screen('OpenOffScreenWindow',c.onscreenWindow,c.screen.color.background);
            
            Screen('BlendFunction', c.mirror, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
            o.guiRect = [c.screen.pixels(3) c.mirrorPixels(2) c.mirrorPixels(3) c.mirrorPixels(4)];
            o.guiText=Screen('OpenOffscreenWindow',-1, c.screen.color.background,o.guiRect);
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
            sampleText=Screen('TextBounds',o.guiFeed,'QTUVWqpgyid');
            o.textHeight=sampleText(4)-sampleText(2);
            o.feedX=c.screen.pixels(3)/2+2*slack;
            o.feedY=c.mirrorPixels(4)*.5+slack;
            o.feedBox = [slack o.feedY-slack c.screen.pixels(3)-slack c.mirrorPixels(4)-(4*slack)];
            o.paramsBox = [c.screen.pixels(3)/2 slack c.screen.pixels(3)-slack o.mirrorRect(4)/2-slack];
            
            o.writeToFeed('Started Experiment');
            
        end
        
        
        function beforeFrame(o,c,evt)
            % Draw
            Screen('glLoadIdentity', c.onscreenWindow);
            
%             drawParams(o,c);
            drawMirror(o,c);
            box=[o.guiRect(1)-c.screen.pixels(3) o.guiRect(2) o.guiRect(3)-c.screen.pixels(3) o.guiRect(4)];
            Screen('DrawTextures',c.onscreenWindow,[o.guiText c.mirror],[box' c.screen.pixels'],[o.guiRect' o.mirrorRect'],[],[1 0]);
%             Screen('DrawTexture',c.onscreenWindow,c.mirror,c.screen.pixels,o.mirrorRect,[],0);
        end
        
        function beforeTrial(o,c,evt)
            % Update
            o.writeToFeed(['Trial #' num2str(c.trial)]);
            o.writeToFeed('Start');
            updateParams(o,c);
            setupKeyLegend(o,c);
            setupBehavior(o,c);
        end
        
        function afterTrial(o,c,evt)
            o.writeToFeed('End');
            updateParams(o,c);
            drawParams(o,c);
            updateBehavior(o,c);
            drawMirror(o,c);
        end
        
        function afterExperiment(o,c,evt)
            updateParams(o,c);
            drawParams(o,c);
        end
        
        
        function writeToFeed(o,text)
            %writeToFeed(o,text)
            % adds a line of text to the feed.
            text=WrapString(text,o.nrCharsPerLine);
            newLines=strfind(text,'\n');
            if o.feedBottom+o.textHeight*(numel(newLines)+1)>=(o.feedBox(4)-o.feedBox(2))
                text=strsplit(text,'\n');
                o.feedBottom=o.feedBottom-(o.textHeight*(numel(text)+1));
                o.guiFeedBack=Screen('OpenOffScreenWindow',o.cic.window,o.cic.screen.color.background);
                Screen('DrawTexture',o.guiFeedBack,o.guiText,[o.feedBox(1)+2 o.feedBox(2)+(o.textHeight*(numel(text)+1))+2 o.feedBox(3)/2 o.feedBox(4)-2],[o.feedBox(1)+2 o.feedBox(2)+2 o.feedBox(3)/2 o.feedBox(4)-(o.textHeight*(numel(text)+1))-2]);
                Screen('FillRect',o.guiText,o.cic.screen.color.background,[o.feedBox(1)+5 o.feedBox(2)+8 o.feedBox(3)/2-5 o.feedBox(4)-5]);
%                 Screen('FillRect',o.guiFeed,o.cic.screen.color.background,[o.feedBox(1)+5 o.feedBox(2)+5 o.feedBox(3)/2-5 o.feedBox(4)-5]);
                

                for a=1:numel(text)
                    %                         o.cic.mirrorPixels(3)/2
                    Screen('DrawText',o.guiFeedBack,text{a},o.feedBox(1)+10,o.feedY+o.feedBottom,WhiteIndex(o.cic.onscreenWindow));

                    o.feedBottom=o.feedBottom+o.textHeight;

                end
                Screen('DrawTexture',o.guiText,o.guiFeedBack,[o.feedBox(1)+2 o.feedBox(2)+2 o.feedBox(3)/2 o.feedBox(4)-2],[o.feedBox(1)+2 o.feedBox(2)+2 o.feedBox(3)/2 o.feedBox(4)-2]);
%                                         hi=Screen('GetImage',o.guiText);
%                                         figure;
%                                         image(hi);
                Screen('Close',o.guiFeedBack);
            else
                Screen('DrawText',o.guiText,text,o.feedBox(1)+10,o.feedY+o.feedBottom,WhiteIndex(o.cic.onscreenWindow));
                o.feedBottom=o.feedBottom+o.textHeight;
            end

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
            Screen('FillRect',c.onscreenWindow,c.screen.color.background,o.guiRect);
                        
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
            Screen('FillRect',o.guiText,c.screen.color.background,[o.paramsBox(1)+2 o.paramsBox(2)+2 o.paramsBox(3)-2 o.paramsBox(4)-2]);
            DrawFormattedText(o.guiText, o.paramText, o.positionX,o.positionY, WhiteIndex(c.onscreenWindow),o.nrCharsPerLine,[],[],o.spacing);
            % The bbox does not seem to fit... add some slack 
            
%           
        end
        

        
        function drawFeed(o,c)
            %drawFeed(o,c)
            % draws the bottom textbox from a texture.
%             Screen('DrawTexture',c.onscreenWindow,o.guiFeed,[],o.guiRect);
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
                       oval=o.phys2Pix(c,oval);
                        o.tolerances=[o.tolerances oval];
                   elseif isa(c.(c.plugins{a}),'neurostim.plugins.saccade')
                      % if is a saccade, find the start and end circles
                      oval1=[c.(c.plugins{a}).startX-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).startY-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).startX+c.(c.plugins{a}).tolerance;c.(c.plugins{a}).startY+c.(c.plugins{a}).tolerance];
                      % convert to pixel dimensions
                      oval1=o.phys2Pix(c,oval1);
                      
                      oval2=[c.(c.plugins{a}).endX-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endY-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endX+c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endY+c.(c.plugins{a}).tolerance];
                      oval2=o.phys2Pix(c,oval2);
                      o.tolerances=[o.tolerances oval1 oval2];
                      % find the rectangle between the two fixation points
                      square = [c.(c.plugins{a}).startX;c.(c.plugins{a}).startY-c.(c.plugins{a}).tolerance;c.(c.plugins{a}).endX;c.(c.plugins{a}).endY+c.(c.plugins{a}).tolerance];
                      % convert to pixel dimensions
                      square=o.phys2Pix(c,square);
                      o.toleranceSquare=[o.toleranceSquare square];
                   end
               end
            end
        end
        
        function shape=phys2Pix(o,c,v)
            [x1,y1]=c.physical2Pixel(v(1),v(2));
            [x2,y2]=c.physical2Pixel(v(3),v(4));
            if x2<x1
                tmp=x1;
                x1=x2;
                x2=tmp;
            end
            if y2<y1
                tmp=y1;
                y1=y2;
                y2=tmp;
            end
            shape=[x1;y1;x2;y2];
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
                if any(cellfun(@(plgin) isa(c.(plgin),'neurostim.plugins.eyetracker'), c.plugins))
                    [eyeX,eyeY]=c.physical2Pixel(c.eye.x,c.eye.y);
                    xsize=30;
                    Screen('DrawLines',c.mirror,[-xsize xsize 0 0;0 0 -xsize xsize],5,WhiteIndex(c.onscreenWindow),[eyeX eyeY]);
                end
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
                    oval=o.phys2Pix(c,oval);
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