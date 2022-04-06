%{
# A table with the names of the data files for each experiment
filename: varchar(255)   # The relative filename
-> ns.Experiment         # The experiment to which this belongs (FK)
---
extension : varchar(10)  # File extension for easy filtering.
%}
%
% BK = April 2022

classdef File < dj.Manual
end