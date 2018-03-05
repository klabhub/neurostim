% wrapper class for New Era syringe pumps

% 2016-06-25 - Shaun L. Cloherty <s.cloherty@ieee.org>

classdef newera <  neurostim.plugins.feedback
  % Wrapper class for New Era syringe pumps (see http://syringepump.com/).
  %
  % To see the public properties of this class, type
  %
  %   properties(neurostim.plugins.newera)
  %
  % To see a list of methods, type
  %
  %   methods(neurostim.plugins.newera)
  %
  % The class constructor can be called with a range of arguments:
  %
  %   port     - serial interface (e.g., COM1)
  %   baud     - baud rate (default: 19200)
  %   address  - pump address (0-99)
  %   diameter - syringe diameter (mm)
  %   volume   - dispensing volume (ml)
  %   rate     - dispensing rate (ml per minute)

  % note: ported from my marmoview class of the same name
  
  properties (SetAccess = private, GetAccess = public)
    dev@serial; % the serial port object - PRIVATE?

    port; % port for serial communications ('COM1','COM2', etc.)
    baud;
    
    address@double; % pump address (0-99)
  end % properties

  % dependent properties, calculated on the fly...
  properties (Dependent, SetAccess = public, GetAccess = public)
    diameter@double; % diameter of the syringe (mm)
    volume@double;   % dispensing volume (mL)
    rate@double;     % dispensing rate (mL per minute)
  end

  methods % set/get dependent properties
    % dependent property set methods
    function o = set.diameter(o,value)
        o.setdia(value);
    end

    function o = set.volume(o,value)
        % note: value is in ml, however, if diameter > 14.0mm, the pump
        %       is expecting volume in microliters (unless the default units
        %       have been over-riden).
        if o.diameter <= 14.0,
          value = value*1e3; % microliters
        end
        o.setvol(value);
    end

    function o = set.rate(o,value)
        o.setrate(value);
    end

    % dependent property get methods
    function value = get.diameter(o)
        [err,status,msg] = o.sndcmd('DIA');
        assert(err == 0);

        value = str2num(msg);
    end

    function value = get.volume(o)
      [err,status,msg] = o.sndcmd('VOL');
      assert(err == 0);

      pat = '(?<value>[\d\.]{5})\s*(?<units>[A-Z]{2})';
      tokens = regexp(msg,pat,'names');
        
      value = str2num(tokens.value);        

      % note: value should be returned in ml, however, if diameter <= 14.0mm,
      %       the pump returns the volume in microliters (unless the default
      %       units have been over-riden).
      switch upper(tokens.units),
        case 'ML', % milliliters
          value = value;
        case 'UL', % microliters
          value = value/1e3; % milliliters
        otherwise,
          warning('NEUROSTIM:NEWERA','Unknown volume units ''%s''.', tokens.units);
      end
    end

    function value = get.rate(o)
      [err,status,msg] = o.sndcmd('RAT');
      assert(err == 0);

      pat = '(?<value>[\d\.]{5})\s*(?<units>[A-Z]{2})';
      tokens = regexp(msg,pat,'names');
        
      value = str2num(tokens.value);
      
      switch upper(tokens.units),
        case 'MM', % milliliters per minute
          value = value;
        case 'MH', % millimeters per hour
          value = value/60.0; % milliliters per minute
        case 'UM', % microliters per minute
          value = value/1e3; % milliliters per minute
        case 'UH', % microliters per hour
          value = value/(60*1e3); % milliliters per minute
        otherwise,
          warning('NEUROSTIM:NEWERA','Unknown rate units ''%s''.', tokens.units);
      end 
    end
  end

  methods
    function o = newera(c,name,varargin) % c is the neurostim cic
//      fprintf(1,'neurostim.plugins.newera()\n');

      o = o@neurostim.plugins.feedback(c,name); % call parent constructor

      % initialise input parser
      args = varargin;
      p = inputParser;
      p.KeepUnmatched = true;
      p.StructExpand = true;
      p.addParamValue('port','COM1',@ischar); % default to COM1?
      p.addParamValue('baud',19200,@(x) any(ismember(x,[300, 1200, 2400, 9600, 19200])));

      p.addParamValue('address',0,@(x) isreal);
      
      p.addParamValue('diameter',20.0,@isreal); % mm
      p.addParamValue('volume',0.010,@isreal); % ml
      p.addParamValue('rate',10.0,@isreal); % ml per minute

      p.parse(varargin{:});

      args = p.Results;

      o.port = args.port;
      o.baud = args.baud;

      o.address = args.address;

      % now try and connect to the New Era syringe pump...
      %
      %   data frame: 8N1 (8 data bits, no parity, 1 stop bit)
      %   terminator: CR (0x0D)
      o.dev = serial(o.port,'BaudRate',o.baud,'DataBits',8,'Parity','none', ...
                            'StopBits',1,'Terminator',13,'InputBufferSize',4096); % CR = 13

      try
        [err,status] = o.open();
      catch
        error('NEUROSTIM:NEWERA','Could not connect to New Era syringe pump on %s!',o.port);
      end

      % configure the pump...
      if status ~= 0, % 0 = stopped
        o.stop();
      end

      o.diameter = args.diameter;
      o.volume = args.volume;
      o.rate = args.rate;
      
      o.setdir(0); % 0 = infusion, 1 = withdrawal
      o.clrvol(0); % 0 = infused volume, 1 = withdrawn volume
%       o.clrvol(1);
    end

    function beforeExperiment(o)
        % check that theh pump is present, 
        try
            o.open();
        catch
            o.cic.error('CONTINUE','Liquid reward added but the NewEra plugin isn''t responding.');
        end
    end
       
    function afterExperiment(o)
        % close the pump
%         o.close();
        o.delete();
    end
    
    function chAdd(o,varargin)
       p = inputParser;
       p.StructExpand = true; % The parent class passes as a struct
       p.parse(varargin{:});      
    end
          
    function deliver(o,item)
%       fprintf(1,'neurostim.plugins.newera.deliver()\n');

      % too slow, this calls the sndcmd() method which involves both a
      % synchronous write operation *and* a synchronous read operation
%       err = run(o);

      % this is inelegant, but fast(er)... it involves only an asynchronous
      % write operation and bypasses the sndcmd() method entirely. However
      % the response from the pump is not read so we need to modify sndcmd()
      % below to flush the input buffer before any subsequent read operation
      err = 0;
%       fprintf(o.dev,'00 RUN','async');
      fprintf(o.dev,'00 RUN');
      
      o.nrDelivered = o.nrDelivered + 1;
      o.totalDelivered = o.totalDelivered + o.volume; % ml
    end
    
    function report(o)
       % report back to the gui?
       
%        fprintf(1,'neurostim.plugins.newera.report()\n');

       o.writeToFeed(horzcat('Delivered: ', num2str(o.nrDelivered), ' (', num2str(round(o.nrDelivered./o.cic.trial,1)), ' per trial); Total volume: ', num2str(o.totalDelivered)));
    end
    
    % low(er) level pump intervace...
    
    function [err,status] = open(o)
      fopen(o.dev);

      % query the pump
      [err,status,~] = o.sndcmd(''); % send a CR... no command
      assert(err == 0);
      
      % beep once so we know the pump is alive...
      err = o.beep(1);
      assert(err == 0);
    end

    function close(o)
      [~,status,~] = o.sndcmd(''); % send a CR... no command

      if status ~= 0, % 0 = stopped
        o.stop(); % stop the pump...
      end
      
      fclose(o.dev);
    end

    function delete(o)
      try
        o.close(); % fails if o.dev is invalid or is already closed
      catch
      end
      delete(o.dev);
    end
  end % methods

  methods (Access = private)
    function err = setdia(o,d) % set syringe diameter
      err = o.sndcmd(sprintf('DIA %5g',d));
    end

    function err = setvol(o,d) % set dispensing volume
      err = o.sndcmd(sprintf('VOL %5g',d));
    end

    function err = setrate(o,d) % set dispensing rate
      err = o.sndcmd(sprintf('RAT I %5g MM',d)); % 'I' set rate for infusion ONLY!
    end

    function err = setdir(o,d) % set pump direction
      switch d,
        case 0, % infuse
          err = o.sndcmd('DIR INF');
%         case 1, % withdraw
%           err = o.sndcmd('DIR WDR');
        otherwise,
          warning('NEUROSTIM:NEWERA','Invalid pump direction %i.',d);
      end
    end
    
    function err = run(o) % start the pump
      err = o.sndcmd('RUN');
    end
    
    function err = stop(o) % stop the pump
      err = o.sndcmd('STP');
    end   
    
    function err = clrvol(o,d) % clear dispensed/withdrawn volume
      switch d,
        case 0, % clear infused volume
          err = o.sndcmd('CLD INF');
        case 1, % clear withdrawn volume
          err = o.sndcmd('CLD WDR');
        otherwise,
          warning('NEUROSTIM:NEWERA','Invalid pump direction %i.', d);
      end
    end
    
    function [infu,wdrn] = qryvol(o) % query dispensed/withdrawn volume
      [err,status,msg] = o.sndcmd('DIS');
      assert(err == 0);

      % note: pump responds with [I <float> W <float> <volume units>] where
      %       "I <float>" refers to the infused volume and "W <float>" refers
      %       to the withdrawn volume

      pat = 'I\s*(?<infu>[\d\.]{5})\s*W\s*(?<wdrn>[\d\.]{5})\s*(?<units>[A-Z]{2})';
      tokens = regexp(msg,pat,'names');
                
      % note: infu and wdrn should be returned in ml, however, if
      %       diameter <= 14.0mm, the pump returns the volumes in
      %       microliters (unless the default units have been over-ridden).
      switch upper(tokens.units),
        case 'ML', % milliliters
          infu = str2num(tokens.infu);
          wdrn = str2num(tokens.wdrn);
        case 'UL', % microliters
          infu = str2num(tokens.infu)/1e3; % milliliters
          wdrn = str2num(tokens.wdrn)/1e3;
        otherwise,
          warning('NEUROSTIM:NEWERA','Unknown volume units ''%s''.', units);
      end
    end
    
    function err = beep(o,n) % sound the buzzer
      if nargin < 2,
        n = 1;
      end
      err = o.sndcmd(sprintf('BUZ 1 %i',n));
    end
    
    function [err,status,msg] = sndcmd(o,cmd) % send command to the pump
      % note: the deliver() method above performs an asynchronous write
      %       operation and doesn't wait around to read the response from
      %       the pump. The pump response(s) therefore remain in the input
      %       buffer... here we discard the contents of the input buffer
      %       before any subsequent write/read operation
%       flushinput(o.dev); % FIXME: requires the instrumentation toolbox
      flushin(o);
      
      cmd_ = sprintf('%02i %s',o.address,cmd);
      fprintf(o.dev,cmd_); %pause(0.100);
      
      if nargout < 1;
        return
      end

      pause(0.100); % <-- FIXME: need to figure out how to remove the need for this
      
      % the response from the pump looks like this:
      %
      %   [STX][Addr][Prmpt][Data][ETX]
      %
      % e.g., '00S10.00MM' <-- Addr = 00, Prmpt = S, Data = 10.00MM
      %
      % STX = Start of text (0x02)
      % ETX = End of text (0x03)
      %
      % [Prmpt] is one of:
      %
      %   'S' <-- Stopped
      %   'I' <-- Infusing
      %   'P' <-- Paused
      %   'A' <-- Alarm  
      %
      % if there is an error, [Data] contains '?[Code]' where [Code] is one
      % of:
      %
      %   ''   <--  not recognised
      %   'NA' <--  not applicable
      %   'OOR' <-- out of range
      %
      % a command with no payload acts as a query:
      %
      %   DIA returns [Data] like '20.00'
      %   RAT returns [Data] like '10.00MM'
      %   VOL returns [Data] like '5.000ML'
      %   DIR returns [Data] like 'INF' or 'WDL'(?)
      n = get(o.dev,'BytesAvailable');
      msg = fread(o.dev,n)';
      msg = char(msg(2:end-1)); % drop [STX] and [ETX]
      
      pat = '(?<addr>[\d]{2})\s*(?<prmpt>[A-Z]{1})\s*(?<msg>\S*)';
      tokens = regexp(msg,pat,'names');
      
      err = 0;
      if any(tokens.msg == '?'), % test for error
        err = 1;
      end

      status = -1;
      switch tokens.prmpt,
        case 'S', % stopped
          status = 0;
        case 'I', % infusing
          status = 1;
        case 'P', % paused
          status = 3;
        case 'A', % alarm, msg contains the alarm code
          warning('NEUROSTIM:NEWERA','Pump alarm code: %s!\nCheck diameter, rate and volume...',tokens.msg);
          o.sndcmd('AL0'); % clear the alarm?
          status = 4;
        otherwise,
          warning('NEUROSTIM:NEWERA','Unknown prompt ''%s'' returned by the New Era syringe pump.',tokens.prmpt);
      end

      msg = tokens.msg;
    end
    
    function flushin(o)
      % read and discard the contents of the serial port input buffer...
      while o.dev.BytesAvailable > 0,
        fread(o.dev,o.dev.BytesAvailable);
        pause(0.050); % <-- urgh!
      end
    end
  end % private emethods

end % classdef
