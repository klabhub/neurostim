function [CIExyY] = readColorCal
% Shows how to make measurements using the ColorCAL II CDC interface.
% This script calls several other separate functions which are included
% below.
%
numReadings=9
% CIExyY returns the XYZ values for each measurement (each row
% represents a different measurement).

% CHANGE THIS TO APPROPRIATE PORT FOR YOUR SETUP
% Determine the appropriate value using Windows Device Manager.
ColorCALIICDCPort = 'COM3';

% Sets how many samples to take.
samples = 1;

% First, the ColorCAL II should have its zero level calibrated. This can
% simply be done by placing one's hand over the ColorCAL II sensor to block
% all light.
disp('Please cover the ColorCAL II so that no light can enter it, then press any key');

% Wait for a keypress to indicate the ColorCAL II sensor is covered.
pause;

% This is a separate function (see further below in this script) that will
% calibrate the ColorCAL II's zero level (i.e. the value for no light).
ColorCALIIZeroCalibrate(ColorCALIICDCPort);

% Confirm the calibration is complete. Position the ColorCAL II to take a
% measurement from the screen.
disp('OK, you can now uncover ColorCAL II. Please position ColorCAL II where desired, then press any key to continue');

% Wait for a keypress to confirm ColorCAL II is in position before
% continuing.
pause;

% Obtains the XYZ colour correction matrix specific to the ColorCAL II
% being used, via the CDC port. This is a separate function (see further
% below in this script).
myCorrectionMatrix = getColorCALIICorrectionMatrix(ColorCALIICDCPort);

% Cycle through each sample.
for i = 1:numReadings
    
    % ADD CODE TO DISPLAY TEST PATCH TO BE MEASURED HERE.
    
    % Pause for approximately 1 second to allow sufficient time for the
    % test patch to be displayed. We do not want our measurement to be
    % taken during the screen transition time from its old value to its new
    % value.
    % Alternatively, just using 'pause'(with no number) will wait for a
    % keypress, allowing for a more flexible interval between measurements
    % for user to ensure desired stimulus is on screen when measurement is
    % made.
    pause(0.05);
    
    % Display a message to let user know what stage the process is at.
    disp(['Taking Measurement ' num2str(i)]);
    
    % Ask the ColorCAL II to take a measurement. It will return 3 values.
    % This is a separate function (see further below in this script).
    myRecording = ColorCALIIGetValues(ColorCALIICDCPort);
    
    % The returned values need to be multiplied by the ColorCAL II's
    % individual calibration matrix, as retrieved earlier. This will
    % convert the three values into CIE XYZ.
    transformedValues(i, 1:3) = myCorrectionMatrix * myRecording';
    CIExyY = XYZToxyY(transformedValues')'
    pause
end

% Convert recorded XYZ values into CIE xyY values using PsychToolbox
% supplied function XYZToxyY (included at the bottom of the script).
CIExyY = XYZToxyY(transformedValues')';

function myCorrectionMatrix = getColorCALIICorrectionMatrix(ColorCALIICDCPort)
% Obtains the individual correction matrix for the ColorCAL II, to be used
% to translate measured readings to calibrated XYZ values

% Use the 'serial' function to assign a handle to the port ColorCAL II is
% connected to. This handle (s1 in the current example) will then be used
% to communicate with the chosen port).
s1 = serial(ColorCALIICDCPort);

% Open the ColorCAL II port so that it is open to be communicated with.
% Communication with the ColorCAL II occurs as though it were a text file.
% Therefore to open it, use fopen.
fopen(s1);

% It can be useful to contain codes within 'try/catch' statements so that
% if the code raises an error and aborts part way, the 'catch' can be used
% to ensure any open ports are closed properly. Aborting the script without
% closing the ports properly may prevent the port from being reopened again
% in future. If this happens, just close and reopen MATLAB.
try
    
    % Cycle through the 3 rows of the correction matrix.
    for j = 1:3
        
        % whichColumn is to indicate the column the current value is to be
        % written to.
        whichColumn = 1;
        
        % Commands are passed to the ColorCAL II as though they were being
        % written to a text file, using fprintf. The commands 'r01', 'r02'
        % and 'r03' will return the 1st, 2nd and 3rd rows of the correction
        % matrix respectively. Note the '13' represents the terminator
        % character. 13 represents a carriage return and should be included
        % at the end of every command to indicate when a command is
        % finished.
        fprintf(s1,['r0' num2str(j) 13]);
        
        % This command returns a blank character at the start of each line
        % by default that can confuse efforts to read the values. Therefore
        % use fscanf once to remove this character.
        fscanf(s1);
        
        % To read the returned data, use fscanf, as though reading from a
        % text file.
        dataLine = fscanf(s1);
        
        % The returned dataLine will be returned as a string of characters
        % in the form of 'OK00, 8053,52040,50642'. Therefore loop through
        % each character until a O is found to be sure of the start
        % position of the data.
        for k = 1:length(dataLine)
            
            % Once an O has been found, assign the start position of the
            % numbers to 5 characters beyond this (i.e. skipping the
            % 'OKOO,').
            if dataLine(k) == 'O'
                myStart = k+5;
                
                % A comma (,) indicates the start of a value. Therefore if
                % this is found, the value is the number formed of the next
                % 5 characters.
            elseif dataLine(k) == ','
                myEnd = k+5;
                
                % Using j to indicate the row position and whichColumn to
                % indicate the column position, convert the 5 characters to
                % a number and assign it to the relevant position.
                myCorrectionMatrix(j, whichColumn) = str2num(dataLine(myStart:myEnd));
                
                % reset myStart to k+6 (the first value of the next number)
                myStart = k+6;
                
                % Add 1 to the whichColumn value so that the next value
                % will be saved to the correct location.
                whichColumn = whichColumn + 1;
                
            end
        end
    end
    
    % If an error occurs and the script aborts early, ensure ports are
    % closed to make it easier to reopen it in the future.
catch ME
    disp('Error');
    
    % Use fclose to close a serial port, the same as though closing a text
    % file.
    fclose(s1);
end

% Values returned by the ColorCAL II are 10000 times larger than their
% actual value. Also, negative values have a further 50000 added to them.
% These transformations need to be reversed to get the actual values.

% The positions of myCorrectionMatrix with values greater than 50000 have
% 50000 subtracted from them and then converted to their equivalent
% negative value.
myCorrectionMatrix(myCorrectionMatrix > 50000) = 0 - (myCorrectionMatrix(myCorrectionMatrix > 50000) - 50000);

% All values are then divided by 10000 to give actual values.
myCorrectionMatrix = myCorrectionMatrix ./ 10000;

% use fclose to close a serial port, the same as though closing a text
% file.
fclose(s1);

function ColorCALIIZeroCalibrate(ColorCALIICDCPort)
% Calibrate zero-level, by which to adjust subsequent measurements by.
% ColorCAL II should be covered during this period so that no light can be
% detected.

% Use the 'serial' function to assign a handle to the port ColorCAL II is
% connected to. This handle (s1 in the current example) will then be used
% to communicate with the chosen port).
s1 = serial(ColorCALIICDCPort);

