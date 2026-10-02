function [tbl, info] = ch17_labelStats(ds, options)
%CH17_LABELSTATS 檢查資料集的類別分布，並在不平衡時發出警告。
%
%   [TBL, INFO] = CH17_LABELSTATS(DS) 對一個 imageDatastore（或任何有
%   countEachLabel 方法的 datastore）統計每個類別的樣本數，回傳
%   countEachLabel 的結果加上一欄百分比，以及 INFO struct：
%
%     ImbalanceRatio - 最多的類別 ÷ 最少的類別
%     MinCount       - 最少類別的樣本數
%     Suggested      - 若要平衡取樣，每類要取幾張
%
%   名稱-值引數：
%     MaxRatio - 可接受的不平衡比（預設 1.5）。超過就警告。
%
%   **為什麼這一步不能跳過**
%
%   類別不平衡會讓準確率變成一個沒有意義的數字。
%   若 90% 的樣本屬於同一類，一個永遠回答那一類的模型
%   就有 90% 準確率——**它什麼都沒學到，但分數很好看**。
%
%   第 16 章已經看過同一件事的另一個版本：
%   patch 準確率 1.0000 但偵測器 precision 0.8%。
%   共同點是**選了一個對任務不敏感的指標**。
%
%   實測（nndemos 的 DigitDataset，10 類手寫數字）：
%
%     每類 1000 張，不平衡比 1.00——這是刻意做成平衡的教學資料集。
%     真實資料幾乎不會這樣。
%
%   **countEachLabel 是 datastore 的方法，不是自由函式。**
%   `exist("countEachLabel")` 回傳 0，但 `ds.countEachLabel` 可以用，
%   `which` 也找得到它——因為它住在 datastore 類別裡。
%   這一章的 `transform`、`splitEachLabel`、`subset`、`shuffle`
%   全都是同一種情況。
%
%   另見 COUNTEACHLABEL, SPLITEACHLABEL, IMAGEDATASTORE.

arguments
    ds
    options.MaxRatio (1,1) double {mustBeGreaterThanOrEqual(options.MaxRatio,1)} = 1.5
end

if ~ismethod(ds, "countEachLabel")
    error("ch17_labelStats:noLabels", ...
        "這個 datastore 沒有 countEachLabel 方法。" + ...
        "建立 imageDatastore 時要加 LabelSource=""foldernames""，" + ...
        "否則它不知道標籤在哪裡。");
end

tbl = countEachLabel(ds);
counts = double(tbl.Count);
total = sum(counts);
tbl.Percent = 100 * counts / total;

info = struct( ...
    "NumClasses",     height(tbl), ...
    "Total",          total, ...
    "MinCount",       min(counts), ...
    "MaxCount",       max(counts), ...
    "ImbalanceRatio", max(counts) / min(counts), ...
    "Suggested",      min(counts));

if info.ImbalanceRatio > options.MaxRatio
    [~, iMax] = max(counts);
    [~, iMin] = min(counts);
    warning("ch17_labelStats:imbalanced", ...
        "類別不平衡比 %.2f 超過門檻 %.2f（最多「%s」%d 張、" + ...
        "最少「%s」%d 張）。**這時候準確率會騙人**——" + ...
        "一個永遠回答多數類的模型就有 %.1f%% 準確率。" + ...
        "請改看每類別的 recall 或混淆矩陣，" + ...
        "或用 splitEachLabel(ds, %d, ""randomized"") 做平衡取樣。", ...
        info.ImbalanceRatio, options.MaxRatio, ...
        string(tbl.Label(iMax)), counts(iMax), ...
        string(tbl.Label(iMin)), counts(iMin), ...
        100*max(counts)/total, info.Suggested);
end
end
