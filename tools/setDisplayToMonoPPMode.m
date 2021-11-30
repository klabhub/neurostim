function setDisplayToMonoPPMode
% sets Display-plus-plus to Mono-Plus-Plus mode

s1 = serial('COM4');
fopen(s1);
fprintf(s1,['$monoPlusPlus' 13]);
% fprintf(s1,['$statusScreen' 13]);
% fprintf(s1,['$USB_massStorage' 13]); %toggle me on for storage mode
fclose(s1);
delete(s1)
clear s1