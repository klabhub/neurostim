function [f,h] = str2fun(str,c)
% Convert a string into a Matlab function handle
%
% BK - Mar 2016

    % @ as the first char signifies a function
    % Here we parse the string for plugin and property names, then create
    % an anonymous funcion that receives the handles of each unique objects
    % (neurostim.plugin or neurostim.parameter) in the function.
    % The tricky thing is to exclude all characters that cannot be the
    % start of the name of an object.
    %
    % Note: Here's an online tool to test and visualise regexp matches: https://regex101.com/
    % Set flavor to pcre, with modifier (right hand box) of 'g'.
    % One catch is that \< (Matlab) should be replaced with \b (online)  
    
    str = str(2:end);
    
    % Find the unique parameter class objects and store their handles
    % For behaviors we want to allow usage like
    % f1.startTime.fixating in ns functions. 
    % The code below translates this into the function call f1.startTime(''fixating'')
    plgAndProp = regexp(str,'(\<[a-zA-Z_]+\w*)\.([\w\.]+)','match');    
    plgAndProp = unique(plgAndProp);
    getLabel = cell(size(plgAndProp));
    h  = cell(size(plgAndProp));
    if ~isempty(plgAndProp)        
        for i=1:numel(plgAndProp)
            itms = strsplit(plgAndProp{i},'.');
            plg = itms{1};
            prm = itms{2};
            if numel(itms)==2
                prop = '';
                %Make sure plugin and parameter exists
                if isempty(prop) && ~(isprop(c,plg) && isprop(c.(plg),prm))
                    c.error('STOPEXPERIMENT',horzcat('No such plugin or property: ',plgAndProp{i}));
                end
            else% Special case for behaviors: behavior.startTime.fixating
                prop = itms{3}; % This is the state whose startTime is requested
                % Make sure this behavior exists
                 if ~isprop(c,plg) || ~isa(c.(plg),'neurostim.behavior')
                    c.error('STOPEXPERIMENT',horzcat('No such behavior : ',plg, '. Cannot parse ',plgAndProp{i}));
                 end
            end               
            
            %Get the handle of the relevant object (neurostim.paramter or neurostim.plugin)
            if isfield(c.(plg).prms,prm)
                %It's a ns parameter (dynprop). Use the param handle.
                h{i} = c.(plg).prms.(prm); % Array of handles.
                getLabel{i} = 'getValue()';% Array of parameters.
                if ~isempty(prop)
                    c.error('STOPEXPERIMENT',horzcat('Cannot access the struct dynamic property: ',plgAndProp{i}));
                end
            else
                %It's just a regular property. Use the plugin handle.
                h{i} = c.(plg);% Array of handles.
                if isempty(prop) % Regular property
                    getLabel{i} = prm;% Array of parameters.
                else % Information on the state of a behavior
                    getLabel{i} = [prm '(''' prop ''')'];% Turn the call into a function
                end                
            end
        end
        
        %Replace each reference to them with args(i)
        for i=1:numel(h)
            str = regexprep(str, ['(\<' plgAndProp{i}, ')'],['args{',num2str(i),'}.' getLabel{i}]);
        end
    else
        h = {};
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
end