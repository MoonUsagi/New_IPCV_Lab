function [params, report] = ch25_calibrateSet(setName, options)
%CH25_CALIBRATESET 標定一組內建的標定影像，並回傳診斷資訊。
%
%   [PARAMS, REPORT] = CH25_CALIBRATESET(SETNAME) 對 MATLAB 內建的
%   標定影像集做單相機標定。SETNAME 可以是：
%     "mono"   1072x712，10 張（**只有 9 張偵測得到**），一般鏡頭
%     "dslr"   1626x1080，9 張
%     "gopro"  2000x1500，11 張，**廣角／魚眼**
%     "slr"    2816x1880，9 張
%
%   REPORT 是 struct：
%     NumImages        提供幾張
%     NumDetected      偵測成功幾張
%     MeanError        平均重投影誤差（像素）
%     PerImageError    每張的平均誤差
%     WorstImage       誤差最大的那一張
%     FocalLength / PrincipalPoint / RadialDistortion / TangentialDistortion
%     BowBefore / BowAfter  去畸變前後的**相對彎曲度**（見下）
%     BowImprovement   彎曲度改善的百分比
%
%   ## 為什麼要多算一個「彎曲度」
%   **重投影誤差是這一章最容易被誤信的數字。**
%   它只在**有標定角點的地方**計算，而角點永遠不會覆蓋到影像的最邊角。
%   §4 量到：2 階與 3 階徑向畸變的重投影誤差只差 **0.0001 像素**，
%   但去畸變後的角落位置差 **200 像素**。
%
%   「彎曲度」量的是另一件事：**棋盤格上本來是直線的一排角點，
%   去畸變之後有多直**。定義為
%
%       彎曲度 = 偏離最佳擬合直線的最大距離 / 直線長度 × 100%
%
%   它是**尺度不變**的，而且直接對應「畸變有沒有被修掉」這個問題。
%
%   名稱-值引數：
%     SquareSize    棋盤格方格邊長（mm），預設依資料集給定
%     NumRadial     徑向畸變係數個數（2 或 3），預設 2
%     Tangential    是否估計切向畸變，預設 false
%     Skew          是否估計傾斜，預設 false
%     UseImages     只用其中幾張（索引向量），預設全部
%     Fisheye       是否改用魚眼模型（`estimateFisheyeParameters`），預設 false
%
%   範例：
%     [p, r] = ch25_calibrateSet("mono");
%     fprintf("誤差 %.4f px，彎曲改善 %.1f%%\n", r.MeanError, r.BowImprovement);
%
%   另見 ESTIMATECAMERAPARAMETERS, ESTIMATEFISHEYEPARAMETERS,
%   CH25_UNDISTORTCOMPARE.

arguments
    setName            (1,1) string {mustBeMember(setName, ["mono" "dslr" "gopro" "slr"])}
    options.SquareSize (1,1) double {mustBeNonnegative} = 0
    options.NumRadial  (1,1) double {mustBeMember(options.NumRadial, [2 3])} = 2
    options.Tangential (1,1) logical = false
    options.Skew       (1,1) logical = false
    options.UseImages  (1,:) double  = []
    options.Fisheye    (1,1) logical = false
end

% 各資料集的方格邊長（mm）。**這個數字決定了所有結果的單位**，
% 給錯不會有任何錯誤訊息——焦距與外參會整組等比例縮放。
defaultSquare = struct(mono=25, dslr=22, gopro=29, slr=22);
if options.SquareSize == 0
    options.SquareSize = defaultSquare.(setName);
end

calRoot = fullfile(toolboxdir("vision"), "visiondata", "calibration", setName);
files = dir(fullfile(calRoot, "*.jpg"));
if isempty(files)
    error("ipcv:ch25:noImages", "在 %s 找不到影像。", calRoot);
end
fileNames = string(fullfile({files.folder}, {files.name}));

[imagePoints, boardSize, imagesUsed] = detectCheckerboardPoints(fileNames);

if ~isempty(options.UseImages)
    keep = options.UseImages;
    keep = keep(keep <= size(imagePoints,3));
    imagePoints = imagePoints(:,:,keep);
end

