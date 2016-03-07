% example build model script for batch analysis
% editing is required where you see all caps
%
% Oliver Hinds <ohinds@mit.edu>
% 2008-02-27

function sess = build_model(varargin)
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

  % CHANGE THE MODEL NAME AND SUBJECTS DIRECTORY
  model_name='model_langlocSN'; % just 'model'  or 'model_<model_name>'
  subjects_dir = '/mindhive/nklab2/u/bpritche/fMRI_analyses/data'; 
  catfiles_dir='';
  parafiles_dir='/mindhive/nklab2/u/bpritche/fMRI_analyses/PARAS';

S    = 1 ;
N    = 2 ;

% build conditions for this session
names{S}    = 'S';
names{N}    = 'N';
 
  % build the sess structure for spm jobman  
  % each sess must have the fields
  % names, onsets, durations, and optionally mod for parametric modulators
  sess = [];
  accumscans = 0;

    %[subject_name_path,subject_name_name,subject_name_ext]=fileparts(subject_name);
    if isempty(catfiles_dir), catfiles_dir=fullfile(subjects_dir,subject_name); end
    filenames=dir(fullfile(catfiles_dir,strcat(subject_name, '*.cat')));
    if length(filenames)>1, 
        [s,v] = listdlg('PromptString',['Subject ',subject_name,' CAT file?'],...
            'SelectionMode','single',...
            'ListString',strvcat(filenames(:).name));
    else,s=1;end
    
    filename=fullfile(catfiles_dir,filenames(s).name);

    % reads CAT file
    catalog=parsefile(filename);
    if ~isfield(catalog,'files'), catalog.files=catalog.arg; end
    if ~isfield(catalog,'path'), catalog.path={parafiles_dir}; end
    if ~isfield(catalog,'runs'), catalog.runs=1:length(niifiles); end
    for n1=1:length(catalog.files),catalog.files{n1}=fullfile(catalog.path{1},catalog.files{n1});end;
    while length(catalog.runs)~=length(catalog.files) || any(catalog.runs>length(niifiles)),
        [s,v] = listdlg('name','Mismatched number of sessions',...
            'PromptString',['Select ',num2str(length(catalog.files)),' functional runs for this study'],...
            'SelectionMode','multiple',...
            'InitialValue',[],...
            'ListString',strcat(num2str((1:length(niifiles))','%d'),repmat(':  ',[length(niifiles),1]),strvcat(niifiles{:})));
        if length(s)==length(catalog.files), catalog.runs=s; end
    end
    para_files=catalog.files;
    niifiles={niifiles{catalog.runs}};
    motionfiles={motionfiles{catalog.runs}};
    


  for(i=1:numel(niifiles))
    nii = load_nifti(niifiles{i},1); % hdr only!
    sess(i).scans = cell(nii.dim(5),1);
    for(j=1:nii.dim(5))
      sess(i).scans{j} = [niifiles{i} ',' num2str(j)];
    end

    % this bit allows you to read in an index file of PARA files per run
    % and auto-populate the onsets.

    para=struct('onsets',[],'names',{{'S','W','N'}},'durations',[2,2,2]); % defaults (overwritten by PARA file info if present)
    para=parsefile(para_files{i},para);
    if ~isfield(para,'onsets'), para.onsets=para.arg; end
    para.onsets=reshape(para.onsets,[2,length(para.onsets)/2])';
    conditions=unique(para.onsets(:,2));
    onsets={};names={};durations={};
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
    %% build conditions for this session
    %names = {'S','W','N'};
    %onsets = {cond1_trs,cond2_trs,cond3_trs};
    %durations = {2,2,2,2};

    %% FILL THE ABOVE CELL ARRAYS
    
    mod = [];
    
    %% build regressors SHOULD NOT HAVE TO CHANGE THIS
    
    % motion files 
    if(numel(motionfiles) >= i)
      R = load(motionfiles{i});
      if(size(R,1) ~= nii.dim(5))
	error(sprintf(['motion file does not have right number of scans (' ...
	' %d != %d).'], size(R,1), nii.dim(5)));
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
    else, % alfnie 02/09: use art_regression_outliers_*.mat files from art
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
    condfn = [subjects_dir '/' subject_name '/' model_name '/cond_sess' num2str(i) '.mat'];
    save(condfn,'names','onsets','durations','mod');
    sess(i).multi = {condfn};
  
    regfn = [subjects_dir '/' subject_name '/' model_name '/reg_sess' num2str(i) '.mat'];
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
