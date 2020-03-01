function v = export(o,names)
if nargin<2
    names= {};
    subset =false;
else 
    subset= true;
end

meta = metaclass(o);
hasExport = ismember('export',{meta.MethodList.Name});
if hasExport && ~subset
    % Call the objects export function
    v  =export(o);
else
    if isstruct(o)
        fn = fieldnames(o);
    elseif isobject(o)
        % Export all public properties    
        fn = {meta.PropertyList.Name};
        access = {meta.PropertyList.GetAccess};
        no = cellfun(@iscell,access);
        [access{no}] =deal('no');
        out = ~strcmpi(access,'public');
        out = out | [meta.PropertyList.Dependent]==1;
        fn(out) = [];
    else
        disp '?'
    end
    if ~isempty(names)
      fn = intersect(fn,names);
    end
    if isempty(fn)
        v.(matlab.lang.makeValidName(meta.Name)) = 'not exported';
    else
    for i=1:numel(fn)
        try
            value = o.(fn{i});
        catch
            value = 'not exported';
        end
        if isobject(value) || isstruct(value)
            %Recursive call to this function
            subValue =  neurostim.utils.export(value);
            value = subValue;
        end
        v.(fn{i}) = value;
    end 
    end
end