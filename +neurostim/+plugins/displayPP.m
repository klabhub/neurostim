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
        
%              function beforeExperiment(o)
%              end
        
        function afterExperiment(o)
            % clears all bits to 0
            BitsPlusPlus('DIOCommand', o.cic.mainWindow, 1, 255, zeros(1,248), 0, 1, 2);
        end
        
        %     function beforeTrial(o)
        % start of trial includes iti, so we send our first digital line on
        % frame 1 using beforeFrame
        %     end
        
        function afterTrial(o)
            afterTrial@neurostim.plugins.daq(o); % parent method
        end
        
        function beforeFrame(o)
            if o.cic.frame ~= 1 % || o.cic.frame >2
%             tOn = '@o.cic.sq.on';
%             if o.cic.frame ~= o.cic.sq.on % start with a known stimulus definition before adding a property to track a defined stimulus
                return
            end
            
            % send trialData
            %             myData = [o.trialData*ones(1,50) zeros(1,248-50)]; % 10 x 100us steps should give us 1 ms. Need 248 entries.
            %             BitsPlusPlus('DIOCommand', o.cic.mainWindow, 1, 255, myData, 0, 1, 2);
            % CRS timing is in 100 us blocks. We need to define 248 blocks (~3 frames). 
            highTime = 1.0; % time to be high in the beginning of the frame (in 100 us steps = 0.1 ms steps)
            lowTime = 24.8-highTime; % followed by x msec low (enough to fill the rest of the frame high + low = 24.8 ms)
%             dat = [repmat(bin2dec('10000000001'),highTime*10,1);repmat(bin2dec('00000000000'),lowTime*10,1)]';
%             BitsPlusPlus('DIOCommand', o.cic.mainWindow, 2, 2047, dat, 0);
            dat = [repmat(32768+255,highTime*10,1); zeros(lowTime*10,1)]';
            BitsPlusPlus('DIOCommand', o.cic.mainWindow, 2, 65535, dat, 0);


% !?! currently need to send message on 2 frames to get anything
           % to work
            
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
            BitsPlusPlus('DIOCommand', o.cic.mainWindow, 1, 255, zeros(1,248), 0, 1, 2);
        end
        
        
        
        function digitalOut(o,channel,value,varargin)
            % Write digital output.
            %
            %   o.digitalOut(channel,value[,duration])
            %
            % If value is logical, channel should contain a bit number (1-24) to
            % set or clear. Setting channel to 0 sets or clears all 24 bits of
            % the output simultaneously, e.g.,
            %
            %   o.digitalOut(3,true) will set bit 3 HIGH,
            %   o.digitalOut(0,false) clears all 24 digital output bits,
            %
            % If value is numeric, channel indicates which byte of the output to
            % write the value to. For channels 1-3, the 8 least significant
            % bits of value are written to the corresponding byte (1-3) of the
            % output. If channel is 0, the 24 least significant bits of value
            % are written directly to the output, e.g.,
            %
            %   o.digitalOut(1,3) will set bits 1 and 2 HIGH and clear bits 3-8,
            %   o.digitalOut(0,3) will set bits 1 and 2 HIGH and clear bits 3-24,
            %   o.digitalOut(0,hex2dec('F6E8)) will write 0x00F6E8 to the digital output.
            %
            % The optional third argument, duration, sets or clears the specified
            % bits for the requested duration before restoring the existing state
            % of the output lines.
            
        end
        
        function value = digitalIn(o,channel)
            % Read digital channel now.
            %
            %
            error('Digital input not implement for Display++');
        end
        
        function analogOut(o,channel,value,varargin)
            % Write analog output.
            %
            %   o.digitalOut(channel,value[,duration])
            %
            error('Analog output is not implemented yet.');
        end
        
        function [value,ref] = analogIn(o,channel)
            % Read analog channel now.
            %
            %   [value,ref] = o.analogIn([channel])
            %
            error('Analog output not implement for Display++');
            
        end
        
    end
    methods (Access = protected)
    end % protected methods
    
    
end % classdef
