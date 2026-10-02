function varargout = ch24_reidSketch(action, varargin)
%CH24_REIDSKETCH ReID 網路的完整程式碼骨架。**預設不執行訓練。**
%
%   ⚠ **本函式的訓練路徑從未在開發機器上執行過**（NVIDIA T550，4.29 GB
%   顯示記憶體跑不動）。程式碼結構、API 形狀與引數都對照過文件，
%   但**數字與收斂行為未經驗證**。換到有 GPU 的機器後見
%   `docs/PENDING_VERIFICATION.md` 的第 24 章清單。
%
%   ACTION 可以是：
%     "build"    建立一個 reidentificationNetwork（**會真的執行**，很快）
%                  reID = ch24_reidSketch("build", classNames)
%     "extract"  抽取 ReID 特徵（**會真的執行**）
%                  F = ch24_reidSketch("extract", reID, images)
%     "train"    訓練（**預設只印出程式碼，不執行**）
%                  ch24_reidSketch("train")                 % 只看程式碼
%                  net = ch24_reidSketch("train", imds, DoTrain=true)
%     "gallery"  示範「特徵庫重認」——DeepSORT 和本章
%                  ch24_multiTracker 的主要差距（**會真的執行**）
%
%   ## 為什麼把訓練和其他分開
%   `build` 與 `extract` 在 CPU 上幾秒就跑完，可以驗證 API 形狀；
%   `train` 需要數十分鐘的 GPU 時間與一份身分標註資料集。
%   **把它們分開，讓教材能在沒有 GPU 的機器上驗證掉大部分的錯誤。**
%   這和第 18–20 章的 `DoTrain=false` 是同一個做法。
%
%   另見 REIDENTIFICATIONNETWORK, TRAINREIDENTIFICATIONNETWORK,
%   CH24_MULTITRACKER.

arguments
    action (1,1) string {mustBeMember(action, ["build" "extract" "train" "gallery"])}
end
arguments (Repeating)
    varargin
end

switch action
    case "build"
        varargout{1} = localBuild(varargin{:});
    case "extract"
        varargout{1} = localExtract(varargin{:});
    case "train"
        [varargout{1:nargout}] = localTrain(varargin{:});
    case "gallery"
        [varargout{1:nargout}] = localGallery(varargin{:});
end
end

% ========================================================================
function reID = localBuild(classNames, inputSize)
%LOCALBUILD 建立 ReID 網路。**這一段會真的執行。**
if nargin < 1 || isempty(classNames)
    classNames = "id" + string(1:4);
end
if nargin < 2
    inputSize = [128 64 3];        % ReID 的慣例：高瘦（人形）
end

% **第一個引數必須是 dlnetwork，不是字串。**
% 傳 "resnet18" 會報「Invalid argument list. Function requires
% 1 more input(s).」——那個訊息在抱怨缺少 classNames，
% 完全指不到「型別錯了」這件事。
backbone = imagePretrainedNetwork("resnet18", ...
    NumClasses = numel(classNames));

reID = reidentificationNetwork(backbone, classNames, ...
    InputSize = inputSize);
end

% ------------------------------------------------------------------------
function feats = localExtract(reID, images)
%LOCALEXTRACT 抽取 ReID 特徵。**這一段會真的執行。**
%   IMAGES 是 1xN cell 或 HxWx3xN 陣列。回傳 N x FeatureLength。
if iscell(images)
    n = numel(images);
    feats = zeros(n, reID.FeatureLength, "single");
    for k = 1:n
        feats(k,:) = extractReidentificationFeatures(reID, images{k});
    end
else
    n = size(images, 4);
    feats = zeros(n, reID.FeatureLength, "single");
    for k = 1:n
        feats(k,:) = extractReidentificationFeatures(reID, images(:,:,:,k));
    end
end

% **一定要 L2 正規化**再拿去算餘弦相似度。
% 第 21 章 §3 踩過同一個坑：不正規化時內積會被特徵長度主導。
feats = feats ./ max(vecnorm(feats, 2, 2), eps("single"));
end

% ------------------------------------------------------------------------
function [net, info] = localTrain(imds, options)
%LOCALTRAIN ReID 訓練。**預設不執行，只印出程式碼。**
arguments
    imds = []
    options.DoTrain    (1,1) logical = false
    options.MaxEpochs  (1,1) double  = 30
    options.MiniBatch  (1,1) double  = 32
    options.LearnRate  (1,1) double  = 1e-4
end

