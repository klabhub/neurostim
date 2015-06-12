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
        yAlign@char = 'center';         % center
        spacing@double = .1;             % Space between lines
        nrCharsPerLine@double= 25;      % Number of chars per line
        font@char = 'Courier New';      % Font
        fontSize@double = 11;           % Font size
        
        props ={'file','paradigm','startTimeStr','nrConditions','condition','nrTrials','trial'}; % List of properties to monitor
        header@char  = '';              % Header to add.
        footer@char  = '';              % Footer to add.
        showKeys@logical = true;        % Show defined keystrokes
        updateEachFrame = false;        % Set to true to update every frame. (Costly; debug purposes only)
    end
    
    properties (SetAccess=protected)
        currentText@char = ''; %Internal storage for the current display
        keyLegend@char= '';      % Internal storage for the key stroke legend
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
    
    
    methods (Access = public)
        function o = gui
            % Construct a GUI plugin
            o = o@neurostim.stimulus('gui');
            o.listenToEvent({'BEFOREFRAME','AFTERTRIAL','AFTEREXPERIMENT','BEFOREEXPERIMENT','BEFORETRIAL'});
            o.on=0;
            o.duration =Inf;
        end
        
        function beforeExperiment(o,c,evt)
            % Handle beforeFrame and beforeTrial events
                    tmp = strcat(KbName(c.keyStrokes),'(',c.keyHelp,')');
                    o.keyLegend = ['Keys: ' tmp{:}];
        end
        function beforeFrame(o,c,evt)
                    % Draw
                    if (o.updateEachFrame); update(o,c);end
                    draw(o,c);
        end
        function beforeTrial(o,c,evt)
                    % Update
                    update(o,c);               
        end
        
        function afterTrial(o,c,evt)
            update(o,c);               
            draw(o,c);
        end
        
        function afterExperiment(o,c,evt)
            update(o,c);               
            draw(o,c);
        end
        
        
    end
    
    
    methods (Access =protected)
        
        function draw(o,c)
            % DrawFormattedText(win, tstring [, sx][, sy][, color][, wrapat][, flipHorizontal][, flipVertical][, vSpacing][, righttoleft][, winRect])
            Screen('TextFont',c.window, o.font);
            Screen('TextSize',c.window, o.fontSize);
            [~,~,bbox] = DrawFormattedText(c.window, o.currentText, o.xAlign,o.yAlign, WhiteIndex(c.window),o.nrCharsPerLine,[],[],o.spacing);
            % The bbox does not seem to fit... add some slack
            slack = 0.05;
            bbox = [1-slack 1-slack 1+slack 1+slack].*bbox;
            Screen('FrameRect',c.window,WhiteIndex(c.window),bbox);
        end
        function update(o,c)
            % Update the text with the current values of the parameters.
            o.currentText = o.header;
            for i=1:numel(o.props)
                tmp = getProp(c,o.props{i}); % getProp allows calls like c.(stim.value)
                if isnumeric(tmp)
                    tmp = num2str(tmp);
                elseif islogical(tmp)
                    if (tmp);tmp = 'true';else;tmp='false';end
                end
                o.currentText= cat(2,o.currentText,[o.props{i} ': ' tmp '\n']);
            end
            o.currentText = cat(2,o.currentText,o.keyLegend);
            o.currentText = cat(2,o.currentText,o.footer);
        end
    end
end