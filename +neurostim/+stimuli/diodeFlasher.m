classdef diodeFlasher < neurostim.stimulus
    % Special stimulus to display a small square in one of the screen
    % corners whenever an important stimulus in an experiment turns on (or
    % off). This flash can be recorded with a photodiode and stored using
    % some external DAQ to get an accurate assement of the physical onset
    % time of the stimulus.
    %
    % In an experiment with a photodiode, you want only two states; below
    % photodiode threshold (.lowColor)  and one above (.highColor). 
    % In most experiments the screen goes to the background color during
    % the ITI.
    % If this background color triggers the diode, you woudl get multiple detections
    % in each trial (and possibly no detection of stimulus onset). To avoid
    % this, the diodeFlasher by default sets cic.itiClear to false, such
    % tha tthe lowCOlor will be shown (in the diodeFlasher location)
    % throughout the ITI. If this causes problems in your experiment
    % (because other stimuli need to be turned off during the ITI and you
    % have no other way (e.g. by using their .duration) to achieve this,
    % then you can set the diodeFlasher.itiClear =true  (but then you'll
    % need a background color that does not trigger the diode).
    % EXMPLE:   
    % To track the onset of a stimulus called 'grating'
    % fl = stimuli.diodeFlasher(c,'grating')
    % and then set one or more of the properties of fl: 
    %
    % location 'sw','nw', 'ne' 'se' - corners of the screen
    % size - size of the flasher in fractions of the screen.
    % whenOff- set to true to flahs the highColor when the targetStimulus
    %           is off (i.e. trigger on stimulus offset).
    % highColor - color of the flasher square when the targetStimulus is
    %               'on'
    % lowColor  - color of the flasher sqyare when the targetStiulus i off.
    % itiClear - Flag to clear to the background color during the ITI (i.e.
    % it will set cic.itiClear. The default is false so that the flasher has
    % a defined color during the ITI (lowColor).
    %
    % Internal bookkeeping properties:
    % stimIsOn - internal flag signalling the state of the targetStimulus
    % targetStimulus - name of the stimulus whose onset/offset changes the
    % state of the diodeFlasher.
    % 
    % BK Mar 2020
    
    properties  (Transient)
        diodePosition;
        loc_location;
        loc_size;
        loc_whenOff;
        loc_lowColor;
        loc_highColor;
        targetStimIsOn;
    end
    
    methods
        
        function o = diodeFlasher(c,targetStimulus)
            o=o@neurostim.stimulus(c,'diodeFlasher');
            o.addProperty('location','sw','validate',@ischar);
            o.addProperty('size',0.05,'validate',@isnumeric);
            o.addProperty('whenOff',false,'validate',@islogical);
            o.addProperty('highColor',[1 1 1],'validate',@isnumeric);
            o.addProperty('lowColor',[],'validate',@isnumeric);            
            o.addProperty('targetStimulus',targetStimulus,'validate',@ischar);
            o.addProperty('itiClear',false,'validate',@islogical);
            o.duration = inf; % Keep low color during iti
            o.targetStimIsOn = false; 
        end
        
        function setStimulusState(o,state)
            % This function is called from the target stimulus. Because cic ensures
            % that the diodeFlasher is always processed last
            % (cic.pluginOder), this state will be used before the frame
            % that triggered the state change is drawn.
            o.targetStimIsOn = state;
        end
        
        function beforeExperiment(o)
            if ~hasStimulus(o.cic,o.targetStimulus)
                o.cic.error('STOPEXPERIMENT',['The targetStimulus ' o.targetStimulus ' for the diodeFlasher does not exist']);
                return
            end
            
            o.cic.(o.targetStimulus).diode = o; % Place a handle to diodeFlasher in the targetStimulus
            % Determine position
            pixelsize=o.size*o.cic.screen.xpixels;
            switch lower(o.location)
                case 'ne'
                    o.diodePosition=[o.cic.screen.xpixels-pixelsize 0 o.cic.screen.xpixels pixelsize];
                case 'se'
                    o.diodePosition=[o.cic.screen.xpixels-pixelsize o.cic.screen.ypixels-pixelsize o.cic.screen.xpixels o.cic.screen.ypixels];
                case 'sw'
                    o.diodePosition=[0 o.cic.screen.ypixels-pixelsize pixelsize o.cic.screen.ypixels];
                case 'nw'
                    o.diodePosition=[0 0 pixelsize pixelsize];
                otherwise
                    error(['Diode Location ' o.location ' not supported.'])
            end
            if isempty(o.lowColor)
                % Default to the background color.
                o.lowColor = o.cic.screen.color.background;
            end
            
            % By default the iti should not be cleard so that the
            % assigned color (low or high) is kept during the ITI (and
            % a false trigger by the background color is avoided)
            % But the user can overrule the itiClear
            o.cic.itiClear = o.itiClear;
        end
        
        function beforeFrame(o)
            Screen('glLoadIdentity', o.window); % This code is in pixels to have the same size on the screen always
            if xor(o.loc_whenOff,o.targetStimIsOn)
                % Target stimulus is on, and whenOff is false, or target
                % stimulus is off and whenOff is true: show the flash
                % (highColor)
                Screen('FillRect',o.window,o.loc_highColor,o.diodePosition);
            else
                % Show lowColor 
                Screen('FillRect',o.window,o.loc_lowColor,o.diodePosition);
            end
        end
        
        
    end
end

