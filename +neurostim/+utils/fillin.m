function v = fillin(maxTrial, trials,values)
% Fill in one value per trial 
v = nan(1,maxTrial);
trials(trials==0)=1;
[~,lastIx] =unique(trials,'last');
v(trials(lastIx)) = [values{lastIx}];
current=v(1); 
if isnan(current)
    warning('First trial not defined...')
end
for tr=1:maxTrial
    if ~isnan(v(tr))
        current = v(tr);
    else
        v(tr) = current;
    end
end