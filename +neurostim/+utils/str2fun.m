function f = str2fun(str)
% Convert a string into a Matlab function handle
%
% BK - Mar 2016

if isa(str,'function_handle')
    % IT's already a handle
    f = str;
elseif ~isempty(str) && strcmpi(str(1),'@')
    % @ as the first char signifies a function
    % Replace stim.size with this.cic.stim.size to allow indirection
    % through cic (assuming that in x.y x always refers to a
    % plugin/stimulus
    funStr = ['@(this) (' regexprep(str(2:end),'(?<plgin>\<[^\d,\[\(\]\)\+-\*\\/]\w*\.)','this.cic.$0') ')'];
    
    % Assignments a=b are not allowed in function handles. (Not sure why). 
    % Replaceit with set(a,b);       
    funStr = regexprep(funStr,'(?<plgin>this.cic.\w+)\.(?<param>\<\w+)\s*=\s*(?<value>\w+)','setProperty($1,''$2'',$3)');

    % Make sure the iff function is found inside the utils package.`
    funStr = regexprep(funStr,'\<iff\(','neurostim.utils.iff(');    

    % Now evaluate the string to create the function    
    try 
        f= eval(funStr);
    catch
        error(['''' str ''' could not be turned into a function: ' funStr]);        
    end
    
elseif isempty(str)
    f = '';
else
    error('Cannot parse function definition?');
end
end