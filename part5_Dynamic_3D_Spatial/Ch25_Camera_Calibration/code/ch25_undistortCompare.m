function report = ch25_undistortCompare(intrinsicsA, intrinsicsB, imageSize, options)
%CH25_UNDISTORTCOMPARE 比較兩個相機模型「去畸變之後」的差異。
%
%   REPORT = CH25_UNDISTORTCOMPARE(A, B, IMAGESIZE) 在整張影像上鋪一個
%   網格，分別用兩組內參去畸變，回傳它們的差異：
%     MedianDiff   網格點差異的中位數（像素）
%     MaxDiff      最大差異
%     CenterDiff   最靠近中心的點的差異
%     CornerDiff   最靠近邊角的點的差異
%     RadialProfile  差異對「離中心距離」的分組統計 table
%
%   ## 這支函式存在的唯一理由
%   **重投影誤差不能用來選畸變模型。**
%
%   重投影誤差只在**標定角點的位置**計算。棋盤格再怎麼擺，
%   角點也不會落在影像的最邊角——那裡**沒有任何資料約束模型**。
%   高階的畸變項在有資料的地方被壓得很好，
%   在沒有資料的地方可以任意外插。
%
%   實測（`mono` 資料集，1072×712）：
%   | | 2 階徑向 | 3 階徑向 |
%   |---|---|---|
%   | 重投影誤差 | 0.1832 px | 0.1833 px |
%   | 中心附近的去畸變差異 | — | **0.00–0.05 px** |
%   | 邊角的去畸變差異 | — | **125–201 px** |
%
%   **兩個模型在重投影誤差上分不出來，在影像邊角差了 200 像素。**
%
%   名稱-值引數：
%     GridSize    網格大小 [列 欄]，預設 [7 9]
%     Fisheye     兩個模型是否為魚眼（`[A B]` 的 logical），預設 [false false]
%     NumBins     徑向分組數，預設 4
%
%   範例：
%     [pA, ~] = ch25_calibrateSet("mono", NumRadial=2);
%     [pB, ~] = ch25_calibrateSet("mono", NumRadial=3);
%     r = ch25_undistortCompare(pA.Intrinsics, pB.Intrinsics, [712 1072]);
%     fprintf("邊角差 %.1f px，重投影誤差卻幾乎相同\n", r.CornerDiff);
%
%   另見 UNDISTORTPOINTS, UNDISTORTFISHEYEPOINTS, CH25_CALIBRATESET.

arguments
    intrinsicsA
    intrinsicsB
    imageSize          (1,2) double
    options.GridSize   (1,2) double = [7 9]
    options.Fisheye    (1,2) logical = [false false]
    options.NumBins    (1,1) double {mustBePositive} = 4
end

[X, Y] = meshgrid(linspace(1, imageSize(2), options.GridSize(2)), ...
                  linspace(1, imageSize(1), options.GridSize(1)));
gridPoints = [X(:) Y(:)];

undA = localUndistort(gridPoints, intrinsicsA, options.Fisheye(1));
undB = localUndistort(gridPoints, intrinsicsB, options.Fisheye(2));
diffs = vecnorm(undA - undB, 2, 2);

center = imageSize([2 1]) / 2;
radius = vecnorm(gridPoints - center, 2, 2);
[~, order] = sort(radius);

% 依離中心的距離分組，看差異怎麼隨半徑成長。
edges = linspace(0, max(radius), options.NumBins + 1);
binIdx = discretize(radius, edges);
Bin        = (1:options.NumBins)';
RadiusFrom = edges(1:end-1)';
RadiusTo   = edges(2:end)';
MedianDiff = nan(options.NumBins,1);
MaxDiff    = nan(options.NumBins,1);
Count      = zeros(options.NumBins,1);
for b = 1:options.NumBins
    sel = binIdx == b;
    Count(b) = nnz(sel);
    if any(sel)
        MedianDiff(b) = median(diffs(sel));
        MaxDiff(b)    = max(diffs(sel));
    end
end

report = struct( ...
    MedianDiff    = median(diffs), ...
    MaxDiff       = max(diffs), ...
    CenterDiff    = median(diffs(order(1:min(5,end)))), ...
    CornerDiff    = median(diffs(order(max(1,end-4):end))), ...
    NumPoints     = size(gridPoints,1), ...
    RadialProfile = table(Bin, RadiusFrom, RadiusTo, Count, MedianDiff, MaxDiff));
end

% ========================================================================
function u = localUndistort(points, intrinsics, isFisheye)
if isFisheye
    u = undistortFisheyePoints(points, intrinsics);
else
    u = undistortPoints(points, intrinsics);
end
end
