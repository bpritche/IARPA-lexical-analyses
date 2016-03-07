% Takes as input a pre-tagged set of words (using Stanford parser,
% english-left3words-distsim.tagger) and puts them into a text file with
% just the relevant word and its tag (can copy paste over).
%
% Author: Brianna Pritchett
% Created: 10/21/2015

input_filename = 'complang_paradigms_stims.csv';
input_cells = read_mixed_csv(input_filename, ',');
% Grab just first column
keywords = input_cells(2:end,1);
num_words = 180;

% Loop through each column, create a unique output txt file for each cell
for i=1
    col_tagged_filename = sprintf('sent%dsTag.txt', i);
    ctfid = fopen(col_tagged_filename, 'r');
    col_output_filename = sprintf('sent%dsKeys.txt', i);
    cofid = fopen(col_output_filename, 'w');
    
    for j=1:num_words
        sent = fgetl(ctfid);
        keyword = keywords{j};
        
        %Set up regular expression to search for this keyword and its
        %associated tag in this sentence
        exp = sprintf('%s_\\w*', keyword);
        [starti, endi] = regexpi(sent, exp);
        word_and_tag = sent(starti:endi);
        fprintf(cofid, '%s\n', word_and_tag);
    end
    
    fclose(ctfid);
    fclose(cofid);
end