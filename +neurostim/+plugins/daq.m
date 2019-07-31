classdef (Abstract) daq < neurostim.plugin
  % Abstract base class for DAQ devices.

  % 2019-05-17 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (Constant)
    ANALOG  = 0;
    DIGITAL = 1;
  end
  
  properties (Access = protected)
    mapList;

    timer;
  end
      
  methods
    function o = daq(c,varargin) % constructor
      o = o@neurostim.plugin(c,varargin{:});
            
      o.mapList.type = [];
      o.mapList.channel = [];
      o.mapList.prop = {};
      o.mapList.when = [];
    end
                   
    function map(o,type,channel,prop,when)
      % Map an input channel to a named dynamic property.
      %
      %   o.map(type,channel,prop,when)
      %
      % where
      %
      %   type    = 'ANALOG' or 'DIGITAL'
      %   channel = channel number
      %   prop    = the property to map the channel to.
      %   when    = 'AFTERFRAME' or 'AFTERTRIAL'
            
%       % add the property
%       addprop(o,prop);
      
      % add to mapList
      o.mapList.type = cat(2,o.mapList.type,o.(upper(type)));
      o.mapList.channel = cat(2,o.mapList.channel,channel);
      o.mapList.prop = cat(2,o.mapList.prop,prop);
      o.mapList.when = cat(2,o.mapList.when,upper(when));
    end
        
    function afterTrial(o)
      ix = any(strcmp(o.mapList.when,'AFTERTRIAL'));
      if ix
        read(o,ix);
      end
    end
        
    function afterFrame(o)
      ix = any(strcmp(o.mapList.when,'AFTERFRAME'));
      if ix
        read(o,ix);
      end
    end
  end % public methods
  
  methods (Abstract)
    % reset the daq device
    reset(o);
    
    % write digital output
    digitalOut(o,channel,value,varargin)
         
    % read digital channel now
    v = digitalIn(o,channel)

    % write analog output
    analogOut(o,channel,value,varargin)
    
    % read analog channel now
    v = analogIn(o,channel);    
  end % abstract methods
  
  methods (Access = protected)
    function ok = read(o,ix)
      % called by afterFrame and afterTrial to read analog or digital
      % input for mapped properties...
      ok = true;
      for ii = ix(:)'
        if o.mapList.type(ii) == o.ANALOG
          v = analogIn(o,o.mapList.channel(ii));
        elseif o.mapList.type(ii) == o.DIGITAL
          v = digitalIn(o,o.mapList.channel(ii));
        else
          error('Huh?')
        end
        
        % set the property value
        o.(o.mapList.prop{ii}) = v;
      end
    end
  end % protected methods
  
end
