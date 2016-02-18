function mea_cleanup(device)

    device.StopDacq();

    device.Disconnect();

%    delete(device);
end