function [cal] = ptbcal(c,varargin)
%function [ cal ] = ptbcal( c)
% Extract PTB cal structure from a neurostim CIC object that contains the
% results of a calibration experiment (see i1calibrate in demos)
% The main requirement of the experiment is that it stores
%  Lxy : the Luminance anc CIE xy values
%  rgb :  The rgb values corresponding to the measurements
% spectrum: the full spectrum for each of the values
% 
% BK  - Feb 2017

p=inputParser;
p.addParameter('plot',true,@islogical);
p.addParameter('save','',@ischar); % File name where to save. Dir is c.dirs.calibration
p.addParameter('wavelengths',380:10:730,@isnumeric);
p.parse(varargin{:});


%%

cal.describe.leaveRoomTime = NaN;
cal.describe.boxSize = NaN;
cal.nDevices = 3; % guns
cal.nPrimaryBases = 1;

% I1Pro
cal.describe.S = [min(p.Results.wavelengths) unique(round(diff(p.Results.wavelengths))) numel(p.Results.wavelengths)];
cal.manual.use = 0;
cal.describe.whichScreen =  c.screen.number; % SCreen number that is calibrated
cal.describe.whichBlankScreen = NaN;
cal.describe.dacsize = 10; % This determines the interpolation steps for the normalized gamma
cal.bgColor = c.screen.color.background;
cal.describe.meterDistance = c.screen.viewDist;
cal.describe.caltype = 'monitor';
cal.describe.computer = c.subject;
cal.describe.monitor = c.screen.number;
cal.describe.driver = '';
cal.describe.hz = c.screen.frameRate;
cal.describe.who = getenv('USERNAME');
cal.describe.date = c.date;
cal.describe.program = 'i1calibrate';
cal.describe.comment = 'no comment';
% These parameters determine how the normalized Gamma function will be interpolated
%  in CalibrateFitLinMod below
cal.describe.gamma.fitType = 'crtPolyLinear';
% in crtPolyLinear mode (heuristic), a cubic spline is used to fit the
% gamma function, then it is modified with these parameters
cal.describe.gamma.contrastThresh = 0.001; % Normalized gamma values [0 1] below this are set to zero
cal.describe.gamma.fitBreakThresh = 0.02;  % Normalized gamma values below this are linearly interpolated

%% Now extract the measurements and average over repeats.
[lxy] = get(c.prms.lxy,'AtTrialTime',inf);
[rgb] = get(c.target.prms.color,'AtTrialTime',inf);
[spectrum] = get(c.prms.spectrum,'AtTrialTime',inf); %Irradiance in mW/(m2 sr nm)
spectrum  =1000*spectrum; % [W/(m2 sr nm)]: SI units compatible with luminance cd/m2

cmfType = 'SB2';
for g=1:3
    stay = find(all(rgb(:,setdiff(1:3,g))==0,2) & rgb(:,g)>0);
    [gunValue,sorted] = sort(rgb(stay,g));
    thisLxy  = lxy(stay,:);
    thisLxy = thisLxy(sorted,:);
    thisSpectrum = spectrum(stay,:);
    thisSpectrum = thisSpectrum(sorted,:);
    [gv,~,ix] = unique(gunValue);
    iCntr=0;
    for i=unique(ix)'
        iCntr= iCntr+1;
        stay = ix ==i;
        nrRepeats(iCntr,g) = sum(stay); %#ok<AGROW>
        meanLxy(iCntr,:,g) = mean(thisLxy(stay,:),1); %#ok<AGROW>
        steLxy(iCntr,:,g) = std(thisLxy(stay,:),0,1)./sqrt(sum(stay)); %#ok<AGROW>
        meanSpectrum(iCntr,:,g) =  mean(thisSpectrum(stay,:),1); %#ok<AGROW>
        XYZ = spdtotristim(squeeze(meanSpectrum(iCntr,:,g)),p.Results.wavelengths,cmfType);
        spectrumLum(iCntr,g) = XYZ(2);
    end
end

cal.describe.nAverage = unique(nrRepeats(:)); % Not used, just bookkeeping
cal.describe.nMeas = size(meanSpectrum,1); % This is the number of levels that were measured.

isAmbient = all(rgb==0,2);
ambient = mean(spectrum(isAmbient,:),1);
ambientLum = mean(lxy(isAmbient,1));
ambientLumSe = std(lxy(isAmbient,1),0,1)/sqrt(sum(isAmbient));
nrGuns =size(meanSpectrum,3);
meanSpectrum = meanSpectrum-repmat(ambient,[size(meanSpectrum,1) 1 nrGuns]);
rectify = meanSpectrum<0;
disp(['Recitifed: ' num2str(100*sum(rectify(:))./numel(meanSpectrum)) '% ( = ' num2str(100*mean(meanSpectrum(rectify))/mean(meanSpectrum(~rectify))) ' % rad'])
meanSpectrum(rectify) =0;
meanSpectrum = permute(meanSpectrum,[2 1 3]);
% Shape it in the [nrWavelenghts*nrLevels nrGuns]
meanSpectrum =reshape(meanSpectrum,[cal.describe.S(3)*cal.describe.nMeas nrGuns]);
cal.rawdata.mon = meanSpectrum; % Ambient corrected mean spectrum for each gun at each of the levels

