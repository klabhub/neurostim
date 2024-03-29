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
        xAlign = 'right';          % 'left', or 'right'
        yAlign= '';         % center
        spacing= 1.2;             % Space between lines
        nrCharsPerLine= 50;      % Number of chars per line
        font= 'Courier New';      % Font
        fontSize= 15;           % Font size
        toleranceColor=[1 1 50];
        
        props ={'file','paradigm','startTimeStr','blockName','nrConditions','condition','trial','blockTrial/nrTrials','trial/nrTrialsTotal'}; % List of properties to monitor
        header= '';              % Header to add.
        footer= '';              % Footer to add.
        showKeys= true;        % Show defined keystrokes
        updateEachFrame = false;        % Set to true to update every frame. (Costly; debug purposes only)
    end
    
    properties (Access=private)
        %% For internal use only.
        paramText= '';
        currentText= ''; %Internal storage for the current display
        keyLegend= '';      % Internal storage for the key stroke legend
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
            if ((o.cic.mirrorPixels(3)-o.cic.mirrorPixels(1))/2)>o.cic.screen.xpixels
                x2=o.cic.screen.xorigin + o.cic.screen.xpixels;
                y2=o.cic.screen.yorigin + o.cic.screen.ypixels;
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
            
%             o.on=0;
%             o.duration =Inf;
        end
        function afterFrame(o)
            if (o.updateEachFrame)
                updateParams(o);
                updateBehavior(o);
            end
        end
        
        function beforeExperiment(o)
            % Handle beforeExperiment setup
            c.guiOn=true;
            c.mirror=Screen('OpenOffscreenWindow',o.cic.window,o.cic.screen.color.background);
            o.guiFeedBack=Screen('OpenOffScreenWindow',c.guiWindow,o.cic.screen.color.background);
            o.guiRect = o.cic.mirrorPixels;
            o.mirrorRect=mirrorRectCalc(o);
            o.guiText=Screen('OpenOffscreenWindow',-1, o.cic.screen.color.background,o.guiRect);
            slack=5;
            switch (o.xAlign)
                case 'right'
                    o.positionX=(o.cic.mirrorPixels(3))*1/2;
                case 'left'
                    o.positionX = o.cic.mirrorPixels(3)/2;
                otherwise
                    o.positionX=(o.cic.mirrorPixels(3))*1/2;
            end
            
            switch (o.yAlign)
                case 'center'
                    o.positionY=(o.cic.mirrorPixels(4)-o.cic.mirrorPixels(2));
                otherwise
                    o.positionY=50;
            end
            
            sampleText=Screen('TextBounds',o.guiText,'QTUVWqpgyid');
            o.textHeight=sampleText(4)-sampleText(2);
            o.feedX=o.cic.mirrorPixels(3)/2+2*slack;
            o.feedY=o.cic.mirrorPixels(4)*.5+slack;
            o.paramsBox=[o.cic.mirrorPixels(3)/2 0 o.cic.mirrorPixels(3) o.mirrorRect(4)];
            o.feedBox = [slack o.feedY-slack o.cic.mirrorPixels(3)-slack o.cic.mirrorPixels(4)-(4*slack)];
            o.eyetrackers=o.cic.pluginsByClass('eyetracker');
            o.behaviours=o.cic.pluginsByClass('behavior');
            o.writeToFeed('Started Experiment');
            
            
            
        end
        
        
        function beforeFrame(o)
            % Draw
            Screen('glLoadIdentity', o.cic.window);
            % TODO: use flipEvery setting that is currently in CIC but
            % should be here to skup a draw
            drawParams(o,o.cic);
            drawMirror(o,o.cic);
            
        end
        
        function beforeTrial(o)
            % Update
            updateParams(o);
            setupKeyLegend(o);
            setupBehavior(o);
        end
        
        function afterTrial(o)
            updateParams(o);
            drawParams(o);
            updateBehavior(o);
            drawMirror(o);
        end
        
        function afterExperiment(o)
            updateParams(o);
            drawParams(o);
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
        
        function setupKeyLegend(o)
            b=1;
%             nrKeys = numel(o.cic.keyboard.keys);
%             keyName = cell(1,nrKeys);
%             keyStroke = cell(1,nrKeys);
%             keyHelp= cell(1,nrKeys);
%             for a=o.cic.keyboard.keys
%                 keyName{b} = upper(a{:}.name);
%                 keyStroke{b}=KbName(o.cic.allKeyStrokes(b));
%                 keyHelp{b} = o.cic.allKeyHelp{b};
%                 b=b+1;
%             end
%             nrUKeys = numel(unique(keyName));
%             tmpstring = cell(1,nrUKeys);
%             for d=1:nrUKeys
%                 tmp=unique(keyName);
%                 tmpName=keyName(strcmp(keyName,tmp{d}));
%                 tmpStroke = keyStroke(strcmp(keyName,tmp{d}));
%                 tmpHelp = keyHelp(strcmp(keyName,tmp{d}));
%                 
%                 tmpstr=strcat('<',tmpStroke,{'> '},tmpHelp,'\n');
%                 tmpstring{d}=[tmpName{1},': \n',tmpstr{:} '\n'];
%             end
%             o.keyLegend = ['Keys: \n\n',tmpstring{:}];
%             DrawFormattedText(o.guiText,o.keyLegend,o.positionX,o.feedY,c.screen.color.text,[],[],[],o.spacing);
%         
        end
        
        function drawParams(o)
                Screen('DrawTexture',o.cic.guiWindow,o.guiText,[],[],[],0);
