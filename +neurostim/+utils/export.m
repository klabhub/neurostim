function v = export(o,names)
% By default, the CIC object with all of the plugins, behaviors etc. it
% contains is saved to disk at the end of an experiment. This is a complete
% record of the experiment, but it has the disadvantage that opening it
% requires a full installation of the Neurostim toolbox (and may even require
% PsychToolbox). THis is not ideal for data analysis, which need not care
% about any of the neurostim or PsychToolbox internals.
% 
% This function takes a CIC object as its input and returns a struct with
% all important information. This can be saved to disk and used in data
% analysis. 
% 
% For all objects , the export struct contains only the values of the
% *public* member variables.
% For the all important neurostim parameters (typically used to log experiment
% relevant parameters that are more than internal bookkeeping), the export struct
% contains all values (including the time point at which those values were
% set.)
%
% INPUT
%  o - A CIC object (recursive calls to this function will call this with
%  other objects too).
% names-  A list of member variables to export (Set to {} to export all public )
% OUTPUT
% v = a struct in which each field is a plugin, stimulus, or behavior. 
%
% BK  - Feb 2020

if nargin<2
    names= {};
    subset =false;
else 
    subset= true;
end
persistent stack
if isempty(stack)
    stack = {};
end

meta = metaclass(o);
hasExport = ismember('export',{meta.MethodList.Name});

if hasExport && ~subset
    % Call the objects export function - CIC, plugin, and parameter have
    % their own export functions.
    if ismember(meta.Name,stack)
        % Recursion. Skip
        v.(matlab.lang.makeValidName(meta.Name)) = 'not exported (recursion)';
    else
        stack = cat(2,stack,{meta.Name});
        v  =export(o);
        stack = stack(1:end-1);
    end
else
    if isstruct(o)
        % Export all fields
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
        o
        error('Export failed. Innput should be an object or a struct') % You should not 
    end
    % Cut to the specified names if any.
    if ~isempty(names)
      fn = intersect(fn,names);
    end
    % None to export; take note
    if isempty(fn)
        v.(matlab.lang.makeValidName(meta.Name)) = 'not exported';
    else
   % Loop over all fields/members
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
        v.(fn{i}) = value; %Store it
    end 
    end
end