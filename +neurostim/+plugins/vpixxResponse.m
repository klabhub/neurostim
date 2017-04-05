classdef vpixxResponse < neurostim.plugins.behavior
    % Behavior subclass for receiving a ResponsePixx keyboard response.
    %
    % Set:
    % keys -        cell array of key characters, e.g. {'a','z'}
    % keyLabel -    cell array of strings which are the labels for the keys declared
    %               above; in the same order. These are logged in o.responseLabel when the key is
    %               pressed.
    % correctKey -  function that returns the index (into 'keys') of the correct key. Usually a function of some stimulus parameter(s).
    %
    
    properties (Constant)
        NRBUTTONS = 5;
        RED         = hex2dec('0000FFFE');
        GREEN       = hex2dec('0000FFFB');
        WHITE       = hex2dec('0000FFEF'); % TODO : not sure about these values
        YELLOW      = hex2dec('0000FFFD');
        BLUE        = hex2dec('0000FFF7');
    end
    properties
        responded@logical=false;
        isMarkerSet@logical =false;
        markerTime=[];
        allButtons = [o.RED o.BLUE o.GREEN o.YELLOW o.WHITE];
    end
    
    methods (Access = public)
        function o = vpixxResponse(c)
            if ~exist('Datapixx',3)
                error(['Datapixx mex file not found. Please install it first']);
            end
            
            o = o@neurostim.plugins.behavior(c,'vpixxResponse');
            o.continuous = false;
            o.addProperty('brightness',zeros(1,o.NRBUTTONS),false);
            o.addProperty('correctKey',[],'validate',@isnumeric);
            
            o.addProperty('correct',false);
            o.addProperty('pressed',[]);
            o.addProperty('oncePerTrial',false);
            o.addProperty('buttonPress',[]);
            o.addProperty('marker',false);
        end
        
        function beforeFrame(o)
            if ~o.isMarkerSet && o.marker
                % The marker is now true.
                Datapixx('SetMarker');
                Datapixx('EnableDinDebounce');      % Filter out button bounce
                Datapixx('SetDinLog');              % Configure logging with default values
                Datapixx('StartDinLog');
                Datapixx('RegWrRdVideoSync');        % Mark and Start on the next flip TODO: check that does not busywait
                o.isMarkerSet = true;
                o.markerTime = Datapixx('GetMarker');
            end
            
            
            
            
        end
        
        function beforeTrial(o)
            beforeTrial@neurostim.plugins.behavior(o); % Call parent
            o.responded = false;   % Update responded for this trial
        end
        
        function afterTrial(o)
            readVpixxLog(o);
        end
        
        function beforeExperiment(o)
            Datapixx('Open');
            Datapixx('StopAllSchedules');
            Datapixx('RegWrRd');    % Synchronize DATAPixx registers to local register cache
            
            %% Set button brightness
            Datapixx('SetDinDataDirection', hex2dec('1F0000'));
            Datapixx('SetDinDataOut', hex2dec('1F0000'));
            Datapixx('SetDinDataOutStrength', 0);   % Set brightness of buttons to be 0 by default
            zero = '0';
            for b=1:numel(o.brightness)         % Set requested brightness
                if o.brightness(b)>0
                    address = zero(ones(1,24)); % 24 bit register
                    address(b) = '1';
                    Datapixx('SetDinDataDirection', bin2dec(address));
                    Datapixx('SetDinDataOut', bin2dec(address));
                    Datapixx('SetDinDataOutStrength', o.brightness(b));
                end
            end
            
            
        end
        
        function afterExperiment(o)
            Datapixx('StopDinLog');
            Datapixx('RegWrRd');
            Datapixx('Close');
        end
        
        
        
        
        
    end
    
    methods (Access=protected)
        
        function readVpixxLog(o)
            Datapixx('RegWrRd');
            status = Datapixx('GetDinStatus');
            if (status.newLogFrames > 0)
                [data,time] = Datapixx('ReadDinLog');
                rt = time -o.markerTime;
                buttons = false(status.newLogFrames,o.NRBUTTONS);
                for i = 1:status.newLogFrames
                    buttons(i,:) = bitand(data(i),o.allButtons);
                end
            end
            % Now store this
            o.buttonPress = [buttons rt];
            
            
            
        end
        
        
        function inProgress = validate(o)
            inProgress = o.inProgress;
        end
        
        function responseHandler(o,key)
            
            if o.enabled && (~o.responded || ~o.oncePerTrial)
                %Which key was pressed (index, and label)
                o.pressedInd = find(strcmpi(key,o.keys));
                o.pressedKey = o.keyLabels{o.pressedInd};
                
                %Is the response correct?
                if ~isempty(o.correctKey)
                    o.correct = o.pressedInd == o.correctKey;
                else
                    %No correctness function specified. Probably using as subjective measurement (e.g. PSE)
                    o.correct = true;
                end
                
                %Set flag so that behaviour class detects completion next frame
                o.inProgress = true;
                o.responded = true;
            end
        end
        
    end
end