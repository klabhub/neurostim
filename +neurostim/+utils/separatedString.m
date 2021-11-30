function s= separatedString(c,sep)
% Create a sep separated string from a cell array of strings.
% s= separatedString({'cic','gabor'},'/')  -> 'cic/gabor'
% BK - April 2017
if nargin<2
    sep = '/';
end
nrC = numel(c);
m = cat(2,deblank(c(:)),repmat({sep},[nrC 1]));
m=m';
s = cat(2,m{:});
s(end) = '';
