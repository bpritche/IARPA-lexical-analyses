% example build model script for batch analysis
% editing is required where you see all caps
%
% Oliver Hinds <ohinds@mit.edu>
% 2008-02-27

% Modified for IARPA lexical analyses version 3 - conditions are 'high', 'medium' or 'low' frequency 
% moved some things around for more intuitive documentation
% Brianna Pritchett, bpritche
% 10/28/2015

function sess = build_model_IARPAlex_freq(varargin)
    % build_model_IARPAlex_freq(subject_name, niifiles[, motionfiles, outliers, hpf])
    % Input:
    %   subject_name: string of subject ID (ex. 'FED_20150613a_3T1')
    %   niifiles: 1xn cell array, where n is number of nii files being
    %       evaluated.  Each element is a string representing the path to
    %       the nii file, and there is one nii file per functional run
    %       (taken from scripts/func_runs.txt) (example
    %       element: '/mindhive/evlab/u/bpritche/Documents/IARPA_analyses/FED_20150619a_3T1/nii/sw828000-30.nii')
    %   motionfiles (optional): 1xn cell array, where n is the number of files being
    %       evaluated. Each element is a string representing the path to
    %       the motion txt file being evaluated (example element:
    %       '/mindhive/evlab/u/bpritche/Documents/IARPA_analyses/FED_20150619a_3T1/nii/rp_828000-30.txt')
    %   outliers (optional): if an outliers.mat file is generated for this
    %       subject (would be stored in nii directory), this will the
    %       output of `load outliers.mat`

    %% CHANGE:
    % names: a cell array with a string representing each condition
    names = {'H', 'M', 'L'};
    % default_durs: an array with the default duration of each stimulus,
    % in case the PARAS file can't be found.  Will be overwritten by PARAS
    % file, when found.
    default_durs = repmat(3,1,length(names));
    % model_name: just 'model' or 'model_<model_name>'
    model_name='model_IARPAlex_freq'; 
    % directory with subject data
    subjects_dir = '/mindhive/evlab/u/bpritche/Documents/IARPA_analyses';
    % directory with cat files: if empty, cat files are assumed to be found
    % in each subject's directory
    catfiles_dir='';
    % directory with PARA files
    parafiles_dir='/mindhive/evlab/u/bpritche/Documents/fMRI_analyses/PARAS';

    %% Process input, separate into appropriate variables
    disp('BUILD_MODEL');
    if(numel(varargin) < 2)
        error(['usage ' mfilename '(subject_name, niifiles[, motionfiles, outliers, hpf,...])']);
    end
    
    subject_name = varargin{1};
    niifiles = varargin{2};

    if(numel(varargin) < 3)
        motionfiles = {};
    else
        motionfiles = varargin{3};
    end
    if(numel(varargin) < 4)
        outliers = [];
    else
        outliers = varargin{4};
    end
    if(numel(varargin) < 5) % probably want to change this to twice your
                            % block length for block designs
        hpf = 200;
    else
        hpf = varargin{5};
    end
 
    % build the sess structure for spm jobman  
    % each sess must have the fields
    % names, onsets, durations, and optionally mod for parametric modulators
    sess = [];
    accumscans = 0;

    %% Find and read CAT files
    %[subject_name_path,subject_name_name,subject_name_ext]=fileparts(subject_name);
    if isempty(catfiles_dir), catfiles_dir=fullfile(subjects_dir,subject_name); end
    filenames=dir(fullfile(catfiles_dir,strcat(subject_name, '*.cat')));
    if length(filenames)>1, 
        [s,~] = listdlg('PromptString',['Subject ',subject_name,' CAT file?'],...
            'SelectionMode','single',...
            'ListString',strvcat(filenames(:).name)); 
    else s=1;
    end
    
    filename=fullfile(catfiles_dir,filenames(s).name);

    % reads CAT file
    catalog=parsefile(filename);
    if ~isfield(catalog,'files'), catalog.files=catalog.arg; end
    if ~isfield(catalog,'path'), catalog.path={parafiles_dir}; end
    if ~isfield(catalog,'runs'), catalog.runs=1:length(niifiles); end
    % make full directory out of given filenames
    for n1=1:length(catalog.files)
        catalog.files{n1}=fullfile(catalog.path{1},catalog.files{n1});
    end
    while length(catalog.runs)~=length(catalog.files) || any(catalog.runs>length(niifiles)),
        [s,~] = listdlg('name','Mismatched number of sessions',...
            'PromptString',['Select ',num2str(length(catalog.files)),' functional runs for this study'],...
            'SelectionMode','multiple',...
            'InitialValue',[],...
            'ListString',strcat(num2str((1:length(niifiles))','%d'),repmat(':  ',[length(niifiles),1]),strvcat(niifiles{:})));
        if length(s)==length(catalog.files), catalog.runs=s; end
    end
    para_files=catalog.files;
    niifiles=niifiles(catalog.runs);
    motionfiles=motionfiles(catalog.runs);
    % replaced {A{i}} with A(i) for efficiency :bpritche
    

    sess(numel(niifiles)) = 0;
    % preallocated for efficiency :bpritche
    for i=1:numel(niifiles)
        nii = load_nifti(niifiles{i},1); % hdr only!
        sess(i).scans = cell(nii.dim(5),1);
        for j=1:nii.dim(5)
          sess(i).scans{j} = [niifiles{i} ',' num2str(j)];
        end

        % this bit allows you to read in an index file of PARA files per run
        % and auto-populate the onsets.

        %% Load in PARAS files
        % defaults (overwritten by PARA file info if present)
        para=struct('onsets',[],'names',names,'durations',default_durs);
        para=parsefile(para_files{i},para);
        if ~isfield(para,'onsets'), para.onsets=para.arg; end
        para.onsets=reshape(para.onsets,[2,length(para.onsets)/2])';
        conditions=unique(para.onsets(:,2));
        numConds = length(conditions);
        onsets=cell(numConds,1);names=cell(numConds,1);durations=cell(numConds,1);
        % preallocated for efficiency :bpritche
        for n1=1:length(conditions),
            onsets{n1}=para.onsets(para.onsets(:,2)==conditions(n1),1);
            names{n1}=para.names{conditions(n1)};
            durations{n1}=para.durations(conditions(n1));
        end
        %catalog = fopen(filename);
        %para_files = textscan(catalog, '%s');
        %para = load(strcat('/groups/domspec/PARAS/', para_files{1,1}{i,1}));
        %cond1_trs=para(para(:,2)==1);
        %cond2_trs=para(para(:,2)==2);
        %cond3_trs=para(para(:,2)==3);

        mod = [];

        %% build regressors SHOULD NOT HAVE TO CHANGE THIS

        % motion files 
        if(numel(motionfiles) >= i)
            R = load(motionfiles{i});
            if(size(R,1) ~= nii.dim(5))
                error(['motion file does not have right number of scans (' ...
                    ' %d != %d).'], size(R,1), nii.dim(5));
                % removed sprintf, as error takes sprintf-like arguments
                % directly :bpritche
            end
            num_mot=6;
        else
            R = [];
            num_mot = 0;
        end

        % outliers
        if ~isempty(outliers), 
            inds = find(outliers > accumscans & outliers <= accumscans+nii.dim(5));
            R(:,end+1:end+length(inds)) = zeros(size(R,1),length(inds));
            for(out=1:length(inds))
                R(outliers(inds(out))-accumscans,out+num_mot) = 1;
            end
        else % alfnie 02/09: use art_regression_outliers_*.mat files from art
            [niifilespath,niifilesname,niifilesext]=fileparts(niifiles{i});
            niifilesfullname=fullfile(niifilespath,['art_regression_outliers_',niifilesname,'.mat']);
            while isempty(dir(niifilesfullname)),
                niifilesname=niifilesname(2:end);
                if isempty(niifilesname), break; end
                niifilesfullname=fullfile(niifilespath,['art_regression_outliers_',niifilesname,'.mat']);
            end
            if ~isempty(dir(niifilesfullname)),
                disp(['Loading regression file: ',niifilesfullname]);
                R2=load(niifilesfullname);
                R=[R,R2.X];
            end
        end

        % build matfile name and save the design for this session
        cond_sess_name = sprintf('cond_sess%d.mat',i);
        condfn = fullfile(subjects_dir, subject_name, model_name, cond_sess_name);
        % changed to fullfile :bpritche
        save(condfn,'names','onsets','durations','mod');
        sess(i).multi = {condfn};

        reg_sess_name = sprintf('reg_sess%d.mat',i);
        regfn = fullfile(subjects_dir, subject_name, model_name, reg_sess_name);
        % changed to fullfile :bpritche
        save(regfn,'R');
        sess(i).multi_reg = {regfn};

        % high pass length
        sess(i).hpf = hpf;

        accumscans = accumscans + nii.dim(5);

    end
    
return

%************************************************************************%
%%% $Source: /home/ohinds/cvs/mri/analysis/batch_analysis/matlab/build_model.m,v $
%%% Local Variables:
%%% mode: Matlab
%%% fill-column: 76
%%% comment-column: 0
%%% End:
