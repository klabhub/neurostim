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
p.addParameter('save',false,@islogical);
p.parse(varargin{:});


%%

cal.describe.leaveRoomTime = NaN;
cal.describe.boxSize = 400;
cal.nDevices = 3;
cal.nPrimaryBases = 1;
% I1Pro
cal.describe.S = [380 10 36];
cal.manual.use = 0;
cal.describe.whichScreen =  c.screen.number; % SCreen number that is calibrated
cal.describe.whichBlankScreen = NaN;
cal.describe.dacsize = ScreenDacBits(c.screen.number);
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
cal.describe.gamma.fitType = 'crtPolyLinear';
cal.describe.gamma.contrastThresh = 0.001;
cal.describe.gamma.fitBreakThresh = 0.02;

%% Now extract the measurements and average over repeats.
[lxy] = get(c.prms.lxy,'AtTrialTime',inf);
[rgb] = get(c.target.prms.color,'AtTrialTime',inf);
[spectrum] = get(c.prms.spectrum,'AtTrialTime',inf);
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
        nrRepeats(iCntr,g) = sum(stay);
        meanLxy(iCntr,:,g) = mean(thisLxy(stay,:)); %#ok<AGROW>
        meanSpectrum(iCntr,:,g) =  mean(thisSpectrum(stay,:)); %#ok<AGROW>
    end
end

cal.describe.nAverage = unique(nrRepeats(:)); % Not used, just bookkeeping
cal.describe.nMeas = size(meanSpectrum,1); % This is the number of levels that were measured.

isAmbient = all(rgb==0,2);
ambient = mean(spectrum(isAmbient,:),1);

nrGuns =size(meanSpectrum,3);
meanSpectrum = meanSpectrum-repmat(ambient,[size(meanSpectrum,1) 1 nrGuns]);
rectify = meanSpectrum<0;
disp(['Recitifed: ' num2str(100*sum(rectify(:))./numel(meanSpectrum)) '%'])
meanSpectrum(rectify) =0;
meanSpectrum = permute(meanSpectrum,[2 1 3]);
% Shape it in the [nrWavelenghts*nrLevels
meanSpectrum =reshape(meanSpectrum,[cal.describe.S(3)*cal.describe.nMeas nrGuns]);
cal.rawdata.mon = meanSpectrum;

% Now we've done all the preprocessing. Pass to PTB functions to extract
% its derived measures (compute gamma functions etc).

disp('Computing gamma, ambient ');
cal = CalibrateFitLinMod(cal);
% Define input settings for the measurements
mGammaInputRaw = linspace(0, 1, cal.describe.nMeas+1)';
mGammaInputRaw = mGammaInputRaw(2:end);
cal.rawdata.rawGammaInput = mGammaInputRaw;
cal = CalibrateFitGamma(cal, 2^cal.describe.dacsize);
Smon = cal.describe.S;
Tmon = WlsToT(Smon);
cal.P_ambient = ambient';
cal.T_ambient = Tmon;
cal.S_ambient = Smon;

% Save the result
if p.Results.save
    filename = [c.file '_ptb_cal'];
    disp(['Saving calibration result to ' fullfile(c.dirs.calibration,filename)]);
    SaveCalFile(cal, filename,c.dirs.calibration);
end

if p.Results.plot
% Put up a plot of the essential data
figure(1); clf;
plot(SToWls(cal.S_device), cal.P_device);
xlabel('Wavelength (nm)', 'Fontweight', 'bold');
ylabel('Power', 'Fontweight', 'bold');
title('Phosphor spectra', 'Fontsize', 13, 'Fontname', 'helvetica', 'Fontweight', 'bold');
axis([380, 780, -Inf, Inf]);

figure(2); clf;
plot(cal.rawdata.rawGammaInput, cal.rawdata.rawGammaTable, '+');
xlabel('Input value', 'Fontweight', 'bold');
ylabel('Normalized output', 'Fontweight', 'bold');
title('Gamma functions', 'Fontsize', 13, 'Fontname', 'helvetica', 'Fontweight', 'bold');
hold on
plot(cal.gammaInput, cal.gammaTable);
hold off

end





end