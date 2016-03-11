function v=repeat(x,ind)
% repeats elements of vector x by the number of times given by
% indices ind.
% repeat ([1 2 3],[1 2 3] ) -> 1 2 2 3 3 3 
if any(size(ind)~=size(x))
    ind=ones(size(x))*ind;
end
cs=cumsum(ind);
idx=zeros(1,cs(end));
idx(1+[0 cs(1:end-1)]) = 1;
idx=cumsum(idx);
v=x(idx);
end
