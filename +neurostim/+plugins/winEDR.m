classdef winEDR < neurostim.plugin
    % Plugin to control the winEDR recording software developed by John
    % Dempster at Strathclyde University.
    % https://spider.science.strath.ac.uk/sipbs/software_ses.htm
    %
    % This plugin:
    % Connects to an existing instance of WinEDR, or opens one.
    % Sets the output file name to match the Neurostim output file, 
    % but with the .edr extension)  (beforeExperiment)
    % Starts recording in WinEDR  (beforeExperiment)
    % Monitors that recording is still ongoing (beforeTrial) and terminates
    % if WinEDR stopped recording.
    % Stops recording in WinEDR (afterExperiment).
    % Closes WinEDR (if it wasn't open already before starting the
    % Neurostim experiment).
    % 
    % PROPERTIES
    %  folder - Name of the data folder on the WinEDR machine 
    %  host - Host name or IP address of the WinEDR machine
    % 
    %  file  - Filename of the WinEDR file (set automatically)
    %  recording - Status log: 0 = idle, 1= seal test, 2= recording, 
    % 
    % Use winEDR.debug to test.
    % 
    % This plugin uses the WinEDR COM automation object.
    % Use WinEDR version 3.9.9 or later.
    % After running the WinEDR installer (as administrator), run
    % winedr.exe /regserver  to register the automation server.
    %
    % Running WinEDR on a computer that is not running Neurostim may
    %  be possible using DCOM (using the .host property) but this has not
    %  been tested yet.
    %
    % BK -  Jan 2022

    properties (Transient)
        hWinEDR; % Handle to the COM Server
    end
    properties (Dependent)
        status; % Current status of WinEDR
        edrFile; % Output file
    end

    methods  %get/set
        function v= get.status(o)
            if isempty(o.hWinEDR)
                v = 0;
            else
                v = o.hWinEDR.Status;
            end
        end

        function v = get.edrFile(o)
             if isempty(o.folder)
                fld = fileparts(o.cic.fullFile);
            else
                fld = o.folder;
            end
            if isempty(o.file)
                fl = o.cic.file;
            else
                fl = o.file;
            end
            v  = fullfile(fld,[fl '.edr']);
        end

    end
    methods
        function o = winEDR(c)
            %winEDR - Contruct a winEDR plugin
            o=o@neurostim.plugin(c,'winEDR');
            try
                o.hWinEDR = actxserver('winedr.auto');
            catch me
                error(['Could not COM connect to WinEDR. Did you run winedr.exe /regserver after installation? (Message: ' me.message])
            end

            addProperty(o,'folder','');
            addProperty(o,'host','');
            addProperty(o,'file','');
            addProperty(o,'recording',[]);

        end

        function beforeExperiment(o)
           
            try
                % There is an (undocumented) CLoseFile() function. Should it be
                % called before deleting com?
                CloseFile(o.hWinEDR);    
                NewFile(o.hWinEDR,o.edrFile);
            catch me
                o.cic.error('STOPEXPERIMENT',sprintf('Failed to create EDR output file %s (Message: %s)',o.edrFile,me.message));
            end
            StartRecording(o.hWinEDR);
            o.recording= o.status;
        end

        function beforeTrial(o)
            o.recording = o.status;
            if o.recording ==0
                o.cic.error('STOPEXPERIMENT','WinEDR stopped recording');
            end
        end

        function afterExperiment(o)
            StopRecording(o.hWinEDR);
            o.recording= o.status;
           
            delete(o.hWinEDR); % Delete the COM object 
        end


    end


    methods (Static)       
        function o = debug(hst)
             % Builtin tool for debugging
            if nargin <1
                hst='localhost';
            end
            c= neurostim.cic;
            c.subject = '0';
            o = winEDR(c);
            o.host = hst;
            beforeExperiment(o);
            for i=1:5
                beforeTrial(o)
            end
            afterExperiment(o);
        end
    end
end