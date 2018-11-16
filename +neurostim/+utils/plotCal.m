function plotCal(cal)
% Take a cal struct (e.g. the output of utils.ptbcal) and postprocess it to
% extract further calibration measures.




    % Put up a plot of the essential data
    figure; clf;
    subplot(2,2,1);
    colors = 'rgb';
    nrGuns  =cal.nDevices;
    
    for i=1:nrGuns
        plot(SToWls(cal.S_device), cal.P_device(:,i),colors(i));
        hold on
    end
    xlabel('Wavelength (nm)');
    
    ylabel('Radiance (W/m^2 sr nm)');
    title('Phosphor spectra');
    axis([380, 780, -Inf, Inf]);
    
    subplot(2,2,2);
    for i=1:nrGuns
        plot(cal.rawdata.rawGammaInput, cal.rawdata.rawGammaTable(:,i), [colors(i) '*']);
        hold on
        plot(cal.gammaInput, cal.gammaTable,colors(i));
    end
    xlabel('Gun value [0 1]');
    ylabel('Normalized output [0 1]')
    title('Normalized Gamma functions');
    hold off
    
    subplot(2,2,3);
    color = 'rgb';
    gvI = linspace(0,1,100);
    gv = [cal.rawdata.rawGammaInput];
    for i=1:nrGuns
        errorbar(gv,cal.ns.meanLxy(:,1,i),cal.ns.steLxy(:,1,i),cal.ns.steLxy(:,1,i),['o' color(i)]);        
        hold on    
        prms = [cal.ns.max(i) cal.ns.gamma(i) cal.ns.bias(i) ];
        plot(gvI,cal.ns.gun2lum(prms,gvI),['-' color(i)])        
    end
    ylabel 'Luminance (cd/m^2)'
    xlabel 'GunValue [0 1]')
    xlim([0 1]);
    
    title (['Inverse Gamma. R^2 = ' num2str(cal.ns.R2,3)]);
    
    str = [cal.describe.computer ':' datestr(cal.describe.date)];
    annotation(gcf,'textbox',[0 0 1 1],'String',str,'HorizontalAlignment','Center')



end