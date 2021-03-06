% This will build the para files for the syntactic category condition (model
% 2).  Because the words are presented in a random order every time, we
% need separate para files for each run for each participant.  
% TODO: Expand to set up cat files as well.
% 
% Created: 11/3/2015, bpritche

%% Initialize variables
% set up map so that we can get from word to (word) condition number
% so nameMap{word} = <conditionNumber>
load('wordCell.mat') %loads in array 'names'
condNums = 1:length(names);
num_subjs = 7;
nameMap = containers.Map(names, condNums);
% grab syntactic category information here, then we can just go from word
% condition number to syntactic category number
syntcat_filename = 'syntcats_perword.txt';
syntcat_fid = fopen(syntcat_filename, 'r');
syntcats_perword_outer = textscan(syntcat_fid, '%s'); %weird artifact of textscan
syntcats_perword = syntcats_perword_outer{1};
name_syntcat_map = containers.Map(names, syntcats_perword);
save name_syntcat_map.mat name_syntcat_map
syntcat_names = {'Adj', 'Adv', 'FuncWord', 'N', 'V'};
syntcat_map = containers.Map(syntcat_names, 1:length(syntcat_names));
fclose(syntcat_fid);

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
% sample: IARPAlex_sentences_syntcat_FED_20150613a_3T1_rp1rn1.para
para_temp = 'IARPAlex_%s_syntcat_%s_rp%drn%d.para';

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
                wordNum = nameMap(concept);
                syntcat_name = syntcats_perword{wordNum};
                condNum = syntcat_map(syntcat_name);
                
                % print to the file!
                %fprintf(para_fid, '%.1f\t%d\n', onset_TRs, condNum);
                fprintf(para_fid, '%.1f %d\n', onset_TRs, condNum);
            end
            
            fclose(data_fid);
            
            % at end, print #names and #durations
            fprintf(para_fid, '\n#names\n');
            for i=1:length(syntcat_names)
                fprintf(para_fid, '%s ', syntcat_names{i});
            end
            fprintf(para_fid, '\n\n#durations\n');
            % just print 3, 5 times
            for i=1:5
                fprintf(para_fid, '1.5 ');
            end
            
            fclose(para_fid);
        end
    end
end

fclose('all');