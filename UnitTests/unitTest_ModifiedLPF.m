function status = unitTest_ModifiedLPF(datafmt, dirname, newval)
global procStreamStyle
if isempty(procStreamStyle)
    procStreamStyle = 'snirf';
end
if strcmp(procStreamStyle,'snirf')
    datafmt = 'snirf';
end
global testidx
if isempty(testidx)
    testidx=0;
end
testidx=testidx+1;

status = -1;
if ~exist('datafmt','var')
    datafmt = 'nirs';
end
if ~exist('dirname','var')
    return;
end
if ~exist('newval','var')
    newval = [];
end

rootpath = fileparts(which('Homer3.m'));
currpath = pwd;

cd([rootpath, '/', dirname]);
resetGroupFolder();
dataTree = calcProcStreamChanged(datafmt, newval);

groupFiles_h2 = mydir('./groupResults_homer2_lpf_*.mat');
for iG=1:length(groupFiles_h2)   
    group_h2 = load(groupFiles_h2(iG).name);
    [~, groupFiles_h2(iG).pathfull] = fileparts(groupFiles_h2(iG).pathfull);
    status = compareOutputs1(group_h2);
    if status==0        
        break;
    end
end

lpfs = getHomer2LpfValue(groupFiles_h2);
lpf = getHomer3LpfValue(dataTree);

if status==0 & lpfs(iG)==lpf
    fprintf('#%d - unitTest_ModifiedLPF(''%s'', ''%s'', %0.1f): TEST PASSED - Homer3 output matches %s.\n', ...
             testidx, datafmt, dirname, newval, [groupFiles_h2(iG).pathfull, '/', groupFiles_h2(iG).name]);
elseif status==0
    fprintf('#%d - unitTest_ModifiedLPF(''%s'', ''%s'', %0.1f): TEST FAILED - Homer3 output matches %s which has a different lpf value {%0.2f ~= %0.2f}.\n', ...
             testidx, datafmt, dirname, newval, [groupFiles_h2(iG).pathfull, '/', groupFiles_h2(iG).name], lpfs(iG), lpf);
elseif status>0
    fprintf('#%d - unitTest_ModifiedLPF(''%s'', ''%s'', %0.1f): TEST FAILED - Homer3 output does NOT match ANY Homer2 groupResults.\n', testidx, datafmt, dirname, newval);
elseif status<0
    fprintf('#%d - unitTest_ModifiedLPF(''%s'', ''%s'', %0.1f): TEST FAILED - Homer3 did not generate any output\n', testidx, datafmt, dirname, newval);
end

cd(currpath);

