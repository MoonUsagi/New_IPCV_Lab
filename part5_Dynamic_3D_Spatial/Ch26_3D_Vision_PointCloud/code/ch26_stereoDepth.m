function [ptCloud, report] = ch26_stereoDepth(options)
%CH26_STEREODEPTH 立體視覺的完整流程，並診斷每一步損失了多少。
%
%   [PTCLOUD, REPORT] = CH26_STEREODEPTH() 用內建的 handshake 立體影片
%   跑完「校正 → 視差 → 深度 → 點雲」，回傳彩色點雲與診斷 struct：
%     ValidDisparityPct  有視差的像素比例
%     PlausiblePct       深度落在合理範圍內的比例
%     ZMin / ZMax / ZMedian   深度的分布（公尺）
%     SecondsRectify / SecondsDisparity / SecondsReconstruct
%     NumPoints / NumValidPoints
%
%   ## 這支函式的重點是那兩個百分比
%   **立體視覺給你的不是一張稠密的深度圖。**
%   本機實測 `handshake` 影片：只有 **52.7%** 的像素算得出視差，
%   而其中又只有一部分的深度是合理的——**最後只剩 51.0%**。
%
%   沒有視差的地方有三類：
%   | 原因 | 典型位置 |
%   |---|---|
%   | **紋理不足** | 白牆、天空、單色物體 |
%   | **遮擋** | 只有一台相機看得到的區域 |
%   | **超出視差範圍** | 太近（視差太大）或太遠（視差太小） |
%
%   `disparitySGM` 對這些像素回傳 `NaN`（不是 0）。
%   **把 NaN 當成 0 會在原點附近堆出一團假點。**
%
%   名稱-值引數：
%     FrameIndex      用第幾幀，預設 50
%     Method          "SGM"（預設）或 "BM"
%     DisparityRange  預設 [0 64]。**必須是 16 的倍數長度**
%     MaxDepth        合理深度的上限（公尺），預設 10
%     MinDepth        合理深度的下限（公尺），預設 0.3
%
%   > **`DisparityRange` 是這一節最重要的參數。**
%   > 它同時決定了「最近看得到多近」與「最遠分得出多遠」，
%   > 而且**放大範圍不會讓有效率變高**——本機實測
%   > `[0 64]` 給 52.7%、`[0 128]` 反而掉到 47.9%。
%
%   範例：
%     [pc, r] = ch26_stereoDepth();
%     fprintf("只有 %.1f%% 的像素有深度\n", r.ValidDisparityPct);
%
%   另見 RECTIFYSTEREOIMAGES, DISPARITYSGM, RECONSTRUCTSCENE, POINTCLOUD.

arguments
    options.FrameIndex     (1,1) double {mustBePositive} = 50
    options.Method         (1,1) string {mustBeMember(options.Method, ["SGM" "BM"])} = "SGM"
    options.DisparityRange (1,2) double = [0 64]
    options.MaxDepth       (1,1) double {mustBePositive} = 10
    options.MinDepth       (1,1) double {mustBePositive} = 0.3
end

dataDir = fullfile(toolboxdir("vision"), "visiondata");
S = load(fullfile(dataDir, "handshakeStereoParams.mat"));
stereoParams = S.stereoParams;

vLeft  = VideoReader(fullfile(dataDir, "handshake_left.avi"));
vRight = VideoReader(fullfile(dataDir, "handshake_right.avi"));
frameL = read(vLeft,  options.FrameIndex);
frameR = read(vRight, options.FrameIndex);

% ---- ① 校正：把兩張影像對齊到同一條水平掃描線上
t0 = tic;
[rectL, rectR, reprojectionMatrix] = rectifyStereoImages(frameL, frameR, stereoParams);
secRectify = toc(t0);

% ---- ② 視差
grayL = rgb2gray(rectL);
grayR = rgb2gray(rectR);
t0 = tic;
if options.Method == "SGM"
    disparityMap = disparitySGM(grayL, grayR, DisparityRange=options.DisparityRange);
else
    disparityMap = disparityBM(grayL, grayR, DisparityRange=options.DisparityRange);
end
secDisparity = toc(t0);

validDisparity = isfinite(disparityMap);

% ---- ③ 重建成三維點
t0 = tic;
points3D = reconstructScene(disparityMap, reprojectionMatrix);
secReconstruct = toc(t0);

points3D = points3D / 1000;                 % mm -> m
Z = points3D(:,:,3);

plausible = validDisparity & isfinite(Z) & ...
    Z > options.MinDepth & Z < options.MaxDepth;

% ---- ④ 點雲。**只保留合理的點**，否則遠處的垃圾會把視野撐爆。
%      把 NaN 留在裡面是合法的（pointCloud 接受），
%      但下游的 pcshow 會自動忽略它們，而統計量不會。
cleaned = points3D;
cleaned(repmat(~plausible, 1, 1, 3)) = NaN;
ptCloud = pointCloud(cleaned, Color=rectL);

zValid = Z(plausible);
report = struct( ...
    Method             = options.Method, ...
    FrameIndex         = options.FrameIndex, ...
    DisparityRange     = options.DisparityRange, ...
    ImageSize          = [size(rectL,1) size(rectL,2)], ...
    ValidDisparityPct  = nnz(validDisparity) / numel(validDisparity) * 100, ...
    PlausiblePct       = nnz(plausible) / numel(plausible) * 100, ...
    ZMin               = min(zValid), ...
    ZMax               = max(zValid), ...
    ZMedian            = median(zValid), ...
    ZMaxRaw            = max(Z(validDisparity & isfinite(Z))), ...
    SecondsRectify     = secRectify, ...
    SecondsDisparity   = secDisparity, ...
    SecondsReconstruct = secReconstruct, ...
    NumPoints          = numel(Z), ...
    NumValidPoints     = nnz(plausible), ...
    DisparityMap       = disparityMap, ...
    RectifiedLeft      = rectL);
end
