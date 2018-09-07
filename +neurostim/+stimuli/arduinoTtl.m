classdef arduinoTtl < neurostim.stimulus
    
    % neurostim.stimuli.arduinoTtl
    % This neurostim stimulus provides interaction with an Arduino to
    % produce a TTL pulse on any or all of the pins 6 through 13
    % (inclusive).
    %
    % This pulse will start at the stimulus standard 'on' and last for
    % stimulus-standard 'duration'.
    %
    % For this to work, you'll need an Arduino Uno and use the Arduino IDE
    % (downloadable from Windows store) to upload some code into its
    % memory. The Arduino code (or "sketch") for this neurostim stimulus
    % can be found by typing <a
    % href="matlab:neurostim.stimuli.arduinoTtl.sketch">neurostim.stimuli.arduinoTtl.sketch</a>.
    %
    % The compiled version of this sketch will remain in the flash memory
    % of the Arduino until it's flashed again. So this upload needs to be
    % done only once unless you use the same Arduino for other purposes,
    % too.
    %
    % This stimulus works by setting up a serial link at the start of the
    % experiment (and close it at the end). This way, at beforeframe time,
    % only a single byte has to be transmitted to the Arduino. This is much
    % faster than the arduino.writeDigitalPin command that the MATLAB
    % provides with their Support Package for Arduino Hardware because that
    % sets up a new connection each call, which takes much longer than a
    % monitor frame. The major advantage of arduino.writeDigitalPin is that
    % it doesn't require a sketch to be loaded into the Arduino's memory,
    % but if timing is even remotely important, it's pretty much useless.
    %
    % EXAMPLE
    %   ttl=neurostim.stimuli.arduinoTtl(c,'ttl');
    %   ttl.port='COM3'; 
    %   ttl.pins=[12 13];
    %   ttl.on=300;
    %   ttl.duration=50;
    %
    % TIPS:
    %   You can find the COM number (port) in the Arduino IDE (under
    %   Tools>Port). The number changes if you connect the Arduino to
    %   another USB port.
    %
    %   On the Arduino Uno (perhaps other models too) Pin 13 has a built in
    %   LED to indicate the state of the TTL. This can be useful for
    %   debugging. However, a potential problem with Pin 13 is that its LED
    %   also flashes (3 times) when a serial link is established and the
    %   Pin 13 is set to HIGH. I like the visual feedback from the Pin 13
    %   LED but connect the to-be-triggered hardware to Pin 12 and run this
    %   stimulus with property pin set to [12 13].
    %
    % See also: neurostim.stimuli.arduinoTtl.sketch
    
    % Jacob Duijnhouwer, 2018-07-31
    
    properties (Access=public)
        port; % char on windows, but don't know on linux,mac so leave type undefined
        pins@double;
    end
    properties (Access=protected)
        link; % serial port connection
    end
    properties (Access=private)
        pins_as_byte; % the byte to be send to the arduino
    end 
    methods (Access=public)
        function o=arduinoTtl(c,name)
            o=o@neurostim.stimulus(c,name);
            o.pins=13;
            o.port='COM1';
        end 
        function beforeExperiment(o)
            sketch='DIO20180731a'; % to determine if the right sketch is active on the arduino device
            try
                test=instrfind('Tag',o.name);
                if ~isempty(test)
                    fprintf('[%s] A serial link with name ''%s'' already exists, it will be deleted.\n',mfilename,o.name);
                    delete(test);
                end
                o.link=serial(o.port,'Tag',o.name); % serial port connection gets same name as stimulus
                o.link.DataBits=8;
                o.link.StopBits=1;
                o.link.BaudRate=9600;
                o.link.Parity='none';
                % Open the connection and attempt handshake
                fopen(o.link);
                start=tic;
                while true
                    fromArduino=char(fread(o.link,numel(sketch),'uchar')');
                    if strcmpi(fromArduino,sketch)
                        break;
                    elseif toc(start)>3
                        error('Connection attempt timed out');
                    end
                end
                % send an 'm' back so arduino knows matlab is listening
                fprintf(o.link,'%c','m');
                % we're friends now
                fprintf('[%s] Serial link ''%s'' is established with the Arduino on port %s running sketch ''%s''.\n',mfilename,o.name,o.port,sketch);
            catch me
                msg=sprintf('Failed to establish a serial link ''%s'' to an Arduino on port %s...',mfilename,o.name,o.port);
                msg=[msg '\n' sprintf('Has the sketch ''%s'' been uploaded to the Arduino?',sketch)];
                msg=[msg '\n' me.message];
                error('a:b',msg);
            end
        end
        function afterExperiment(o)
            fclose(o.link);
            delete(instrfind('Tag',o.name))
        end
        function beforeFrame(o) 
            if o.frame==0
                % signal arduino to turn the requested pins on
                fprintf(o.link,'%c',o.pins_as_byte);
            elseif o.frame==o.offFrame-o.onFrame-1
                % turn all pins off
                fprintf(o.link,'%c',char(0));
            end
        end
    end
    methods
        function set.pins(o,val)
            allpins=6:13;
            if ~isnumeric(val) && ~all(ismember(val,allpins))
                error('pins must be a vector (N>=1) containing the integers 6--13 inclusive');
            end
            o.pins=val;
            % pre-convert the pins array to a 8-bit code, e.g. [6 10 13] -> '10001001'
            bitstr=dec2bin(0,8); % '00000000'
            bitstr(ismember(allpins,o.pins))='1';
            o.pins_as_byte=char(bin2dec(bitstr)); %#ok<MCSUP>
        end
        function set.port(o,val)
            if ispc
                if ischar(val) && strncmpi(val,'COM',3) && numel(val)>3 && ~isnan(str2double(val(4:end)))
                    o.port=upper(val);
                else
                    error('a:b','port must be a string like, for example, ''COM1''.\n\tTIP: Use the Arduino IDE to look up the com-port for your device under ''Tools>Port''');
                end
            else
                o.port=val; % I don't know what port names look like on ~PCs, you're on your own
            end     
        end 
    end
    methods (Static)
        function sketch
            % Copy/paste the below sketch into the Arduino IDE (Windows
            % Strore, for example) and upload it to your Arduino Uno.
            %
            % // --- BEGIN OF ARDUINO CODE ---
            % 
            % /* Digital Input (pins 2--5) and Output (pins 6--13) for
            %   Neurostim-PTB. See also: ArduinoTtl.m
            %   Jacob Duijnhouwer, 20180731 */
            % 
            % const char sketch_name_and_version[]="DIO20180731a";
            % bool inPinIsOn[6];
            %
            % void setup()
            % {
            %   // Setup the inputs
            %   for (int pin = 2; pin < 6; pin++) {
            %     pinMode(pin, INPUT);
            %     inPinIsOn[pin] = false;
            %   }
            %   // Setup the outputs
            %   for (int pin = 6; pin < 14; pin++) {
            %     pinMode(pin, OUTPUT);
            %     digitalWrite(pin, LOW);
            %   }
            %   // Setup the Serial link with matlab
            %   Serial.begin(9600);
            %   // Initiate handshake with Matlab, send out ID
            %   Serial.println(sketch_name_and_version);
            %   char c = '0';
            %   while (c != 'm') {
            %     // Until host has send the letter 'm' ...
            %     c = Serial.read();
            %   }
            %   Serial.println(sketch_name_and_version);
            %   // now, loop() will be called until connection is closed
            % }
            %
            % void loop()
            % {
            %   /*  Registers the inputs, i.e., voltage being put on pins 0--5.
            %     It's important that the input-pins are connected to ground
            %     through a, say 10kOhm resistor so that when released they are
            %     immediately pulled to ground. Else, if they're just floating,
            %     random time will pass */
            %
            %   for (int pin = 2; pin <= 5; pin++) {
            %     if (digitalRead(pin) == HIGH && inPinIsOn[pin] == false) {
            %       Serial.println(pin, DEC);
            %       inPinIsOn[pin] = true;
            %     }
            %     else if (digitalRead(pin) == LOW && inPinIsOn[pin] == true)
            %     {
            %       Serial.println(-pin, DEC); // output negative pin number
            %       inPinIsOn[pin] = false;
            %     }
            %     Serial.flush(); // Waits for transmission to complete
            %   }
            %   delay(5); // in ms
            % }
            %
            % void serialEvent()
            % {
            %   // This function is called automatically in the event new
            %   // data is available on the serial link
            %   char c = Serial.read();
            %   for (int bitnr = 0; bitnr < 8; bitnr++) {
            %     if bitRead(c, bitnr) { // bitnr 0 is least significant, rightmost bit
            %       digitalWrite(13 - bitnr, HIGH);
            %     }
            %     else {
            %       digitalWrite(13 - bitnr, LOW);
            %     }
            %   }
            % }
            % // --- END OF ARDUINO CODE ---
            help neurostim.stimuli.arduinoTtl.sketch
        end
    end
end


