function [consess,existingcontrasts] = build_contrasts_IARPAlex_syntcat(subj,SPMfn,params)

if nargin<3, params=[]; end
if ~isfield(params,'REDOALL'), params.REDOALL=1; end
if ~isfield(params,'BREAKODDEVEN'), params.BREAKODDEVEN=1; end
if ~isfield(params,'BREAKCV'), params.BREAKCV=1; end

%% Only thing that needs to change
%Contrast structure  = {'Con1Name','first cond', weight, 'second cond',weight, ...;
%'Con2Name',...;}
existingcontrasts=[];
Contrasts = { ...
    {'N', 'N', 1};
    {'Adj', 'Adj', 1};
    {'Adv', 'Adv', 1};
    {'V', 'V', 1};
    {'FuncWord', 'FuncWord', 1};
    {'N-V'  ,'N',1,'V',-1};
    {'N-Adj' ,'N',1,'Adj',-1};
    {'N-Adv' ,'N',1,'Adv',-1};
    {'V-N'  ,'N',-1,'V',1};
    {'V-Adj' ,'Adj',-1,'V',1};
    {'V-Adv' ,'Adv',-1,'V',1};
    {'Adj-N' ,'N',-1,'Adj',1};
    {'Adj-V' ,'V',-1,'Adj',1};
    {'Adj-Adv','Adv',-1,'Adj',1};
    {'Adv-N' ,'N',-1,'Adv',1};
    {'Adv-V' ,'V',-1,'Adv',1};
    {'Adv-Adj','Adj',-1,'Adv',1};
    {'N-VAdjAdv','N',.5,'V',-.17,'Adj',-.17,'Adv',-.16};
    {'V-NAdjAdv','V',.5,'N',-.17,'Adj',-.17,'Adv',-.16};
    {'Adj-NVAdv','Adj',.5,'N',-.17,'V',-.17,'Adv',-.16};
    {'Adv-NVAdj','Adv',.5,'N',-.17,'V',-.17,'Adj',-.16};
    {'cont-func' ,'N',.125,'V',.125,'Adj',.125,'Adv',.125,'FunctionWord',-1};
    {'func-cont' ,'N',-.125,'V',-.125,'Adj',-.125,'Adv',-.125,'FunctionWord',1};
    };
%%
if ~nargin, % if no arguments returns the contrast definitions
    iContall=1;
    names={};
    partitions=0;
    if params.BREAKODDEVEN, partitions=[partitions,[1,2]]; end
    if params.BREAKCV, partitions=[partitions,[3,4]]; end
    for partition=partitions,
        for iCont = 1:size(Contrasts,1)
            curCont = Contrasts{iCont};
            names{iContall}=curCont;
            switch(partition),
                case 0,names{iContall}{1} = curCont{1};
                case 1,names{iContall}{1} = ['ODD_',curCont{1}];
                case 2,names{iContall}{1} = ['EVEN_',curCont{1}];
                case 3,names{iContall}{1} = ['FIRST_',curCont{1}];
                case 4,names{iContall}{1} = ['REST_',curCont{1}];
            end
            iContall=iContall+1;
        end
    end
    consess=names; 
    return; 
end; 

if ischar(SPMfn),
    load(SPMfn);
    if params.REDOALL,
        SPM.xCon = {};
        save(SPMfn, 'SPM');
    end
else, SPM=SPMfn; end

CondNames = [SPM.Sess(1).U.name];
iNumConds = length(CondNames);
for i = 1:iNumConds
    CondInds{i} = [];
end

% build a list of contrast indices
names = SPM.xX.name;
sessions=zeros(1,numel(names));
for(i=1:numel(names))
    
    [a,v,w] = regexp(names{i},'Sn\(\d+\)','match','start','end'); % removes Sn(???) from name
    if ~isempty(a), names{i}(v(1):w(1))=[]; sessions(i)=str2num(a{1}(4:end-1)); end
    
    % make sure its not a derivative
    [a,v,w] = regexp(names{i},'*bf\(1\)', 'match','start','end');
    if(isempty(a))
        continue;
    else, names{i}(v(1):w(1))=[];end % removes bf(1) from name
    
    % Does this match a condition we care about?
    for iCond = 1:iNumConds
        [a w] = regexp(names{i}, CondNames{iCond}, 'match');
        if(~isempty(a))
            CondInds{iCond} = [CondInds{iCond} i];
            continue;
        end
    end
end
disp(sessions);

iContall=1; iContspm=1;
partitions=0;
if params.BREAKODDEVEN, partitions=[partitions,[1,2]]; end
if params.BREAKCV, partitions=[partitions,[3,4]]; end
for partition=partitions,
    for iCont = 1:size(Contrasts,1)
        curCont = Contrasts{iCont};
        
        switch(partition),
            case 0,tname = curCont{1};
            case 1,tname = ['ODD_',curCont{1}];
            case 2,tname = ['EVEN_',curCont{1}];
            case 3,tname = ['FIRST_',curCont{1}];
            case 4,tname = ['REST_',curCont{1}];
        end
        if params.REDOALL || (length(SPM.xCon)<iContspm) || (~strcmp(SPM.xCon(iContspm).name,tname)),
            consess{iContall}.tcon.name=tname;
            consess{iContall}.tcon.convec = zeros(numel(names),1);
            for iCond = 2:2:size(curCont,2) - 1
                sCondName = curCont{iCond};
                iCondWeight = curCont{iCond+1};
                iCondNameInd = strmatch(sCondName,CondNames,'exact');
                consess{iContall}.tcon.convec(CondInds{iCondNameInd}) = iCondWeight;
            end
            switch(partition),
                case 1,consess{iContall}.tcon.convec(sessions>0&rem(sessions,2)==0)=0;%odd
                case 2,consess{iContall}.tcon.convec(sessions>0&rem(sessions,2)==1)=0;%even
                case 3,consess{iContall}.tcon.convec(sessions>0&(sessions~=1))=0;%first
                case 4,consess{iContall}.tcon.convec(sessions>0&(sessions==1))=0;%all but first
            end
            idx1=find(consess{iContall}.tcon.convec>0);if ~isempty(idx1), s1=sum(abs(consess{iContall}.tcon.convec(idx1)));consess{iContall}.tcon.convec(idx1)=consess{iContall}.tcon.convec(idx1)/s1; end
            idx1=find(consess{iContall}.tcon.convec<0);if ~isempty(idx1), s1=sum(abs(consess{iContall}.tcon.convec(idx1)));consess{iContall}.tcon.convec(idx1)=consess{iContall}.tcon.convec(idx1)/s1; end
            
            iContall=iContall+1;
        else,
            existingcontrasts=[existingcontrasts,iContspm];
        end
        iContspm=iContspm+1;
    end
end

return

%************************************************************************%
%%% $Source$
%%% Local Variables:
%%% mode: Matlab
%%% fill-column: 76
%%% comment-column: 0
%%% End:
