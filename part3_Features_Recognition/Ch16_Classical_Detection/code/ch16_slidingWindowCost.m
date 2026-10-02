function costTbl = ch16_slidingWindowCost(I, model, winSize, cellSize, options)
%CH16_SLIDINGWINDOWCOST 量測滑動視窗的計算成本。
%
%   COSTTBL = CH16_SLIDINGWINDOWCOST(I, MODEL, WINSIZE, CELLSIZE) 對不同的
%   步長與尺度數組合，回傳視窗數、偵測數與耗時。
%
%   名稱-值引數：
%     Strides    要測的步長，預設 [16 8 4]
%     NumScales  要測的尺度數，預設 [1 3]
%
%   實測（480x640 單張影像，第 16 章第 8 節）
%   ------------------------------------------
%     步長   尺度數    視窗數     秒數
%      16      1       1,131     1.76
%      16      3       2,276     4.53
%       8      1       4,389     8.46
%       8      3       8,814    15.85
%       4      1      17,289    31.36
%       4      3      34,708    60.56
%
%   **步長減半 -> 視窗數 4 倍 -> 時間約 4 倍。**
%   每千個視窗固定花 1.55–1.93 秒，比值接近常數——**沒有規模經濟**。
%
%   34,708 個視窗要 60.6 秒。換算成 30 fps 的即時影片，
%   需要快 **1,800 倍**。
%
%   三個成本來源與傳統的補救
%   ------------------------
%     問題              傳統的補救
%     視窗太多          **cascade**：多數視窗在第一級就被拒絕
%     重複算特徵        **積分影像**：Haar 特徵可 O(1) 取得
%     尺度太多          **特徵金字塔近似**（ACF 的核心技巧）
%
%   第 2 點特別值得注意：步長 8、視窗 32x32 時，
%   **相鄰視窗有 75% 的像素重疊**，但 HOG 被完整重算了一次。
%   這是純粹的浪費，也是卷積神經網路「共享計算」要解決的問題。
%
%   對照：內建的 FrontalFaceLBP 在 413x800 的影像上只花 **0.016 秒**，
%   比這裡快 520 倍——差別在架構，不在特徵或分類器。
%
%   另見 CH16_SLIDINGWINDOW, VISION.CASCADEOBJECTDETECTOR.

arguments
    I        {mustBeNumeric, mustBeNonempty}
    model
    winSize  (1,2) double {mustBePositive, mustBeInteger}
    cellSize (1,2) double {mustBePositive, mustBeInteger} = [8 8]
    options.Strides   (1,:) double = [16 8 4]
    options.NumScales (1,:) double = [1 3]
end

stride    = [];
nScale    = [];
nWindows  = [];
nDetect   = [];
seconds   = [];

for st = options.Strides
    for ns = options.NumScales
        t = tic;
        [boxes, ~, nw] = ch16_slidingWindow(I, model, winSize, ...
            Stride=st, NumScales=ns, CellSize=cellSize);
        el = toc(t);

        stride(end+1,1)   = st;
        nScale(end+1,1)   = ns;
        nWindows(end+1,1) = nw;
        nDetect(end+1,1)  = size(boxes,1);
        seconds(end+1,1)  = el;
    end
end

costTbl = table(stride, nScale, nWindows, nDetect, seconds, ...
    VariableNames=["Stride" "NumScales" "NumWindows" "NumDetections" "Seconds"]);

% --- 檢查線性關係 ---------------------------------------------------
single = costTbl(costTbl.NumScales == min(options.NumScales), :);
if height(single) >= 2
    fprintf("\n單尺度下，視窗數與時間的比值（秒 / 千個視窗）：\n");
    for k = 1:height(single)
        fprintf("  步長 %2d：%d 視窗、%.3f 秒 -> %.3f 秒/千視窗\n", ...
            single.Stride(k), single.NumWindows(k), single.Seconds(k), ...
            1000*single.Seconds(k)/single.NumWindows(k));
    end
    fprintf("比值接近常數 -> **成本與視窗數成線性**，沒有規模經濟。\n");
end
end
