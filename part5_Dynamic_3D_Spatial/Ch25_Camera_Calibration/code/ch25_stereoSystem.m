function [stereoParams, multiParams, report] = ch25_stereoSystem(options)
%CH25_STEREOSYSTEM 立體與多相機標定，並用三種方法交叉檢查基線。
%
%   [SP, MP, REPORT] = CH25_STEREOSYSTEM() 用內建的 stereo 影像集
%   （左右各 10 張，1280×960）做三件事：
%     ① `estimateCameraParameters` 的立體模式 → `stereoParameters`
%     ② `estimateStereoBaseline`（已知內參，只估外參）
%     ③ `estimateMultiCameraParameters`（當成 2 台相機的多相機系統）
%
%   REPORT 含三者的基線與重投影誤差，以及它們彼此的差異。
%
%   ## 為什麼要用三種方法算同一個數字
%   **因為基線沒有真值可比。** 你不知道那兩台相機實際上差幾公分。
%   三個獨立的估計法如果**互相吻合到 0.1%**，你對這個數字的信心
%   就遠高於只跑一次。
%
%   實測：119.72 / 119.87 / 119.74 mm，**最大差 0.15 mm（0.13%）**。
%
%   > 這是一種很便宜的驗證：**沒有真值時，用多個獨立方法互相檢查。**
%   > 第 22 章的留一法、第 24 章「和獨立偵測器比對」都是同一個想法。
%
%   ## 三個 API 的差別（很容易記錯）
%   | 函式 | 內參 | 用途 |
%   |---|---|---|
%   | `estimateCameraParameters(pts, wpts, ImageSize=...)` | **同時估** | 從零開始 |
%   | `estimateStereoBaseline(pts, wpts, intr1, intr2)` | **要先給** | 內參已知，只要外參 |
%   | `estimateMultiCameraParameters(pts, wpts, intrArray)` | **要先給** | 2 台以上 |
%
%   **`estimateStereoBaseline` 的內參是第 3、4 個位置引數，不是
%   `ImageSize` 名稱-值引數。** 傳成 `ImageSize=` 會報
%   「The value of 'intrinsics1' is invalid ... Instead its type was string」
%   ——訊息指向 intrinsics1，但你根本沒傳那個引數。
%
%   名稱-值引數：
%     SquareSize  方格邊長（mm），預設 108
%     MaxPairs    最多用幾對影像，預設全部
%
%   另見 ESTIMATESTEREOBASELINE, ESTIMATEMULTICAMERAPARAMETERS,
%   STEREOPARAMETERS, MULTICAMERAPARAMETERS.

arguments
    options.SquareSize (1,1) double {mustBePositive} = 108
    options.MaxPairs   (1,1) double {mustBePositive} = Inf
end

calRoot = fullfile(toolboxdir("vision"), "visiondata", "calibration", "stereo");
leftFiles  = dir(fullfile(calRoot, "left",  "*.png"));
rightFiles = dir(fullfile(calRoot, "right", "*.png"));
leftNames  = string(fullfile({leftFiles.folder},  {leftFiles.name}));
rightNames = string(fullfile({rightFiles.folder}, {rightFiles.name}));

n = min([numel(leftNames), numel(rightNames), options.MaxPairs]);
leftNames  = leftNames(1:n);
rightNames = rightNames(1:n);

[imagePoints, boardSize, pairsUsed] = ...
    detectCheckerboardPoints(leftNames, rightNames);
worldPoints = generateCheckerboardPoints(boardSize, options.SquareSize);

sampleImage = imread(leftNames(1));
imageSize   = [size(sampleImage,1) size(sampleImage,2)];

% ---- ① 立體標定（內外參一起估）
stereoParams = estimateCameraParameters(imagePoints, worldPoints, ...
    ImageSize = imageSize);
baselineStereo = norm(stereoParams.PoseCamera2.Translation);

% ---- 先各自單獨標定，取得內參給後面兩個方法用
paramsLeft  = estimateCameraParameters(imagePoints(:,:,:,1), worldPoints, ...
    ImageSize = imageSize);
paramsRight = estimateCameraParameters(imagePoints(:,:,:,2), worldPoints, ...
    ImageSize = imageSize);

% ---- ② 只估基線（內參當成已知）
%      **內參是位置引數 3、4**，不是名稱-值引數。
baselineParams = estimateStereoBaseline(imagePoints, worldPoints, ...
    paramsLeft.Intrinsics, paramsRight.Intrinsics);
baselineOnly = norm(baselineParams.PoseCamera2.Translation);

% ---- ③ 多相機系統（把左右當成 2 台相機）
%      R2026b 起，多相機標定工具要先執行 installMultiSensorCalibrationTools 才能用；
%      沒安裝時這一欄回傳 NaN，其餘兩種方法照常比較。
multiAvailable = multiSensorToolsAvailable();
if multiAvailable
    multiParams = estimateMultiCameraParameters(imagePoints, worldPoints, ...
        [paramsLeft.Intrinsics paramsRight.Intrinsics]);
    poses = multiParams.CameraPoses;
    baselineMulti  = norm(poses(2).Translation);
    errorMulti     = multiParams.MeanReprojectionError;
    errorPerCamera = multiParams.MeanReprojectionErrorPerCamera(:)';
    covisibility   = multiParams.CovisibilityMatrix;
    translation    = poses(2).Translation;
else
    multiParams    = [];              % 第二個輸出：未安裝時回傳空
    baselineMulti  = NaN;
    errorMulti     = NaN;
    errorPerCamera = [NaN NaN];
    covisibility   = [];
    translation    = stereoParams.PoseCamera2.Translation;
end

baselines = [baselineStereo baselineOnly baselineMulti];
spread = max(baselines) - min(baselines);            % max/min 會忽略 NaN

report = struct( ...
    NumPairs            = n, ...
    NumPairsUsed        = nnz(pairsUsed), ...
    BoardSize           = boardSize, ...
    ImageSize           = imageSize, ...
    BaselineStereo      = baselineStereo, ...
    BaselineOnly        = baselineOnly, ...
    BaselineMulti       = baselineMulti, ...
    BaselineSpread      = spread, ...
    BaselineSpreadPct   = spread / mean(baselines, "omitnan") * 100, ...
    ErrorStereo         = stereoParams.MeanReprojectionError, ...
    ErrorBaselineOnly   = baselineParams.MeanReprojectionError, ...
    ErrorMulti          = errorMulti, ...
    ErrorPerCamera      = errorPerCamera, ...
    CovisibilityMatrix  = covisibility, ...
    Translation         = translation, ...
    MultiAvailable      = multiAvailable);
end

function tf = multiSensorToolsAvailable()
%MULTISENSORTOOLSAVAILABLE 多相機標定工具能不能用。
%   R2026a 以前內建在 Computer Vision Toolbox；R2026b 起要另外執行
%   installMultiSensorCalibrationTools 安裝。
if isMATLABReleaseOlderThan("R2026b")
    tf = true;
else
    tf = ~isempty(which("multisensorcalib.internal.isMultiSensorCalibToolsInstalled"));
end
end
