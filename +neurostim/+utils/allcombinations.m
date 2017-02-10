function out = allcombinations(varargin)
% Return all combinations of the input vectors. Reduced version of allcomb,
% written by (c) Jos van der Geest (File Exchange)

NC = nargin ;
ii = NC:-1:1 ;
[out{ii}] = ndgrid(varargin{ii}) ;
out = reshape(cat(NC+1,out{:}),[],NC) ;