% Open the ColorCAL II port so that it is open to be communicated with.
% Communication with the ColorCAL II occurs as though it were a text file.
% Therefore to open it, use fopen.
fopen(s1);

% Current status of the calibration success. This will be changed to 1 when
% calibration is successful.
calibrateSuccess = 0;

% Continue trying until a calibration is successful.
while calibrateSuccess == 0;

% It can be useful to contain codes within 'try/catch' statements so that
% if the code raises an error and aborts part way, the 'catch' can be used
% to ensure any open ports are closed properly. Aborting the script without
% closing the ports properly may prevent the port from being reopened again
% in future. If this happens, just close and reopen MATLAB.
try
    % Commands are passed to the ColorCAL II as though they were being
    % written to a text file, using fprintf. The command UZC will read
    % current light levels and store them in a zero correction array. All
    % subsequent light readings have this value subtracted from them before
    % being returned to the host. Note the '13' represents the terminator
    % character. 13 represents a carriage return and should be included at
    % the end of every command to indicate when a command is finished.
    fprintf(s1, ['UZC' 13]);
    
    % This command returns a blank character at the start of each line by
    % default that can confuse efforts to read the values. Therefore use
    % fscanf once to remove this character.
    fscanf(s1);
    
    % To read the returned data, use fscanf, as though reading from a text
    % file.
    dataLine = fscanf(s1);
    
    % The expected returned messag if successful is 'OKOO' or if an error,
    % 'ER11'. In case of any additional blank characters either side of
    % these messages, search through each character until either an O or an
    % E is found so that the start of the relevant message can be
    % determined.
    for k = 1:length(dataLine)
        
        % Once either an O or an E is found, the start of the relevant
        % information is the current character positiong while the end is 3
        % characters further (as each possible message is 4 characters in
        % total).
        if dataLine(k) == 'O' || dataLine(k) == 'E'
            myStart = k;
            myEnd = k+3;
        end
    end
    
    % the returned message is the characters between the start and end
    % positions.
    myMessage = dataLine(myStart:myEnd);
    
    % if the message is 'OK00', then report a successful calibration.
    if myMessage == 'OK00'
        disp('Zero-calibration successful');
        
        % calibration is successful. Changing calibrateSuccess to 1 will
        % break the while loop and allow the script to continue.
        calibrateSuccess = 1;
        
        % If an error message is returned, report an error, perhaps because
        % of too much residual light. Wait for a key press and then try
        % again. This while loop will continue until a success is returned.
    else
        disp('ERROR during zero-calibration. Perhaps too much light.') 
        disp('Ensure sensor is covered and press any key to try again');
        pause
    end
    
    % If an error occurs and the script aborts early, ensure ports are
    % closed to make it easier to reopen it in the future.
