classdef viewpoint < neurostim.plugins.eyetracker
  % Wrapper for the Viewpoint eye tracker from Arrington Research.
  %
  % Properties:
  %
  %   getSamples - if true, stores eye position/sample validity on every frame.
  %   getEvents - if true, stores eye event data in eyeEvts.
  %   eyeEvts - saves Viewpoint data in its original structure format.
  %
  %   doTrackerSetup - do setup before next trial (default: true).
  %   doDriftCorrect - do drift correction before next trial (default: false).
  %
  %   ipAddress - IP address of the remote Viewpoint PC.
  %   port - network port on the remote Viewpoint PC.
  %
  % Optional properties:
  %
  %   You can enable automatic retrieval of the .vpx data file from the remote
  %   Viewpoint PC by providing ssh credentials as follows:
  %
  %   ssh.username - username for ssh/scp.
  %   ssh.privateKey - private key (file name) for ssh/scp.
  %
  %   Note that this requires David Freedman's matlab-ssh2 package, available
  %   from https://github.com/davidfreedman/matlab-ssh2) and that ssh/scp is
  %   enabled on the remote Viewpoint PC.
  %
  % Commands:
  %
  %   You can pass an arbitrary command sequence to Viewpoint by adding
  %   them to the .command property. These commands are executed before the
  %   experiment starts, but *after* the default configuration commands and
  %   so can overide the default behaviour.
  %
  %   e.g., c.eye.command = {'calibration_Points 9'}; will request
  %   Viewpoint's 9 point calibration pattern, or you could specify a
  %   custom calibration pattern using something like:
  %
  %   cmd = {'calibration_Points 9', ...
  %          'calibration_PointLocationMethod Custom', ...
  %          'calibration_PresentationOrder Sequential'};
  %   for ii = 1:9
  %     cmd = cat(2,cmd,sprintf('calibration_CustomPoint %d %.1f %.1f',ii,rand(1),rand(1));
  %   end
  %   c.eye.command = cmd;
  %
  % Keyboard hotkeys:
  %
  %   F8  - do tracker setup/calibration before next trial
  %   F9  - do drift correction immediately (assumes a target is present
  %         at (0,0). Press the space bar to indicate correct fixation, or
  %         press Esc to abort drift correction and continue.
  %
  %   F10 - do drift correction before the next trial. (Viewpoint will draw
  %         a target).
  %
  % See also: neurostim.plugins.eyetracker
  
  % 2018-04-09 - Shaun L. Cloherty <s.cloherty@ieee.org>
    
  properties
    vp;
        
    % custom viewpoint config commands...
    %
    % e.g., 'calibration_RealRect 0.2 0.2 0.8 0.8'
    %       'gazeSpace_MouseAction Simulation' for debugging?
    commands = {};
        
    vpxPath = ''; % path to save .vpx file(s) (on the remote Viewpoint PC)

    vpxFile = 'test.vpx';
        
    getSamples = true;
    getEvents = false;
  
    doTrackerSetup = true; % do setup/calibration before the next trial
    doDriftCorrect = false; % do drift correction before the next trial
    
    % ip address and port of the remote Viewpoint PC
    ipAddress = '192.168.1.2';
    port = 5000;
    
    % ssh settings
    ssh = struct('username',[],'privateKey',[]);
  end
    
  properties (Dependent)
    isConnected;
    isRecording;
  end
    
  methods % get/set methods
    function v = get.isRecording(~)
      % check if viewpoint data file is open and *not* paused
      v = Viewpoint('checkRecording');
    end
        
    function v = get.isConnected(~)
      % check if viewpoint is running
            
      % FIXME: see p.25 of the Viewpoint toolbox documentation. what are the possible return values...?

      v = Viewpoint('isConnected');
    end
  end
  
  methods % public methods
    function o = viewpoint(c,varargin)
      % confirm that the Viewpoint toolbox is available...
      assert(exist('Viewpoint.m','file') == 2, ...
                   'The Viewpoint toolbox is not available?');
               
      o = o@neurostim.plugins.eyetracker(c);
      o.addKey('F8','ViewpointSetup');
      o.addKey('F9','QuickDriftCorrect');
      o.addKey('F10','FullDriftCorrect');
            
      o.addProperty('eyeEvts',struct);
      o.addProperty('clbTargetInnerSize',[]); % inner diameter (?) of annulus
      
%       o.addProperty('clbType','AUTO',@(x) ismember(upper(x),{'AUTO','MANUAL'}));
%       o.clbMatrix = [ o.cic.screen.xpixels,    0,                      0.0; ...
%                       0,                       o.cic.screen.ypixels,   0.0; ...
%                      -o.cic.screen.xpixels/2, -o.cic.screen.ypixels/2, 0.0];
    end
        
    function beforeExperiment(o)
      % initalise default Viewpoint parameters in the vp structure
      o.vp = ViewpointInitDefaults(o.cic.mainWindow);

      % note: using Beeper() causes the following:
      %
      %   Snd(): Initializing PsychPortAudio driver for sound output.
      %   Snd(): PsychPortAudio already in use. Using old sound() fallback instead...
      %
      % followed by:
      %
      %   Audio output device has become unresponsive: 512 sample(s) remain after timeout.
      %
      % for now, just disable sound feedback for viewpoint-ptb
      o.vp.targetbeep = false;
      o.vp.feedbackbeep = false;
           
      o.vp.width = o.cic.screen.xpixels; % force width, to play nice with SOFTWARE-OVERLAY
      o.vp.height = o.cic.screen.ypixels;         
      
      if isempty(o.backgroundColor)
        % no background colour specified... use the screen background
        o.backgroundColor = o.cic.screen.color.background;
      end

      % overide default calibration parameters
      o.vp.backgroundcolour = o.backgroundColor;
      o.vp.calibrationtargetcolour = o.clbTargetColor;

      o.vp.calibrationtargetsize = 100*o.clbTargetSize./o.cic.screen.width; % percentage of screen width
      if isempty(o.clbTargetInnerSize)
        % no target inner size specified... use half the target size
        o.clbTargetInnerSize = o.clbTargetSize/2;
      end
      o.vp.calibrationtargetwidth = 100*o.clbTargetInnerSize/o.cic.screen.width;
      
      if ~o.useMouse
        % initialise connection to Viewpoint on the remote PC
        Viewpoint('setAddress',o.ipAddress,o.port);
        Viewpoint('initialize');
      end
      
      % set sample rate
      if ~any(o.sampleRate == [90,220])
        c.error('STOPEXPERIMENT','Requested sample rate is invalid.');
      end
      % FIXME: set the sample rate, i.e., 'eyeA:videoMode 90' or 'eyeA:videoMode 220'
            
      % open file to record data
      o.vpxFile = [o.cic.file '.vpx'];
%       o.vpxFile = ['C:\Data\' o.cic.file '.vpx']; % FIXME: Viewpoint doesn't seem to be honouring setDir DATA:

      Viewpoint('command','dataFile_UnPauseUponClose 0'); % recording is paused by default
      Viewpoint('command','dataFile_Pause 1');
      Viewpoint('command','datafile_includeEvents 1');
      Viewpoint('command','dataFile_includeRawData 1');
      Viewpoint('command','dataFile_AsynchStringData 1'); % for Viewpoint('message',...)
      Viewpoint('command','dataFile_startFileTimeAtZero 0');
      
      Viewpoint('command','smoothingPoints 1'); % 1 = no smoothing

      Viewpoint('command','calibration_RealRect 0.0 0.0 1.0 1.0');
      
      % send any custom commands to Viewpoint
      for ii = 1:length(o.commands)
        try
          Viewpoint('command',o.commands{ii});
        catch
          writeToFeed(o,['Viewpoint Command: ' o.commands{ii} ' failed!']);
        end
      end

      % should be all set up now...
      
      Viewpoint('openFile',[o.vpxPath, o.vpxFile]);
      
      switch upper(o.eye)
        case 'LEFT'
          Viewpoint('message','EYE_USED 0');
        case 'RIGHT'
          Viewpoint('message','EYE_USED 1');
        case {'BOTH','BINOCULAR'}
          Viewpoint('message','EYE_USED 2');
      end
                        
      Viewpoint('message','RECORDED BY %s',o.cic.experiment);
      Viewpoint('message','NEUROSTIM FILE %s',o.cic.fullFile);
      Viewpoint('message','DISPLAY_COORDS %d %d %d %d',0, 0, o.cic.screen.xpixels,o.cic.screen.ypixels);
      Viewpoint('message','DISPLAY_SIZE %.2f %.2f',o.cic.screen.width,o.cic.screen.height);
      Viewpoint('message','FRAMERATE %d Hz.',o.cic.screen.frameRate);     
    end
        
    function afterExperiment(o)            
      Viewpoint('stopRecording');
      Viewpoint('closeFile');
      
      pause(0.1);
      
      if ~isempty(o.ssh.username) && ~isempty(o.ssh.privateKey)
        writeToFeed(o,'Attempting to retrieve Viewpoint .vpx file via scp.');
        
        try
          newFileName = [o.cic.fullFile '.vpx'];

          % open ssh connection... public/private key
          connection = ssh2_config_publickey(o.ipAddress,o.ssh.username,o.ssh.privateKey,'nopass');

          % scp file from remote Viewpoint PC
          connection = scp_get(connection,[o.vpxPath,o.vpxFile],o.cic.fullPath);
        
          o.vpxFile = newFileName;
          writeToFeed(o,'Success: transferred .vpx file (%s).',o.vpxFile);
        
          % close ssh connection
          connection = ssh2_close(connection);
        catch me
          writeToFeed(o,'Fail: could not transfer .vpx file. Saved on Viewpoint PC as %s.',[o.vpxPath,o.vpxFile]);
          writeToFeed(o,'%s',me.message);
        end
      end
      
      Viewpoint('shutdown');      
    end
        
    function beforeTrial(o)
      % do re-calibration if requested
      if ~o.useMouse && (o.doTrackerSetup || o.doDriftCorrect)
        % temporarily undo neurostim's transformations so viewpoint-ptb
        % can draw its targets in pixels...
        Screen('glPushMatrix',o.cic.window);
        Screen('glLoadIdentity',o.cic.window);

        if o.doTrackerSetup
          ViewpointDoTrackerSetup(o.vp);
          o.doTrackerSetup = false;
        end
        
        if o.doDriftCorrect
          ViewpointDoDriftCorrect(o.vp); % note: uses Viewpoint's gazeNudge
          o.doDriftCorrect = false;
        end
        
        ViewpointClearCalDisplay(o.vp);
        
        % restore neurostim's transformations
        Screen('glPopMatrix',o.cic.window);
      end            
            
      if ~o.isRecording
        Viewpoint('startRecording');
        
        available = Viewpoint('eyeAvailable'); % returns vp.EYE_A, vp.EYE_B or vp.BOTH
        if available == -1
          o.cic.error('STOPEXPERIMENT','eye not available')
        else
          o.eye = eye2str(o,available);
        end
      end
      
      Viewpoint('message','TR:%d',o.cic.trial); % used to align clocks later
            
      Viewpoint('message','TRIALID %d-%d',o.cic.condition,o.cic.trial);

      o.eyeClockTime = Viewpoint('trackerTime'); % note: time since library initialized...
    end
        
    function afterFrame(o)
      if ~o.isRecording
        o.cic.error('STOPEXPERIMENT','Viewpoint is not recording...');
        return;
      end
            
      if o.getSamples
        % continuous samples requested
%         if Viewpoint('newFloatSampleAvailable')
          % get the most recent sample...
          sample = Viewpoint('newestFloatSample');
          
          idx = str2eye(o,o.eye);
          
          % note: Viewpoint returns gaze position in normalized screen
          %       coordinates... convert to neurostim's physical coods
          [o.x,o.y] = o.raw2ns(sample.gx(idx+1), sample.gy(idx+1)); % idx+1, since we're indexing a MATLAB array
          
          o.pupilSize = sample.pa(idx+1);

          o.valid = isnumeric(o.x) && isnumeric(o.y) && o.pupilSize >0; % FIXME: only if configured to measure pupil size...
%         end
      end
            
      % TODO: figure out how we should configure/handle Viewpoint events...
      if o.getEvents
        warning('Viewpoint events are not supported yet.');
      end
    end
       
    function command(o,cmd)
      % add a command to be sent to Viewpoint before the experiment starts
      if o.cic.trial > 0
        o.cic.error('STOPEXPERIMENT','Viewpoint commands can only be set before the experiment starts.');
      end
            
      % add cmd to the queue
      if isempty(cmd)
        o.commands = {};
        return
      end
      
      o.commands = cat(2,o.commands,{cmd});
    end
    
    function keyboard(o,key,~)
      switch upper(key)
        case 'F8'
          % do tracker setup before next trial
          o.doTrackerSetup = true;
        case 'F9'
          % do drift correct right now
          Viewpoint('StopRecording');
     
          [tx,ty] = o.cic.physical2Pixel(0,0);
          draw = 0; % assume neurostim has drawn a target
          allowSetup = 0; % if it fails it fails..(we just press on, we don't want to mess up the flow)
          ViewpointDoDriftCorrect(o.vp,tx/o.cic.screen.xpixels,ty/o.cic.screen.ypixels,draw,allowSetup);

          Viewpoint('StartRecording');
        case 'F10'
          % do drift correct before next trial
          o.doDriftCorrect = true;
      end
    end

    function str = eye2str(o,eyeNr)
      % convert a Viewpoint number to a string that identifies the eye
      % (matching with plugins.eyetracker)
      eyes = {'LEFT','RIGHT','BOTH'};
      eyeNrs = [o.vp.EYE_A,o.vp.EYE_B,o.vp.BOTH];
      str = eyes{eyeNr == eyeNrs};
    end
        
    function nr = str2eye(o,eye)
      % convert a string that identifies the eye to a Viewpoint number
      eyes = {'LEFT','RIGHT','BOTH','BINOCULAR'};
      eyeNrs = [o.vp.EYE_A,o.vp.EYE_B,o.vp.BOTH,o.vp.BOTH];
      nr = eyeNrs(strcmpi(eye,eyes));
    end
    
  end % public methods
   
end % classdef