% Now we've done all the preprocessing. Pass to PTB functions to extract
% its derived measures (compute gamma functions etc).
% This PTB function will take the measured spectra, for each gun, and find
% a linear model that describes them best (using SVD). I.e. it finds a
% basis function (or more .nPrimaryBases) and the projections onto that
% basis for each gun. The projection values are stored as
% cal.rawdata.rawGammaTable, these are between 0 and 1. The basis functions
% (essentially spectrum per gun) are stored as cal.P_device. 
cal = CalibrateFitLinMod(cal);
% The measurements of the spectrum for each of the guns was done at these
% gunvalues:
cal.rawdata.rawGammaInput = gv; 
% Create a gamma table by interpolation. This is stored as cal.gammaTable
% and cal.gammaInput are the corresponding gunvalues. This table is used to
% do lookups
cal = CalibrateFitGamma(cal, 2^cal.describe.dacsize);
Smon = cal.describe.S;
Tmon = WlsToT(Smon);
cal.P_ambient = ambient';
cal.T_ambient = Tmon;
cal.S_ambient = Smon;

tmpCmf = load(c.screen.calibration.cmf);
fn = fieldnames(tmpCmf);
Tix = strncmpi('T_',fn,2); % Assuming the convention that the variable starting with T_ contains the CMF
Six = strncmpi('S_',fn,2); % Variable startgin with S_ specifies the wavelengths
T = tmpCmf.(fn{Tix}); % CMF
S = tmpCmf.(fn{Six}); % Wavelength info
T = 683*T;

% The "sensor" is the human observer and we can pick different ones by
% chosing a different CMF (in c.screen.calibration.cmf). Sensor coordinates
% are XYZ. 
cal = SetSensorColorSpace(cal,T,S);
cal = SetGammaMethod(cal,0);
% After setting this we can for instance get the correct settings for the
% gunvalues for a desired color/luminance:
% 
desired_xyL= [1/3 1/3 40]';
desired_XYZ = xyYToXYZ(desired_xyL);
desired_rgb = SensorToSettings(cal,desired_XYZ);



%%
% ALso extract extended gamma parameters to use simple Gamma calibration
ambientRatio = ambient*cal.P_device;
ambientRatio = ambientRatio./sum(ambientRatio);
lum = [ambientLum*ambientRatio ; squeeze(meanLxy(:,1,:))];
gv = [0 ;gv];
% lum = squeeze(meanLxy(:,1,:));
 lumSe = [ambientLumSe*ambientRatio;squeeze(steLxy(:,1,:))];

lum2gun = @(prms,lum) (prms(3)+ (lum./prms(1)).^(1./prms(2))); %
gun2lum = @(prms,gv) (prms(1).*((gv-prms(3)).^prms(2)));
for i=1:3
    maxLum = max(lum(:,i));
    parameterGuess = [maxLum 1/2.2 0]; % gain gamma bias
    [prms(i,:),residuals,~] = nlinfit(lum(:,i),gv,lum2gun,parameterGuess); %#ok<AGROW>
    cal.extendedGamma.R2(i)  =1-sum(residuals.^2)./sum(((gv-mean(gv)).^2));
end
cal.extendedGamma.bias = prms(:,3)';
cal.extendedGamma.min  = zeros(1,nrGuns);
cal.extendedGamma.gain  = ones(1,nrGuns);
cal.extendedGamma.max  = prms(:,1)';
cal.extendedGamma.gamma  = prms(:,2)';
cal.extendedGamma.lum2gun  = lum2gun;
cal.extendedGamma.gun2lum  = gun2lum;

% Save the result
if ~isempty(p.Results.save)        
    disp(['Saving calibration result to ' fullfile(c.dirs.calibration,p.Results.save)]);
    SaveCalFile(cal, p.Results.save,c.dirs.calibration);
end

if p.Results.plot
    % Put up a plot of the essential data
    figure(1); clf;
    plot(SToWls(cal.S_device), cal.P_device);
    xlabel('Wavelength (nm)', 'Fontweight', 'bold');
    ylabel('Irradiance (W/m^2 sr nm)', 'Fontweight', 'bold');
    title('Phosphor spectra', 'Fontsize', 13, 'Fontname', 'helvetica', 'Fontweight', 'bold');
    axis([380, 780, -Inf, Inf]);
    
    figure(2); clf;
    colors = 'rgb';
    for i=1:3
        plot(cal.rawdata.rawGammaInput, cal.rawdata.rawGammaTable(:,i), '+');
        hold on
        plot(cal.gammaInput, cal.gammaTable,colors(i));
    end
    xlabel('gun value [0 1]', 'Fontweight', 'bold');
    ylabel('Normalized output [0 1]', 'Fontweight', 'bold');
    title('Gamma functions', 'Fontsize', 13, 'Fontname', 'helvetica', 'Fontweight', 'bold');
   
    hold off
    
    figure(3);clf;
    color = 'rgb';
    for i=1:3
        errorbar(gv,lum(:,i),lumSe(:,i),color(i));
        
        hold on
        %x = lum(:,i) + ambientLum;
        plot(gv,cal.extendedGamma.gun2lum([cal.extendedGamma.max(i) cal.extendedGamma.gamma(i) cal.extendedGamma.bias(i)],gv),['*' color(i)])
        
    end
    xlabel 'Luminance (cd/m^2)'
    ylabel 'GunValue [0 1]')
    title 'Inverse Gamma'
end





end