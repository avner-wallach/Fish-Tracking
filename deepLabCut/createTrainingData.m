%% initialize new training data structure

% settings
trainingSetName = 'IntialRun';
%view = 'both';
sessions = {'20180222'};
vidfiles = {'video_20180222_1754'};
frameNum = 3;
%obsPortion = .5; % portion of trials to include obstacle


trainingSetDir = [getenv('OBSDATADIR') '\' trainingSetName '\'];

if ~exist(trainingSetDir, 'dir'); mkdir(trainingSetDir); end

if ~exist([trainingSetDir 'trainingData.mat'], 'file')
    trainingData = createTrainingDataStruct(sessions, frameNum,vidfiles);
    save([trainingSetDir 'trainingData.mat'], 'trainingData')
else
    fprintf('%s already exists... did not create file\n', trainingSetName);
end

%% label things

trainingSetName = 'IntialRun';

trainingSetDir = [getenv('OBSDATADIR')  '\' trainingSetName '\'];
% features = {'pawTL', 'pawTR', 'pawBR', 'pawBL', 'gen', 'tailBase', 'tailMid', 'tailEnd'};
features = {'chin', 'mouth', 'LED', 'LPecBase', 'LPecTip', 'RPecBase', 'RPecTip',...
    'Trunk1', 'Trunk2', 'Tail1', 'Tail2', 'CaudalFork','SideView'};
labelFrames(trainingSetDir, features);



%% prepare data for deepLabCut
trainingSetName = 'IntialRun';
features = {'chin', 'mouth', 'LED', 'LPecBase', 'LPecTip', 'RPecBase', 'RPecTip',...
    'Trunk1', 'Trunk2', 'Tail1', 'Tail2', 'CaudalFork','SideView'};

trainingSetDir = [getenv('OBSDATADIR') '\' trainingSetName '\'];
if ~exist(trainingSetDir, 'dir'); mkdir(trainingSetDir); end
load([getenv('OBSDATADIR') '\' trainingSetName  '\trainingData.mat'], 'trainingData')
prepareTrainingImages(trainingSetDir, trainingData, features);


