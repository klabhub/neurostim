classdef gui <neurostim.plugin
    % Class to create GUI-like functionality in the second connected PTB window.
    % EXAMPLE:
    % If c is your CIC, add this plugin, then, for instance tell it to
    % display the horizontal eye position, and the x parameter of the
    % fix stimulus.
    % c.add(plugins.gui);
    % c.gui.props = 'eye.x';
    % c.gui.props  = 'fix.x';
    %
    %
    properties (Access=public)
        %% User-settable properties
        xAlign@char = 'right';          % 'left', or 'right'
        yAlign@char = '';         % center
        spacing@double = 1.2;             % Space between lines
        nrCharsPerLine@double= 50;      % Number of chars per line
        font@char = 'Courier New';      % Font
        fontSize@double = 15;           % Font size
        toleranceColor=[1 1 50];
        
        props ={'file','paradigm','startTimeStr','blockName','nrConditions','condition','trial','blockTrial/nrTrials','trial/fullNrTrials'}; % List of properties to monitor
        header@char  = '';              % Header to add.
        footer@char  = '';              % Footer to add.
        showKeys@logical = true;        % Show defined keystrokes
        updateEachFrame = false;        % Set to true to update every frame. (Costly; debug purposes only)
    end
    
    properties (Access=private)
        %% For internal use only.
        paramText@char = '';
        currentText@char = ''; %Internal storage for the current display
        keyLegend@char= '';      % Internal storage for the key stroke legend
        guiRect;
        guiFeed;
        guiFeedBack;
        behaviors={};
        tolerances=[];
        toleranceLine=[];
        textHeight;
        feedBottom=0;
        eyetrackers=[];
        behaviours=[];
        lastFrameDrop=0;
        
        mirrorRect;
        positionX;
        positionY;
        paramsBox;
        feedX;
        feedY;
        feedBox;
        guiText;
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
        
    end
    
    methods (Access=private)
        function v=mirrorRectCalc(o)
            % calculates the rect for mirroring the experimental display
            x1=o.cic.mirrorPixels(1);
            y1=o.cic.mirrorPixels(2);
            if ((o.cic.mirrorPixels(3)-o.cic.mirrorPixels(1))/2)>(o.cic.screen.pixels(3)-o.cic.screen.pixels(1))
                x2=o.cic.screen.pixels(3);
                y2=o.cic.screen.pixels(4);
            else
                x2=o.cic.mirrorPixels(3)/2;
                y2=o.cic.mirrorPixels(4)/2;
            end
            v=[x1 y1 x2 y2];
        end
        
    end
    
    
    methods (Access = public)
        function o = gui(c)
            % Construct a GUI plugin
            o = o@neurostim.plugin(c,'gui');
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
            o.guiFeedBack=Screen('OpenOffScreenWindow',c.guiWindow,o.cic.screen.color.background);
            o.guiRect = c.mirrorPixels;
            o.mirrorRect=mirrorRectCalc(o);
            o.guiText=Screen('OpenOffscreenWindow',-1, c.screen.color.background,o.guiRect);
            slack=5;
            switch (o.xAlign)
                case 'right'
                    o.positionX=(c.mirrorPixels(3))*1/2;
                case 'left'
                    o.positionX = c.mirrorPixels(3)/2;
                otherwise
                    o.positionX=(c.mirrorPixels(3))*1/2;
            end
            
            switch (o.yAlign)
                case 'center'
                    o.positionY=(c.mirrorPixels(4)-c.mirrorPixels(2));
                otherwise
                    o.positionY=50;
            end
            
            sampleText=Screen('TextBounds',o.guiText,'QTUVWqpgyid');
            o.textHeight=sampleText(4)-sampleText(2);
            o.feedX=c.mirrorPixels(3)/2+2*slack;
            o.feedY=c.mirrorPixels(4)*.5+slack;
            o.paramsBox=[c.mirrorPixels(3)/2 0 c.mirrorPixels(3) o.mirrorRect(4)];
            o.feedBox = [slack o.feedY-slack c.mirrorPixels(3)-slack c.mirrorPixels(4)-(4*slack)];
            o.eyetrackers=c.pluginsByClass('eyetracker');
            o.behaviours=c.pluginsByClass('behavior');
            c.writeToFeed('Started Experiment');
            
            
            
        end
        
        
        function beforeFrame(o,c,evt)
            % Draw
            Screen('glLoadIdentity', c.onscreenWindow);
            
            drawParams(o,c);
            drawMirror(o,c);
            
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
            text=[num2str(o.cic.trial) ':' num2str(round(o.cic.trialTime)) ' ' text];
            text=WrapString(text,o.nrCharsPerLine);
            newLines=strfind(text,'\n');
            if o.feedBottom+o.textHeight*(numel(newLines)+1)>=(o.feedBox(4)-o.feedBox(2))
                if newLines>0
                    text=strsplit(text,'\n');
                else
                    text={text};
                end
                o.feedBottom=o.feedBottom-(o.textHeight*(numel(text)+1));
                
                Screen('FillRect',o.guiFeedBack,o.cic.screen.color.background);
                Screen('DrawTexture',o.guiFeedBack,o.guiText,[o.feedBox(1)+2 o.feedBox(2)+(o.textHeight*(numel(text)+1))+2 o.feedBox(3)/2 o.feedBox(4)-2],[o.feedBox(1)+2 o.feedBox(2)+2 o.feedBox(3)/2 o.feedBox(4)-(o.textHeight*(numel(text)+1))-2],[],0,1);
