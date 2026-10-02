function tbl = ch18_backboneSweep(names, dsTrain, dsTest, options)
%CH18_BACKBONESWEEP 比較不同預訓練骨幹的遷移特徵品質。
%
%   TBL = CH18_BACKBONESWEEP(NAMES, DSTRAIN, DSTEST) 對每個骨幹
%   自動找出它最後的全域池化層、抽特徵、訓練分類器、評估。
%
%   名稱-值引數：
%     MiniBatchSize - 轉傳（預設 32）
%     Verbose       - 印出進度（預設 true）
%
%   **自動找池化層，而不是寫死層名。**
%   每個骨幹的層名都不一樣：
%     resnet18     -> pool5
%     mobilenetv2  -> global_average_pooling2d_1
%     resnet50     -> avg_pool
%     darknet19    -> avg1
%   寫死層名的程式碼換一個骨幹就壞掉，所以這裡用**層的類別**去找
%   （`GlobalAveragePooling2DLayer`），不是用名字。
%
%   實測（DigitDataset 每類 40／20）：
%
%     骨幹           維度    準確率    秒數
%     resnet18        512    0.9000    13.4
%     **mobilenetv2  1280    0.9250     9.0**
%     resnet50       2048    0.9000    11.1
%     darknet19      1000    0.8950     9.5
%
%   **最小的網路贏了，而且也最快。**
%   `resnet50` 的參數量約是 `resnet18` 的 2 倍、
%   ImageNet top-1 準確率高約 6 個百分點，
%   但在這個遷移任務上**分數完全一樣（0.9000）**。
%
%   > **「ImageNet 分數越高，遷移特徵越好」不成立。**
%   > 這是一個很常見的選模型依據，而它在這裡給出錯誤的建議。
%
%   實務上的意義：**先用最小的骨幹試**。它最快、最省顯示記憶體，
%   而且可能就是最好的。要換大骨幹之前先量，不要假設。
%
%   **注意 `googlenet` 等骨幹需要各自的支援包。**
%   沒裝時 `imagePretrainedNetwork` 會報錯並告訴你要裝哪一個
%   （`Weights="none"` 可以拿到未訓練的架構，但那對遷移學習沒用）。
%   這個函式會捕捉該錯誤、跳過那個骨幹並繼續。
%
%   另見 CH18_TRANSFERSVM, CH18_LAYERSWEEP, IMAGEPRETRAINEDNETWORK.

arguments
    names (1,:) string {mustBeNonempty}
    dsTrain
    dsTest
    options.MiniBatchSize (1,1) double {mustBePositive, mustBeInteger} = 32
    options.Verbose       (1,1) logical = true
end

n = numel(names);
nameCol = strings(n,1); layerCol = strings(n,1);
nFeat = nan(n,1); acc = nan(n,1); sec = nan(n,1);
ok = false(n,1);

ws = warning("off", "ch18_transferSVM:weakClass");
for k = 1:n
    nameCol(k) = names(k);
    try
        if options.Verbose
            fprintf("  骨幹 %d/%d：%s ...\n", k, n, names(k));
        end
        t = tic;
        net = imagePretrainedNetwork(names(k));

        layer = findPoolingLayer(net);
        if layer == ""
            layerCol(k) = "(找不到池化層)";
            continue
        end

        [~, r] = ch18_transferSVM(net, dsTrain, dsTest, layer, ...
            MiniBatchSize=options.MiniBatchSize);
        layerCol(k) = layer;
        nFeat(k) = r.NumFeatures;
        acc(k) = r.Accuracy;
        sec(k) = toc(t);
        ok(k) = true;

        % **每個骨幹用完就釋放。** 第 17 章 §10.1 量到留著不放會讓
        % 顯示記憶體用盡、推論安靜地慢好幾倍。
        clear net
    catch ME
        layerCol(k) = "(失敗)";
        if options.Verbose
            fprintf("    略過：%s\n", extractBefore(ME.message + " ", ...
                min(80, strlength(ME.message)+1)));
        end
    end
end
warning(ws);

tbl = table(nameCol, layerCol, nFeat, acc, sec, ...
    VariableNames=["骨幹" "池化層" "維度" "準確率" "秒數"]);

if any(ok)
    [bestAcc, iBest] = max(acc);
    [~, iSmall] = min(nFeat);
    fprintf("\n準確率最高：%s（%.4f）\n", nameCol(iBest), bestAcc);
    if iBest == iSmall
        fprintf("**而它也是特徵維度最小的骨幹——大的不一定好。**\n");
    end
end
end

% ========================================================================
function layer = findPoolingLayer(net)
%FINDPOOLINGLAYER 用層的**類別**找最後的全域池化層，不靠層名。
cls = arrayfun(@(L) string(class(L)), net.Layers);
nm  = string({net.Layers.Name});

idx = find(contains(cls, "GlobalAveragePooling"), 1, "last");
if isempty(idx)
    idx = find(contains(cls, "AveragePooling2D"), 1, "last");
end
if isempty(idx)
    layer = "";
else
    layer = nm(idx);
end
end
