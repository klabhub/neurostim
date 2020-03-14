classdef diodeFlasher < neurostim.stimulus
    % Special stimulus to display a small square in one of the screen
    % corners whenever an important stimulus in an experiment turns on (or
    % off). This flash can be recorded with a photodiode and stored using
    % some external DAQ to get an accurate assement of the physical onset
    % time of the stimulus.
    %
    % location 'sw','nw', 'ne' 'se' - corners of the screen
    % size - size of the flasher in fractions of the screen.
    % whenOff- set to true to flahs the highColor when the targetStimulus
    %           is off (i.e. trigger on stimulus offset).
    % highColor - color of the flasher square when the targetStimulus is
    %               'on'
    % lowColor  - color of the flasher sqyare when the targetStiulus i off.
    % stimIsOn - internal flag signalling the state of the targetStimulus
    % targetStimulus - name of the stimulus whose onset/offset changes the
    % state of the diodeFlasher.
    % itiClear - Flag to clear to the background color during the ITI (i.e.
    % it will set cic.itiClear. The default is false so that the flasher has
    % a defined color during the ITI (lowColor).
    %
    % BK Mar 2020
    
    properties  (Transient)
        diodePosition;
        loc_location;
        loc_size;
        loc_whenOff;
        loc_lowColor;
        loc_highColor;
    end
    
    methods
        
        function o = diodeFlasher(c,targetStimulus)
            o=o@neurostim.stimulus(c,'diodeFlasher');
            o.addProperty('location','sw','validate',@ischar);
            o.addProperty('size',0.05,'validate',@isnumeric);
            o.addProperty('whenOff',false,'validate',@islogical);
            o.addProperty('highColor',[1 1 1],'validate',@isnumeric);
            o.addProperty('lowColor',[],'validate',@isnumeric);
            o.addProperty('stimIsOn',false,'validate',@isnumeric);
            o.addProperty('targetStimulus',targetStimulus,'validate',@ischar);
            o.addProperty('itiClear',false,'validate',@islogical);
            o.duration = inf;
        end
        
        function setStimulusState(o,state)
            % This function is called from the target stimulus. Because cic ensures
            % that the diodeFlasher is always processed last
            % (cic.pluginOder), this state will be used before the frame
            % that triggered the state change is drawn.
            o.stimIsOn = state;
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
            if xor(o.loc_whenOff,o.stimIsOn)
                % Target stimulus is on, and whenOff is false, or target
                % stimulus is off and whenOff is true: show the flash
                Screen('FillRect',o.window,o.loc_highColor,o.diodePosition);
            else
                % Show background
                Screen('FillRect',o.window,o.loc_lowColor,o.diodePosition);
            end
        end
        
        
    end
end

