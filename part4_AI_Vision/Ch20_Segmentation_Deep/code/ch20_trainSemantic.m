function [net, info] = ch20_trainSemantic(dsTrain, dsVal, classNames, options)
%CH20_TRAINSEMANTIC 訓練語意分割網路。**預設不執行訓練。**
%
%   [NET, INFO] = CH20_TRAINSEMANTIC(DSTRAIN, DSVAL, CLASSNAMES) 組好
%   網路（`deeplabv3plus` 或 `unet`）與 TRAININGOPTIONS，
%   但**預設只回傳設定、不呼叫 TRAINNET**。
%
%   名稱-值引數：
%     DoTrain          - **預設 false**
%     Architecture     - "unet"（預設）或 "deeplabv3plus"
%     InputSize        - 預設 [64 64 3]
%     Encoder          - deeplabv3plus 的骨幹（預設 "resnet18"）
%     ClassWeights     - 類別權重，"auto" 用逆頻率（預設 "auto"）
%     MaxEpochs        - 預設 20
%     MiniBatchSize    - 預設 8
%     InitialLearnRate - 預設 1e-3
%     Plots            - 預設 "none"
%
%   ============================================================
%   **這個函式尚未在本機執行過，這是刻意的。**
%
%   與第 18、19 章不同，**語意分割沒有可以直接推論的預訓練權重**：
%   `deeplabv3plus` 與 `unet` 只提供**未訓練的架構**
%   （它們的說明文件沒有 pretrained 選項，
%   已安裝的分割相關支援包只有 SOLOv2 實例分割）。
%
%   所以本章的量化內容來自：
%     - 第 3 節：類別不平衡的「全部猜背景」基準（不需訓練）
%     - 第 5 節：指標比較（不需訓練）
%     - 第 6 節：SOLOv2 預訓練實例分割（不需訓練）
%
%   而**語意分割本身只有架構與訓練程式碼**。
%   換到記憶體更大的機器之後，README 的清單列出要驗證什麼。
%   ============================================================
%
%   **分割訓練與分類／偵測訓練的三個差異**
%
%   **① 標籤是一整張圖，不是一個數字或幾個框。**
%   所以資料量、記憶體與計算量都大得多：
%   每個像素都要算一次 loss。
%
%   **② 類別不平衡是常態，而且很極端。**
%   `triangleImages` 的前景只佔 **4.62%**；真實場景的
%   「瑕疵」「腫瘤」「裂縫」常常不到 1%。
%   不加權的 cross-entropy 會讓模型**直接全部預測背景**——
%   而第 3 節證明了那樣的模型 GlobalAccuracy 有 95.4%。
%   所以 `ClassWeights` 幾乎是必要的，預設用**逆頻率**加權。
%
%   **③ 評估指標要看逐類別的 IoU。**
%   任何按像素數加權的摘要（GlobalAccuracy、WeightedIoU）
%   在這種不平衡下都會騙人。
%
%   另見 UNET, DEEPLABV3PLUS, TRAINNET, CH20_TRIVIALBASELINE.

arguments
    dsTrain
    dsVal
    classNames (1,:) string {mustBeNonempty}
    options.DoTrain          (1,1) logical = false
    options.Architecture     (1,1) string {mustBeMember(options.Architecture, ...
        ["unet" "deeplabv3plus"])} = "unet"
    options.InputSize        (1,3) double {mustBePositive, mustBeInteger} = [64 64 3]
    options.Encoder          (1,1) string = "resnet18"
    options.ClassWeights           = "auto"
    options.MaxEpochs        (1,1) double {mustBePositive, mustBeInteger} = 20
    options.MiniBatchSize    (1,1) double {mustBePositive, mustBeInteger} = 8
    options.InitialLearnRate (1,1) double {mustBePositive} = 1e-3
    options.Plots            (1,1) string = "none"
end

nClasses = numel(classNames);

% --- ① 建立網路（未訓練的架構）-------------------------------------
switch options.Architecture
    case "unet"
        net = unet(options.InputSize, nClasses);
    case "deeplabv3plus"
        net = deeplabv3plus(options.InputSize, nClasses, options.Encoder);
end

% --- ② 類別權重 -----------------------------------------------------
% 不加權的話，模型會直接全部預測背景（第 3 節證明那樣的
% GlobalAccuracy 有 95.4%，但前景的 IoU 是 0）。
if isstring(options.ClassWeights) && options.ClassWeights == "auto"
    w = inverseFrequencyWeights(dsTrain, classNames);
else
    w = options.ClassWeights;
end
lossFcn = @(Y, T) crossentropy(Y, T, w, ...
    NormalizationFactor="all-elements", WeightsFormat="C");

% --- ③ 訓練設定 -----------------------------------------------------
opts = trainingOptions("adam", ...
    InitialLearnRate    = options.InitialLearnRate, ...
    MaxEpochs           = options.MaxEpochs, ...
    MiniBatchSize       = options.MiniBatchSize, ...
    ValidationData      = dsVal, ...
    ValidationFrequency = 20, ...
    ValidationPatience  = 5, ...
    OutputNetwork       = "best-validation", ...
    Shuffle             = "every-epoch", ...
    Verbose             = false, ...
    Plots               = options.Plots, ...
    ExecutionEnvironment= "auto");

info = struct( ...
    "Architecture",    options.Architecture, ...
    "InputSize",       options.InputSize, ...
    "NumClasses",      nClasses, ...
    "ClassNames",      classNames, ...
    "ClassWeights",    w, ...
    "TrainingOptions", opts, ...
    "Trained",         false, ...
    "SecTrain",        NaN, ...
    "VerifiedOnThisMachine", false);

if ~options.DoTrain
    fprintf("【未訓練】已組好 %s（%d 類，輸入 %s）。\n", ...
        options.Architecture, nClasses, mat2str(options.InputSize));
    fprintf("  類別權重（逆頻率）：%s\n", mat2str(round(w(:).', 3)));
    fprintf("  設定：學習率 %.0e、%d epochs、批次 %d\n", ...
        options.InitialLearnRate, options.MaxEpochs, options.MiniBatchSize);
    fprintf("  **本章刻意不執行訓練**——語意分割沒有預訓練權重，\n");
    fprintf("  而本機記憶體不足。換機器後請見 README 的驗證清單。\n");
    return
end

t = tic;
net = trainnet(dsTrain, net, lossFcn, opts);
info.SecTrain = toc(t);
info.Trained = true;
fprintf("訓練完成，耗時 %.1f 秒。\n", info.SecTrain);
end

% ========================================================================
function w = inverseFrequencyWeights(ds, classNames)
%INVERSEFREQUENCYWEIGHTS 以像素頻率的倒數當類別權重。
%
%   稀有類別權重大，讓它在 loss 裡佔得到份量。
%   這是分割最常用的預設做法，但**不是唯一的選擇**：
%   權重太大會讓模型過度預測前景（precision 崩潰），
%   所以它本身也是一個要調的超參數。
counts = zeros(numel(classNames), 1);
reset(ds);
nRead = 0;
while hasdata(ds) && nRead < 50      % 取樣 50 筆估計頻率就夠了
    data = read(ds);
    L = data{2};
    if iscell(L), L = L{1}; end
    for k = 1:numel(classNames)
        counts(k) = counts(k) + nnz(L == classNames(k));
    end
    nRead = nRead + 1;
end
reset(ds);

freq = counts / max(sum(counts), 1);
freq(freq == 0) = eps;
w = median(freq) ./ freq;            % 中位數頻率加權
w = w(:).';
end
