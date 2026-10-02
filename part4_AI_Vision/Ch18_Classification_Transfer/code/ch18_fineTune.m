function [net, info] = ch18_fineTune(backbone, dsTrain, dsVal, numClasses, options)
%CH18_FINETUNE 遷移學習策略二／三：微調預訓練網路。**預設不執行訓練。**
%
%   [NET, INFO] = CH18_FINETUNE(BACKBONE, DSTRAIN, DSVAL, NUMCLASSES)
%   組好網路與 TRAININGOPTIONS，但**預設只回傳設定、不呼叫 TRAINNET**。
%   要真的訓練必須明確傳 DoTrain=true。
%
%   名稱-值引數：
%     DoTrain        - **預設 false**。false 時回傳未訓練的網路與設定。
%     FreezeBackbone - true 只訓練分類頭（策略二），false 全網路微調（策略三）
%     MaxEpochs      - 預設 6
%     MiniBatchSize  - 預設 16（T550 只有 4.29 GB，再大會 OOM）
%     InitialLearnRate - 預設 1e-4（微調要用**很小**的學習率）
%     Plots          - 預設 "none"（"training-progress" 會開視窗）
%
%   **為什麼預設不訓練**
%
%   本章的教學目標是「看懂遷移學習的結構與每個設定的意義」，
%   而不是「跑出一個模型」。訓練需要幾分鐘到幾小時，
%   會讓教材無法自動驗證，也讓讀者卡在等待上。
%   策略一（CH18_TRANSFERSVM）幾秒鐘就有**真實的數字**可以討論，
%   所以本章的所有量化結論都來自策略一。
%
%   > **要真的訓練時，把 `DoTrain=true` 傳進來即可，
%   > 程式碼是完整的、可執行的。**
%
%   **三個最容易出錯的設定**
%
%   **① 學習率。** 微調的學習率要比從零訓練**小 10–100 倍**
%   （這裡預設 1e-4，從零訓練典型值是 1e-2）。
%   預訓練權重已經在一個好的位置，大學習率會把它們直接破壞掉——
%   症狀是**前幾個 iteration 的 loss 就爆掉**，
%   或者訓練得比從零開始還差。
%
%   **② 分類頭的學習率要更大。** 骨幹是預訓練好的，
%   新的分類頭是隨機初始化的。兩者用同一個學習率的話，
%   分類頭學得太慢。標準做法是給新層 10 倍的
%   `WeightLearnRateFactor`。
%
%   **③ `ValidationData` 一定要給。** 沒有驗證集就看不到過擬合，
%   而遷移學習在小資料上**非常容易**過擬合
%   （骨幹的容量遠大於你的資料量）。
%
%   **顯示記憶體的現實**：T550 只有 4.29 GB。`resnet18` +
%   `MiniBatchSize=16` + 224x224 大約剛好；改成 32 就可能 OOM。
%   OOM 的錯誤訊息會提到 CUDA out of memory——
%   **那時候要調的是批次大小，不是別的**。
%
%   另見 CH18_TRANSFERSVM, TRAINNET, TRAININGOPTIONS, IMAGEPRETRAINEDNETWORK.

arguments
    backbone   (1,1) string {mustBeNonzeroLengthText}
    dsTrain
    dsVal
    numClasses (1,1) double {mustBePositive, mustBeInteger}
    options.DoTrain          (1,1) logical = false
    options.FreezeBackbone   (1,1) logical = true
    options.MaxEpochs        (1,1) double {mustBePositive, mustBeInteger} = 6
    options.MiniBatchSize    (1,1) double {mustBePositive, mustBeInteger} = 16
    options.InitialLearnRate (1,1) double {mustBePositive} = 1e-4
    options.Plots            (1,1) string = "none"
end

% --- ① 載入骨幹並換掉分類頭 -----------------------------------------
% **注意：帶 NumClasses 時 imagePretrainedNetwork 只能有一個輸出引數。**
% 寫 [net, classes] = imagePretrainedNetwork(name, NumClasses=n) 會報
% 「For transfer learning workflows or when Weights is "none",
%  the function must have one output argument only」。
net = imagePretrainedNetwork(backbone, NumClasses=numClasses);

% --- ② 要不要凍結骨幹 -----------------------------------------------
% 策略二：凍結骨幹，只訓練新的分類頭。
% 做法是把所有可學習參數的學習率因子設成 0，
% 再把最後的全連接層設回 1（而且給它 10 倍）。
if options.FreezeBackbone
    net = freezeAllLearnables(net);
end
net = boostFinalLayer(net);

% --- ③ 訓練設定 ------------------------------------------------------
opts = trainingOptions("adam", ...
    InitialLearnRate   = options.InitialLearnRate, ...
    MaxEpochs          = options.MaxEpochs, ...
    MiniBatchSize      = options.MiniBatchSize, ...
    ValidationData     = dsVal, ...
    ValidationFrequency= 20, ...
    ValidationPatience = 3, ...        % 連 3 次沒進步就停（避免過擬合）
    Shuffle            = "every-epoch", ...
    Verbose            = false, ...
    Plots              = options.Plots, ...
    OutputNetwork      = "best-validation", ...
    ExecutionEnvironment = "auto");

info = struct( ...
    "Backbone",       backbone, ...
    "NumClasses",     numClasses, ...
    "Strategy",       ternary(options.FreezeBackbone, "策略二：凍結骨幹", ...
                              "策略三：全網路微調"), ...
    "TrainingOptions", opts, ...
    "Trained",        false, ...
    "SecTrain",       NaN);

% --- ④ 真正的訓練（預設不執行）--------------------------------------
if ~options.DoTrain
    fprintf("【未訓練】已組好 %s + %s。\n", backbone, info.Strategy);
    fprintf("  要真的訓練請傳 DoTrain=true。\n");
    fprintf("  設定摘要：學習率 %.0e、%d epochs、批次 %d、early stopping patience %d\n", ...
        options.InitialLearnRate, options.MaxEpochs, ...
        options.MiniBatchSize, opts.ValidationPatience);
    return
end

t = tic;
net = trainnet(dsTrain, net, "crossentropy", opts);
info.SecTrain = toc(t);
info.Trained = true;
fprintf("訓練完成，耗時 %.1f 秒。\n", info.SecTrain);
end

% ========================================================================
function net = freezeAllLearnables(net)
%FREEZEALLLEARNABLES 把所有層的學習率因子設成 0。
for k = 1:numel(net.Layers)
    L = net.Layers(k);
    if isprop(L, "WeightLearnRateFactor")
        L.WeightLearnRateFactor = 0;
    end
    if isprop(L, "BiasLearnRateFactor")
        L.BiasLearnRateFactor = 0;
    end
    if isprop(L, "ScaleLearnRateFactor")
        L.ScaleLearnRateFactor = 0;
    end
    if isprop(L, "OffsetLearnRateFactor")
        L.OffsetLearnRateFactor = 0;
    end
    net = replaceLayer(net, net.Layers(k).Name, L);
end
end

% ========================================================================
function net = boostFinalLayer(net)
%BOOSTFINALLAYER 給最後一個全連接層 10 倍學習率（新層學得比較慢）。
cls = arrayfun(@(L) string(class(L)), net.Layers);
idx = find(contains(cls, "FullyConnected"), 1, "last");
if isempty(idx)
    return
end
L = net.Layers(idx);
L.WeightLearnRateFactor = 10;
L.BiasLearnRateFactor   = 10;
net = replaceLayer(net, L.Name, L);
end

% ========================================================================
function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
