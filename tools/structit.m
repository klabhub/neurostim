function s= struct(o)
% Convert this plugin to a struct.

%%
s = struct(o);
fns = fieldnames(s);

for fn = fns'
    switch class(s.(fn))
        case {'logical','double','char','struct','cell'}
            
        otherwise
            s.(fn) = struct(s.(fn)); % Recursive
    end
end
end