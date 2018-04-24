function makeLabeledSet(className, labeledDataSessions, view, subFrameSize, posEgs, negEgsPerEg,...
    featureSetting, paws, jitterPixels, jitterNum, maxOverlap, minBrightness, flipBot)

% !!! need to document, but generally takes hand labeled paw locations and creates features for classifier training
% this is done by taking subframes at paw locations of subFrameSize, and extracting features with getSubFrameFeatures
% it also automatically grabs negative examples in same frames by randomly taking subframes that don't overlap too much with positive examples
% can also create more positive examples by jittering paw locations

% settings
flipLabels = [4 3 2 1]; % 1 flips to 3, 2 to 3, 3 to 2, and 4 to 1

% concatinate all labeled data sets
sessionInds = []; % stores the session identity for each saved location
locationsAll = [];
locationFrameIndsAll = [];

for i = 1:length(labeledDataSessions)
    
    % get labeled locations for single session
    load([getenv('OBSDATADIR') 'tracking\trainingData\handLabeledSets\run' view 'HandLabeledLocations' labeledDataSessions{i} '.mat' ], ...
        'locations', 'locationFrameInds');
    
    % remove nan entries
    validInds = ~isnan(locations(1,:,1));
    locations = locations(:,validInds,:);
    locationFrameInds = locationFrameInds(validInds);
    
    % sort chronologically (this may make reading video frames faster)
    [locationFrameInds, sortInds] = sort(locationFrameInds);
    locations = locations(:, sortInds, :);
    
    % store
    locationsAll = cat(2, locationsAll, locations);
    locationFrameIndsAll = [locationFrameIndsAll, locationFrameInds];
    sessionInds = [sessionInds i*ones(1,length(locationFrameInds))];
    
end

locations = locationsAll; clear locationsAll;
locationFrameInds = locationFrameIndsAll; clear locationFrameIndsAll;


% initializations
centPad = floor(subFrameSize / 2); % y,x
posEgsCount = 0;
jitterDirections = [1 1; 1 0; 1 -1; 0 1; 0 -1; -1 1; -1 0; -1 -1] * jitterPixels;
numClasses = size(paws,1) + 1; % add one for the not paw class // otherwise, every row in the paws matrix is a class
egsPerFrame = size(locations,3);
imNumberInd = 1;
lastSessionInd = 0;
featureLength = length(getSubFrameFeatures(zeros(subFrameSize), [0 0], featureSetting));


% randomly select indices from entire batch

% iterate through frames of all examples (locations)
posEgsPerFrame = size(locations,3) * (1 + flipBot + jitterNum);
posEgs = min(posEgs, size(locations,2) * posEgsPerFrame);
totalFrames = floor(posEgs / posEgsPerFrame);
totalEgs = totalFrames * size(locations,3) * (1 + jitterNum + negEgsPerEg + flipBot); % for each pawframe, you have four paws
features = nan(featureLength, totalEgs);
images = nan(prod(subFrameSize), totalEgs); % stores all images in a matrix, so subframes can be viewed prior to feature extraction
labels = nan(1, totalEgs);

locationInds = randperm(size(locations,2), totalFrames);
locationInds = sort(locationInds);


