function rc = eyelinkDispatchCallback(args, msg)
% Adapted from PsychEyelinkDispatchCallback - The host computer
% calls this with various arguments (callArgs) and those then get
% passed to plugin member functions for actual drawing to the
% screen.

% TODO
% Set this up directly without EyelinkInitDefaults

% BK April 2019

if nargin < 2
    msg = [];
end
persistent o
if isstruct(args)
    o =args.o;
    
    return;
end
if numel(args)~=4
    error('Incorrect arguments to the Eyelink callback');
end
eyeCmd = args(1);


rc=0;
if eyeCmd~=2
eyeCmd

args(2:end)
msg
end

% Flag that tells if a new camera image was received and our camera image texture needs update:
newCamImage = 0;
needsUpdate = 1;
calXY =[];
switch eyeCmd
    case 1
        % New videoframe received. See code below for actual processing.
        newCamImage = 1;
    case 2
        % Eyelink Keyboard query:
     %   [rc, o.el] = EyelinkGetKey(o.el);
     rc=0;
        needsUpdate = 0;
        return
    case 3
        % Alert message:
        o.writeToFeed(sprintf('Eyelink Alert: %s.\n', msg));
        needsUpdate = 0;
    case 4
        % Image title of camera image transmitted from Eyelink:
        if args(2) ~= -1
            o.title = sprintf('Camera: %s [Threshold = %f]', msg, args(2));
        else
            o.title = msg;
        end
    case 5
        % Define calibration target and enable its drawing:
        calXY = args(2:3);
        clearScreen=1;
    case 6
        % Clear calibration display:
        clearScreen=1;
        drawInstructions=1;
    case 7
        % Setup calibration display:
        if o.inDriftCorrect
            drawInstructions = 0;
            o.inDriftCorrect = false;
        else
            drawInstructions = 1;
        end
        clearScreen=1;
    case 8
        newCamImage = 1;
        % Setup image display:
        o.inDisplayEye=true;
        drawInstructions=1;
    case 9
        % Exit image display:
        clearScreen=1;
        o.inDisplayEye=false;
        drawInstructions=1;
    case 10
        % Erase current calibration target:
        calXY = [];
        clearScreen=1;
    case 11
        clearScreen=1;
    case 12
        % New calibration target sound:
        makeSound(o,'cal_target_beep');
        needsUpdate = 0;
    case 13
        % New drift correction target sound:
        makeSound(o, 'drift_correction_target_beep');
        needsUpdate = 0;
    case 14
        % Calibration done sound:
        errc = args(2);
        if errc > 0
            % Calibration failed:
            makeSound(o, 'calibration_failed_beep');
        else
            % Calibration success:
            makeSound(o, 'calibration_success_beep');
        end
        needsUpdate = 0;
    case 15
        % Drift correction done sound:
        errc = args(2);
        if errc > 0
            % Drift correction failed:
            makeSound(o, 'drift_correction_failed_beep');
        else
            % Drift correction success:
            makeSound(o, 'drift_correction_success_beep');
        end
        needsUpdate = 0;
    case 16
        [width, height]=Screen('WindowSize', o.window);
        % get mouse
        [x,y, buttons] = GetMouse(o.window);
        
        HideCursor
        if find(buttons)
            rc = [width , height, x , y,  dw , dh , 1];
        else
            rc = [width , height, x , y , dw , dh , 0];
        end
        needsUpdate = 0;
    case 17
        o.inDrift =1;
        needsUpdate = 0;
    otherwise
        % Unknown command:
        o.writeToFeed(sprintf('Eyelink callback: Unknown eyelink command (%i)\n', eyeCmd));
        needsUpdate = 0;
end

if ~needsUpdate
    % Nope. Return from callback:
    return;
end

% Need to rebuild/redraw and flip the display:
% need to clear screen?
if clearScreen==1
    Screen('FillRect', o.window, o.backgroundColor);
end
% New video data from eyelink?
if newCamImage
    % Video callback from Eyelink: We have a 'eyewidth' by 'eyeheight' pixels
    % live eye image from the Eyelink system. Each pixel is encoded as a 4 byte
    % RGBA pixel with alpha channel set to a constant value of 255 and the RGB
    % channels encoding a 1-Byte per channel R, G or B color value. The
    % given 'eyeimgptr' is a specially encoded memory pointer to the memory
    % buffer inside Eyelink() that encodes the image.
    ptr = args(2);
    imWidth  = args(3);
    imHeight = args(4);
    
    % Create a new PTB texture of proper format and size and inject the 4
    % channel RGBA color image from the Eyelink memory buffer into the texture.
    % Return a standard PTB texture handle to it. If such a texture already
    % exists from a previous invocation of this routiene, just recycle it for
    % slightly higher efficiency:
    
    GL_RGBA = 6408;
    GL_RGBA8 = 32856;
    GL_UNSIGNED_INT_8_8_8_8_REV = 33639;
    hostDataFormat = GL_UNSIGNED_INT_8_8_8_8_REV;
    o.eyeImageTexture = Screen('SetOpenGLTextureFromMemPointer', o.window,  o.eyeImageTexture, ptr, imWidth, imHeight, 4, 0, [], GL_RGBA8, GL_RGBA, hostDataFormat);
end

% If we're in imagemodedisplay, draw eye camera image texture centered in
% window, if any such texture exists, also draw title if it exists.
if ~isempty(o.eyeImageTexture) && o.inDisplayEye
    drawCameraImage(o);
end

% Draw calibration target, if any is specified:
if ~isempty(calXY)
    drawInstructions=0;
    drawCalibrationTarget(o,calXY);
end

% Need to draw instructions?
if drawInstructions==1
    o.cic.drawFormattedText(msg)
end

Screen('Flip', o.window, [], 1, 1); %Immediate flip,no clear.


end