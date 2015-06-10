classdef  map <handle
properties (Constant)
    CHUNK = 10;             % Log size increase (NIY).
end
    properties
        keys@cell   = {};   % Current keys (char)
        values@cell = {};   % Currently stored values (any) 
        log;                % The timed assignment log of all keys and values
    end
    
    properties (Dependent)
        nrKeys@double;      % Number of keys currently stored in this map        
    end
    
    methods
        function v= get.nrKeys(m)
            v = length(m.keys);
        end
    end
    
    methods
        function m = map(varargin)
            % Create a map from a set of keys and values.
            if nargin >0
                k = varargin(1:2:end);
                v = varargin(2:2:end);
                if ~all(cellfun(@ischar,k)); error('Map Keys should be char');end
                if numel(k) ~=numel(v)
                    error('The number of Keys does not match the number of Values');
                end
                m.keys = k;
                m.values= v;
                t = now;
                m.log(1).keys   = k;
                m.log(1).values = v;
                m.log(1).t      = t*ones(1,length(k));
            else
                % No input. Just initialize an empty log.
                m.log(1).keys = {};
                m.log(1).values= {};
                m.log(1).t =[];
            end
        end
        
        function value = key(m,nr)
            if nr <= m.nrKeys
                value = m.keys{nr};
            else
                value = '';
            end
        end
        
        function value = length(m)
            value = m.nrKeys;
        end
       
        function value = isempty(m)
            value= m.nrKeys==0;
        end
        
        % Determine whether this char or cell array of chars is a key.
        function value = iskey(m,key)
            if size(m,1)>0
                value = ismember(key,m.keys);
            else
                value = false;
            end
        end
        
        % Delete this key (and its values)
        function remove(m,key)
            ix = index(m,key);            
            % Log the removal
            m.log.keys = cat(2,m.log.keys,m.keys(ix));
            logVal = cell(1,numel(ix));
            [logVal{:}] = deal(NaN);
            m.log.values = cat(2,m.log.values,logVal);
            % Remove
            m.keys(ix) = [];
            m.values(ix) =[];            
        end
        
        % Find the index corresponding to this key (char) or keys (cell)
        function ix = index(m,key)
            if iscell(key)
                nrKeys = numel(key);
                ix = nan(1,nrKeys);
                for k=1:nrKeys                    
                    ix(k) = index(m,key{k});
                end
            elseif ischar(key)
                if any(ismember('*+.',key))
                    % Limited regexp matching
                    match = regexp(m.keys,key);
                    ix = find(~cellfun(@isempty,match));                   
                else
                    ix = find(strcmp(key,m.keys));
                end
                if isempty(ix);ix =NaN;end                    
            end
        end
        
        % Deal with usage like map('key') and allow the user to retrieve
        % some raw properties 
        function  value = subsref(m,S)
            nrSubs = numel(S);
            switch S(1).type 
                case '()'
                    if nrSubs>1
                        error('NIY')
                    end
                    key = S.subs{1};
                    if ischar(key)
                        ix  = index(m,key);
                    else
                        ix = key;
                    end
                    if isnan(ix)
                        value = NaN;
                    else
                        value = m.values{ix};
                    end
                case '.'
                    % Handle read accesss to public member variables
                    switch (S(1).subs)
                        case 'keys'
                            value =m.keys;
                        case 'values';
                            value = m.values;   
                        case 'log';
                            if nrSubs>1
                                value = m.log.(S(2).subs);
                            else
                            value= m.log;
                            end
                        otherwise 
                            error('NIY');
                    end
                            
                otherwise
                    error('NIY');
            end                        
        end
 
        % Deal with  
        % map('key') = value
        % map({'key1','key2','key3'}) = value
        % map({'key1','key2','key3'}) = {'value1','value2','value3'};
        % All assignments are time logged.
        function  m = subsasgn(m,S,value)
            S=S(1);
            switch S.type 
                case '()'
                    key = S.subs{1};
                     if ischar(key) 
                         key  ={key};
                         value = {value};                         
                     end
                     if iscell(key)
                        ix  = index(m,key);                          
                     else % numeric index provided
                        ix = key;
                        key = m.keys(ix);                        
                     end
                     
                     if ~iscell(value) 
                         tmpV = cell(1,numel(ix));
                         [tmpV{:}] = deal(value);
                         value = tmpV;
                     end
                     newOnes = isnan(ix);
                     nrNewOnes = sum(newOnes);
                     if nrNewOnes>0
                         % add space
                         m.keys = cat(2,m.keys,cell(1,nrNewOnes));
                         m.values = cat(2,m.values,cell(1,nrNewOnes));
                         ix(newOnes) = (m.nrKeys-nrNewOnes+1):m.nrKeys;
                     end
                     
                     
                     % Log 
                     m.log.keys =cat(2,m.log.keys, key);
                     m.log.values = cat(2,m.log.values,value);
                     m.log.t      = cat(2,m.log.t,now*ones(1,numel(ix)));                     
                     % Assign
                     [m.keys{ix}] = deal(key{:});
                     [m.values{ix}] = deal(value{:});
                     
                   otherwise
                    error('NIY');
            end                        
        end
        
        
    end
end