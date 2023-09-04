classdef dmx512 < neurostim.stimulus
    % A stimulus to control a light fixture using the industry standard 
    % DMX512 and RDM protocols. This specific implemntation uses the Enttec
    % DMX USB Pro device to target the  Filmgrade DMX512 LED Dimmer/Decoder (which can be connected to any
    % LED light strip, I used FilmGrade 24V strips.
    % To talk to the DMX USB Pro device, I use the D2XX DLL from FTDI. 
    %
    % Signal pathway:
    % Matlab --(D2XX library over USB)--> Enttec Device --(DMX512/RDM
    % protocol) --> Filmgrade Dimmer --(voltage)-->  Filmgrade LED Strips
    %
    % Notes on installation:
    %  . Install the MingW compiler (a Matlab AddOn), this is needed to use
    %  the USB library from FTDI.
    %
    % .  Install drivers for the USB device from here:
    %       https://ftdichip.com/drivers/d2xx-drivers/
    % (The code below uses the "direct access via the dll" rather than the
    % Virual Com Port (VCP) drivers, although the latter may also be an
    % option to use in combination with the Instrument Control Toolbox).
    % 2. 
    %
properties
end

methods
end


methods (Access=public)
    function o = dmx512(c,nm)
        if nargin <2
            nm = 'dmx512';
        end
        assert(exist('FTD2XX.h','file'),'Please add the FTD2XX library to the Matlab search path.'); 
        if ~libisloaded('FTD2XX')
            [ok,warnings] = loadlibrary('FTD2XX.dll', 'FTD2XX.h');
        end
        
        o = o@neurostim.plugin(c,nm);
    
         o.addProperty('host','');
           
    end

end

end