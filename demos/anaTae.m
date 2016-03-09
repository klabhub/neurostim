[choice,~,tr]= getEvent(data,'pressedKey','choice');
[orientation,~,trO] =  getEvent(data,'orientation','testGabor','onePerTrial',true);
[adapter,~,trO] =  getEvent(data,'orientation','adapt','onePerTrial',true);

uOris = unique(orientation);
uAdapt = unique(adapter);

pctCCW = nan(numel(uAdapt),numel(uOris));

aCntr=0;
for a = uAdapt
    aCntr= aCntr+1;
    oCntr = 0;
    for o=uOris
        oCntr = oCntr+1;
        stay = adapter == a & orientation == o;
        pctCCW(aCntr,oCntr) = mean(strcmp('ccw',choice(stay)));
    end
end
plot(uOris,pctCCW)
legend(num2str(uAdapt(:)))
