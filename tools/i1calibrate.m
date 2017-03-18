function c=i1calibrate(skipWhiteTile,fakeItAll)
% Calibrate a monitor using the I1Pro spectrometer.
%
% This relies on the I1 Mex file.
%
% Set the skipWhiteTile input argument to true if you;ve already calibrated
% the I1Pro with the white tile.
%
% Set fakeItAll to true to run this without a photometer.
%
% BK - Dec 2016

if nargin < 2 
    fakeItAll = false;
    if nargin<1
        skipWhiteTile = false;
    end
end
T_xyz1931=[];
S_xyz1931 = [];
cals = {};

if fakeItAll 
    load 'PTB3TestCal.mat'
    load T_xyz1931
    T_xyz = 683*T_xyz1931;
    fakeCal= SetSensorColorSpace(cals{end},T_xyz,S_xyz1931); 
    fakeCal = SetGammaMethod(fakeCal,0);
elseif exist('I1') ~=3 %#ok<EXIST>
    error('Could not find the I1 mex-file that is required to run this calibration tool');
end

%% Prerequisites.
import neurostim.*


%% Setup CIC and the stimuli.
c = myRig; 
c.screen.colorMode = 'RGB';
c.screen.type = 'GENERIC';
c.trialDuration = 250;
c.iti           = 250;
c.paradigm      = 'calibrate';
c.subject      =  getenv('COMPUTERNAME');
%% Connect and calibrate the I1
% Confirm that there is an i1 detected in the system
if ~fakeItAll && I1('IsConnected') == 0
    error('No i1 detected');
end
if ~fakeItAll && ~skipWhiteTile
    disp('Place I1 onto its white calibration tile, then press any key to continue: ');
    pause
    disp('Calibrating...');
    I1('Calibrate');
end
if fakeItAll
    disp('Place your fake I1 on the center of the fake screen, then press any key to continue');
else
    disp('Place I1 on the center of the screen, then press any key to continue');
end
pause;

%% Setup the actual calibration routine.
c.addScript('AfterFrame',@measure); % Tell CIC to call this eScript after drawing each frame.
    function measure(c)
        if c.frame ==10
            % In frame 10 we'll measure                
            if fakeItAll
                % Generate fake Lxy and spectral data
                currentColor = c.target.color;
                switch c.screen.colorMode
                    case 'LUM'
                        
                    case 'RGB'
                        XYZ = PrimaryToSensor(fakeCal,currentColor'); xyL = XYZToxyY(XYZ);
                        Lxy = xyL([3 1 2])';
                        spc = (fakeCal.P_device * PrimaryToSettings(fakeCal,currentColor'))'; % 
                    case 'XYL'
                end
            else
                I1('TriggerMeasurement');
                Lxy = I1('GetTriStimulus');
                spc = I1('GetSpectrum');                           
            end
            write(c,'lxy',Lxy);
            write(c,'spectrum',spc);
            c.nextTrial; % And move to the next trial            
        end
    end

% Convpoly to create the target patch
target = stimuli.convPoly(c,'target');
target.radius       = 5;
target.X            = 0;
target.Y            = 0;
target.nSides       = 4;
target.filled       = true;  
target.color        = 0;
target.on           = 0;
target.duration     = 1000;


%% Define conditions and blocks
% One block of gamma calibration
step =0.1;
gv  = 0.1:step:1; % Gun values - per gun
nrGv = numel(gv);
red = [gv' zeros(nrGv,2)];
colors = [[0 0 0];red; red(:,[2 1 3]); red(:,[2 3 1]);[ 1 1 1]];
eachGun=design('rgb');
eachGun.fac1.target.color  = num2cell(colors,2);
blck=block('tfBlock',eachGun);
blck.nrRepeats  = 1; 
%% Run the calibration
c.run(blck);

%% From the data extract cal structure
if fakeItAll 
     wavelengths = linspace(fakeCal.describe.S(1),fakeCal.describe.S(1)+fakeCal.describe.S(2)*fakeCal.describe.S(3),fakeCal.describe.S(3));
else
    wavelengths  = 380:10:730;
end
cal= neurostim.utils.ptbcal(c,'save',[c.subject '_calibration'],'plot',true,'wavelengths',wavelengths); % Create a cal object in PTB format. 



%% Test the calibration
% Generate some test luminance value per gun
nrTestLums = 10;
gunValues= nan(nrTestLums,3);
gParms = cal.extendedGamma;
lums = repmat(gParms.bias,[nrTestLums 1]) + repmat(gParms.max,[nrTestLums 1]).*rand(nrTestLums,3); % Lum between 0 and maxLum per gun
for g=1:3
    gunValues(:,g) = gParms.lum2gun([gParms.gain(g) gParms.gamma(g) gParms.bias(g)],lums(:,g));
end

%%
% Apply the calibration to the CIC object
c.screen.calibration.min = 0;
c.screen.calibration.max = 1;
c.screen.calibration.bias  = gParms.gamma(1,:);
c.screen.calibration.gain = gParms.gamma(2,:);
c.screen.calibration.gamma = gParms.gamma(3,:);
c.screen.colorMode = 'LUM';

checkLum=neurostim.design('checkLum');
checkLum.fac1.target.color  = num2cell(lums,2);

blck=block('checkLumBlock',checkLum);
blck.nrRepeats  = 5;
c.run(blck);
% One block to measure various colors (testing purpose)
end



