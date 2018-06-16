dll = NET.addAssembly([pwd '\x64\McsUsbNet.dll']);
import Mcs.Usb.* 

deviceList = CMcsUsbListNet();
deviceList.Initialize(DeviceEnumNet.MCS_STG_DEVICE);

fprintf('Found %d STGs\n', deviceList.GetNumberOfDevices());


for i=1:deviceList.GetNumberOfDevices()
   SerialNumber = char(deviceList.GetUsbListEntry(i-1).SerialNumber);
   fprintf('Serial Number: %s\n', SerialNumber);
end

device = CStg200xStreamingNet(50000);
device.Connect(deviceList.GetUsbListEntry(0));
device.EnableContinousMode();
device.SetOutputRate(50000);
ntrigger = device.GetNumberOfTriggerInputs(); 

fprintf('Number of Triggers: %d\n', ntrigger);

device.Disconnect();

delete(deviceList);
delete(device);


