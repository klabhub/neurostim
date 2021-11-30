function whichKeyboardIsThis
% Run this to find the numeric ID's of a keyboard. Just press a key on the
% keyboard and this function will give the Keyboard index. This keyboard
% index is the number to use as cic.kbInfo.subject (the keyboard that your
% subjects use) or cic.kbInfo.experimenter (the keyboard you use to control
% your experiment).
% 
% Press escape to quit the loop.
%
keyboards = GetKeyboardIndices;
while (true)
    for kb = keyboards
        [keyIsDown,~,keyCode] = KbCheck(kb);
        if keyIsDown
             disp([KbName(keyCode)  ' pressed on keyboard: ' num2str(kb)]);
             if strcmpi(KbName(keyCode),'ESCAPE')
                 return;
             end
        end
        
    end
end
    