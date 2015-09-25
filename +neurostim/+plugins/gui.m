classdef gui <neurostim.stimulus
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
        nrCharsPerLine@double= 25;      % Number of chars per line
        font@char = 'Courier New';      % Font
        fontSize@double = 15;           % Font size
        positionX;
        positionY;
        paramsBox;
        feedX;
        feedY;
        feedBox;
        mirrorRect;
        
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
        guiTexture;
        guiRect;
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
            o = o@neurostim.stimulus('gui');
            o.listenToEvent({'BEFOREFRAME','AFTERTRIAL','AFTEREXPERIMENT','BEFOREEXPERIMENT','BEFORETRIAL','AFTERFRAME'});
            o.on=0;
            o.duration =Inf;
        end
        function afterFrame(o,c,evt)
            if (o.updateEachFrame)
                updateParams(o,c);
            end
        end
        
        function beforeExperiment(o,c,evt)
            % Handle beforeExperiment setup
            c.guiOn=true;
            o.guiRect = [c.screen.pixels(3) c.mirrorPixels(2) c.mirrorPixels(3) c.mirrorPixels(4)];
%             o.guiKeyTexture = Screen('OpenOffscreenWindow',-1,c.screen.color.background,o.guiRect);
            setupKeyLegend(o,c);
            switch (o.xAlign)
                case 'right'
                    o.positionX=(c.mirrorPixels(3))*3/4;
                case 'left'
                    o.positionX = c.mirrorPixels(3)/2;
                otherwise
                    o.positionX=(c.mirrorPixels(3))*3/4;
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
            o.feedBox = [c.screen.pixels(3) c.mirrorPixels(4)/2 o.mirrorRect(3)-slack c.mirrorPixels(4)-slack];
            o.paramsBox = [o.mirrorRect(3) slack c.mirrorPixels(3)-slack o.mirrorRect(4)/2-slack];
            o.writeToFeed('Started Experiment \n');
        end
        function beforeFrame(o,c,evt)
            % Draw
            Screen('glLoadIdentity', c.onscreenWindow);
            drawParams(o,c);
            drawFeed(o,c);
            Screen('DrawTexture',c.onscreenWindow,c.window,c.screen.pixels,o.mirrorRect,[],0);
        end
        
        function beforeTrial(o,c,evt)
            % Update
            updateParams(o,c);
        end
        
        function afterTrial(o,c,evt)
            updateParams(o,c);
            drawParams(o,c);
            drawFeed(o,c);
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
            end
        
        function drawParams(o,c)
            % DrawFormattedText(win, tstring [, sx][, sy][, color][, wrapat][, flipHorizontal][, flipVertical][, vSpacing][, righttoleft][, winRect])
            DrawFormattedText(c.onscreenWindow, o.paramText, o.positionX,o.positionY, c.screen.color.text,o.nrCharsPerLine,[],[],o.spacing);
            % The bbox does not seem to fit... add some slack 
            Screen('FrameRect',c.onscreenWindow,WhiteIndex(c.onscreenWindow),o.paramsBox);
            %draw key text
            DrawFormattedText(c.onscreenWindow,o.keyLegend,o.positionX,o.feedY,c.screen.color.text,o.nrCharsPerLine,[],[],o.spacing);
%             DrawFormattedText(c.onscreenWindow,o.string,o.positionX,800,c.screen.color.text);
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
        end
        

        
        function drawFeed(o,c)
            %drawFeed(o,c)
            % draws the bottom textbox using currentText.
            DrawFormattedText(c.onscreenWindow, o.currentText, o.feedX,o.feedY, c.screen.color.text,o.nrCharsPerLine,[],[],o.spacing);
            
            Screen('FrameRect',c.onscreenWindow,WhiteIndex(c.onscreenWindow),o.feedBox);
            
        end
        
        function drawBehavior(o,c)
            
            
            
        end
    end
end