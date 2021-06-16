function c = myRig(varargin)
% This is a template for a convenience function that sets up a CIC object 
% with appropriate settings for the current rig/computer. Rather than
% changing this file (inside the neurostim toolbox), make a copy and put
% that in your own experiments repository or somewhere else ahead on the search path 
% compared to this template myRig function 
% 
% 
% Note that nsGui calls this function with 'cic' set to the cic object as
% defined by the settings in the GUI and with 'debug' set as selected in the
% GUI. All other parameter/value pairs are for command line use only (and will get their
% default values when called from nsGUI)

pin = inputParser;
% nsGUI parameters.
pin.addParameter('cic',[]);
pin.addParameter('debug',false);
% Other convenience parameters.
pin.addParameter('smallWindow',false);   %Set to true to use a half-screen window
pin.addParameter('bgColor',[0.25,0.25,0.25]);
pin.addParameter('cicConstructArgs',{});
pin.parse(varargin{:});

%% Create or extract a CIC
import neurostim.*
if isempty(pin.Results.cic)
    %Create a Command and Intelligence Center object - the central controller for Neurostim.
    c = cic(pin.Results.cicConstructArgs{:});
else
    % Use the cic created by nsGui
    c = pin.Results.cic;
end

%% Retrieve some information on our current installation.
[here,myRigFile] = fileparts(mfilename('fullpath'));
computerName = getenv('COMPUTERNAME');
if isempty(computerName)
    [~,computerName] =system('hostname');
    computerName = deblank(computerName);
end

%% Lab defaults 
c.dirs.output             = tempdir; % Output files will be stored here.
c.iti                     = 500;
c.saveEveryBlock          = true;
c.saveEveryN              = inf;
c.hardware.textEcho       = true;
c.useConsoleColor         = true;
c.useFeedCache            = true;
c.hardware.keyEcho        = true;
c.timing.vsyncMode        = 0; % 0 waits for the flip and makes timing most accurate.
c.screen.colorMode        = 'RGB';        
c.screen.type             = 'GENERIC';                    
c.cursor                  = 'arrow';  % Probably easiest for user to keep seeing the mouse in a demo.
%% Lab default settings that vary with debug flag
if pin.Results.debug
    
else
    % Actual Experiment
    Screen('Preference', 'SkipSyncTests', 0); % Make sure PTB runs its tests.    
    %c.cursor = 'none';
end

%% Settings that vary per machine
switch upper(computerName)
    case 'EXPERIMENTRIG'
        % An example experimental rig called 'experimentrig'
        c.screen.number     = 2; % Use the second screen as the display for the subject
        c.screen.frameRate  = 120;
        % Geometry
        c.screen.xpixels    = 1920;
        c.screen.ypixels    = 1080;
        c.screen.xorigin    = [];
        c.screen.yorigin    = [];
        c.screen.width      = 52;
        c.screen.height     = c.screen.width*c.screen.ypixels/c.screen.xpixels;

    otherwise
        fprintf('This computer (%s) is not recognised. Using default settings.\nHint: Make your own myRig function to prevent this warning. Starting from template %s.\n',computerName,strrep(fullfile(here,myRigFile),'\','/'));        
        scrNr = max(Screen('screens'));
        fr = Screen('FrameRate',scrNr);
        rect = Screen('rect',scrNr);
        c.screen.number =scrNr;
        c.screen.xpixels    = rect(3)/2; % Start half size so that you can get to the command line
        c.screen.ypixels    = rect(4)/2;
        c.screen.xorigin    = [];
        c.screen.yorigin    = [];
        c.screen.width      = 42;
        c.screen.height     = c.screen.width*c.screen.ypixels/c.screen.xpixels;
        c.screen.frameRate  = fr;        
end

if pin.Results.smallWindow
    c.screen.xpixels = c.screen.xpixels/2;
    c.screen.ypixels = c.screen.ypixels/2;
end

c.screen.color.background = pin.Results.bgColor;


%% Additional sections could follow here, with for instance
% specific settings for a subject. 

    