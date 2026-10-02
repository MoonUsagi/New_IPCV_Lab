function [mdl, report] = ch18_transferSVM(net, dsTrain, dsTest, layer, options)
%CH18_TRANSFERSVM 遷移學習策略一：抽特徵 + 訓練一個線性分類器。
%
%   [MDL, REPORT] = CH18_TRANSFERSVM(NET, DSTRAIN, DSTEST, LAYER)
%   從預訓練網路抽特徵，用 FITCECOC 訓練多類分類器，並在測試集評估。
%
%   REPORT 含 Accuracy、ConfusionMatrix、PerClassRecall、
%   SecExtract、SecFit、NumFeatures。
%
%   名稱-值引數：
%     MiniBatchSize - 轉傳給 CH18_EXTRACTFEATURES（預設 32）
%     Learner       - fitcecoc 的基學習器（預設 "linear"）
%
%   **這個函式完全不做深度學習訓練，但它是真正的遷移學習。**
%
%   三種遷移學習策略的分工：
%
%     策略一  特徵抽取 + 淺層分類器   骨幹**凍結**，只訓練分類器
%     策略二  微調分類頭             換掉最後一層，用梯度訓練它
%     策略三  全網路微調             所有權重都更新
%
%   策略一的價值常被低估：
%     - **不需要 GPU**（推論可以在 CPU 上跑）
%     - 訓練是**凸最佳化**，沒有學習率、沒有 epoch、不會發散
%     - 幾秒鐘就有結果，適合先確認「這個任務有沒有搞頭」
%     - 樣本很少時（每類幾十張）它常常**贏過**微調
%
%   實測（DigitDataset 每類 40 訓練／20 測試、resnet18 `pool5`）：
%
%     準確率 **0.9000**，抽特徵 3.3 秒、擬合不到 1 秒。
%
%   **90% 聽起來不錯，但要放在脈絡裡看**：一個為 MNIST 設計的
%   小型 CNN 從零訓練就能到 99% 以上。ImageNet 的特徵
%   在 28x28 的手寫數字上只能到 90%——
%   **因為這兩個領域差得很遠**（自然彩色照片 vs 二值筆劃）。
%
%   > **遷移學習不是魔法，它的效果取決於領域距離。**
%   > 這個結論不能從「ImageNet 網路很強」推出來，只能量。
%
%   另見 CH18_EXTRACTFEATURES, CH18_LAYERSWEEP, FITCECOC.

arguments
    net
    dsTrain
    dsTest
    layer (1,1) string {mustBeNonzeroLengthText}
    options.MiniBatchSize (1,1) double {mustBePositive, mustBeInteger} = 32
    options.Learner       (1,1) string = "linear"
end

t = tic;
Ftr = ch18_extractFeatures(net, dsTrain, layer, ...
    MiniBatchSize=options.MiniBatchSize);
Fte = ch18_extractFeatures(net, dsTest, layer, ...
    MiniBatchSize=options.MiniBatchSize);
secExtract = toc(t);

ytr = dsTrain.Labels;
yte = dsTest.Labels;

t = tic;
mdl = fitcecoc(Ftr, ytr, Learners=options.Learner);
secFit = toc(t);

pred = predict(mdl, Fte);
acc = mean(pred == yte);

C = confusionmat(yte, pred);
perClass = diag(C) ./ sum(C, 2);

report = struct( ...
    "Layer",           layer, ...
    "NumFeatures",     size(Ftr, 2), ...
    "NumTrain",        numel(ytr), ...
    "NumTest",         numel(yte), ...
    "Accuracy",        acc, ...
    "ConfusionMatrix", C, ...
    "ClassNames",      string(categories(yte)).', ...
    "PerClassRecall",  perClass.', ...
    "SecExtract",      secExtract, ...
    "SecFit",          secFit);

% 逐類別 recall 的離散程度比整體準確率更能看出問題（第 17 章 §3 的主題）
worst = min(perClass);
if worst < acc - 0.15
    [~, iw] = min(perClass);
    cats = string(categories(yte));
    warning("ch18_transferSVM:weakClass", ...
        "整體準確率 %.4f，但類別「%s」的 recall 只有 %.4f。" + ...
        "**整體準確率把這件事藏起來了**——" + ...
        "請看混淆矩陣，不要只看一個數字。", ...
        acc, cats(iw), worst);
end
end