if ~options.DoTrain || isempty(imds)
    % **不要把多行程式碼塞進一個含轉義序列的格式字串。**
    % 兩個坑疊在一起：① ["A" "B"] 是 string 陣列不是串接，
    % fprintf 會把第一個元素當成 file identifier；
    % ② 用工具產生 .m 檔時，格式字串裡的換行轉義很容易被多吃一層。
    % 改成「字串陣列 + newline」就兩個都避開了。
    codeLines = [
        "% ---- ReID 訓練（本機未執行）----------------------------"
        "% 資料：每一個「身分」是一個類別，每個類別數十到數百張裁切。"
        "% imageDatastore 的 Labels 就是身分編號。"
        "imds = imageDatastore(rootDir, ..."
        "    IncludeSubfolders = true, LabelSource = ""foldernames"");"
        ""
        "backbone = imagePretrainedNetwork(""resnet18"", ..."
        "    NumClasses = numel(categories(imds.Labels)));"
        "reID = reidentificationNetwork(backbone, ..."
        "    string(categories(imds.Labels)), InputSize = [128 64 3]);"
        ""
        "opts = trainingOptions(""adam"", ..."
        "    MaxEpochs        = <EPOCHS>, ..."
        "    MiniBatchSize    = <BATCH>, ..."
        "    InitialLearnRate = <LR>, ..."
        "    Shuffle          = ""every-epoch"", ..."
        "    ValidationData   = imdsVal, ..."
        "    Plots            = ""training-progress"");"
        ""
        "net = trainReidentificationNetwork(imds, reID, opts);"
        "metrics = evaluateReidentificationNetwork(net, imdsTest);"
        "% ----------------------------------------------------------"
        ];
    codeLines = replace(codeLines, "<EPOCHS>", string(options.MaxEpochs));
    codeLines = replace(codeLines, "<BATCH>",  string(options.MiniBatch));
    codeLines = replace(codeLines, "<LR>",     string(options.LearnRate));
    fprintf("%s" + newline, codeLines);

    fprintf("\n⚠ DoTrain=false（預設）。上面是程式碼，沒有執行。\n");
    fprintf("  要真的訓練：ch24_reidSketch(""train"", imds, DoTrain=true)\n");
    fprintf("  **切分資料時，同一個身分不可以同時出現在訓練集與測試集**——\n");
    fprintf("  ReID 要驗的是「沒見過的身分能不能配對」，不是分類準確率。\n");
    net  = [];
    info = struct(Trained=false, Reason="DoTrain=false 或未提供資料");
    return
end

classNames = string(categories(imds.Labels));
reID = localBuild(classNames);
opts = trainingOptions("adam", ...
    MaxEpochs        = options.MaxEpochs, ...
    MiniBatchSize    = options.MiniBatch, ...
    InitialLearnRate = options.LearnRate, ...
    Shuffle          = "every-epoch", ...
    Verbose          = true);

net  = trainReidentificationNetwork(imds, reID, opts);
info = struct(Trained=true, NumClasses=numel(classNames));
end

% ------------------------------------------------------------------------
function [matchId, similarity] = localGallery(query, galleryFeats, galleryIds, options)
%LOCALGALLERY 特徵庫重認：DeepSORT 和本章 ch24_multiTracker 的主要差距。
%
%   ch24_multiTracker 只把外觀混進成本矩陣。DeepSORT 多做一件事：
%   **軌跡被刪掉時，它的外觀特徵留在一個「特徵庫」裡**，
%   之後出現的新軌跡要先去特徵庫裡問「我是不是以前的某個人」。
%
%   這就是為什麼 DeepSORT 能處理「走出畫面幾十幀又走回來」，
%   而純 SORT 只會給它一個新編號。
arguments
    query                       (1,:) single
    galleryFeats                (:,:) single
    galleryIds                  (:,1)
    options.MinSimilarity (1,1) double = 0.6
end

if isempty(galleryFeats)
    matchId    = missing;
    similarity = NaN;
    return
end

% 兩邊都已 L2 正規化，所以內積就是餘弦相似度。
sims = galleryFeats * query';
[similarity, idx] = max(sims);

% **門檻不能省。** 沒有門檻的話，任何新物體都會被硬塞給
% 特徵庫裡最像的那個身分——這是 ReID 最常見的失效方式，
% 而且它產生的是「看起來很連貫的錯誤軌跡」。
if similarity >= options.MinSimilarity
    matchId = galleryIds(idx);
else
    matchId = missing;            % 認不出來就開新身分，不要硬配
end
end
