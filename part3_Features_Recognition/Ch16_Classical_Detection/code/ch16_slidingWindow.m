function [boxes, scores, numWindows] = ch16_slidingWindow(I, model, winSize, options)
%CH16_SLIDINGWINDOW 滑動視窗偵測（含非極大值抑制）。
%
%   [BOXES, SCORES, NUMWINDOWS] = CH16_SLIDINGWINDOW(I, MODEL, WINSIZE)
%   在影像上滑動視窗、對每個視窗取 HOG 特徵並分類，回傳 NMS 後的框。
%   NUMWINDOWS 是實際掃描的視窗數，用來看計算成本。
%
%   名稱-值引數：
%     Stride           步長（像素），預設 8
%     NumScales        尺度數，預設 1
%     ScaleRatio       每層縮小的比例，預設 1.25
%     CellSize         HOG 的 CellSize，預設 [8 8]
%     PositiveClass    正類別的名稱，預設 "circle"
%     OverlapThreshold NMS 的重疊門檻，預設 0.3
%
%   計算成本（第 16 章第 8 節實測，480x640 單張影像）
%   -------------------------------------------------
%     步長   尺度數    視窗數     秒數
%      16      1       1,131     1.76
%      16      3       2,276     4.53
%       8      1       4,389     8.46
%       8      3       8,814    15.85
%       4      1      17,289    31.36
%       4      3      34,708    60.56
%
%   **步長減半 -> 視窗數 4 倍 -> 時間約 4 倍。**
%
%   一張 480x640 的影像，步長 4、三個尺度要 **60.6 秒**。
%   換算成 30 fps 的即時影片需要快 **1,800 倍**。
%
%   三個成本來源：
%     1. 視窗數 ~ (影像面積 / 步長^2) x 尺度數
%     2. **相鄰視窗有 75% 的像素重疊，但 HOG 被完整重算了一次**
%     3. 每個視窗都跑一次分類器
%
%   對照：內建的 FrontalFaceLBP 在 413x800 的影像上只花 **0.016 秒**，
%   比這裡快 520 倍。差別不在特徵或分類器，在**架構**——
%   cascade 的前幾級只用兩三個特徵就能拒絕 99% 的視窗。
%
%   這三個成本來源，正是第 19 章深度學習偵測器要解決的問題
%   （卷積共享計算、單次前向傳播處理所有位置與尺度）。
%
%   NMS 為什麼不夠
%   --------------
%   本函式已經做了 selectStrongestBbox，但第 6 節仍然得到 509 個框。
%   **NMS 只能合併「重疊的」重複偵測，無法消除散佈在各處的假陽性。**
%   那需要硬負樣本挖掘（CH16_MINEHARDNEGATIVES）。
%
%   範例：
%     [boxes, scores, n] = ch16_slidingWindow(scene, svmModel, [32 32], ...
%         Stride=8, NumScales=1);
%     fprintf("掃了 %d 個視窗，得到 %d 個框\n", n, size(boxes,1));
%
%   另見 CH16_MINEHARDNEGATIVES, CH16_EVALDETECTIONS, SELECTSTRONGESTBBOX.

arguments
    I       {mustBeNumeric, mustBeNonempty}
    model
    winSize (1,2) double {mustBePositive, mustBeInteger}
    options.Stride           (1,1) double {mustBePositive, mustBeInteger} = 8
    options.NumScales        (1,1) double {mustBePositive, mustBeInteger} = 1
    options.ScaleRatio       (1,1) double {mustBeGreaterThan(options.ScaleRatio,1)} = 1.25
    options.CellSize         (1,2) double {mustBePositive, mustBeInteger} = [8 8]
    options.PositiveClass    (1,1) string = "circle"
    options.OverlapThreshold (1,1) double {mustBeInRange(options.OverlapThreshold,0,1)} = 0.3
end

if size(I,3) > 1
    I = im2gray(I);
end
I = im2double(I);

boxes = zeros(0,4);
scores = [];
numWindows = 0;

for s = 1:options.NumScales
    sc = 1 / (options.ScaleRatio^(s-1));
    J = imresize(I, sc);
    if any(size(J) < winSize)
        break                       % 縮太小了，放不進一個視窗
    end

    for r = 1:options.Stride:(size(J,1) - winSize(1) + 1)
        for c = 1:options.Stride:(size(J,2) - winSize(2) + 1)
            numWindows = numWindows + 1;
            patch = J(r:r+winSize(1)-1, c:c+winSize(2)-1);
            f = extractHOGFeatures(patch, CellSize=options.CellSize);
            [label, score] = predict(model, f);
            if label == options.PositiveClass
                % 座標要換回原始尺度
                boxes(end+1,:) = [c/sc, r/sc, winSize(2)/sc, winSize(1)/sc];
                scores(end+1,1) = max(score);
            end
        end
    end
end

if ~isempty(boxes)
    [boxes, scores] = selectStrongestBbox(boxes, scores, ...
        OverlapThreshold=options.OverlapThreshold);
end
end
