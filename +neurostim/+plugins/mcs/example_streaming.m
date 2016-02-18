% addpath('C:/Program Files/Multi Channel Systems/MC_Stimulus II')


if ~libisloaded('McsUsbDLL')
  loadlibrary('McsUsbDLL', 'McsUsbDLL.h','alias','McsUsbDLL')
end

t=linspace(0,50*3.1415,2000);
sync=linspace(0,1.9999,2000);
y=30000*sin(t);
yp=libpointer('int16Ptr',y);
sp=libpointer('uint16Ptr',sync);
[d,arraysize] = size(t);

dummy = libpointer('voidPtr');
pmem = libpointer('uint32Ptr', 0);

if (exist('DeviceID','var') == 1) && (DeviceID ~= 0)
  fprintf(1, 'Closing existing connection\n')
  calllib('McsUsbDLL', 'McsUsb_Disconnect', DeviceID);
  DeviceID = 0;
end


DeviceID = calllib('McsUsbDLL', 'STG200x_Connect', -1, '');


if (DeviceID ~= 0)
  [result, Serial] = calllib('McsUsbDLL', 'McsUsb_GetSerialNumber', DeviceID, '          ', 10);
  fprintf (1, 'Connected to STG with Serial: %s\n', Serial);

  channelmap=[1 0 0 0]; % Channel 1 is in Trigger 1
  syncoutmap=[1 0 0 0];
  digoutmap=[0 0 0 0];
  autostart=[1 0 0 0];
  callback_threshold=[0 0 0 0];

  capacity=[100000 100000 100000 100000];

  % Prepare the STG for the Streaming mode
  calllib('McsUsbDLL', 'STG200x_InitStreamingMode', DeviceID);
  calllib('McsUsbDLL', 'STG200x_EnableStreamingMode', DeviceID);

  calllib('McsUsbDLL', 'STG200x_EnableContinousMode', DeviceID);

  calllib('McsUsbDLL', 'STG200x_GetMemory', DeviceID, pmem);
  calllib('McsUsbDLL', 'STG200x_SetStreamingCapacity', DeviceID, capacity );
  calllib('McsUsbDLL', 'STG200x_SetOutputRate', DeviceID, 50000);

  loop = calllib('McsUsbDLL', 'Stg200xStreaming_CreateStreamingLoop', 100000, 0, 0, 0, 0);
  calllib('McsUsbDLL', 'Stg200xStreaming_SetupTrigger', DeviceID, loop, channelmap, syncoutmap, digoutmap, autostart, callback_threshold);
    
  % Fill the RingQueue
  space = calllib('McsUsbDLL','Stg200xStreaming_GetDataQueueSpace',loop,0);
  fprintf(1,'Space in Ringqueue before download: %d\n', space);
  while (space > arraysize)
     calllib('McsUsbDLL','Stg200xStreaming_EnqueueData',loop,0,yp,arraysize);
     space = calllib('McsUsbDLL','Stg200xStreaming_GetDataQueueSpace',loop,0);
  end
  fprintf(1,'Space in Ringqueue after download: %d\n', space);

  % Fill the Syncout Queue
  space = calllib('McsUsbDLL','Stg200xStreaming_GetSyncoutQueueSpace',loop,0);
  fprintf(1,'Space in Syncout-Queue before download: %d\n', space);
  while (space > arraysize)
     calllib('McsUsbDLL','Stg200xStreaming_EnqueueSyncout',loop,0,sp,arraysize);
     space = calllib('McsUsbDLL','Stg200xStreaming_GetSyncoutQueueSpace',loop,0);
  end
  fprintf(1,'Space in Syncout-Queue after download: %d\n', space);



  % Start to stream
  res = calllib('McsUsbDLL', 'Stg200xStreaming_StartLoop', DeviceID, loop);
  calllib('McsUsbDLL','STG200x_Start', DeviceID, 15);
  
  % refill queue
  refill = 0;
  while (refill < 1000)
      space = calllib('McsUsbDLL','Stg200xStreaming_GetDataQueueSpace',loop,0);
      if (space > arraysize)
          calllib('McsUsbDLL','Stg200xStreaming_EnqueueData',loop,0,yp,arraysize);
          fprintf (1, '*');
          refill = refill+1;
          if (rem(refill,100) == 0)
              fprintf (1, '\n');
          end
      end
      space = calllib('McsUsbDLL','Stg200xStreaming_GetSyncoutQueueSpace',loop,0);
      if (space > arraysize)
          calllib('McsUsbDLL','Stg200xStreaming_EnqueueSyncout',loop,0,sp,arraysize);
          fprintf (1, '.');
          refill = refill+1;
          if (rem(refill,100) == 0)
              fprintf (1, '\n');
          end
      end
  end
          

  % finish
  calllib('McsUsbDLL','STG200x_Stop', DeviceID, 15);
  res = calllib('McsUsbDLL', 'Stg200xStreaming_StopLoop', DeviceID, loop);

  space = calllib('McsUsbDLL','Stg200xStreaming_GetDataQueueSpace',loop,0);
  fprintf(1,'Space in Ringqueue after streaming: %d\n', space);
  space = calllib('McsUsbDLL','Stg200xStreaming_GetSyncoutQueueSpace',loop,0);
  fprintf(1,'Space in Syncout-Queue after streaming: %d\n', space);


  calllib('McsUsbDLL', 'Stg200xStreaming_DestroyStreamingLoop', loop);
  calllib('McsUsbDLL', 'McsUsb_Disconnect', DeviceID);
  DeviceID = 0;
else
   fprintf (1,'Cant connect to STG\n');
end

clear dummy

unloadlibrary('McsUsbDLL')

