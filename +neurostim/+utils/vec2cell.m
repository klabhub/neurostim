function c= vec2cell(v)
% Simple function to convert a vector to a cell array with one cell per
% element of the vector.
% This is useful to specify parameters in a factorial, which requires a
% cell for generality, but is often easier to do with a vector.
% 
% BK - Mar 2016

c = cell(size(v));
for i=1:numel(c)
    c{i} = v(i);
end