%                 Screen('FillRect',o.guiText,o.cic.screen.color.background,[o.feedBox(1)+5 o.feedBox(2)+8 o.feedBox(3)/2-5 o.feedBox(4)-5]);

                for a=1:numel(text)
                    %                         o.cic.mirrorPixels(3)/2
                    Screen('DrawText',o.guiFeedBack,text{a},o.feedBox(1)+10,o.feedY+o.feedBottom,o.cic.screen.color.text);

                    o.feedBottom=o.feedBottom+o.textHeight;

                end
                Screen('DrawTexture',o.guiText,o.guiFeedBack,[o.feedBox(1)+2 o.feedBox(2)+2 o.feedBox(3)/2 o.feedBox(4)-2],[o.feedBox(1)+2 o.feedBox(2)+2 o.feedBox(3)/2 o.feedBox(4)-2],[],0,1);
                Screen('FillRect',o.guiFeedBack,o.cic.screen.color.background);
            else
                Screen('DrawText',o.guiText,text,o.feedBox(1)+10,o.feedY+o.feedBottom,o.cic.screen.color.text);
                o.feedBottom=o.feedBottom+o.textHeight;
            end
        end
        
    end
    
    
    methods (Access =private)
        
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
            DrawFormattedText(o.guiText,o.keyLegend,o.positionX,o.feedY,c.screen.color.text,[],[],[],o.spacing);
        
        end
        
        function drawParams(o,c)
%             Screen('FillRect',c.onscreenWindow,c.screen.color.background,o.guiRect);
%             Screen('DrawTexture',c.guiWindow,o.guiText,[],o.guiRect,[],0);
                Screen('DrawTexture',c.guiWindow,o.guiText,[],[],[],0);
%             DrawFormattedText(win, tstring [, sx][, sy][, color][, wrapat][, flipHorizontal][, flipVertical][, vSpacing][, righttoleft][, winRect])
        end
        
        function updateParams(o,c)
            % Update the text with the current values of the parameters.
            o.paramText  = o.header;
            for i=1:numel(o.props)
                str=strsplit(o.props{i},'/');
                for j=1:numel(str)
                    tmp = getProp(c,str{j}); % getProp allows calls like c.(stim.value)
                    if isnumeric(tmp)
                        tmp = num2str(tmp);
                    elseif islogical(tmp)
                        if (tmp);tmp = 'true';else tmp='false';end
                    end
                    if numel(str)>1
                        if j==1
                            o.paramText=[o.paramText o.props{i} ': ' tmp];
                        else
                            o.paramText=[o.paramText '/' tmp];
                        end
                    else
                        o.paramText = [o.paramText o.props{i} ': ' tmp];
                    end
                end
                o.paramText=[o.paramText '\n'];
            end
            o.paramText=[o.paramText o.footer];
            %draw to offscreen window
            Screen('FillRect',o.guiText,c.screen.color.background,o.paramsBox);
            DrawFormattedText(o.guiText, o.paramText, o.positionX,o.positionY, c.screen.color.text,o.nrCharsPerLine,[],[],o.spacing);
            
%           
        end
        
        function setupBehavior(o,c)
            o.tolerances=[];
            o.toleranceLine=[];
            if ~isempty(o.behaviours)
            for a=o.behaviours
                   if isa(a{:},'neurostim.plugins.fixate')
                       % if is a fixation dot, find the corners of the rect
                       % which the fixation tolerance allows
                       oval=[a{:}.X-a{:}.tolerance; a{:}.Y-a{:}.tolerance;a{:}.X+a{:}.tolerance;a{:}.Y+a{:}.tolerance];
                       % convert to pixel dimensions
                       oval=o.phys2Pix(c,oval);
                       o.tolerances=[o.tolerances oval];
                   elseif isa(a{:},'neurostim.plugins.saccade')
                      % find the line between the two fixation points
                      line = [a{:}.startX;a{:}.startY;a{:}.endX;a{:}.endY];
                      % convert to pixel dimensions
                      line=o.phys2Pix(c,line);
                      line=[line(1) line(2);line(3) line(4)];
                      o.toleranceLine=[o.toleranceLine line];
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
            if ~isempty(o.tolerances)
            Screen('FrameOval',c.mirror,[o.toleranceColor],o.tolerances,2);
            end
            if ~isempty(o.toleranceLine)
                Screen('DrawLines',c.mirror,o.toleranceLine',2,[o.toleranceColor]);
            end
            if c.frame>1 && ~isempty(o.eyetrackers)
                    [eyeX,eyeY]=c.physical2Pixel(c.eye.x,c.eye.y);
                    xsize=30;
                    Screen('DrawLines',c.mirror,[-xsize xsize 0 0;0 0 -xsize xsize],5,c.screen.color.text,[eyeX eyeY]);
            end
            Screen('DrawTexture',o.guiText,c.mirror,c.screen.pixels,o.mirrorRect,[],0);
            Screen('FrameRect',o.guiText,c.screen.color.text,o.mirrorRect);
        end
        
        function updateBehavior(o,c)
            %updateBehavior(o,c)
            %updates behavior circles
            o.tolerances=[];
            o.toleranceLine=[];
            if ~isempty(o.behaviors)
            for a=o.behaviors
                if isa(a{:},'neurostim.plugins.fixate')
                    oval=[a{:}.X-a{:}.tolerance; a{:}.Y-a{:}.tolerance;a{:}.X+a{:}.tolerance;a{:}.Y+a{:}.tolerance];
                    oval=o.phys2Pix(c,oval);
                    o.tolerances=[o.tolerances oval];
                elseif isa(a{:},'neurostim.plugins.saccade')
                    line = [a{:}.startX;a{:}.startY;a{:}.endX;a{:}.endY];
                    line=o.phys2Pix(c,line);
                    line=[line(1) line(2);line(3) line(4)];
                    o.toleranceLine=[o.toleranceLine line];
                end
            end
            end
        end
        
    end
end