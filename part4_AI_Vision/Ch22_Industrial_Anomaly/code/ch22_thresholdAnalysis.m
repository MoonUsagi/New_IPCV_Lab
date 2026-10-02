function [tbl, info] = ch22_thresholdAnalysis(scoresGood, scoresBad, options)
%CH22_THRESHOLDANALYSIS 門檻決策：過殺率 vs 漏檢率。
%
%   [TBL, INFO] = CH22_THRESHOLDANALYSIS(SCORESGOOD, SCORESBAD) 掃描門檻，
%   回傳每個門檻的**過殺率**（良品被判成瑕疵）與**漏檢率**（瑕疵被放過）。
%
%   名稱-值引數：
%     NumPoints  - 掃描點數（預設 25）
%     MaxFPR     - 給 ANOMALYTHRESHOLD 的最大過殺率（預設 0.01）
%
%   INFO 含三個建議門檻：
%     ThresholdYouden - `anomalyThreshold` 的預設（Youden's index）
%     ThresholdMaxFPR - 限制過殺率不超過 MaxFPR
%     Separation      - (min(瑕疵) - max(良品)) / std(良品)
%
%   ============================================================
%   **產線上這兩種錯的代價完全不同，而它們不對稱。**
%
%   | 錯誤 | 產線上的後果 |
%   |---|---|
%   | **過殺**（良品判成瑕疵） | 多一道人工複檢；成本可算、可控 |
%   | **漏檢**（瑕疵放過去） | 流到客戶端；可能是召回、賠償、商譽 |
%
%   所以**幾乎沒有產線會用「平衡」的門檻**。
%   典型的做法是**先定一個可接受的漏檢率**（例如 0%），
%   再看那個條件下的過殺率能不能接受。
%
%   > 這和第 17 章 §11「刪框比畫框便宜」、
%   > 第 19 章 §6「分數門檻要看下游」是同一個原則：
%   > **門檻由成本決定，不是由 F1 決定。**
%   ============================================================
%
%   **`anomalyThreshold` 的引數順序很容易搞錯：**
%
%     t = anomalyThreshold(gtLabels, scores, anomalyLabels)
%
%   第三個引數 `anomalyLabels` 是「**哪些標籤值代表異常**」，
%   **不是每個樣本的標籤**。gtLabels 是 logical 時就傳 `true`。
%   傳錯會得到「Expected input number 3, anomalyLabels,
%   to be integer-valued」——訊息完全指不到真正的問題。
%
%   要限制過殺率用名稱-值：
%
%     t = anomalyThreshold(gt, scores, true, MaxFalsePositiveRate=0.01)
%
%   **實測（本章的合成資料）**：良品 1.17 ± 0.03、瑕疵 22.93 ± 0.96，
%   兩個分布完全分開，所以任何介於中間的門檻都是 0% 過殺 + 0% 漏檢。
%   **真實資料不會這麼好**——分布一定會重疊，那時候這張表才有意義。
%
%   另見 ANOMALYTHRESHOLD, EVALUATEANOMALYDETECTION, CH22_TRAINANOMALY.

arguments
    scoresGood (:,1) double {mustBeNonempty}
    scoresBad  (:,1) double
    options.NumPoints (1,1) double {mustBePositive, mustBeInteger} = 25
    options.MaxFPR    (1,1) double {mustBeInRange(options.MaxFPR,0,1)} = 0.01
end

allScores = [scoresGood; scoresBad];
gtLabels  = [false(numel(scoresGood),1); true(numel(scoresBad),1)];

lo = min(allScores); hi = max(allScores);
ths = linspace(lo, hi, options.NumPoints).';

overkill = zeros(size(ths));    % 過殺率：良品被判成瑕疵
escape   = zeros(size(ths));    % 漏檢率：瑕疵被放過
for k = 1:numel(ths)
    overkill(k) = mean(scoresGood >= ths(k));
    if isempty(scoresBad)
        escape(k) = NaN;
    else
        escape(k) = mean(scoresBad < ths(k));
    end
end

tbl = table(ths, 100*overkill, 100*escape, ...
    VariableNames=["門檻" "過殺率百分比" "漏檢率百分比"]);

info = struct();
info.Separation = NaN;
if ~isempty(scoresBad)
    info.Separation = (min(scoresBad) - max(scoresGood)) / max(std(scoresGood), eps);

    % **注意第三個引數是「哪些值代表異常」，不是每個樣本的標籤**
    info.ThresholdYouden = anomalyThreshold(gtLabels, allScores, true);
    info.ThresholdMaxFPR = anomalyThreshold(gtLabels, allScores, true, ...
        MaxFalsePositiveRate=options.MaxFPR);

    % 零漏檢所需的門檻
    info.ThresholdZeroEscape = min(scoresBad);
    info.OverkillAtZeroEscape = mean(scoresGood >= info.ThresholdZeroEscape);
end

info.GoodMean = mean(scoresGood);
info.GoodStd  = std(scoresGood);
info.GoodMax  = max(scoresGood);
if ~isempty(scoresBad)
    info.BadMean = mean(scoresBad);
    info.BadStd  = std(scoresBad);
    info.BadMin  = min(scoresBad);
end

if ~isempty(scoresBad)
    if info.Separation > 0
        fprintf("良品與瑕疵的分數**完全分開**（間隔 = %.1f 個良品標準差）。\n", ...
            info.Separation);
        fprintf("  任何介於 %.3f 與 %.3f 之間的門檻都是 0%% 過殺 + 0%% 漏檢。\n", ...
            info.GoodMax, info.BadMin);
        fprintf("  **真實資料不會這樣**——兩個分布一定會重疊。\n");
    else
        fprintf("兩個分布**有重疊**（間隔 %.2f 個標準差）。\n", info.Separation);
        fprintf("  零漏檢要把門檻設到 %.3f，代價是 %.1f%% 的過殺率。\n", ...
            info.ThresholdZeroEscape, 100*info.OverkillAtZeroEscape);
    end
end
end
