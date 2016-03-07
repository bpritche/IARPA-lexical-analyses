% make_conceptCond_mapping
% Takes in wordCell.mat, which contains a list of concepts used in the
% experiments, and makes a mapping from the concept to the condition name.
% Done because of weird behavior of the analyzing script on mindhive.
%
% Created: 12/10/2015, bpritche

% load in cell with concept names
load wordCell.mat

conceptCondMap = containers.Map;

for i = 1:length(names)
    concept_name = names{i};
    % Shortest concept name is Do, splice in underscore after first two
    % characters of word
    if length(concept_name) > 2
        cond_name = [concept_name(1:2) '_' concept_name(3:end)];
    else
        cond_name = [concept_name '_'];
    end
    
    % map concept name onto condition name
    conceptCondMap(concept_name) = cond_name;
end

% Close, finish things up
save conceptCondMap.mat conceptCondMap