% Simple file that takes the words from conceptWords.txt and throws them
% into a cell in a .mat file for use later.  Ideally will be used as source of
% condition names for build_model files and build_contrast files.  May
% modify later so that just three letters are used
%
% Author: Brianna Pritchett
% Date: 10/28/2015
% Edited: 12/9/2015, bpritche: edit so that we get a mapping from condition
%   names in original file to condition names that can be used in
%   preprocessing stream.

wordID = fopen('conceptWords.txt', 'r');
numWords = 180;
names = cell(180, 1);

for i=1:numWords
    word = fgetl(wordID);
    names{i} = word;
end

save('wordCell.mat', 'names');

fclose('all');