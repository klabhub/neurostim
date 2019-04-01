classdef textFeedback < neurostim.plugins.feedback
    % Plugin to deliver on screen text feedback.
    
    properties
        % Internally this code calls  DrawFormattedText in PTB (via o.cic) all
        % parameters that can be set in the call to DrawFormattedText can
        % be set here (help DrawFormattedText).        
        left            = 'center'; % The sx parameter in PTB
        top             = 'center'; % The sy parameter in PTB
        wrapAt          = []% The wrapAt parameter in PTB
        flipHorizontal  = 0 % The flipHorizontal parameter in PTB
        flipVertical    = 0 % The flipVertical parameter in PTB
        vSpacing        = 1; % The vSpacing parameter in PTB
        rightToLeft     = 0; % The righttoleft parameter in PTB
        winRect         = []; % The rect to center/justify in- defaults to full screen.
    end
    
    methods (Access=public)
        function o=textFeedback(c,name)
            o=o@neurostim.plugins.feedback(c,name);
            o.winRect = [0 0 c.screen.xpixels c.screen.ypixels];
        end
        
        
    end
    
    methods (Access=protected)
        function chAdd(o,varargin)
            % This is called from feedback.add only, there the standard
            % parts of the item have already been added to the class.
            % Here we just add the sound specific arts.
            p=inputParser;
            p.StructExpand = true; % The parent class passes as a struct
            p.addParameter('text',[],@ischar);     %Waveform data, filename (wav), or label for known (built-in) file (e.g. 'correct')
            p.parse(varargin{:});
            %Store the text
            o.addProperty(['item', num2str(o.nItems) 'text'],p.Results.text);
        end
    end
    
    
    
    methods (Access=protected)        
        function deliver(o,itemNr)
            % Draw it directly on the screen.
            o.cic.drawFormattedText(o.(['item' num2str(itemNr) 'text']));
        end
    end
    
    
    
end