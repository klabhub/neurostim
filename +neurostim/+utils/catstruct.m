function v = catstruct(dim,varargin)
% Create a struct array out of a comma separated list of structs while allowing for
% different fields in the structs. Fields that are not defined in some of
% the structs will get  [] (of the appropriate class) as their value.
%
% INPUT
% dim = Dimension along which to concatenate
% varargin = Comma separated list of structs.
% OUTPUT
% v = Cell array of structs
%
% EXAMPLE
%  a= struct('x',1,'y',2,'name',"My Name",'sub',struct);
%  b = struct('y',2,'name',"My Name",'sub',struct);
%  c = struct('y',2,'name',"My Name",'sub',struct,'extra',{{'bla','bla'}});
%  d = catstruct(1,a,b,c)
%
% BK - Dec 2022

nrStructs = numel(varargin);

% Find the union of all field names
eachFields= cellfun(@fieldnames,varargin,'UniformOutput',false);
allFields = unique(cat(1,eachFields{:}));
% Find structs that don't have the full set
missingFields= cellfun(@(x) (setdiff(allFields,x)),eachFields,'UniformOutput',false);
hasMissingIx = find(~cellfun(@isempty,missingFields));
allMissingFields = unique(cat(1,missingFields{hasMissingIx}));

if ~isempty(hasMissingIx)
    % Fill in the missing fields
    % Find the class of each missing field
    noneMissing = setdiff(1:nrStructs,hasMissingIx);
    if any(noneMissing)
        % We can get all meta data from one struct or the first element of a struct array
        meta = structfun(@class,varargin{noneMissing(1)}(1),'uniformoutput',false);
    else
        % Need to iterate until complete
        % Get as much as we can from the first
        meta = structfun(@class,varargin{1},'uniformoutput',false);
        i=2;
        % Then loop until complete
        while (i<=nrStructs)
            metaToDo = setdiff(intersect(allMissingFields,eachFields{i}),fieldnames(meta));
            for j=1:numel(metaToDo)
                meta.(metaToDo{j}) = class(varargin{i}.(metaToDo{j}));
            end
            if isempty(setdiff(allMissingFields,fieldnames(meta)));break;end %Done,
            i=i+1;
        end
        assert(isempty(setdiff(allMissingFields,fieldnames(meta))),'NOt all missing fields were found???')
    end

    % With the meta data, construct [] default values for each class.
    for j=1:numel(allMissingFields)
        thisClass = meta.(allMissingFields{j});
        switch thisClass
            case 'cell'
                thisDefValue = cell(0,0);
            case 'function_handle'
                thisDefValue = @(varargin)([]);
            case {'char','string'}
                thisDefValue = feval(thisClass,'');
            otherwise
                thisDefValue = feval(thisClass,[]);
        end
        defValue.(allMissingFields{j}) =thisDefValue;
    end

    % Update the ones structs that have missing fields with these defaults.
    for i = hasMissingIx
        for j=1:numel(missingFields{i})
            if isempty(varargin{i})
                varargin{i} = struct(missingFields{i}{j},defValue.(missingFields{i}{j}));
            else
                [varargin{i}.(missingFields{i}{j})] = deal(defValue.(missingFields{i}{j}));
            end
        end
    end
end

 v = cat(dim,varargin{:});