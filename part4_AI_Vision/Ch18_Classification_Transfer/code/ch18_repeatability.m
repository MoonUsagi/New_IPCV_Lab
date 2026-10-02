function [tbl, info] = ch18_repeatability(net, dsTrain, dsTest, layer, options)
%CH18_REPEATABILITY 量「同一段程式碼跑幾次」與「換幾個切分」的變異。
%
%   [TBL, INFO] = CH18_REPEATABILITY(NET, DSTRAIN, DSTEST, LAYER) 在
%   **完全相同**的資料上重複執行特徵抽取與分類，回傳每次的準確率。
%
%   名稱-值引數：
%     NumRepeats - 重複次數（預設 5）
%     Verbose    - 印出每次的結果（預設 true）
%
%   INFO 含 Mean、Std、Range，以及對應的二項理論標準誤 TheorySE。
%
%   **為什麼要量這個**
%
%   「跑一次得到 0.905，另一個模型跑一次得到 0.890，所以第一個比較好」
%   ——這個推論**需要知道重跑同一件事會差多少**。
%   若重跑的變異就有 5 個百分點，那 1.5 個百分點的差距毫無意義。
%
%   實測（resnet18 `pool5`、DigitDataset、n=200 測試、**切分固定**）：
%
%     執行 A:  0.8100  0.8550  0.8450  0.8300  0.8600   std 0.0203  全距 0.0500
%     執行 B:  0.8300  0.8500  0.8450  0.8350  0.8400   std 0.0079  全距 0.0200
%
%   **切分完全一樣、程式碼完全一樣，準確率卻會在 2–5 個百分點的
%   範圍內跳動——而且連「跳多少」本身都不穩定。**
%
%   為什麼？兩個來源疊在一起：
%
%   **① GPU 推論不是逐位元決定性的。** cuDNN 會依當下的狀況挑
%   不同的卷積演算法，而浮點加法**不符合結合律**，
%   所以累加順序不同就會得到略微不同的特徵
%   （§5.1 量到的 1.4e-06）。
%
%   **② 分類器把微小的差異放大成離散的翻面。**
%   落在決策邊界附近的樣本，特徵差 1e-06 就可能換邊。
%   200 張測試影像裡，一張就是 0.5 個百分點。
%
%   對照「換切分」的變異（同樣 5 次，不同 rng 種子）：
%
%     0.8750  0.8900  0.8400  0.8750  0.8050
%     平均 0.8570、標準差 0.0344、全距 0.0850
%
%   而二項分布的理論標準誤（p=0.86、n=200）是 **0.0248**。
%
%   | 變異來源 | 標準差 |
%   |---|---|
%   | 同一切分重跑（GPU 非決定性） | 0.0203 |
%   | 換切分（抽樣 + 訓練集變動） | 0.0344 |
%   | 二項理論下限 | 0.0248 |
%
%   > **結論：在這個設定下，小於約 5 個百分點的差異不可解釋。**
%   > 不是「不顯著」——是**連重跑同一件事都會差這麼多**。
%
%   **這也是為什麼本章不把準確率的具體數字寫死在敘述裡。**
%   你在自己的機器上重跑會得到不同的digits；
%   要看的是**效應量的等級**（20 個百分點 vs 2 個百分點），
%   不是小數第三位。
%
%   另見 CH18_TRANSFERSVM, CH18_BACKBONESWEEP.

arguments
    net
    dsTrain
    dsTest
    layer (1,1) string {mustBeNonzeroLengthText}
    options.NumRepeats (1,1) double {mustBePositive, mustBeInteger} = 5
    options.Verbose    (1,1) logical = true
end

n = options.NumRepeats;
acc = zeros(n,1);

ws = warning("off", "ch18_transferSVM:weakClass");
for k = 1:n
    [~, r] = ch18_transferSVM(net, dsTrain, dsTest, layer);
    acc(k) = r.Accuracy;
    if options.Verbose
        fprintf("  第 %d 次：%.4f\n", k, acc(k));
    end
end
warning(ws);

nTest = numel(dsTest.Labels);
pBar = mean(acc);
theorySE = sqrt(pBar*(1-pBar)/nTest);

tbl = table((1:n).', acc, VariableNames=["次數" "準確率"]);

info = struct( ...
    "Mean",     pBar, ...
    "Std",      std(acc), ...
    "Range",    max(acc) - min(acc), ...
    "NumTest",  nTest, ...
    "TheorySE", theorySE, ...
    "MinResolvable", 1.96*sqrt(2)*max(std(acc), theorySE));

if options.Verbose
    fprintf("平均 %.4f、標準差 %.4f、**全距 %.4f**\n", ...
        info.Mean, info.Std, info.Range);
    fprintf("二項理論標準誤（n=%d）= %.4f\n", nTest, theorySE);
    fprintf("**要宣稱兩個做法有差別，差距至少要大於約 %.1f 個百分點。**\n", ...
        100*info.MinResolvable);
end

if info.Range > 0.02
    warning("ch18_repeatability:unstable", ...
        "同一份資料重跑 %d 次，準確率的全距是 %.1f 個百分點。" + ...
        "**這個設定下小於這個幅度的差異不可解釋**——" + ...
        "要比較模型必須先擴大測試集或改用重複多次的平均。", ...
        n, 100*info.Range);
end
end
