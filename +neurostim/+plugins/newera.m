% wrapper class for New Era syringe pumps

% 2016-06-25 - Shaun L. Cloherty <s.cloherty@ieee.org>

classdef newera <  neurostim.plugins.liquid
  % Wrapper class for New Era syringe pumps (see http://syringepump.com/).
  %  
  % usage:
  %
  %   r = plugins.newera(c); % c being a neurostim cic object
  %   r.add('volume',0.010,'when','afterFrame','criterion','@fixation1.success');
  %   r.add('volume',0.040,'when','afterTrial','criterion','@fixation2.success');

  % 2018-03-12 - Shaun L. Cloherty <s.cloherty@ieee.org>
  %
  % note: ported from my marmoview class of the same name.
  
  properties (SetAccess = private, GetAccess = public)
    dev@serial; % the serial port object

%     port; % port for serial communications ('COM1','COM2', etc.)
%     baud;
%     
%     address@double; % pump address (0-99)
    
%     mcc; % (boolean) set to TRUE if the mcc is available
% 
%     % for the gui...
%     nrDelivered = 0;
%     totalDelivered = 0;
  end % properties

%   % dependent properties, calculated on the fly...
%   properties (Dependent, SetAccess = public, GetAccess = public)
%     diameter@double; % diameter of the syringe (mm)
%     volume@double;   % dispensing volume (mL)
%     rate@double;     % dispensing rate (mL per minute)
%   end
% 
%   methods % set/get dependent properties
%     % dependent property set methods
%     function o = set.diameter(o,value)
%         o.setdia(value);
%     end
% 
%     function o = set.volume(o,value)
%         % note: value is in ml, however, if diameter > 14.0mm, the pump
%         %       is expecting volume in microliters (unless the default units
%         %       have been over-riden).
%         if o.diameter <= 14.0,
%           value = value*1e3; % microliters
%         end
%         o.setvol(value);
%     end
% 
%     function o = set.rate(o,value)
%         o.setrate(value);
%     end
% 
%     % dependent property get methods
%     function value = get.diameter(o)
%         [err,status,msg] = o.sndcmd('DIA');
%         assert(err == 0);
% 
%         value = str2num(msg);
%     end
% 
%     function value = get.volume(o)
%       [err,status,msg] = o.sndcmd('VOL');
%       assert(err == 0);
% 
%       pat = '(?<value>[\d\.]{5})\s*(?<units>[A-Z]{2})';
%       tokens = regexp(msg,pat,'names');
%         
%       value = str2num(tokens.value);        
% 
%       % note: value should be returned in ml, however, if diameter <= 14.0mm,
%       %       the pump returns the volume in microliters (unless the default
%       %       units have been over-riden).
%       switch upper(tokens.units),
%         case 'ML', % milliliters
%           value = value;
%         case 'UL', % microliters
%           value = value/1e3; % milliliters
%         otherwise,
%           warning('NEUROSTIM:NEWERA','Unknown volume units ''%s''.', tokens.units);
%       end
%     end
% 
%     function value = get.rate(o)
%       [err,status,msg] = o.sndcmd('RAT');
%       assert(err == 0);
% 
%       pat = '(?<value>[\d\.]{5})\s*(?<units>[A-Z]{2})';
%       tokens = regexp(msg,pat,'names');
%         
%       value = str2num(tokens.value);
%       
%       switch upper(tokens.units),
%         case 'MM', % milliliters per minute
%           value = value;
%         case 'MH', % millimeters per hour
%           value = value/60.0; % milliliters per minute
%         case 'UM', % microliters per minute
%           value = value/1e3; % milliliters per minute
%         case 'UH', % microliters per hour
%           value = value/(60*1e3); % milliliters per minute
%         otherwise,
%           warning('NEUROSTIM:NEWERA','Unknown rate units ''%s''.', tokens.units);
%       end 
%     end
%   end

  methods
    function o = newera(c,varargin) % c is the neurostim cic
      o = o@neurostim.plugins.liquid(c,'newera'); % call parent constructor
     
      % add properties (these are logged!):
      %
      %   port     - serial interface (e.g., COM1)
      %   baud     - baud rate (default: 19200)
      %   address  - pump address (0-99)
      %   diameter - syringe diameter (mm)
      %   rate     - dispensing rate (ml per minute)
      %
      %   channel  - mcc channel (if mcc is available)
      o.addProperty('port','COM1','validate',@ischar); % or something like '/dev/ttyUSB0' on linux
      o.addProperty('baud',19200,'validate',@(x) any(ismember(x,[300, 1200, 2400, 9600, 19200])));
      o.addProperty('address',0,'validate',@isreal);
       
      o.addProperty('diameter',20.0,'validate',@isreal); % mm
%      o.addProperty('volume',0.010,'validate',@isreal); % ml
      o.addProperty('rate',10.0,'validate',@isreal); % ml per minute
% 
%       o.addProperty('mccChannel',9,'validate',@isreal); % mcc channel
    end

    function beforeExperiment(o)
      % try and connect to the New Era syringe pump...
      %
      %   data frame: 8N1 (8 data bits, no parity, 1 stop bit)
      %   terminator: CR (0x0D)
      o.dev = serial(o.port,'BaudRate',o.baud,'DataBits',8,'Parity','none', ...
                     'StopBits',1,'Terminator',13,'InputBufferSize',4096); % CR = 13

      % check that the pump is present,
      try
        [err,status] = o.open();
      catch
        o.cic.error('CONTINUE','Liquid reward added but the NewEra pump isn''t responding.');
      end

      % configure the pump...
      if status ~= 0 % 0 = stopped
        o.stop();
      end

      o.setdia(o.diameter);
%       o.setvol(o.volume);
      o.setrate(o.rate);

      o.setdir(0); % 0 = infusion, 1 = withdrawal
      o.clrvol(0); % 0 = infused volume, 1 = withdrawn volume
%       o.clrvol(1);
        
%       % look for the MCC plugin...
%       o.mcc = pluginsByClass(o.cic,'mcc');
%       if numel(o.mcc) == 1
%         % initialise the bit low
%         o.mcc.digitalOut(o.mccChannel,false);
%       else
%         o.cic.error('CONTINUE','Liquid reward added but no MCC plugin present (or, more than one present!!)');
%       end
      o.beforeExperiment@neurostim.plugins.liquid()
    end
       
    function afterExperiment(o)
      % close the pump
%       o.close();
      o.delete();
    end
  end
  
  methods (Access = protected)
    function chAdd(o,varargin)
      % available arguments:
      %
      %   volume - dispensing volume (ml)
      %
      % see also: @liquid
      p = inputParser;
      p.StructExpand = true; % @feedback passes args as a struct
      p.KeepUnmatched = true;
      p.addParamValue('volume',0.0,@isreal); % ml
      p.parse(varargin{:});

      o.chAdd@neurostim.plugins.liquid(p.Unmatched); % adds o.itemNduration
      
      args = p.Results;
            
      o.addProperty(['item', num2str(o.nItems), 'volume'],args.volume);
      
      % setting a volume overides any specified duration...?
%       duration = (60*1e3)*args.volume/o.rate; % ml / (ml/min) --> converted milliseconds
      duration = o.ml2ms(args.volume); % ml / (ml/min) --> converted milliseconds

      o.(['item', num2str(o.nItems), 'duration']) = duration;
    end
          
    function deliver(o,item)
      if o.mcc
%         o.deliver@neurostim.plugins.liquid();
        return
      end
      
      % if we don't have an MCC device we use the serial connection
      
      volume = o.(['item', num2str(item) 'volume']);
      o.setvol(volume);
      
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
            
      % keep track of what we've 'delivered'...
      o.nrDelivered = o.nrDelivered + 1;
      o.totalDelivered = o.totalDelivered + volume; % ml
    end
    
    function report(o)
       % report back to the gui?
       volume = o.qryvol();
       
       msg = sprintf('Delivered: %i (%i per trial); Total volume: %.2f', o.nrDelivered,round(o.nrDelivered./o.cic.trial,1),volume);
       o.writeToFeed(msg);
    end
  end % protected methods
  
  %
  % low(er) level pump interface...
  %
  methods (Access = public)
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
    
    function ms = ml2ms(o,ml)
      ms = 1e3*60*ml/o.rate;
    end
  end % public methods

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

      pause(0.500); % <-- FIXME: need to figure out how to remove the need for this
      
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
      if any(tokens.msg == '?') % test for error
        err = 1;
      end

      status = -1;
      switch tokens.prmpt
        case 'S' % stopped
          status = 0;
        case 'I' % infusing
          status = 1;
        case 'P' % paused
          status = 3;
        case 'A' % alarm, msg contains the alarm code
          warning('NEUROSTIM:NEWERA','Pump alarm code: %s!\nCheck diameter, rate and volume...',tokens.msg);
          o.sndcmd('AL0'); % clear the alarm?
          status = 4;
        otherwise
          warning('NEUROSTIM:NEWERA','Unknown prompt ''%s'' returned by the New Era syringe pump.',tokens.prmpt);
      end

      msg = tokens.msg;
    end
    
    function flushin(o)
      % read and discard the contents of the serial port input buffer...
      while o.dev.BytesAvailable > 0
        fread(o.dev,o.dev.BytesAvailable);
        pause(0.050); % <-- urgh!
      end
    end
  end % private emethods

end % classdef
