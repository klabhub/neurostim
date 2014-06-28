classdef mcc < neurostim.plugin
    % Wrapper for the Psychtoolbox DAQ
    % Before using this, run the DaqTest script that is part of PTB to test
    % that your Measurement Computing hardware is working and accessible.
    %
    % AM: I had to configure the ports as "output" for digitalOut() to
    % work, e.g.
    %       err=DaqDConfigPort(c.mcc.daq,0,0); % port A as output
 
    
    properties (Constant)
        AFTERFRAME=1;
        AFTERTRIAL=2;
        ANALOG=0;
        DIGITAL=1;
    end
    properties
        devices;
        daq;
        mapList;
    end
    
    
    properties (Dependent)
        product@char;
        status@struct;
    end
    
    methods
        function v= get.product(o)
            v = o.devices(o.daq).product;
        end
        
        function v= get.status(o)
            v = DaqGetStatus(o.daq);
        end
    end
    methods
        function o =mcc
            o  = o@neurostim.plugin('mcc');
            
            % Check what is there.
            o.devices = PsychHID('Devices');
            
            %Find the main MCC Interface.
            o.daq  = find(arrayfun(@(device) strcmpi(device.product,'Interface 0'), o.devices));    %DaqDeviceIndex
            
            err=DaqDConfigPort(o.daq,0,0); % configure digital port A for output
            err=DaqDConfigPort(o.daq,1,1); % configure digital port B for input
            
            o.mapList.type = [];
            o.mapList.channel =[];
            o.mapList.prop = {};
            o.mapList.when = [];
            
            
        end
        function map(o,type,channel,prop, when)
            % Map a channel to a named dynamic property.
            % INPUT
            %   type = 'ANALOG' or 'DIGITAL'
            %   channel = channel number
            %   prop   = The property to map the channel to.
            %   when = When should the value be updated. 'AFTERFRAME','AFTERTRIAL'
            %
            %
            
            % Add the property
            addprop(o,prop);
            o.mapList.type      = cat(2,o.mapList.type,o.(upper(type)));
            o.mapList.channel   = cat(2,o.mapList.channel,channel);
            o.mapList.prop      = cat(2,o.mapList.prop,prop);
            o.mapList.when      = cat(2,o.mapList.when,o.(upper(when)));
        end
        
        
        function  digitalOut(o,channel,value)
            % Output the value to the digital channel
            % o.digitalOut(0,unit8(2)) will write '2' to port A
            % o.digitalOut(3,false) will set bit #3 to false.
            if isa(value,'uint8') && ismember(channel ,[0 1])
                % Writing a full byte to port A (channel 0) or  B (1)
                DaqDOut(o.daq,channel,value);
            elseif islogical(value)
                % Set a single bit
                % First get the current values;
                current = DaqDIn(o.daq);
                port = (channel>8)+1;
                current = current(port); %A or B
                newValue = bitset(current,channel,value);
                DaqDOut(o.daq,port-1,newValue);
            else
                error('Huh?')
            end
        end
        
        % Read the digital channel now
        function v= digitalIn(o,channel)
            % data(1) is the 8-bit value read from port A.
            % data(2) is the 8-bit value read from port B.
            data = DaqDIn(o.daq);
            % Extract the bit of the channel
            if channel<9
                v = bitget(data(1),channel);
            else
                v = bitget(data(2),channel-8);
            end
        end
        
        % Read the specified analog channel now
        function v= analogIn(o,channel)
            % range scales differential recordings. Not using for
            % now.
            range = 0;
            v  = DaqAIn(o.daq,channel,range);
        end
        
        function events(o,src,evt)
            switch evt.EventName
                case 'AFTERTRIAL'
                    ix = find(o.mapList.when ==o.AFTERTRIAL);
                    if ~isempty(ix)
                        read(o,ix);
                    end
                case 'AFTERFRAME'                    
                    ix = find(o.mapList.when ==o.AFTERFRAME);
                    if ~isempty(ix)
                        read(o,ix);
                    end
            end
        end
        
    end
    
    methods (Access = protected)
        
        % Read the Analog or Digital values and store them in a property.
        % Called by afterFrame and afterTrial after setting up a map()
        function ok = read(o,ix)
            ok = true;
            for i=ix
                if o.mapList.type(i) == o.ANALOG
                    v = analogIn(o,o.mapList.channel(i));
                elseif o.mapList.type(i) == o.DIGITAL
                    v = digitalIn(o,o.mapList.channel(i));
                else
                    error('Huh?')
                end
                % Set the value
                o.(o.mapList.prop{i}) = v;
            end
        end
        
        
    end
    
end