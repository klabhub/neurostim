classdef mcs < neurostim.plugin
    % Plugin used to communicate with the MultiChannel Systems Stimulator
    % (e.g. STG2000, STG4000, sTG8000)
    
    properties
        device =[];
        dll=[];
        deviceList;
    end
    
    properties (Dependent =true)
        nrDevices;
        serialNumber;
    end
    
    %get/set
    methods
        function v = get.nrDevices(o)
            if isempty(o.deviceList)
                v = [];
            else
                v = o.deviceList.GetNumberOfDevices();
            end
        end
        
        function v=get.serialNumber(o)
            if isempty(o.deviceList)
                v = [];
            else
                v= nan(1,o.nrDevices);
                for i=1:numel(v);
                    v(i) = char(o.deviceList.GetUsbListEntry(i-1).SerialNumber);
                end
            end
        end
    end
    
    methods 
        function o = mcs(c)
            o = o@neurostim.plugin(c,'mcs');
            switch computer
                case 'PCWIN64'
                    o.dll = NET.addAssembly([mfunction '\x64\McsUsbNet.dll']);
                case 'PCWIN32'
                    o.dll = NET.addAssembly([mfunction '\x32\McsUsbNet.dll']);
                otherwise
                    error(['Sorry, the MCS .NET libraries are not available on your platform: ' computer]);
            end
            
            import Mcs.Usb.*
            o.deviceList = CMcsUsbListNet();
            % For now assume we always want the STG
            o.deviceList.Initialize(DeviceEnumNet.MCS_STG_DEVICE);
            o.device = CStg200xStreamingNet(50000);

        end

        function connect(o)
            
        end
        
        % handle the key strokes defined above
%         function keyboardResponse(o,key)
%             switch upper(key)
%             end
%         end
        
        
    end
end