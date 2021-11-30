function setDisplayToMassStore
% sets Display-plus-plus to Mono-Plus-Plus mode

%s1 = serial('COM5');
fopen(s1);
fprintf(s1,['$statusScreen' 13]);
fprintf(s1,['$USB_massStorage' 13]); %toggle me on for storage mode
fclose(s1);
delete(s1)

fprintf('You should now be seeing the D++ status screen.. \n'); 

clear s1