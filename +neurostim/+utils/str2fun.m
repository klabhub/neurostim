function [f,h] = str2fun(str,c)
% Convert a string into a Matlab function handle
%
% BK - Mar 2016

if isa(str,'function_handle')
    % IT's already a handle
    f = str;
elseif strncmpi(str,'@',1)
    % @ as the first char signifies a function
    % Replace stim.size with this.cic.stim.size to allow indirection
    % through cic (assuming that in x.y x always refers to a
    % plugin/stimulus
    % The tricky thing is to exclude all characters that cannot be the
    % start of the name of an object. We could add some sanity check here
    % that when xxx.y is replaced with this.cic.xxx.y that xxx is actually
    % a plugin/stimulus.
    %
    % Note: Here's an online tool to test and visualise regexp matches: https://regex101.com/
    % Set flavor to pcre, with modifier (right hand box) of 'g'.
    % One catch is that \< (Matlab) should be replaced with \b (online)
    
    %Old version that goes via plugins and cic.
    %funStr = ['@(this) (' regexprep(str(2:end),'(\<[a-zA-Z_]+\w*\.\w+)','this.cic.$0') ')'];
    
    
    str = str(2:end);
    
    %Find the unique parameter class objects and store their handles
    plgAndProp = regexp(str,'(\<[a-zA-Z_]+\w*\.\w+)','match');
    plgAndProp = unique(plgAndProp);
    
    for i=1:numel(plgAndProp)
        plg = cell2mat(regexp(plgAndProp{i},'(\<[a-zA-Z_]+\w*\.)','match'));
        prm = strrep(plgAndProp{i},plg,'');
        plg = plg(1:end-1);
        h(i) = c.(plg).prms.(prm);
    end
    
    %Replace each reference to them with args(i)
    for i=1:numel(h)
        str = regexprep(str, ['(\<' plgAndProp{i}, ')'],['args(',num2str(i),').value']);
    end
    
    funStr = horzcat('@(args) ',str);
       
    % temporarily replace == with eqMarker to simplify assignment (=) parsing below.
    eqMarker = '*eq*';
    funStr = strrep(funStr,'==',eqMarker);
    % Assignments a=b are not allowed in function handles. (Not sure why). 
    % Replaceit with set(a,b);    
%     funStr = regexprep(funStr,'(?<plgin>this.cic.\w+)\.(?<param>\<\w+)\s*=\s*(.+)','setProperty($1,''$2'',$3)');
    funStr = regexprep(funStr,'(?<handle>args\(\d+\))\.value\s*=\s*(?<setValue>.+)','setProperty($1.plg,$1.hDynProp.Name,$2)');
    
    % Replace the eqMarker with ==
    funStr = strrep(funStr,eqMarker,'==');

    
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