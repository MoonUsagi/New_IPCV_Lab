function [detector, info] = ch19_trainDetector(dsTrain, dsVal, classNames, options)
%CH19_TRAINDETECTOR 訓練一個 YOLOX 偵測器。**預設不執行訓練。**
%
%   [DETECTOR, INFO] = CH19_TRAINDETECTOR(DSTRAIN, DSVAL, CLASSNAMES)
%   組好偵測器與 TRAININGOPTIONS，但**預設只回傳設定、不呼叫
%   TRAINYOLOXOBJECTDETECTOR**。要真的訓練必須明確傳 DoTrain=true。
%
%   名稱-值引數：
%     DoTrain          - **預設 false**
%     ModelName        - "tiny-coco"（預設）或 "small-coco"
%     InputSize        - 網路輸入尺寸（預設 [320 320 3]）
%     MaxEpochs        - 預設 10
%     MiniBatchSize    - 預設 4（偵測比分類吃記憶體得多）
%     InitialLearnRate - 預設 5e-4
%     Plots            - 預設 "none"
%
%   ============================================================
%   **這個函式尚未在本機驗證過。**
%   本課程的開發機器是 NVIDIA T550（4.29 GB），跑不動偵測器訓練。
%   程式碼是照 R2026a 的 API 寫完整的，但**實際執行要在
%   記憶體更大的機器上驗證**。換機器後請見 README 的
%   「換機器後要驗證什麼」清單。
%   ============================================================
%
%   **偵測訓練與分類訓練的四個差異**
%
%   **① 資料格式不同。** 分類是 imds（影像 + 標籤），
%   偵測要 `combine(imds, blds)`——每次 read 回傳
%   `{影像, 框, 標籤}` 三格，而不是兩格。
%
%   **② 擴增要同時變換影像與框。** 這是第 17 章 §5
%   「標籤要跟著一起變」在偵測上的版本，而且更麻煩：
%   翻轉影像時框的 x 座標要鏡射、縮放時框要跟著縮放。
%   寫錯一樣**不會報錯**，只會讓模型學不起來。
%   `bboxresize`／`bboxwarp` 是為此存在的。
%
%   **③ 批次大小要小得多。** 偵測器的輸入通常是 320–640，
%   而且要保留多尺度的特徵圖。分類能用 32 的地方，偵測可能只能用 4。
%
%   **④ 錨框／輸入尺寸要配合目標大小。**
%   `vehicles` 的車大約 20–40 像素寬，而輸入若縮放到 320x320，
%   那些車會變得更小。目標小於幾個像素時任何偵測器都學不起來。
%   **訓練前先量目標尺寸的分布**（第 16 章練習 2 的教訓）。
%
%   另見 TRAINYOLOXOBJECTDETECTOR, YOLOXOBJECTDETECTOR, CH19_RUNDETECTOR.

arguments
    dsTrain
    dsVal
    classNames (1,:) string {mustBeNonempty}
    options.DoTrain          (1,1) logical = false
    options.ModelName        (1,1) string {mustBeMember(options.ModelName, ...
        ["tiny-coco" "small-coco"])} = "tiny-coco"
    options.InputSize        (1,3) double {mustBePositive, mustBeInteger} = [320 320 3]
    options.MaxEpochs        (1,1) double {mustBePositive, mustBeInteger} = 10
    options.MiniBatchSize    (1,1) double {mustBePositive, mustBeInteger} = 4
    options.InitialLearnRate (1,1) double {mustBePositive} = 5e-4
    options.Plots            (1,1) string = "none"
end

% --- 建立未訓練（但帶預訓練骨幹）的偵測器 ---------------------------
detector = yoloxObjectDetector(options.ModelName, classNames, ...
    InputSize=options.InputSize);

% --- 訓練設定 --------------------------------------------------------
opts = trainingOptions("adam", ...
    InitialLearnRate    = options.InitialLearnRate, ...
    MaxEpochs           = options.MaxEpochs, ...
    MiniBatchSize       = options.MiniBatchSize, ...
    ValidationData      = dsVal, ...
    ValidationFrequency = 50, ...
    ResetInputNormalization = false, ...
    Shuffle             = "every-epoch", ...
    VerboseFrequency    = 20, ...
    Plots               = options.Plots, ...
    ExecutionEnvironment= "auto");

info = struct( ...
    "ModelName",       options.ModelName, ...
    "ClassNames",      classNames, ...
    "InputSize",       options.InputSize, ...
    "TrainingOptions", opts, ...
    "Trained",         false, ...
    "SecTrain",        NaN, ...
    "VerifiedOnThisMachine", false);

if ~options.DoTrain
    fprintf("【未訓練】已組好 YOLOX（%s，%d 類，輸入 %s）。\n", ...
        options.ModelName, numel(classNames), mat2str(options.InputSize));
    fprintf("  要真的訓練請傳 DoTrain=true。\n");
    fprintf("  設定：學習率 %.0e、%d epochs、批次 %d\n", ...
        options.InitialLearnRate, options.MaxEpochs, options.MiniBatchSize);
    fprintf("  **本機（T550 4.29 GB）跑不動，這段程式碼尚未實測。**\n");
    return
end

t = tic;
detector = trainYOLOXObjectDetector(dsTrain, detector, opts);
info.SecTrain = toc(t);
info.Trained = true;
fprintf("訓練完成，耗時 %.1f 秒。\n", info.SecTrain);
end
