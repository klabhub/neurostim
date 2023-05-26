classdef scanbox <  neurostim.plugin
    % Class to interact with the ScanBox software controlling the neurolabware
    % two-photon microscope
    %
    % PROPERTIES
    %  ip - IP address of the scanbox
    %  port - port of the scanbox UDP listener [7000]
    % timeout - timeout for UDP commands [10]seconds.
    % root  - Root data folder where Scanbox should save its files.
    % blankITI - Set to true to turn off the laser/ acquisition during the ITI.
    %
    % BK -  Jan 2023.

    properties  (Transient)
        hUdp =[];  % Handle to the udpport object.
        shutdownDaq;  % Function called after grabbing stops
    end

    methods
       
        function delete(o)
            % Make sure the port is released
            o.hUdp =[]; % Remove the ref deletes it.
        end

        function o = scanbox(c)
            % Construct a scanbox plugin.
            o=o@neurostim.plugin(c,'scanbox'); % Fixed name 'popCoder'
            o.addProperty('fake',false);
            o.addProperty('ip',''); % IP address of machine running scanbox.
            o.addProperty('port',7000); % Default port
            o.addProperty('timeout',10); % 10 s
            o.addProperty('root',''); % Root folder on the ScanBox
            o.addProperty('blankITI',false); % Set to true to stop the laser during the ITI.
            o.addProperty('grab',true,'sticky',true); % Set to false to not grab (i.e. save) on scanbox.
            o.addProperty('waitTime',2); % Seconds to wait after sending a command to scanbox (Except Blank command)
            % Properties used to log events
            o.addProperty('file',[]); 
            o.addProperty('grabbing',[]); 
            o.addProperty('blank',[]); 
            if isempty(which('udpport'))
                error('The scanbox plugin relies on the Instrument Control Toolbox for its udpport function. Please install it first.')
            end
        end

        function open(o)
            % Open a local IDP port to use later to send messages to the
            % remote scanbox host.
            if o.fake;return;end
            try
                o.hUdp =udpport("byte", 'LocalPort', o.port,"Timeout",o.timeout);
                configureTerminator(o.hUdp,"LF");
            catch me
                if strcmpi(me.identifier,'instrument:interface:udpport:ConnectFailed')
                    fprintf(2,'Could not open a UDP port %d. clear all will likely fix it.\n',o.port)
                    return;
                else
                    rethrow(me)
                end
            end
        end

        function close(o)
            % CLose the local UDP port
            if o.fake;return;end
            if ~isempty(o.hUdp)
                flush(o.hUdp);
                o.hUdp = []; % Removes the last reference and should delete it
            end
        end

        function beforeExperiment(o)
            % Setup the folder/filename in ScanBox to match Neurostim
            % convention
            open(o);
            [rt,fldr,fName] = namingConvention(o);
            send(o,'D',rt) ; % Directory (root/year/mo/day)
            send(o,'A',fldr); % A is the animal ID : ScanBox creates a folder per animal.
            send(o,'U',fName); % Somewhat of a duplication, but not sure that SB can handle an empty
            send(o,'E','1');  % If left empty, scanbox will add _nan. Adding _1 instead
            o.file = true;
            pause(o.waitTime);
        end

        function beforeTrial(o)
            if  o.cic.trial ==1 && o.grab
                send(o,'G'); % Start grabbing
                o.grabbing = true;
                pause(o.waitTime);
            end
            if o.blankITI
                send(o,'L','1'); % Laser on
                o.blank = false;
            end
        end

        function afterTrial(o)
            if o.blankITI
                send(o,'L','0'); % Laser off
                o.blank = true;
            end
        end


        function afterExperiment(o)
            % Stop
           if o.grab 
               send(o,'S'); % Stop grabbing
               o.grabbing = false;
               pause(o.waitTime);
           end
           close(o);
           if ~isempty(o.shutdownDaq)
               shutdown(o.cic.mdaq); % Call the shutdown function.
           end
        end

        function [rt,fldr,fname] = namingConvention(o)
            %% Setup folder/filename
            % Create a folder with the year/mo/day/filename format under
            % the root folder on the ScanBox. Scanbox will save all its
            % files in that folder, which avoids potential naming conflicts
            % (as it creates sbx as well as .mat files).
            % The sbx file will be:
            % root/year/month/day/subject.paradigm.starttime/subject.paradigm.starttime.sbx
            [folder,filename] = fileparts([o.cic.fullFile '.mat']);
            rt =strrep(folder,strrep(o.cic.dirs.output,'/','\'),o.root);
            fldr= filename;
            fname= filename;
        end
    end
    methods (Access=protected)
        function send(o,tag,value)
            % Send [tag value] to the remote scanbox
            arguments
                o (1,1)
                tag (1,1) char
                value {mustBeText} = ''
            end
            if o.fake
                fprintf('Fake: Sending %s to %s:%d\n',[tag value],o.ip,o.port)
            else
                writeline(o.hUdp,[tag value],o.ip,o.port);
            end
        end
    end

    methods (Static)
        function o = debug(mode)
            % Testing...
            arguments
                mode {mustBeMember(mode,["readback","fake"])} = 'local'
            end
            o = scanbox(neurostim.cic);
            switch (mode)
                case 'readback'
                    % Fake a scanbox listener on port 7000 the localhost
                    echoudp("off");
                    echoudp("on",7000)
                    o.cic.subject = 'M001';
                    o.cic.paradigm = 'paradigm';
                    o.ip = 'localhost';
                    % This would be setup in the run/experiment file (once)
                    o.root = 'd:\sibel\';

                    open(o);
                    [rt,fldr,fname]= namingConvention(o);
                    send(o,'D',rt) ;
                    fprintf('Root: \t %s \n',readline(o.hUdp));
                    send(o,'A',fldr);
                    fprintf('Folder: \t %s \n',readline(o.hUdp));
                    send(o,'U',fname);
                    fprintf('File: \t %s \n',readline(o.hUdp));
                    send(o,'E','');             % Empty.
                    fprintf('E: \t %s \n',readline(o.hUdp));
                    echoudp("off")
                    close(o)

                case 'fake'
                    echoudp("off");
                    echoudp("on",7000)
                    o.cic.subject = 'M001';
                    o.cic.paradigm = 'paradigm';
                    o.ip = 'localhost';
                    % This would be setup in the run/experiment file (once)
                    o.root = 'd:\sibel\';
                    o.fake = true;
                    o.blankITI = true;
                    % Simulate what would happen in an experiment
                    beforeExperiment(o); % Setup connection with DAQ
                    pause(0.1);
                    for i=1:3
                        beforeTrial(o);  % Send the signal to the hardware.
                        pause(1);
                        afterTrial(o);
                        pause(1);
                    end
                    afterExperiment(o); % Close down
                    echoudp("off")
            end

        end

    end
    %% GUI Functions
    methods (Access= public)
        function guiSet(o,parms)
            %The nsGui calls this just before the experiment starts;
            % o = plugin
            % p = struct with settings for each of the elements in the
            % guiLayout, named after the Tag property
            %
            if strcmpi(parms.onOffFakeKnob,'Fake')
                o.fake=true;
            else
                o.fake =false;
            end
            o.blankITI = parms.blankITI;
        end
    end

    methods (Static)
        function guiLayout(pnl)
            % Add plugin specific elements
            h = uilabel(pnl);
            h.HorizontalAlignment = 'left';
            h.VerticalAlignment = 'bottom';
            h.Position = [110 39 60 22];
            h.Text = 'Blank ITI';

            h = uicheckbox(pnl,'Tag','blankITI');
            h.Position = [130 17 22 22];
            h.Text = '';
            h.Value=  false;
            h.Tooltip = 'Check to blank the laser in the ITI.';

        end
    end

end