catch ME
    disp('Error');
    
    % use fclose to close a serial port, the same as though closing a text
    % file.
    fclose(s1);
end

end

% use fclose to close a serial port, the same as though closing a text
% file.
fclose(s1);

function myMeasureMatrix = ColorCALIIGetValues(ColorCALIICDCPort)
% Takes a reading. These values need to be transformed by above correction
% matrix to obtain XYZ values

% Use the 'serial' function to assign a handle to the port ColorCAL II is
% connected to. This handle (s1 in the current example) will then be used
% to communicate with the chosen port).
s1 = serial(ColorCALIICDCPort);

% Open the ColorCAL II port so that it is open to be communicated with.
% Communication with the ColorCAL II occurs as though it were a text file.
% Therefore to open it, use fopen.
fopen(s1);

% whichColumn is to indicate the column the current value is to be written
% to.
whichColumn = 1;

% It can be useful to contain codes within 'try/catch' statements so that
% if the code raises an error and aborts part way, the 'catch' can be used
% to ensure any open ports are closed properly. Aborting the script without
% closing the ports properly may prevent the port from being reopened again
% in future. If this happens, just close and reopen MATLAB.
try
    
    % Commands are passed to the ColorCAL II as though they were being
    % written to a text file, using fprintf. The command MES will read
    % current light levels and and return the tri-stimulus value (to 2
    % decimal places), adjusted by the zero-level calibration values above.
    % Note the '13' represents the terminator character. 13 represents a
    % carriage return and should be included at the end of every command to
    % indicate when a command is finished.
    fprintf(s1, ['MES' 13]);
    
    % This command returns a blank character at the start of each line by
    % default that can confuse efforts to read the values. Therefore use
    % fscanf once to remove this character.
    fscanf(s1);
    
    % To read the returned data, use fscanf, as though reading from a text
    % file.
    dataLine = fscanf(s1);
    
    % The returned dataLine will be returned as a string of characters in
    % the form of 'OK00,242.85,248.11, 89.05'. In case of additional blank
    % characters before or after the relevant information, loop through
    % each character until a O is found to be sure of the start position of
    % the data.
    for k = 1:length(dataLine)
        
        % Once an O has been found, assign the start position of the
        % numbers to 5 characters beyond this (i.e. skipping th 'OKOO,')
        if dataLine(k) == 'O'
            myStart = k+5;
            
            % A comma (,) indicates the start of a value. Therefore if this
            % is found, the value is the number formed of the next 6
            % characters
        elseif dataLine(k) == ','
            myEnd = k+6;
            
            % Using k to indicate the row position and whichColumn to
            % indicate the column position, convert the 5 characters to a
            % number and assign it to the relevant position.
            myMeasureMatrix(whichColumn) = str2num(dataLine(myStart:myEnd));
            
            % reset myStart to k+7 (the first value of the next number)
            myStart = k+7;
            
            % Add 1 to the whichColumn value so that the next value will be
            % saved to the correct location.
            whichColumn = whichColumn + 1;
            
        end
    end
    
    % If an error occurs and the script aborts early, ensure ports are
    % closed to make it easier to reopen it in the future.
catch ME
    disp('Error');
    
    % use fclose to close a serial port, the same as though closing a text
    % file.
    fclose(s1);
end

% use fclose to close a serial port, the same as though closing a text
% file.
fclose(s1);

function [xyY] = XYZToxyY(XYZ)
% [xyY] = XYZToxyY(XYZ)
%
% Compute chromaticity and luminance from tristimulus values.
%
% 8/24/09  dhb  Speed it up vastly for large arrays.

denom = sum(XYZ,1);
xy = XYZ(1:2,:)./denom([1 1]',:);
xyY = [xy ; XYZ(2,:)];