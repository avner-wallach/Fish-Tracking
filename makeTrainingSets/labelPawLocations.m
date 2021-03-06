function labelPawLocations(session, vidfile, frameInds, totalEgs, colors)

% !!! need to document


% settings
figSize = .8;

% initializations
% switch view
%     case 'Bot'
        objectNum = 13;
%     case 'Top'
%         objectNum = 2;
% end
vid = VideoReader([getenv('OBSDATADIR') '\' session '\' vidfile '.avi']);
frame = read(vid,1);
egInd = 1;
stillGoing = true;
frameInd = [];
objects=0;

% prepare figure
fig = figure('units', 'pixels', 'outerposition', [300 100 vid.Width*figSize vid.Height*figSize],...
             'color', [0 0 0], 'menubar', 'none', 'keypressfcn', @keypress...
             ,'WindowButtonDownFcn',@buttondown,'WindowButtonUpFcn',@buttonup);
imPreview = image(frame);hold on;

% scatter([anchorPts{1}(1) anchorPts{2}(1) anchorPts{3}(1) anchorPts{4}(1)] .* (vid.Width-1) + 1,...
%     [anchorPts{1}(2) anchorPts{2}(2) anchorPts{3}(2) anchorPts{4}(2)] .* (vid.Height-1) + 1,...
%     200, colors, 'filled');     % show anchor points



% initialize draggable objects
impoints = cell(1,objectNum);
labels= [];
locations = nan(2, totalEgs, objectNum); % ([x,y], egNum, obNum)
locationFrameInds = nan(1, totalEgs);

% scatter([1, vid.Width, vid.Width, 1], [1, 1, vid.Height, vid.Height], 200, colors, 'filled');
set(gca, 'units', 'normalized', 'position', [0 0 1 1],'ButtonDownFcn',@buttondown)
getNewFrame;


while stillGoing
    waitforbuttonpress
end

% save and close up shop
saveData();
close(fig);



% ---------
% FUNCTIONS
% ---------

function keypress(~,~)
        
    % save positive and create/save negative examples when ENTER is pressed
    key = double(get(fig, 'currentcharacter'));

    if ~isempty(key) && isnumeric(key)
        switch key
        
            % commit locations for frame
            case 13 % enter
                
                % sore locations
                for j = 1:objectNum    
                    xy = getPosition(impoints{j});
                    locations(1:2, egInd, j) = xy;
                end
                
                % store frame ind
                locationFrameInds(egInd) = frameInd;
                
                % get next frame
                getNewFrame()
                
                % update counter
                egInd = egInd + 1;
                if egInd > totalEgs
                    stillGoing = false;
                else
                    disp(egInd)
                end
            

            % get new frame
            case 110 % 'n'
                getNewFrame();
            
            % save current progress
            case 115 % 's'
                saveData();
        end
    end
end

function buttondown(~,~)
    if(objects<objectNum)
        objects=objects+1;
        CP=get(gca,'CurrentPoint');
        impoints{objects} = impoint(gca,CP(1,1:2));
        labels(objects) = text(CP(1,1),CP(1,2),num2str(objects),'Color',[1 1 1]);        
        setColor(impoints{objects}, colors(objects,:));
%     else
%         for i=1:objects
%             set(labels(i),'Position',getPosition(impoints{i}));
%         end
    end
 
end

function buttonup(~,~)
    for i=1:objects
        set(labels(i),'Position',getPosition(impoints{i}));
    end
end


function getNewFrame
    frameInd = frameInds(randi(length(frameInds)));
    frame = read(vid, frameInd);
    set(imPreview, 'CData', frame);
    for i=1:objectNum
        if(numel(impoints{i}))
            impoints{i}.delete;
        end
    end
    objects=0;
end

function saveData
    D=[getenv('OBSDATADIR') '\' session '\' 'handLabeledSets'];
    if(~exist(D))
        mkdir(D);
    end
    save([D '\' vidfile '.mat'], ...
        'locations', 'locationFrameInds');
end

end