for i = locationInds
    
    % load new video if you have reached the next session
    if sessionInds(i) ~= lastSessionInd
        vid = VideoReader([getenv('OBSDATADIR') 'sessions\' labeledDataSessions{sessionInds(i)} '\run' view '.mp4']);
        bg = getBgImage(vid, 1000, 120, 2*10e-4, false);
        load([getenv('OBSDATADIR') 'sessions\' labeledDataSessions{sessionInds(i)} '\runAnalyzed.mat'], 'obsPixPositions')
        lastSessionInd = sessionInds(i);
    end
    
    
    % get frame
    frame = rgb2gray(read(vid, locationFrameInds(i)));
    frame = frame - bg;
    
    
    % mask obstacle
    if ~isnan(obsPixPositions(locationFrameInds(i)))
        frame = maskObs(frame, obsPixPositions(locationFrameInds(i)));
    end
    
    
    % create mask of locations of positive examples
    egsMask = zeros(size(frame,1), size(frame,2));

    for j = 1:egsPerFrame
        xy = round(locations(1:2, i, j));
        imgInds = {xy(2)-centPad(1):xy(2)+centPad(1), xy(1)-centPad(2):xy(1)+centPad(2)};
        imgInds{1}(imgInds{1}<1)=1; imgInds{1}(imgInds{1}>vid.Height)=vid.Height;
        imgInds{2}(imgInds{2}<1)=1; imgInds{2}(imgInds{2}>vid.Width)=vid.Height;
        egsMask(imgInds{1}, imgInds{2}) = 1;
    end


    % save positive and create negative examples
    for j = 1:egsPerFrame
            
        % get positive examples
        xy = round(locations(1:2, i, j));
        img = getSubFrame(frame, flipud(xy), subFrameSize); % get subframe
        [features(:, imNumberInd), images(:, imNumberInd)] = getSubFrameFeatures(img, xy, featureSetting);

        if ismember(j, paws)
            [label, ~] = ind2sub(size(paws), find(paws==j));
            labels(imNumberInd) = label;
            posEgsCount = posEgsCount+1;
            fprintf('positive eg #%i\n', posEgsCount);

            if flipBot
                imgFlipped = flipud(img);
                imNumberInd = imNumberInd + 1;
                posEgsCount = posEgsCount+1;
                fprintf('positive eg #%i\n', posEgsCount);
                [features(:, imNumberInd), images(:, imNumberInd)] = getSubFrameFeatures(imgFlipped, xy, featureSetting);
                [label, ~] = ind2sub(size(paws), find(paws==flipLabels(j)));
                labels(imNumberInd) = label;
            end

        else
            labels(imNumberInd) = numClasses;
        end

        imNumberInd = imNumberInd + 1;



        % get jitered positive examples
        offsetInds = randperm(8);
        offsetInds = offsetInds(1:jitterNum);

        
        for k = 1:jitterNum

            xyJittered = xy + jitterDirections(offsetInds(k), :)';
            img = getSubFrame(frame, flipud(xyJittered), subFrameSize); % get subframe
            [features(:, imNumberInd), images(:, imNumberInd)] = getSubFrameFeatures(img, xyJittered, featureSetting);

            if ismember(j, paws)
                [label, ~] = ind2sub(size(paws), find(paws==j));
                labels(imNumberInd) = label;
                posEgsCount = posEgsCount+1;
                fprintf('positive eg #%i\n', posEgsCount);
            else
                labels(imNumberInd) = numClasses;
            end

            imNumberInd = imNumberInd+1;
        end




        % get negative examples
        for k = 1:negEgsPerEg

            % find a frame that doesn't overlap with positive examples
            acceptableImage = false;

            while ~acceptableImage 

                pos = [randi([centPad(1)+1 size(frame,1)-centPad(1)-1])...
                       randi([centPad(2)+1 size(frame,2)-centPad(2)-1])]; % y,x
                temp = egsMask(pos(1)-centPad(1):pos(1)+centPad(1)-1, pos(2)-centPad(2):pos(2)+centPad(2)-1);
                pixelsOverlap = sum(temp(:));
                img = getSubFrame(frame, pos, subFrameSize);

                if (pixelsOverlap/featureLength) < maxOverlap &&...
                   mean(img(:)) > (mean(frame(:))*minBrightness)
                    acceptableImage = true;
                end
            end

            % store negative example
            [features(:, imNumberInd), images(:, imNumberInd)] = getSubFrameFeatures(img, fliplr(pos), featureSetting);
            labels(imNumberInd) = numClasses;
            imNumberInd = imNumberInd+1;
        end
    end
end

% remove nan values
if any(isnan(labels)); disp('THERE ARE NANS IN THE LABELS, WTF!!!'); keyboard; end
% validInds = ~isnan(labels);
% features = features(:,validInds);
% images = images(:,validInds);
% labels = labels(validInds);


save([getenv('OBSDATADIR') 'tracking\trainingData\' className '\labeledFeatures.mat'], 'features', 'images', 'labels', 'subFrameSize')







