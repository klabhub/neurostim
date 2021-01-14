classdef displayPP < neurostim.plugins.daq
    % Wrapper for the CRS Display++ (i.e. displayPP) Digital I/O functionality.
    %
    % See also: BitsPlusPlus, plugins.datapixx
    % https://www.crsltd.com/tools-for-vision-science/visual-stimulation/bits-sharp-visual-stimulus-processor/nest/product-support#npm
    % This needs a CRS account
    
    % 2020-01-14 - NicP
    
    % Add the following to your rig-config
    % % add the Display++ for digital output - sends trialData at start of
    % first frame of each trial
    % neurostim.plugins.displayPP(c);
    % c.displayPP.trialData = 1; % (should be range 1-255)
    
    methods
        function o = displayPP(c,varargin) % constructor
            o = o@neurostim.plugins.daq(c,'displayPP');
            
            %TODO Check that ScreenType is Display++ and make sure Output is enabled
            %       if ~Datapixx('Open')
            %         error('Datapixx plugin added but no device could be found.');
            %       end
            
            o.addProperty('trialData',[]); % digital output data (1-255) to send on first frame of each trial
        end
        
        %     function beforeExperiment(o)
        %     end
        
        function afterExperiment(o)
            % clears all bits to 0
            BitsPlusPlus('DIOCommand', c.mainWindow, 1, 255, zeros(1,248), 0, 1, 2);
        end
        
        %     function beforeTrial(o)
        % start of trial includes iti, so we send our first digital line on
        % frame 1 using beforeFrame
        %     end
        
        function afterTrial(o)
            afterTrial@neurostim.plugins.daq(o); % parent method
        end
        
        function beforeFrame(o)
            if o.cic.frame ~= 1
                return
            end
            
            % send trialData
            myData = trialData*ones(1,10); % 10 x 100us steps should give us 1 ms.
            BitsPlusPlus('DIOCommand', c.mainWindow, 1, 255, myData, 0, 1, 2);
            
                % BitsPlusPlus('DIOCommand', Scr.w, 1, 255, triggerData, 0);
    % BitsPlusPlus('DIOCommand', window, repetitions, mask, data, command [, xpos, ypos]);
    % repetitions - number of flips to trigger for.
    
    % Setting the Mask and Data
    % Data is an array of decimal values representing 16-bit binary strings, indicating the status of
    % each pin. It is important to note that using this function, data must be a 248 element vector,
    % even though the number of 100 microsecond packets will be less than this for most screens. It
    % is therefore important still to calculate the number of such packets in one frame and not to
    % exceed this, instead setting any unused slots to 0. Remember the "Trigger out" is on bit 16 so
    % to set it high you should prvide the decimal 32768:.
    % >> bin2dec('1000000000000000')
    
    % Example: 1ms trigger
    % Therefore, to create a trigger that will apply to the first 8 pins (‘11111111’, 255), but only cause
    % pin 1 to pulse (‘00000001’, 1), for 1ms for the next Screen(‘Flip’, windowHandle) only:
    % >> myData = ones(1,10);
    % >> BitsPlusPlus(‘DIOCommand’, windowHandle, 1, 255, myData, 0, 1, 2);
    % uses second row (default is third row)

        end
    end
    
    methods
        function reset(o)
            BitsPlusPlus('DIOCommand', c.mainWindow, 1, 255, zeros(1,248), 0, 1, 2);
        end
    end
    
end % classdef
