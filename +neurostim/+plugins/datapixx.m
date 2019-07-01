classdef datapixx < neurostim.plugins.daq
  % Wrapper for the VPixx Technologies Datapixx Digital I/O functionality.
  %
  % See also: http://www.vpixx.com/manuals/psychtoolbox/html/index.html
  
  % 2019-05-16 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (Constant)
    DATAPIXX    = 1;
    DATAPIXX2   = 2;
    VIEWPIXX    = 3;
    VIEWPIXX3D  = 4;
    PROPIXXCTRL = 5;
    PROPIXX     = 6;
  end
  
  properties
    product;
    ramsize;
    version;
  end
    
  properties (Dependent)
    status;
  end
    
  methods % get/set methods
    function v = get.status(o)
      v = Datapixx('IsReady');
%       v = Datapixx('GetDoutStatus');
    end
  end
  
  methods
    function o = datapixx(c,varargin) % constructor
      o = o@neurostim.plugins.daq(c,'datapixx');

      if ~Datapixx('Open')
        error('Datapixx plugin added but no device could be found.');
      end

      % check what is there...
      [o.product,o.ramsize,o.version] = o.getProduct();
      
      Datapixx('Close');
      
%       o.addProperty('flipBit',[]); % digital output bit (1-16) set HIGH on each screen flip
      o.addProperty('trialBit',[]); % digital output bit (1-16) set HIGH for half the duration of the first frame of each trial
    end
        
    function beforeExperiment(o)
      % open connection and clear schedule...
      Datapixx('Open');
      Datapixx('StopAllSchedules');
      Datapixx('SetDinDataDirection',0); % force digital inputs to be inputs...
      Datapixx('DisableDinDebounce');
      Datapixx('SetDoutValues',0); % force digital outputs low

      if any(o.mapList.type == o.ANALOG)
        Datapixx('EnableAdcFreeRunning'); % sample continuously at 200kHz
      end

      Datapixx('RegWrRd');
    end
        
    function afterExperiment(o)
      % cleanup and close connection...
      Datapixx('RegWrRd');
      status = Datapixx('GetDoutStatus');
      
      t0 = tic;
      while status.scheduleRunning && (toc(t0) < 1.0) % wait 1s max.
        warning();
        
        % give it a chance to finish
        pause(0.1);

        Datapixx('RegWrRd');
        status = Datapixx('GetDoutStatus');
      end
      
      if status.scheduleRunning
        warning('Digital output schedule is still running... stopping it now.');
      end
      
      Datapixx('StopDoutSchedule');
      Datapixx('DisbleAdcFreeRunning');
      Datapixx('RegWrRd');

      Datapixx('Close');
    end
    
