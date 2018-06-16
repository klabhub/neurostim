function run_mea(device)

    devicelist = Mcs.Usb.CMcsUsbListNet();
    devicelist.Initialize(Mcs.Usb.DeviceEnumNet.MCS_MEA_DEVICE);
    status = device.Connect(devicelist.GetUsbListEntry(0));
    if (status == 0)
        cleanupObj = onCleanup(@()mea_cleanup(device));
        
        device.SendStop();
        [status,hwchannels]=device.HWInfo().GetNumberOfHWADCChannels()
        status = device.SetNumberOfChannels(hwchannels);
        [status, analogchannels, digitalchannels, checksumchannels, timestampchannels, channelsinblock] = device.GetChannelLayout(0);

        status = device.SetSampleRate(50000, 1, 0);

        device.SetSelectedChannels(channelsinblock, 50000, 5000, Mcs.Usb.SampleSizeNet.SampleSize16, channelsinblock);

        device.StartDacq();

        x = 0;
        while(1)

            for(i = [0 channelsinblock - 1])

                number = device.ChannelBlock_AvailFrames(i);
                if (number >= 5000)
                   [data, read] = device.ChannelBlock_ReadFramesUI16(i, 5000);

                   if (i == 0) % selected channel

                       y = single(data) - 32768;
                       plot(y); 
                   end
                end

            end
            pause(0.01);
            x = x + 1;
            if (x == 5000)
                break;
            end
        end

    else
        disp ('connection failed');
        disp (dec2hex(status));
        disp (Mcs.Usb.CMcsUsbNet.GetErrorText(status));
        
    end
end