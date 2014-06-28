classdef debug < neurostim.plugin
    % Simple plugin used for debugging only:
    % n = move to next trial
    % e = dont clear.
    methods
        function o = debug
            o = o@neurostim.plugin('debug');
            listenToKeyStroke(o,KbName('n'),'Next Trial');
            listenToKeyStroke(o,KbName('e'),'Toggle Erase');
            listenToKeyStroke(o,KbName('c'),'Toggle Cursor');
        end
        
        % handle the key strokes defined above
        function keyboard(o,key,time)
            switch upper(key)
                case 'N'
                    % End trial immediately and move to the next
                    o.nextTrial;
                case 'E'
                    % Toggle the 'clear'ing of the window.
                    o.cic.clear = 1-o.cic.clear;
                case 'C'
                    % Toggle cursor visibility
                    if o.cic.cursorVisible
                        o.cic.cursor = -1;
                    else
                        o.cic.cursor= 'Arrow';
                    end
                    
            end
        end
    end
end