worldPoints = generateCheckerboardPoints(boardSize, options.SquareSize);
sampleImage = imread(fileNames(1));
imageSize   = [size(sampleImage,1) size(sampleImage,2)];

if options.Fisheye
    params = estimateFisheyeParameters(imagePoints, worldPoints, imageSize);
    intrinsics = params.Intrinsics;
    undistortFcn = @(p) undistortFisheyePoints(p, intrinsics);
else
    params = estimateCameraParameters(imagePoints, worldPoints, ...
        ImageSize = imageSize, ...
        NumRadialDistortionCoefficients = options.NumRadial, ...
        EstimateTangentialDistortion    = options.Tangential, ...
        EstimateSkew                    = options.Skew);
    intrinsics = params.Intrinsics;
    undistortFcn = @(p) undistortPoints(p, intrinsics);
end

perImage = squeeze(mean(vecnorm(params.ReprojectionErrors, 2, 2), 1));
[~, worst] = max(perImage);

% ---- 彎曲度：用第一張影像的每一「欄」角點
% **注意 detectCheckerboardPoints 的排序是逐欄的**，
% 所以連續的角點屬於同一欄，不是同一列。索引搞反會得到
% 一個看起來很大但完全沒有意義的彎曲度（我第一次就是這樣）。
nRows = boardSize(1) - 1;
nCols = boardSize(2) - 1;
bowBefore = zeros(1, nCols);
bowAfter  = zeros(1, nCols);
for c = 1:nCols
    idx = (c-1)*nRows + (1:nRows);
    line0 = imagePoints(idx, :, 1);
    bowBefore(c) = localBow(line0);
    bowAfter(c)  = localBow(undistortFcn(line0));
end

report = struct( ...
    SetName        = setName, ...
    NumImages      = numel(fileNames), ...
    NumDetected    = nnz(imagesUsed), ...
    BoardSize      = boardSize, ...
    SquareSize     = options.SquareSize, ...
    ImageSize      = imageSize, ...
    MeanError      = params.MeanReprojectionError, ...
    PerImageError  = perImage(:)', ...
    WorstImage     = worst, ...
    BowBefore      = mean(bowBefore), ...
    BowAfter       = mean(bowAfter), ...
    BowImprovement = (1 - mean(bowAfter)/mean(bowBefore)) * 100, ...
    Fisheye        = options.Fisheye);

% **fisheyeIntrinsics 沒有 FocalLength／PrincipalPoint／RadialDistortion。**
% 它用的是完全不同的參數化（Scaramuzza 的多項式映射 +
% DistortionCenter + StretchMatrix），不是針孔模型加畸變係數。
% 想寫一段「不管哪個模型都印出焦距」的程式碼會在這裡失敗——
% 錯誤訊息是「Unrecognized method, property, or field 'FocalLength'」。
if options.Fisheye
    report.MappingCoefficients  = intrinsics.MappingCoefficients;
    report.DistortionCenter     = intrinsics.DistortionCenter;
    report.StretchMatrix        = intrinsics.StretchMatrix;
    report.FocalLength          = [];
    report.PrincipalPoint       = [];
    report.RadialDistortion     = [];
    report.TangentialDistortion = [];
else
    report.FocalLength          = intrinsics.FocalLength;
    report.PrincipalPoint       = intrinsics.PrincipalPoint;
    report.RadialDistortion     = intrinsics.RadialDistortion;
    report.TangentialDistortion = intrinsics.TangentialDistortion;
end
end

% ========================================================================
function b = localBow(points)
%LOCALBOW 相對彎曲度（%）：偏離最佳擬合直線的最大距離 ÷ 直線長度。
%   **尺度不變**，所以去畸變前後可以直接比——
%   `undistortPoints` 回傳的座標可能整體縮放，
%   用絕對距離比會得到「去畸變讓線變更彎」的錯誤結論。
P = double(points);
c = mean(P, 1);
Q = P - c;
[~, ~, V] = svd(Q, 0);
deviation = max(abs(Q * V(:,2)));
lengthAlong = max(Q * V(:,1)) - min(Q * V(:,1));
b = deviation / lengthAlong * 100;
end
