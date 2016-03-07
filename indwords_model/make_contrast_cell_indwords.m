% This will go through and make the contrasts cell for the build_contrasts
% file
% Contrast structure  = {'Con1Name','first cond', weight, 'second cond',weight, ...;
%'Con2Name',...;}
% 
% Created: bpritche, 11/3/2015

% loads names array, just cell array with the words in alphabetical order
load('wordCell.mat');
% load conceptCondMap, mapping concept to actual condition name
load('conceptCondMap.mat');

% this is going to be
% {{'word1', 'word1', 1};
% {'word2', 'word2', 1}}
% since right now we're only interested in one contrast per condition (that
% word vs. fixation)
num_conds = length(names);
Contrasts = cell(num_conds, 1);
fprintf(1, '{');
for i=1:num_conds
    conceptName = names{i};
    conditionName = conceptCondMap(conceptName);
    fprintf(1, '{''%s'', ''%s'', 1};\n', conditionName, conditionName);
    condCell = {conditionName, conditionName, 1};
    Contrasts{i} = condCell;
end

save('contrastsCell_indwords.mat', 'Contrasts');
fprintf(1, '};\n');