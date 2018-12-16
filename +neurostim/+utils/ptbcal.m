function [cal] = ptbcal(c,varargin)
%function [ cal ] = ptbcal( c)
% Extract PTB cal structure from a neurostim CIC object that contains the
% results of a calibration experiment (see i1calibrate in demos)
% The main requirement of the experiment is that it stores
%  Lxy : the Luminance anc CIE xy values
%  rgb :  The rgb values corresponding to the measurements
% spectrum: the full spectrum for each of the values
% See i1calibrate for an example script that generates such a cic object as
% its output.
% 
% BK  - Feb 2017

p=inputParser;
p.addParameter('plot',true,@islogical);
p.addParameter('save','',@ischar); % File name where to save. Dir is c.dirs.calibration
p.addParameter('wavelengths',380:10:730,@isnumeric);
p.parse(varargin{:});

if ~isa(c,'neurostim.cic')
    error('ptbcal needs a cic object as its input');
end
if ~isfield(c.prms,'lxy')
    error('Cannot extract a cal struct from this CIC object: no measurements?');
end

%% Extract the measurements .
[lxy] = get(c.prms.lxy,'AtTrialTime',inf);
[rgb] = get(c.target.prms.color,'AtTrialTime',inf);
[spectrum] = get(c.prms.spectrum,'AtTrialTime',inf)/1000; %Radiance in W/(m2 sr nm)

nrGuns = size(rgb,2);

%% Basic cal definition
cal.describe.leaveRoomTime = NaN;
cal.describe.boxSize = NaN;
cal.nDevices = nrGuns; % guns
cal.nPrimaryBases = 1;

% I1Pro
cal.describe.S = [min(p.Results.wavelengths) unique(round(diff(p.Results.wavelengths))) numel(p.Results.wavelengths)];
cal.manual.use = 0;
cal.describe.whichScreen =  c.screen.number; % SCreen number that is calibrated
cal.describe.whichBlankScreen = NaN;
cal.describe.dacsize = max(8,ScreenDacBits(c.screen.number)); % This determines the interpolation steps for the normalized gamma
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

% Find each of the single gun modulations and average over repeated
% measures

for g=1:nrGuns
    stay = find(all(rgb(:,setdiff(1:nrGuns,g))==0,2) & rgb(:,g)>0);
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
    end
    % Sanity check: integrating the spectrum with Judd-Vos 2 degree vlambda should be the
    % luminance: multiple with the step size of the wavelenghts and with
    % the maximum human efficiency (683 lm/W). I checked, this works fine:
    % lumFromSpec./ meanLxy(:,1,:)   ~ 1
    %lumFromSpec(:,g) = (vlambda(p.Results.wavelengths,2)'*meanSpectrum(:,:,g)')'*unique(diff(p.Results.wavelengths))*683; %#ok<NASGU>
end

cal.describe.nAverage = unique(nrRepeats(:)); % Not used, just bookkeeping
cal.describe.nMeas = size(meanSpectrum,1); % This is the number of levels that were measured.
isAmbient = all(rgb==0,2);
ambient = mean(spectrum(isAmbient,:),1);
meanSpectrum = meanSpectrum-repmat(ambient,[size(meanSpectrum,1) 1 nrGuns]);
rectify = meanSpectrum<0;
disp(['Recitifed: ' num2str(100*sum(rectify(:))./numel(meanSpectrum)) '% ( = ' num2str(100*mean(meanSpectrum(rectify))/mean(meanSpectrum(~rectify))) ' % rad'])
meanSpectrum(rectify) =0;
meanSpectrum = permute(meanSpectrum,[2 1 3]);
% Shape it in the [nrWavelenghts*nrLevels nrGuns]
meanSpectrum =reshape(meanSpectrum,[cal.describe.S(3)*cal.describe.nMeas nrGuns]);
cal.rawdata.mon = meanSpectrum; % Ambient corrected mean spectrum for each gun at each of the levels
% The measurements of the spectrum for each of the guns was done at these
% gunvalues:
cal.rawdata.rawGammaInput = gv; 


% Now we've done all the preprocessing. Pass to PTB functions to extract
% its derived measures (compute gamma functions etc).
% This PTB function will take the measured spectra, for each gun, and find
% a linear model that describes them best (using SVD). I.e. it finds a
% basis function (or more .nPrimaryBases) and the projections onto that
% basis for each gun. The projection values are stored as
% cal.rawdata.rawGammaTable, these are between 0 and 1. The basis functions
% (essentially spectrum per gun) are stored as cal.P_device. 
cal = CalibrateFitLinMod(cal);
% Create a gamma table by interpolation. This is stored as cal.gammaTable
% and cal.gammaInput are the corresponding gunvalues. This table is used to
% do lookups
cal = CalibrateFitGamma(cal, 2^cal.describe.dacsize);


cal.P_ambient = ambient';
cal.T_ambient = WlsToT(cal.describe.S);
cal.S_ambient = cal.describe.S;



%% Neurostim specific additions are stored in cal.ns
ambientRatio = cal.P_ambient'*cal.P_device;
ambientRatio = ambientRatio./sum(ambientRatio);

cal.ns.meanLxy = meanLxy;
cal.ns.steLxy  = steLxy;
cal.ns.meanAmbientLum = ambientRatio.*mean(lxy(isAmbient,1));
cal.ns.steAmbientLum = ambientRatio.*std(lxy(isAmbient,1),0,1)/sqrt(sum(isAmbient));



%% Extended gamma
% Extract extended gamma parameters to use Gamma calibration
% using a power function fit.  These are used in LUM mode

lum = [cal.ns.meanAmbientLum ; squeeze(cal.ns.meanLxy(:,1,:))];
gv = [0 ;cal.rawdata.rawGammaInput];
%prms  = max gamma bias
lum2gun = @(prms,lum) (prms(3)+ (lum./prms(1)).^(1./prms(2))); 
gun2lum = @(prms,gv) (prms(1).*((gv-prms(3)).^prms(2)));
maxLum = max(lum);
for i=1:nrGuns
    parameterGuess = [maxLum(i) 1/2.2 0]; % max gamma bias
    [prms(i,:),residuals,~] = nlinfit(lum(:,i),gv,lum2gun,parameterGuess); %#ok<AGROW>
    cal.ns.R2(i)  =1-sum(residuals.^2)./sum(((gv-mean(gv)).^2));
end
% Add to cal struct to use later.
cal.ns.bias = prms(:,3)';
cal.ns.min  = zeros(1,nrGuns);
cal.ns.gain  = ones(1,nrGuns);
cal.ns.max   = prms(:,1)';
cal.ns.gamma  = prms(:,2)';
cal.ns.lum2gun  = lum2gun;
cal.ns.gun2lum  = gun2lum;
cal.ns.maxLum = squeeze(cal.ns.meanLxy(end,1,:))'; % not corrected for ambient


% Save the result
if ~isempty(p.Results.save)        
    disp(['Saving calibration result to ' fullfile(c.dirs.calibration,p.Results.save)]);
    SaveCalFile(cal, p.Results.save,c.dirs.calibration);
end

if p.Results.plot
    neurostim.utils.plotCal(cal)
end




end