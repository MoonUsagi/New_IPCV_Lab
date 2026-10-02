function [result, info] = ch24_multiTracker(frames, options)
%CH24_MULTITRACKER 多物件追蹤：偵測 → 關聯 → 更新。
%
%   [RESULT, INFO] = CH24_MULTITRACKER(FRAMES) 對一組影格做多物件追蹤，
%   回傳 RESULT table，每一列是一個（幀，軌跡）配對：
%     Frame     幀號
%     TrackID   軌跡編號
%     X, Y      估計位置
%     Measured  這一幀是否有對應的偵測（false 表示靠預測維持）
%
%   INFO 是 struct，含 NumTracks、NumFrames、Assignments、
%   MeanDetections、AppearanceWeight。
%
%   **三個步驟，缺一不可：**
%     ① **預測**　對每一條既有軌跡用 Kalman 推進一步
%     ② **關聯**　算「軌跡 × 偵測」的成本矩陣，用匈牙利法指派
%     ③ **更新**　配到的軌跡用量測修正；沒配到的軌跡靠預測撐、
%        撐太久就刪除；沒配到的偵測開新軌跡
%
%   **關聯那一步才是多物件追蹤的難點。** 單物件（第 3 節）沒有這一步，
%   因為只有一個候選。物體一多，「哪個偵測屬於哪條軌跡」就變成
%   一個指派問題——而**位置相近時它無解**，那正是 ReID 存在的理由。
%
%   名稱-值引數：
%     Detector          "color"（預設，找彩色圓形）或 "foreground"
%                       （vision.ForegroundDetector 背景相減）
%     MinArea           最小區塊面積，預設 60
%     CostOfNonAssignment  不指派的成本，預設 40。
%                       **這個數字決定了「多遠算太遠」**，
%                       太小會一直開新軌跡，太大會亂配。
%     AppearanceWeight  外觀成本的權重（0–1），預設 0。
%                       0 表示只用位置；> 0 會把顏色直方圖的差異
%                       混進成本矩陣——這是 DeepSORT 的簡化版。
%     MaxInvisible      軌跡最多能連續幾幀沒有量測，預設 5
%     MinVisibleToKeep  軌跡至少要被看到幾幀才算數，預設 2
%     MotionModel       "ConstantVelocity"（預設）或 "ConstantAcceleration"
%
%   **`AppearanceWeight` 是本章的核心變數。** 第 9 節用它示範
%   「位置不夠」到底是什麼意思：兩個同色物體交會時，
%   `AppearanceWeight` 給多少都沒用（因為外觀一樣）；
%   異色物體交會時，它可以把 ID 切換降到零。
%
%   範例：
%     scene = ch24_crossingScene();
%     [r, info] = ch24_multiTracker(scene.Frames);
%     fprintf("產生了 %d 條軌跡（真值是 2 條）\n", info.NumTracks);
%
%   另見 CH24_CROSSINGSCENE, CH24_TRACKMETRICS, ASSIGNDETECTIONSTOTRACKS.

arguments
    frames                           cell
    options.Detector            (1,1) string {mustBeMember(options.Detector, ["color" "foreground"])} = "color"
    options.MinArea             (1,1) double {mustBePositive} = 60
    options.CostOfNonAssignment (1,1) double {mustBePositive} = 40
    options.AppearanceWeight    (1,1) double {mustBeInRange(options.AppearanceWeight, 0, 1)} = 0
    options.MaxInvisible        (1,1) double {mustBePositive} = 5
    options.MinVisibleToKeep    (1,1) double {mustBePositive} = 2
    options.MotionModel         (1,1) string {mustBeMember(options.MotionModel, ["ConstantVelocity" "ConstantAcceleration"])} = "ConstantVelocity"
end

n = numel(frames);

% 背景相減偵測器要先學背景，所以提到迴圈外建立一次。
% （第 23 章 §7.1 量到每幀重建會慢 10 倍，**而且背景模型永遠學不起來**。）
fgDetector = [];
if options.Detector == "foreground"
    fgDetector = vision.ForegroundDetector( ...
        NumTrainingFrames = max(2, round(n*0.15)), NumGaussians = 3);
end

tracks = localEmptyTrackStruct();
nextId = 1;

