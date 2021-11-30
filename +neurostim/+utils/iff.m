function val = iff(condition,trueVal,falseVal)
% Convenience function to allow a user to write a Neurostim 
% function with an if/then construct. This basically mimicks the 
% C-functionality a>b?c:d; 
% INPUT
% condition = expression that evaluates to a boolean
% trueVal   = value that will be returned when condition==true
% falseVal = value to be returned when condition == false
% 
% EXAMPLE 
% o.size = iff(this.time >5000,100,50)
% would assign 50 to o.size in the first 5 s after a stimulus is turned on
% and then 100 for the remainder.
% 
% NOTE 
% The only reason to have this function is that 
% using if/then in inline functions is not allowed in Matlab.
%
% BK - 2016

if (condition)
    val =trueVal;
else
    val = falseVal;
end
end