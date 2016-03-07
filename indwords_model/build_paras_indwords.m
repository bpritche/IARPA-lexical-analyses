% This will build the para files for the individual words condition (model
% 1).  Because the words are presented in a random order every time, we
% need separate para files for each run for each participant.  
% 
% Created: 11/2/2015, bpritche

%% Initialize variables
% set up map so that we can get from word to condition number
% so nameMap{word} = <conditionNumber>
load('wordCell.mat'); %loads in array 'names'
concept_names = names;
num_subjs = 7;
% load in mapping from concept name to condition name
load('conceptCondMap.mat'); % loads in containers.Map object conceptCondMap
condNames = conceptCondMap.values;
condNums = 1:length(condNames);
nameMap = containers.Map(condNames, condNums);


% for each paradigm, load in the subject ID corresponding to when each
% participant did that paradigm (ie sbjIDs{1}{2} will be when subject 2 did the sentences paradigm)
% According to ls -l run on /mindhive/evlab/u/bpritche/Documents/IARPA_analyses
sent_sbj = {'FED_20150613a_3T1', 'FED_20150619a_3T1', 'FED_20150729a_3T1', ...
    'FED_20150810a_3T1', 'FED_20150811b_3T1', 'FED_20150813a_3T1', ...
    'FED_20150818a_3T1'};
wordclouds_sbj = {'FED_20150619b_3T1', 'FED_20150613b_3T1', 'FED_20150730a_3T1', ...
    'FED_20150812b_3T1', 'FED_20150810b_3T1', 'FED_20150811c_3T1', ...
    'FED_20150817a_3T1'};
img_sbj = {'FED_20150722b_3T1', 'FED_20150722a_3T1', 'FED_20150812c_3T1', ...
    'FED_20150814a_3T1', 'FED_20150812a_3T1', 'FED_20150814b_3T1', ...
    'FED_20150827a_3T1'};
sbjIDs = {sent_sbj, wordclouds_sbj, img_sbj};
pdgm_names = {'sentences', 'wordclouds', 'images'};

data_dir = fullfile(pwd, '..', 'txt_data');
paras_dir = fullfile(pwd, 'PARAS');

% templates for input and output filenames
txt_temp = 'complang04_%s_paradigm%d_repetition%d_run%d_data.txt';
% sample: IARPAlex_sentences_indwords_FED_20150613a_3T1_rp1rn1.para
para_temp = 'IARPAlex_%s_indwords_%s_rp%drn%d.para';

% Step through each paradigm, make files!
for pdgm=1:length(pdgm_names)
    for subj=1:num_subjs
        
        % Find our txt files of interest
        subjID = sbjIDs{pdgm}{subj};
        subj_file_regex = sprintf('complang04_%s_*.txt', subjID);
        subj_files = dir(fullfile(data_dir, subj_file_regex));
        % each repetition within a run counts as "one run" here
        num_runs = length(subj_files);
        
        for sess_run=1:num_runs
            % Open appropriate files
            data_filename = subj_files(sess_run).name;
            data_fid = fopen(fullfile(data_dir, data_filename), 'r');
            rep = ceil(sess_run/2); % repetition (1-6)
            run = 2 - mod(sess_run, 2); % run (1-2)
            para_filename = sprintf(para_temp, pdgm_names{pdgm}, ...
                subjID, rep, run);
            para_fid = fopen(fullfile(paras_dir, para_filename), 'w');
            
            % write header
            fprintf(para_fid, '#onsets\n\n');
            
            % loop through the datafile
            while ~feof(data_fid)
                % grab the entire line
                output_line = fgetl(data_fid);
                line_comps = strsplit(output_line);
                
                % grab onset (in TRs)
                onset_secs = str2double(line_comps{3});
                onset_TRs = onset_secs/2;
                
                % pull out concept
                conceptLine = line_comps{2};
                if strcmp(conceptLine, 'FIX')
                    continue;
                end
                if pdgm == 3
                    concept = conceptLine;
                else
                    concept_comps = strsplit(conceptLine, '_');
                    concept = concept_comps{2};
                    if pdgm == 2
                        % make first letter uppercase
                        concept = strcat(upper(concept(1)), concept(2:end));
                    end
                end
                
                % find condition number associated with concept
                if strcmpi(concept, 'Counting'),concept = 'Count';end
                condName = conceptCondMap(concept);
                condNum = nameMap(condName);
                
                % print to the file!
                fprintf(para_fid, '%5.1f\t%d\n', onset_TRs, condNum);
            end
            
            fclose(data_fid);
            
            % at end, print #names and #durations
            fprintf(para_fid, '\n#names\n');
            for i=1:length(condNames)
                fprintf(para_fid, '%s ', condNames{i});
            end
            fprintf(para_fid, '\n\n#durations\n');
            % just print 3, 90 times
            for i=1:length(names)
                fprintf(para_fid, '1.5 ');
            end
            
            fclose(para_fid);
        end
    end
end