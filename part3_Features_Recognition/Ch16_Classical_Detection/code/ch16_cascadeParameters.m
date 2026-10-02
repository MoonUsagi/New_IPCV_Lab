function paramTbl = ch16_cascadeParameters(I, expectedCount, options)
%CH16_CASCADEPARAMETERS 掃描 cascade 偵測器的三個關鍵參數。
%
%   PARAMTBL = CH16_CASCADEPARAMETERS(I, EXPECTEDCOUNT) 掃描
%   MergeThreshold、ScaleFactor、MinSize，回傳每個設定的偵測數與耗時。
%   EXPECTEDCOUNT 是人工數的正解，用來標示哪些設定是對的。
%
%   名稱-值引數：
%     Model            用哪個模型，預設 "FrontalFaceCART"
%     MergeThresholds  預設 [1 2 4 6 8 12 20]
%     ScaleFactors     預設 [1.01 1.05 1.1 1.2 1.4]
%     MinSizes         預設 [20 40 60 80 120]（正方形邊長）
%
%   三個參數的性格完全不同（visionteam.jpg、正解 6）
%   -------------------------------------------------
%   **MergeThreshold：有很寬的平台區**
%     1 -> 15、2 -> 9、**4(預設) 到 12 -> 都是 6**、20 -> 5
%   低於 4 時假陽性爆炸，高於 12 開始漏抓。
%   平台區很寬是好參數的特徵——**代表它不敏感，不用細調**。
%
%   **ScaleFactor：越小越慢也越差**
%     1.01 -> 14 個、0.726 秒
%     1.05 -> 6 個、0.119 秒
%     1.10 -> 6 個、0.065 秒（預設）
%     1.20 -> 6 個、0.034 秒
%     1.40 -> 3 個、0.018 秒
%   1.01 比 1.20 **慢 21 倍**，而且多找出 8 個錯的。
%   這與第 12 章「掃描太密不一定比較好」相通：
%   **更細的搜尋會找到更多東西，但不保證是對的東西。**
%
%   **MinSize：是懸崖不是斜坡**
%     [20 20] -> 6、[40 40] -> 6、**[60 60] -> 0**、[80 80] -> 0
%   從 40 到 60 直接掉到零，因為這張影像的臉介於 40–60 像素之間。
%
%   > **MinSize 是最有價值的效能參數**（不用掃小尺度就能大幅加速），
%   > **但設太大會完全失效而不是逐漸變差。**
%   > 實務上要**先量測目標的實際尺寸範圍**再設它，不要憑感覺——
%   > 與第 10 章 imfindcircles 的 RadiusRange 同一個道理。
%
%   另見 VISION.CASCADEOBJECTDETECTOR, CH16_CASCADEMODELS.

arguments
    I {mustBeNumeric, mustBeNonempty}
    expectedCount (1,1) double {mustBeNonnegative, mustBeInteger}
    options.Model           (1,1) string = "FrontalFaceCART"
    options.MergeThresholds (1,:) double = [1 2 4 6 8 12 20]
    options.ScaleFactors    (1,:) double = [1.01 1.05 1.1 1.2 1.4]
    options.MinSizes        (1,:) double = [20 40 60 80 120]
end

paramName = strings(0);
value     = strings(0);
counts    = [];
times     = [];

% --- MergeThreshold ---
for mt = options.MergeThresholds
    d = vision.CascadeObjectDetector(char(options.Model), MergeThreshold=mt);
    d(I);                                  % 暖機
    t = tic; bb = d(I); el = toc(t);
    paramName(end+1,1) = "MergeThreshold";
    value(end+1,1)     = string(mt);
    counts(end+1,1)    = size(bb,1);
    times(end+1,1)     = el;
end

% --- ScaleFactor ---
for sf = options.ScaleFactors
    d = vision.CascadeObjectDetector(char(options.Model), ScaleFactor=sf);
    d(I);
    t = tic; bb = d(I); el = toc(t);
    paramName(end+1,1) = "ScaleFactor";
    value(end+1,1)     = sprintf("%.2f", sf);
    counts(end+1,1)    = size(bb,1);
    times(end+1,1)     = el;
end

% --- MinSize ---
for ms = options.MinSizes
    d = vision.CascadeObjectDetector(char(options.Model), MinSize=[ms ms]);
    d(I);
    t = tic; bb = d(I); el = toc(t);
    paramName(end+1,1) = "MinSize";
    value(end+1,1)     = sprintf("[%d %d]", ms, ms);
    counts(end+1,1)    = size(bb,1);
    times(end+1,1)     = el;
end

isCorrect = counts == expectedCount;

paramTbl = table(paramName, value, counts, times, isCorrect, ...
    VariableNames=["Parameter" "Value" "NumDetections" "Seconds" "Correct"]);

% --- 找出每個參數的平台區 ------------------------------------------
for pn = unique(paramName)'
    sel = paramName == pn;
    ok = isCorrect(sel);
    vals = value(sel);
    if any(ok)
        fprintf("%-16s 正解區間：%s\n", pn, join(vals(ok), ", "));
    else
        fprintf("%-16s **沒有任何設定給出正解 %d**\n", pn, expectedCount);
    end
end
end
