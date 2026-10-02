function [metrics, info] = ch20_trivialBaseline(pxdsGT, classNames, labelIDs, options)
%CH20_TRIVIALBASELINE 做一個「全部猜多數類」的模型，並用標準指標評估它。
%
%   [METRICS, INFO] = CH20_TRIVIALBASELINE(PXDSGT, CLASSNAMES, LABELIDS)
%   產生一組「每個像素都預測成多數類別」的預測圖，寫到暫存資料夾，
%   再用 EVALUATESEMANTICSEGMENTATION 評估。
%
%   名稱-值引數：
%     MajorityClass - 要猜的類別（預設自動取像素數最多的）
%     OutputDir     - 預測圖的輸出位置（預設 tempdir 下的暫存資料夾）
%
%   **這個函式的唯一目的，是讓你看到指標可以有多騙人。**
%
%   實測（`triangleImages` 的 100 張測試標籤，triangle 只佔 4.62%）：
%
%     GlobalAccuracy   **0.9538**
%     WeightedIoU      **0.9098**
%     MeanBFScore      **0.8970**
%     MeanIoU            0.4769
%     MeanAccuracy       0.5000
%
%     逐類別：
%       triangle     Accuracy 0      IoU 0        BFScore NaN
%       background   Accuracy 1      IoU 0.9538   BFScore 0.8970
%
%   **這個模型什麼都沒偵測到——triangle 的 IoU 是 0——
%   但它的 GlobalAccuracy 是 95.4%、WeightedIoU 是 0.91、
%   MeanBFScore 是 0.90。**
%
%   三個指標的行為差很多：
%
%   | 指標 | 值 | 有沒有揭露問題 |
%   |---|---|---|
%   | GlobalAccuracy | 0.9538 | **完全沒有** |
%   | WeightedIoU | 0.9098 | **完全沒有**（它就是按像素數加權的） |
%   | MeanBFScore | 0.8970 | **完全沒有** |
%   | MeanAccuracy | 0.5000 | 有（剛好是 1/類別數） |
%   | **MeanIoU** | **0.4769** | **有，但看起來像「中等」而不是「沒用」** |
%   | **逐類別 IoU** | **triangle = 0** | **只有這個講了實話** |
%
%   > **報告分割效能時，一定要給逐類別的 IoU。**
%   > 任何被像素數加權的摘要指標，在類別不平衡時都會被多數類支配。
%
%   這是第 17 章 §3（分類的不平衡）與第 18 章 §7（混淆矩陣）
%   在分割上的版本，而且**更嚴重**——分割的「背景」通常佔九成以上，
%   所以一個沒用的模型看起來會非常好。
%
%   注意 `triangle` 的 BFScore 是 **NaN**（沒有預測出任何邊界），
%   而 `MeanBFScore` 仍然算得出 0.8970——它跳過了 NaN。
%   **NaN 被靜默忽略是另一個容易漏看的陷阱。**
%
%   另見 EVALUATESEMANTICSEGMENTATION, CH20_METRICCOMPARISON.

arguments
    pxdsGT
    classNames (1,:) string {mustBeNonempty}
    labelIDs   (1,:) double {mustBeNonempty}
    options.MajorityClass (1,1) string = ""
    options.OutputDir     (1,1) string = ""
end

cnt = countEachLabel(pxdsGT);
if options.MajorityClass == ""
    [~, iMaj] = max(cnt.PixelCount);
    majName = string(cnt.Name(iMaj));
else
    majName = options.MajorityClass;
    iMaj = find(string(cnt.Name) == majName, 1);
    if isempty(iMaj)
        error("ch20_trivialBaseline:noSuchClass", ...
            "類別「%s」不在標籤裡。可用的是：%s", ...
            majName, strjoin(string(cnt.Name)', ", "));
    end
end
majID = labelIDs(classNames == majName);

if options.OutputDir == ""
    outDir = fullfile(tempdir, "ch20_trivial_" + string(feature("getpid")));
else
    outDir = options.OutputDir;
end
if isfolder(outDir)
    rmdir(outDir, "s");
end
mkdir(outDir);

% 把每一張標籤圖換成「全部是多數類」的預測圖
files = pxdsGT.Files;
for k = 1:numel(files)
    L = imread(files{k});
    [~, nm, ext] = fileparts(files{k});
    imwrite(repmat(uint8(majID), size(L,1), size(L,2)), ...
        fullfile(outDir, nm + string(ext)));
end

pxdsPred = pixelLabelDatastore(outDir, classNames, labelIDs);
metrics = evaluateSemanticSegmentation(pxdsPred, pxdsGT, Verbose=false);

pctMaj = 100 * cnt.PixelCount(iMaj) / sum(cnt.PixelCount);
info = struct( ...
    "MajorityClass",   majName, ...
    "MajorityPercent", pctMaj, ...
    "OutputDir",       outDir, ...
    "ClassCounts",     cnt);

fprintf("「全部猜 %s」的基準（%s 佔 %.2f%% 的像素）：\n", ...
    majName, majName, pctMaj);
fprintf("  GlobalAccuracy %.4f、WeightedIoU %.4f、MeanBFScore %.4f\n", ...
    metrics.DataSetMetrics.GlobalAccuracy, ...
    metrics.DataSetMetrics.WeightedIoU, ...
    metrics.DataSetMetrics.MeanBFScore);
fprintf("  MeanIoU %.4f\n", metrics.DataSetMetrics.MeanIoU);

minIoU = min(metrics.ClassMetrics.IoU);
if minIoU < 0.05 && metrics.DataSetMetrics.GlobalAccuracy > 0.8
    warning("ch20_trivialBaseline:misleadingMetrics", ...
        "有類別的 IoU 是 %.4f（形同完全沒偵測到），" + ...
        "但 GlobalAccuracy 仍有 %.4f。" + ...
        "**任何按像素數加權的摘要指標在類別不平衡時都會騙人**——" + ...
        "報告分割效能一定要附逐類別的 IoU。", ...
        minIoU, metrics.DataSetMetrics.GlobalAccuracy);
end
end
