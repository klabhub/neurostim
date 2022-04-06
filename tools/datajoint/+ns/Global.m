%{
# A table with global properties (e..g the data root)
id : smallint auto_increment
---
name: varchar(255) # Name
value : longblob  # Any value.
%}
%
% BK - April 2022

classdef Global < dj.Manual
end