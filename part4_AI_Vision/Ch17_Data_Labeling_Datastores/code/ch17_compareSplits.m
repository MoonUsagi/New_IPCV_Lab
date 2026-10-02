function [tbl, splits] = ch17_compareSplits(S, groupId, options)
%CH17_COMPARESPLITS 比較三種資料切分策略的「跨集合近重複」比例。
%
%   [TBL, SPLITS] = CH17_COMPARESPLITS(S, GROUPID) 用 CH17_DUPGROUPS 算出的
%   相似度矩陣 S 與群組編號 GROUPID，比較三種切分：
%
%     "隨機切分"     - randperm 之後照比例切（最常見的做法）
%     "區塊切分"     - 照索引順序前段訓練、後段測試
%     "群組感知切分" - 先把近重複的影像歸群，再**以群為單位**切
%
%   回傳 TBL（每種策略的訓練／測試張數與跨集合近重複比例）與
%   SPLITS（struct，含每種策略的 Train／Test 索引）。
%
%   名稱-值引數：
%     TrainFraction - 訓練集比例（預設 0.7）
%     Threshold     - 判定近重複的門檻（預設 0.99）
%     Seed          - 隨機種子（預設 0）
%
%   **這個函式回答一個只能用量測回答的問題**：
%   「我的切分有沒有洩漏？」
%
%   實測（vehicles 295 張、門檻 0.99、7:3）：
%
%     策略            訓練  測試   跨集合近重複
%     隨機切分         207    88        27%
%     區塊切分         207    88        41%
%     **群組感知切分   199    96         0%**
%
%   三件事值得注意：
%
%   **① 區塊切分比隨機切分更糟。** 「照時間順序切」是時序資料的標準
%   建議，但它的前提是重複只發生在相鄰樣本。這個資料集的重複是
%   成對出現在兩個相距很遠的位置（第 37/38 與第 283/284 張），
%   照順序切剛好把每一對拆開。**建議的前提不成立時，建議就是錯的。**
%
%   **② 群組感知切分的張數不是剛好 7:3**（199/96 而不是 207/88）。
%   因為切的單位是「群」而不是「張」，群的大小不一，
%   比例只能近似。**這是正確的代價，不是 bug。**
%
%   **③ 0% 不是運氣。** 群組感知切分在建構上就保證了 0%——
%   同一群的影像一定在同一邊。它不需要靠隨機種子好運。
%
%   另見 CH17_DUPGROUPS, SPLITEACHLABEL.

arguments
    S       double
    groupId (:,1) double {mustBePositive, mustBeInteger}
    options.TrainFraction (1,1) double {mustBeInRange(options.TrainFraction,0,1)} = 0.7
    options.Threshold     (1,1) double {mustBeInRange(options.Threshold,-1,1)} = 0.99
    options.Seed          (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

n = numel(groupId);
if size(S,1) ~= n
    error("ch17_compareSplits:sizeMismatch", ...
        "S 是 %dx%d，groupId 有 %d 個元素——兩者必須對應同一批影像。", ...
        size(S,1), size(S,2), n);
end

rng(options.Seed);
f = options.TrainFraction;

% --- ① 隨機切分 -------------------------------------------------------
p = randperm(n);
nTr = round(f*n);
splits.random = struct("Train", p(1:nTr), "Test", p(nTr+1:end));

% --- ② 區塊切分 -------------------------------------------------------
splits.block = struct("Train", 1:nTr, "Test", (nTr+1):n);

% --- ③ 群組感知切分 ---------------------------------------------------
ug = unique(groupId);
pg = ug(randperm(numel(ug)));
nTrG = round(f*numel(pg));
trGroups = pg(1:nTrG);
isTrain = ismember(groupId, trGroups);
splits.grouped = struct("Train", find(isTrain).', "Test", find(~isTrain).');

names = ["隨機切分" "區塊切分" "群組感知切分"];
keys  = ["random" "block" "grouped"];
nTrain = zeros(3,1); nTest = zeros(3,1); leakPct = zeros(3,1);

for k = 1:3
    sp = splits.(keys(k));
    nTrain(k) = numel(sp.Train);
    nTest(k)  = numel(sp.Test);
    % 每張測試影像在訓練集裡的最大相似度
    maxSim = max(S(sp.Test, sp.Train), [], 2);
    leakPct(k) = 100 * mean(maxSim > options.Threshold);
end

tbl = table(names.', nTrain, nTest, leakPct, ...
    VariableNames=["策略" "訓練張數" "測試張數" "跨集合近重複百分比"]);

[~, worst] = max(leakPct);
if leakPct(worst) > 0
    fprintf("最糟的策略是「%s」：%.0f%% 的測試影像在訓練集裡有近重複。\n", ...
        names(worst), leakPct(worst));
end
end
