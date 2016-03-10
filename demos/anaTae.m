% Analyze the output of the tae.m Neurostim demo.
% data is the saved data struct
%
% BK - Mar 2016

import neurostim.utils.*

%% Pull the relevant properties from the output data struct.
[choice,~,tr]= getproperty(data,'pressedKey','choice'); % Retrieve all choices
[orientation,~,trO] =  getproperty(data,'orientation','testGabor','onePerTrial',true); % Retrieve test orientation per trial
[adapter,~,trO] =  getproperty(data,'orientation','adapt','onePerTrial',true); % Retrieve adapter orientation per trial
uOris = unique(orientation);
uAdapt = unique(adapter);
pctCCW = nan(numel(uAdapt),numel(uOris));

%% Calculate performance for all conditions
aCntr=0;
% Loop over adapters
for a = uAdapt
    aCntr= aCntr+1;
    oCntr = 0;
    % Loop over test orientations
    for o=uOris
        oCntr = oCntr+1;
        stay = adapter == a & orientation == o;
        % Determine the percentage of trials in which the subject said
        % 'ccw'
        pctCCW(aCntr,oCntr) = mean(strcmp('ccw',choice(stay)));
    end
end

%% Create a graph
figure;
plot(uOris,pctCCW,'.-')
xlabel 'Test Orientation (deg)'
ylabel '%CCW'
legend(num2str(uAdapt(:)))