%     function beforeTrial(o)
%       if o.trialBit > 0
%         % setup digital output schedule...
%         bufferData = [bitset(0,o.trialBit), 0];
%         bufferAddress = 8e6; % <-- hmmm, ok?
%         Datapixx('WriteDoutBuffer',bufferData,bufferAddress);
% 
%         samplesPerFrame = size(bufferData,2);
%         
%         % note: every call to StartDoutSchedule must be preceeded by a
%         %       call to SetDoutSchedule, 
%         
% %         Datapixx('SetDoutSchedule', 0, [samplesPerFrame, 2], 0, bufferAddress, samplesPerFrame);
%         Datapixx('SetDoutSchedule', 0, [samplesPerFrame, 2], samplesPerFrame, bufferAddress, samplesPerFrame);
% 
%         Datapixx('StartDoutSchedule');
%         Datapixx('RegWrRdVideoSync'); % start on next video refresh
%       end
%     end
%     
%     function afterTrial(o)
%       afterTrial@neurostim.plugins.daq(o); % parent method
% 
%       if o.trialBit > 0
%         Datapixx('StopDoutSchedule');
%       end
%     end
    
    function beforeFrame(o)
      if c.frame ~= 1
        return
      end
        
      if o.trialBit < 1 || o.trialBit > 16
        return
      end
      
      % setup digital output schedule...
      %
      % we set o.trialBit HIGH for half the period of the first frame
      bufferData = [bitset(uint16(0),o.trialBit), 0];
      bufferAddress = 8e6; % <-- hmmm, ok?
      Datapixx('WriteDoutBuffer',bufferData,bufferAddress);

      samplesPerFrame = size(bufferData,2);
      
      % note: every call to StartDoutSchedule must be preceeded by a
      %       call to SetDoutSchedule,
        
      Datapixx('SetDoutSchedule', 0, [samplesPerFrame, 2], samplesPerFrame, bufferAddress, samplesPerFrame);

      Datapixx('StartDoutSchedule');
      Datapixx('RegWrVideoSync'); % start on next video refresh (note: this does *NOT* read back the registers from the Datapixx
    end
  end
  
  methods
    function reset(o)
      Datapixx('Reset');
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

      Datapixx('RegWrRd');
      oldValue = Datapixx('GetDinValues');

      nrBits = Datapixx('GetDoutNumBits');
      
      if islogical(value)
        if isempty(channel) || channel == 0
          % set/clear all bits        
          newValue = value * ((2^nrBits)-1);
        else
          assert(channel <= nrBits,'Invalid channel. Channel must be 1-%i.',nrBits);
          
          % set/clear a single bit
          newValue = bitset(oldValue,channel,value);
        end
      else
        if isempty(channel) || channel == 0
          newValue = bitand((2^nrBits)-1,value);
        else
          assert(ismember(channel,[1,2,3]),'Invalid channel. Channel must be 1-3.');
          
          % set specified bit
          newValue = bitand((2^nrBits)-1,bitshift(uint8(value),(channel-1)*8));
          newValue = bitand(oldValue,newValue);
        end          
      end
                
      Datapixx('SetDoutValues',newValue);
      Datapixx('RegWrRd');
      
      if nargin > 3        
        duration = varargin{1};
        
        % note: the timerfcn may interrupt execution when the timer times
        % out... this could cause dropped frames etc.
        o.timer = timer('StartDelay',duration/1000,'TimerFcn',@(~,~) digitalOut(o,0,oldValue));
        start(o.timer);
      end
      
    end
    
    function value = digitalIn(o,channel)
      % Read digital channel now.
      %
      % 

      Datapixx('RegWrRd');
      data = Datapixx('GetDinValues');

      if isempty(chennel) || channel == 0
        % return all bits...
        value = data;
        return;
      end
      
      % ... otherwise, return only the state of the requested channel
      value = bitget(data,channel);
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
      % Channel should contain a number (1-16) for the channel to sample. 
      % If channel is empty (or 0), all chennels will be returned, e.g.,
      %
      %   o.analogIn(1) will sample analog input channel 1,
      %   o.analogIn(0) will sample all analog input channels.
      %      
      [value,ref] = Datapixx('GetAdcVoltages');
      
      if ~isempty(channel) && all(channel > 0)
        value = data(channel);
        ref = ref(channel);
      end
    end
  end
  
  methods (Access = protected)
        
    function [product,ram,rev] = getProduct(o)
      % get product type
      if Datapixx('IsDatapixx')
        product = o.DATAPIXX;
      end
      
      if Datapixx('IsDatapixx2')
        product = o.DATAPIXX2;
      end

      if Datapixx('IsViewpixx')
        product = o.VIEWPIXX;
      end

      if Datapixx('IsViewpixx3D')
        product = o.VIEWPIXX3D;
      end

      if Datapixx('IsPropixxCtrl')
        product = o.PROPIXXCTRL;
      end

      if Datapixx('IsPropixx')
        product = o.PROPIXX;
      end
      
      ram = Datapixx('GetRamSize');

      rev = Datapixx('GetFirmwareRev');
    end
    
  end % protected methods
  
end % classdef
