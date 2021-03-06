% This script will take in the matfiles that were spit out by
% build_paras_freq and build_paras_syntcat, which map words onto
% frequencies and words onto their syntcat values, respectively.  It will
% output (and save) a map from words onto condition names (like N_hi, V_lo,
% or AV_med).
%
% Created: bpritche, 3/7/2016

%% Initialize, load in our maps
% word -> syntcat
name_synt_dir = fullfile(pwd, '..', 'syntcat_model','name_syntcat_map.mat');
load(name_synt_dir, 'name_syntcat_map');

% word -> freq
name_freq_dir = fullfile(pwd, '..', 'freq_model','wordFreqMap.mat');
load(name_freq_dir, 'wordFreqMap');
name_freq_map = wordFreqMap; clear wordFreqMap; % for consistency

% word index -> word
load('wordCell.mat', 'names');

%% Loop through and combine
num_words = length(name_syntcat_map.keys());
synt_freqs = cell(1, num_words);
for i = 1:num_words
    word = names{i};
    
    % Grab syntcat & standardize
    syntcat = name_syntcat_map(word);
%     if strcmp(syntcat, 'Adj'), syntcat = 'AJ';
%     elseif strcmp(syntcat, 'Adv'), syntcat = 'AV';
%     elseif strcmp(syntcat, 'FuncWord'), syntcat = 'FW';
%     end
    if ~strcmp(syntcat, 'N'), syntcat = 'OTH';
    end
    
    % Grab freq & standardize
    freq = name_freq_map(lower(word));
    if freq == 1, freq = 'hi';
    elseif freq == 2, freq = 'med';
    elseif freq == 3, freq = 'lo';
    else error('freq = %d!\n', freq);
    end
    
    % set up condition name
    synt_freq_cond_name = sprintf('%s_%s',syntcat,freq);
    synt_freqs{i} = synt_freq_cond_name;
    
end

%% Save!
synt_freq_map = containers.Map(names, synt_freqs);
save synt_freq_map_justN.mat synt_freq_map