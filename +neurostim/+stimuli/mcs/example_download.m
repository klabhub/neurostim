% addpath('C:/Program Files/Multi Channel Systems/MC_Stimulus II')


if ~libisloaded('McsUsbDLL')
  loadlibrary('McsUsbDLL', 'McsUsbDLL.h','alias','McsUsbDLL')
end

if (exist('DeviceID','var') == 1) && (DeviceID ~= 0)
  fprintf(1, 'Closing existing connection\n')
  calllib('McsUsbDLL', 'McsUsb_Disconnect', DeviceID);
  DeviceID = 0;
end

DeviceID = calllib('McsUsbDLL', 'STG200x_Connect', -1, '');

if (DeviceID ~= 0)
  [result, Serial] = calllib('McsUsbDLL', 'McsUsb_GetSerialNumber', DeviceID, '          ', 10);
  fprintf (1, 'Connected to STG with Serial: %s\n', Serial);

  calllib('McsUsbDLL', 'STG200x_DisableStreamingMode', DeviceID);


  data=uint16([0 8191 4095 8191]);
  time=uint32([1000000 1000000 1000000 1000000]);

  pdata=libpointer('uint16Ptr', data);
  ptime=libpointer('uint32Ptr', time);

  res = calllib('McsUsbDLL', 'STG200x_ClearChannelData', DeviceID, 0);
  res = calllib('McsUsbDLL', 'STG200x_SendChannelData32', DeviceID, 0, pdata, ptime, 4);
  res = calllib('McsUsbDLL', 'McsUsb_Disconnect', DeviceID);
  DeviceID = 0;
  
  fprintf(1,'Press Start on STG to start the Trigger')

  clear pdata
  clear ptime

else
   fprintf (1,'Cant connect to STG\n');
end

unloadlibrary('McsUsbDLL')