Frame    = zeros(0,1);
TrackID  = zeros(0,1);
X        = zeros(0,1);
Y        = zeros(0,1);
Measured = false(0,1);

nDetections  = zeros(n,1);
nAssignments = zeros(n,1);

for k = 1:n
    [centroids, histograms] = localDetect(frames{k}, options, fgDetector);
    nDetections(k) = size(centroids,1);

    % ---- ① 預測
    for i = 1:numel(tracks)
        p = predict(tracks(i).KF);
        tracks(i).PredictedCentroid = p;
    end

    % ---- ② 關聯
    [assignments, unassignedTracks, unassignedDets] = ...
        localAssociate(tracks, centroids, histograms, options);
    nAssignments(k) = size(assignments,1);

    % ---- ③ 更新：配到的
    for a = 1:size(assignments,1)
        ti = assignments(a,1);
        di = assignments(a,2);
        c  = correct(tracks(ti).KF, centroids(di,:));
        tracks(ti).Centroid       = c;
        tracks(ti).Age            = tracks(ti).Age + 1;
        tracks(ti).TotalVisible   = tracks(ti).TotalVisible + 1;
        tracks(ti).ConsecInvisible = 0;
        % 外觀用指數移動平均更新，不要直接取代——
        % 單幀的直方圖會被部分遮擋整個帶歪。
        tracks(ti).Histogram = 0.7*tracks(ti).Histogram + 0.3*histograms(di,:);
    end

    % ---- 更新：沒配到的軌跡（靠預測撐著）
    for ti = unassignedTracks(:)'
        tracks(ti).Centroid        = tracks(ti).PredictedCentroid;
        tracks(ti).Age             = tracks(ti).Age + 1;
        tracks(ti).ConsecInvisible = tracks(ti).ConsecInvisible + 1;
    end

    % ---- 刪除撐太久的
    if ~isempty(tracks)
        dead = [tracks.ConsecInvisible] > options.MaxInvisible;
        tracks(dead) = [];
    end

    % ---- 沒配到的偵測開新軌跡
    for di = unassignedDets(:)'
        kf = localMakeKF(centroids(di,:), options.MotionModel);
        newTrack = struct( ...
            Id                = nextId, ...
            KF                = kf, ...
            Centroid          = centroids(di,:), ...
            PredictedCentroid = centroids(di,:), ...
            Histogram         = histograms(di,:), ...
            Age               = 1, ...
            TotalVisible      = 1, ...
            ConsecInvisible   = 0);
        if isempty(tracks)
            tracks = newTrack;
        else
            tracks(end+1) = newTrack; %#ok<AGROW>
        end
        nextId = nextId + 1;
    end

    % ---- 記錄
    for i = 1:numel(tracks)
        if tracks(i).TotalVisible < options.MinVisibleToKeep
            continue
        end
        Frame(end+1,1)    = k;                              %#ok<AGROW>
        TrackID(end+1,1)  = tracks(i).Id;                   %#ok<AGROW>
        X(end+1,1)        = tracks(i).Centroid(1);          %#ok<AGROW>
        Y(end+1,1)        = tracks(i).Centroid(2);          %#ok<AGROW>
        Measured(end+1,1) = tracks(i).ConsecInvisible == 0; %#ok<AGROW>
    end
end

result = table(Frame, TrackID, X, Y, Measured);

info = struct( ...
    NumTracks        = nextId - 1, ...
    NumKeptTracks    = numel(unique(TrackID)), ...
    NumFrames        = n, ...
    MeanDetections   = mean(nDetections), ...
    MeanAssignments  = mean(nAssignments), ...
    AppearanceWeight = options.AppearanceWeight, ...
    MotionModel      = options.MotionModel);
end

% ========================================================================
function s = localEmptyTrackStruct()
s = struct(Id={}, KF={}, Centroid={}, PredictedCentroid={}, ...
    Histogram={}, Age={}, TotalVisible={}, ConsecInvisible={});
end