%             DrawFormattedText(win, tstring [, sx][, sy][, color][, wrapat][, flipHorizontal][, flipVertical][, vSpacing][, righttoleft][, winRect])
        end
        
        function updateParams(o)
            % Update the text with the current values of the parameters.
            o.paramText  = o.header;
            for i=1:numel(o.props)
                str=strsplit(o.props{i},'/');
                for j=1:numel(str)
                    tmp = getProp(c,str{j}); % getProp allows calls like c.(stim.value)
                    if isnumeric(tmp)
                        tmp = num2str(tmp(:)');
                    elseif islogical(tmp)
                        if (tmp);tmp = 'true';else ;tmp='false';end
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
            Screen('FillRect',o.guiText,o.cic.screen.color.background,o.paramsBox);
            DrawFormattedText(o.guiText, o.paramText, o.positionX,o.positionY, c.screen.color.text,o.nrCharsPerLine,[],[],o.spacing);
            
%           
        end
        
        function setupBehavior(o)
            o.tolerances=[];
            o.toleranceLine=[];
            if ~isempty(o.behaviours)
            for a=o.behaviours
                   if isa(a{:},'neurostim.plugins.fixate')
                       % if is a fixation dot, find the corners of the rect
                       % which the fixation tolerance allows
                       oval=[a{:}.X-a{:}.tolerance; a{:}.Y-a{:}.tolerance;a{:}.X+a{:}.tolerance;a{:}.Y+a{:}.tolerance];
                       % convert to pixel dimensions
                       oval=phys2Pix(o,oval);
                       o.tolerances=[o.tolerances oval];
                   elseif isa(a{:},'neurostim.plugins.saccade')
                      % find the line between the two fixation points
                      line = [a{:}.startX;a{:}.startY;a{:}.endX;a{:}.endY];
                      % convert to pixel dimensions
                      line=phys2Pix(o,line);
                      line=[line(1) line(2);line(3) line(4)];
                      o.toleranceLine=[o.toleranceLine line];
                   end
            end
            end
        end
        
        function shape=phys2Pix(o,v)
            [x1,y1]=o.cic.physical2Pixel(v(1),v(2));
            [x2,y2]=o.cic.physical2Pixel(v(3),v(4));
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
        
        function drawMirror(o)
            %drawBehavior(o)
            % draws any behavior tolerance circles.
            Screen('DrawTexture',o.cic.mirror,o.cic.window,[],[],[],0);
            if ~isempty(o.tolerances)
            Screen('FrameOval',c.mirror,[o.toleranceColor],o.tolerances,2);
            end
            if ~isempty(o.toleranceLine)
                Screen('DrawLines',c.mirror,o.toleranceLine',2,[o.toleranceColor]);
            end
            if c.frame>1 && ~isempty(o.eyetrackers)
                    [eyeX,eyeY]=o.cic.physical2Pixel(o.cic.eye.x,o.cic.eye.y);
                    xsize=30;
                    Screen('DrawLines',o.cic.mirror,[-xsize xsize 0 0;0 0 -xsize xsize],5,o.cic.screen.color.text,[eyeX eyeY]);
            end
            
            Screen('DrawTexture',o.guiText,o.cic.mirror,[o.cic.screen.xorigin o.cic.screen.yorigin  o.cic.screen.xorigin+c.screen.xpixels o.cic.screen.yorigin+o.cic.screen.ypixels],o.mirrorRect,[],0);
            Screen('FrameRect',o.guiText,o.cic.screen.color.text,o.mirrorRect);
        end
        
        function updateBehavior(o)
            %updateBehavior(o)
            %updates behavior circles
            o.tolerances=[];
            o.toleranceLine=[];
            if ~isempty(o.behaviors)
            for a=o.behaviors
                if isa(a{:},'neurostim.plugins.fixate')
                    oval=[a{:}.X-a{:}.tolerance; a{:}.Y-a{:}.tolerance;a{:}.X+a{:}.tolerance;a{:}.Y+a{:}.tolerance];
                    oval=phys2Pix(o,oval);
                    o.tolerances=[o.tolerances oval];
                elseif isa(a{:},'neurostim.plugins.saccade')
                    line = [a{:}.startX;a{:}.startY;a{:}.endX;a{:}.endY];
                    line=phys2Pix(o,line);
                    line=[line(1) line(2);line(3) line(4)];
                    o.toleranceLine=[o.toleranceLine line];
                end
            end
            end
        end
        
    end
end