classdef pupilLabs < neurostim.plugin
    % Wrapper around the Pupil Labs Toolbox
    % (itself a wrapper for a Python library)
    %
    % Plugin to interact with the Pupil Labs eyetracker.
    % https://pupil-labs.github.io/realtime-network-api/
    %
    % Properties
    %   getSamples - if true, stores eye position/sample validity on every frame.
    %   getEvents - if true, stores eye event data in eyeEvts.
    %   eyeEvts - saves eyelink data in its original structure format.
    %
    % Commands:
    % You can execute an arbitrary set of Eyelink commands by specifying
    % them in the .commands field. For instance, to define your own
    % (random?) calibration routine:
    %
    % xy = rand(9,2);
    % c.eye.commands = {'generate_default_targets = NO',...
    %                   'calibration_samples = 9',...
    %                   'calibration_sequence = 0,1,2,3,4,5,6,7,8',...
    %                   ['calibration_targets =' xy ],...
    %                   'validation_samples = 9',...
    %                   'validation_sequence = 0,1,2,3,4,5,6,7,8',...
    %                   ['validation_targets =' xy]};
    %
    % The Commands cell array is also the way to change what is sent along
    % the TCP link from eyelink to neurostim or to change other Eyelink
    % settings.
    %
    %
    % NicPrice, 230623
    
    properties (SetAccess = private, GetAccess = public)
        %     dev; %@serial; % the serial port object
        %
        %     keys;% @cell;
    end % properties
    
    methods
        function o = pupilLabs(c,varargin) % c is the neurostim cic
            o = o@neurostim.plugin(c,'pupilLabs');
            
            % add properties (these are logged!):
            o.addProperty('URLhost','49.127.42.4:8080/','validate',@ischar);
        end
        
        function beforeExperiment(o)
            % this will throw a well-commented error if it can't connect and start recording. That seems
            % reasonable.
            r=pupil_labs_realtime_api('Command','start','URLhost',o.URLhost); %#ok<*NASGU> % start recording
            txt = [o.cic.paradigm ' ' o.cic.fullPath filesep o.cic.file];
            r=pupil_labs_realtime_api('Command','event','Event',txt,'URLhost',o.URLhost); % send paradigm and file name
            
        end
               
        function afterExperiment(o)
            r=pupil_labs_realtime_api('Command','save','URLhost',o.URLhost); % stop/save recording
        end
    
        function beforeTrial(o)
            % send text with current trial + time
            % need to work out how to timestamp things precisely
            txt = sprintf('TRIALID %d-%d', o.cic.condition, o.cic.trial);
            r=pupil_labs_realtime_api('Command','event','EventName',txt,'URLhost',o.URLhost); % send event
        end
    end
end