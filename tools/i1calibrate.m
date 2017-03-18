function [c,cal,cTest]=i1calibrate(varargin)
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

import neurostim.*

p =inputParser;
p.addParameter('skipWhiteTile',false);
p.addParameter('fakeItAll',false);
p.addParameter('measure',true);
p.addParameter('show',true);
p.addParameter('saveFile','');
p.addParameter('lumTest',false);
p.addParameter('xylTest',false);
p.addParameter('nrRepeats',3); % How many times to measure each lum value
p.addParameter('nrGunSteps',10);  % Steps with which to measure gunvalues
p.addParameter('c',[]);
p.addParameter('nrTestLum',40);
parse(p,varargin{:});

T_xyz1931=[];
S_xyz1931 = [];
cals = {};
cal = [];
cTest=[];
if p.Results.fakeItAll
    load 'PTB3TestCal.mat'
    load T_xyz1931
    T_xyz = 683*T_xyz1931;
    fakeCal= SetSensorColorSpace(cals{end},T_xyz,S_xyz1931);
    fakeCal = SetGammaMethod(fakeCal,0);
elseif exist('I1') ~=3 && isempty(p.Results.c)%#ok<EXIST>
    error('Could not find the I1 mex-file that is required to run this calibration tool');
end


%% Setup CIC
if isempty(p.Results.c)
    %% Setup CIC and the stimuli.
    c = createCic(p.Results.fakeItAll);
    %% Define conditions and blocks
    % One block of gamma calibration
    gv  = linspace(0,1,p.Results.nrGunSteps);
    if strcmpi(c.screen.type ,'VPIXX-M16')
        colors = gv';
    else

    nrGv = numel(gv);
    red = [gv' zeros(nrGv,2)];
    colors = [red; red(:,[2 1 3]); red(:,[2 3 1]);[ 1 1 1]];
    end
    eachGun=design('rgb');
    eachGun.fac1.target.color  = num2cell(colors,2); 
    blck=block('rgbBlock',eachGun);
    blck.nrRepeats  = p.Results.nrRepeats;
else
    c = p.Results.c;
end


%% Connect and calibrate the I1
% Confirm that there is an i1 detected in the system
if ~p.Results.fakeItAll && I1('IsConnected') == 0
    error('No i1 detected');
end
if ~p.Results.fakeItAll && ~p.Results.skipWhiteTile
    disp('Place I1 onto its white calibration tile, then press any key to continue: ');
    pause
    disp('Calibrating...');
    I1('Calibrate');
end

%% Measure if requested
if p.Results.measure
    %% Run the calibration
    
    
    if p.Results.fakeItAll
        disp('Place your fake I1 on the center of the fake screen, then press any key to continue');
    else
        disp('Place I1 on the center of the screen, then press any key to continue');
    end
    pause;
    
    c.run(blck);
end

%% Show graphs

%% From the data extract cal structure
if p.Results.fakeItAll
    wavelengths = linspace(fakeCal.describe.S(1),fakeCal.describe.S(1)+fakeCal.describe.S(2)*fakeCal.describe.S(3),fakeCal.describe.S(3));
else
    wavelengths  = 380:10:730;
end
return
cal= neurostim.utils.ptbcal(c,'save',p.Results.saveFile,'plot',p.Results.show,'wavelengths',wavelengths); % Create a cal object in PTB format.

%% Test the calibration
if p.Results.lumTest
    % Generate some test luminance value per gun
    % Create a new cic
    cTest = createCic(p.Results.fakeItAll);
    % Apply the calibration to the CIC object
    cTest.screen.calibration.min = cal.neurostim.extendedGamma.min;
    cTest.screen.calibration.max = cal.neurostim.extendedGamma.max;
    cTest.screen.calibration.bias  = cal.neurostim.extendedGamma.bias;
    cTest.screen.calibration.gain = cal.neurostim.extendedGamma.gain;
    cTest.screen.calibration.gamma = cal.neurostim.extendedGamma.gamma;
    cTest.screen.calibration.gammaTable = cal.gammaTable;
    cTest.screen.calibration.gammaInput = cal.gammaInput;
    cTest.screen.calibration.maxLum   =  cal.neurostim.maxLum;
    cTest.screen.calibration.ambientLum = cal.neurostim.ambientLum;
    
    cTest.screen.colorMode = 'LUM'; % Uses a linearized gamma table together with extendedGamma 
   
    %% Test across the gamut
    targetLum = rand([p.Results.nrTestLum 3]).*repmat(cal.neurostim.maxLum,[p.Results.nrTestLum 1]);
    checkLum=neurostim.design('checkLum');
    checkLum.fac1.target.color  = num2cell(targetLum,2);
    checkLum.randomization  = 'sequential';    
    blck=block('checkLumBlock',checkLum);
    blck.nrRepeats  = 1;
    cTest.run(blck);

    %% Test predicted lums etc.    
    [testLxy] = get(cTest.prms.lxy,'AtTrialTime',inf);
    testLum = testLxy(:,1);
    specLum  = sum(get(cTest.target.prms.color,'atTrialtime',inf),2);
    
    figure;
    subplot(1,2,1);
    plot(specLum,testLum, '.');
    xlabel 'Target (cd/m^2)'
    ylabel 'Measured (cd/m^2)'
    axis equal;axis square;
    hold on
    plot(xlim,xlim,'k')
    
    subplot(1,2,2);
    delta = 100*(testLum-specLum)./specLum;
    hist(delta)
    xlabel 'Error (%)'
    ylabel '#Measurements'
    titel 'Mismatch'
    
    
end

%% Test the color calibration
if p.Results.xylTest
     % Create a new cic
    cxyL = createCic(p.Results.fakeItAll);
    
    
    
    xyLtarget = [0.2 0.4 5; 0.4 0.2 10; 0.33 0.33 25];
    %%
    % Apply the calibration to the CIC object
    cxyL.screen.calibration.min = 0;
    cxyL.screen.calibration.max = cal.neurostim.extendedGamma.max;
    cxyL.screen.calibration.bias  = cal.neurostim.extendedGamma.bias;
    cxyL.screen.calibration.gain = 1;
    cxyL.screen.calibration.gamma = cal.neurostim.extendedGamma.gamma;
    cxyL.screen.colorMode = 'xyL';
    cxyL.screen.calibration.calFile = [c.file '_ptb_cal.mat'];
    
    checkxyL=neurostim.design('checkLum');
    checkxyL.fac1.target.color  = num2cell(xyLtarget,2);
    checkxyL.randomization  = 'sequential';
    
    blck=block('checkxyLBlock',checkxyL);
    blck.nrRepeats  = 1;
    cxyL.run(blck);
    % One block to measure various colors (testing purpose)
    
    
    
    %% Test predicted lums etc.
    
    [testLxy] = get(cxyL.prms.lxy,'AtTrialTime',inf);
    
    figure;
    plot(sum(targetLumNorm,2),testLxy(:,1), '.');
    xlabel 'Target (cd/m^2)'
    ylabel 'Measured (cd/m^2)'
    axis equal;axis square;
    
    hold on
    plot(xlim,ylim,'k')
    
end

%% Local, nested function that does the measurements, called every frame.
    function measure(c,fakeItAll)
        if nargin<2
            fakeItAll = false;
        end
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



    function c = createCic(fake)
        c = neurostim.myRig;
        c.screen.colorMode = 'RGB';
        c.screen.type = 'VPIXX-M16';
        c.trialDuration = 250;
        c.iti           = 250;
        c.paradigm      = 'calibrate';
        c.subject      =  getenv('COMPUTERNAME');
        
        %% Define measurement routine
        c.addScript('AfterFrame',@(x) (measure(x,fake))); % Tell CIC to call this eScript after drawing each frame. Function is defined below.
        
        % Convpoly to create the target patch
        target = neurostim.stimuli.convPoly(c,'target');
        target.radius       = 5;
        target.X            = 0;
        target.Y            = 0;
        target.nSides       = 4;
        target.filled       = true;
        target.color        = 0;
        target.on           = 0;
        target.duration     = 1000;
        
        c.keyBeforeExperiment     = false;  % Dont wait for a key, keep runnng
        c.keyAfterExperiment      = false;
        
        c.dirs.calibration = 'c:/temp/';
        
        
    end

end