% ------------------------------------------------------------------------
function kf = localMakeKF(centroid, motionModel)
%LOCALMAKEKF 建立 Kalman 濾波器。
%   **注意 ConstantVelocity 要 2 元素向量、ConstantAcceleration 要 3 元素。**
%   給錯長度的錯誤訊息還算清楚，但很容易在切換模型時忘記。
if motionModel == "ConstantVelocity"
    kf = configureKalmanFilter("ConstantVelocity", centroid, ...
        [200 50], [100 25], 100);
else
    kf = configureKalmanFilter("ConstantAcceleration", centroid, ...
        [200 50 10], [100 25 10], 100);
end
end

% ------------------------------------------------------------------------
function [centroids, histograms] = localDetect(frame, options, fgDetector)
%LOCALDETECT 一幀的偵測，回傳質心與顏色直方圖。
if isempty(fgDetector)
    % 彩色圓形：任一通道明顯高於背景灰階
    R = double(frame(:,:,1));
    G = double(frame(:,:,2));
    B = double(frame(:,:,3));
    mx = max(cat(3,R,G,B), [], 3);
    mn = min(cat(3,R,G,B), [], 3);
    mask = (mx - mn) > 40 & mx > 80;          % 有彩度且夠亮
else
    mask = fgDetector(frame);
    mask = imopen(mask, strel("rectangle",[3 3]));
    mask = imclose(mask, strel("rectangle",[15 15]));
end
mask = imfill(mask, "holes");
mask = bwareaopen(mask, options.MinArea);

stats = regionprops(mask, "Centroid", "PixelIdxList");
nDet  = numel(stats);
centroids  = zeros(nDet, 2);
histograms = zeros(nDet, 24);                  % 每個通道 8 個 bin
for i = 1:nDet
    centroids(i,:) = stats(i).Centroid;
    histograms(i,:) = localColorHist(frame, stats(i).PixelIdxList);
end
end

% ------------------------------------------------------------------------
function h = localColorHist(frame, idx)
%LOCALCOLORHIST 區塊內的 RGB 直方圖（各 8 bin），L1 正規化。
%   這是 DeepSORT 裡「外觀特徵」的**最簡版本**。
%   真正的 DeepSORT 用 ReID 網路的嵌入（第 10 節），
%   但顏色直方圖已經足以示範「外觀能解決位置解決不了的事」。
[h1, w1, ~] = size(frame);
npx = h1 * w1;
h = zeros(1, 24);
for c = 1:3
    ch = frame(idx + (c-1)*npx);
    h((c-1)*8 + (1:8)) = histcounts(double(ch), linspace(0, 256, 9));
end
s = sum(h);
if s > 0
    h = h / s;
end
end

% ------------------------------------------------------------------------
function [assignments, unassignedTracks, unassignedDets] = ...
    localAssociate(tracks, centroids, histograms, options)
%LOCALASSOCIATE 建成本矩陣並指派。
nTracks = numel(tracks);
nDets   = size(centroids,1);

if nTracks == 0
    assignments      = zeros(0,2);
    unassignedTracks = zeros(0,1);
    unassignedDets   = (1:nDets)';
    return
end
if nDets == 0
    assignments      = zeros(0,2);
    unassignedTracks = (1:nTracks)';
    unassignedDets   = zeros(0,1);
    return
end

% ---- 位置成本：預測位置到偵測的歐氏距離
cost = zeros(nTracks, nDets);
for i = 1:nTracks
    d = vecnorm(centroids - tracks(i).PredictedCentroid, 2, 2);
    cost(i,:) = d';
end

% ---- 外觀成本：直方圖的 L1 距離，縮放到和位置成本同量級
if options.AppearanceWeight > 0
    appCost = zeros(nTracks, nDets);
    for i = 1:nTracks
        appCost(i,:) = sum(abs(histograms - tracks(i).Histogram), 2)';
    end
    % 直方圖 L1 距離的範圍是 0–2，乘上 CostOfNonAssignment
    % 讓它和位置成本可以相加。**這個縮放是一個設計選擇，
    % 不是理論結果**——DeepSORT 原論文用的是門檻式的串聯（gating）。
    appCost = appCost / 2 * options.CostOfNonAssignment;
    w    = options.AppearanceWeight;
    cost = (1-w) * cost + w * appCost;
end

[assignments, unassignedTracks, unassignedDets] = ...
    assignDetectionsToTracks(cost, options.CostOfNonAssignment);
end
