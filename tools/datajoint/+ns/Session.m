%{
# A session refers to all recordings on a single day from a single subject
session_date: date  #Recording date (ISO 8601)
-> ns.Subject       #Subject (FK)
---
%}
% BK - April 2022
classdef Session < dj.Manual
end