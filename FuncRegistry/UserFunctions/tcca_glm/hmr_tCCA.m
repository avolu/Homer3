function [Aaux] = hmr_tCCA(data_y, yRuns (#TO PICK RESTING FROM#),  probe , flagtCCA, tCCAparams, tCCAaux_inx, tCCArest_inx, rhoSD_ssThresh)
% data_y: current run
% yRuns: all runs in the session
% flagtCCA: on/off
% tCCAparams: [timelag sts ctr]
% tCCAaux_inx: Indices of the aux channels to be used to generate regressors
% ### ss should be there by default?
% tCCArest_inx: The order of resting run in the session folder.
% rhoSD_ssThresh: ss channel distance threshold (will determine whether to include ss in generating tCCA regressors)

%% flags
flags.pcaf =  [0 0]; % no pca of X or AUX
flags.shrink = true;
% perform regularized (rtcca) (alternatively old approach)
rtccaflag = true;
flag_conc = true; % if 1 CCA inputs are in conc, if 0 CCA inputs are in intensity

%% extract user input
timelag = tCCAparams(1);
sts = tCCAparams(2); % step size
ctr = tCCAparams(3);

%% resting run
filename = XXXXXXXXX (from tCCArestinx and yRuns)
d_rest = XXXXXXXXXXX
AUX_rest = XXXXXXX


%% current run\
for iBlk=1:length(data)
    snirf = SnirfClass(data_y,stim);
    AUX = snirf.GetAuxiliary();  % CHECK THIS ONE!
    d = snirf.GetDataMatrix();
    SrcPos = probe.GetSrcPos();
    DetPos = probe.GetDetPos();
    t = data_y(iBlk).GetTime();
    fq = 1/(t(2)-t(1));
    ml = data_y(iBlk).GetMeasListSrcDetPairs();
    if isempty(mlActAuto{iBlk})
        mlActAuto{iBlk} = ones(size(ml,1),1);
    end
    mlAct = mlActAuto{iBlk};
end

%% find the list of short and long distance channels
lst = 1:size(ml,1);
rhoSD = zeros(length(lst),1);
posM = zeros(length(lst),3);
for iML = 1:length(lst)
    rhoSD(iML) = sum((SrcPos(ml(lst(iML),1),:) - DetPos(ml(lst(iML),2),:)).^2).^0.5;
    posM(iML,:) = (SrcPos(ml(lst(iML),1),:) + DetPos(ml(lst(iML),2),:)) / 2;
end
lstSS = lst(find(rhoSD<=rhoSD_ssThresh & mlAct(lst) == 1));
lstLS = lst(find(rhoSD>rhoSD_ssThresh & mlAct(lst) == 1));


%% get long and short channels
if flag_conc % get short(and active) now in conc
      
    % resting
    dod = hmrR_Intensity2OD(d_rest);
    dod = hmrR_BandpassFilt(dod, fq, 0, 0.5);
    dc = hmrR_OD2Conc(dod, SD, [6 6]);
    foo = [squeeze(dc(:,1,:)),squeeze(dc(:,2,:))];    % resize conc to match the size of d, HbO first half, HbR second half
    d_long_rest = [foo(:,lstLS), foo(:,lstLS+size(d_rest,2)/2)]; % first half HbO; second half HbR
    d_short_rest = [foo(:,lstSS), foo(:,lstSS+size(d_rest,2)/2)];
    
    % current run
    foo = [squeeze(d(:,1,:)),squeeze(d(:,2,:))]; % resize conc to match the size of d, HbO first half, HbR second half   
    d_short = [foo(:,lstSS), foo(:,lstSS+size(d,2)/2)]; % first half HbO; second half HbR

else % get d_long and short(and active)
     
    % resting
    d_long_rest = [d_rest(:,lstLS), d_rest(:,lstLS+size(d_rest,2)/2)]; % first half 690 nm; second half 830 nm
    d_short_rest = [d_rest(:,lstLS), d_rest(:,lstLS+size(d_rest,2)/2)];
    
    % current run
    d_short = [d(:,lstLS), d(:,lstLS+size(d,2)/2)]; %!!
end

% Use only the selected aux channels
AUX_rest = AUX_rest(:,tCCAaux_inx);
AUX = AUX(:,tCCAaux_inx);

%% lowpass filter AUX signals
AUX_rest = hmrR_BandpassFilt(AUX_rest, fq, 0, 0.5);
AUX = hmrR_BandpassFilt(AUX, fq, 0, 0.5);

%% AUX signals + add ss signal if it exists
if ~isempty(d_short_rest)
    AUX_rest = [AUX_rest, d_short_rest]; % EG: AUX = [acc1 acc2 acc3 PPG BP RESP, d_short];
    AUX = [AUX, d_short]; % this should be of the current run
end

%% zscore AUX signals
AUX_rest = zscore(AUX_rest);
AUX = zscore(AUX);

%% set stepsize for CCA
param.tau = sts; %stepwidth for embedding in samples (tune to sample frequency!)
param.NumOfEmb = ceil(timelag*fq / sts);

%% Temporal embedding of auxiliary data from testing run (current run)
aux_sigs = AUX;
aux_emb = aux_sigs;
for i=1:param.NumOfEmb
    aux = circshift(aux_sigs, i*param.tau, 1);
    aux(1:2*i,:) = repmat(aux(2*i+1,:),2*i,1);
    aux_emb = [aux_emb aux];
end

%zscore
aux_emb = zscore(aux_emb);

%% set correlation trheshold for CCA to 0 so we dont lose anything here
param.ct = 0;   % correlation threshold

%% Perform CCA on training data
X = d_long_rest;
if ~rtccaflag
    %% Old tCCA
    [REG_trn,  ADD_trn] = perf_temp_emb_cca(X,AUX_rest,param,flags);
else
    %% new tCCA with shrinkage
    [REG_trn,  ADD_trn] = rtcca(X,AUX,param,flags);
end


%% now use correlation threshold for CCA outside of function to avoid redundant CCA recalculation
% overwrite: auxiliary cca components that have
% correlation > ctr
if ctr < 1  % if corr
    compindex = find(ADD_trn{tt}.ccac>ctr);
else        % # of regressors
    compindex = 1:ctr;
end

%overwrite: reduced mapping matrix Av
ADD_trn.Av_red = ADD_trn.Av(:,compindex);

%% Calculate testing regressors with CCA mapping matrix A from testing
REG_tst = aux_emb*ADD_trn.Av_red;

Aaux = REG_tst;