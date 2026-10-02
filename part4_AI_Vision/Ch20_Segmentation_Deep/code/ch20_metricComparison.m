function [tbl, info] = ch20_metricComparison(gtMask, options)
%CH20_METRICCOMPARISON 用「已知型態的錯誤」比較 IoU／Dice／BFscore。
%
%   [TBL, INFO] = CH20_METRICCOMPARISON(GTMASK) 從一個正確的遮罩出發，
%   製造五種**不同型態**的錯誤，再用三個指標各自評分。
%
%   五種錯誤：膨脹、侵蝕、平移、邊界雜訊、缺一角。
%
%   **為什麼要用人造的錯誤**
%
%   拿兩個真實模型來比，你只會知道「A 比 B 好」，
%   但不知道**指標在什麼情況下會意見不合**。
%   自己製造已知型態的錯誤，就能回答「這個指標對哪一種錯特別敏感」。
%
%   實測（`triangleImages` 的三角形放大到 256x256）：
%
%     變體          Jaccard     Dice   BFscore
%     邊界雜訊       0.8851   0.9390    1.0000
%     膨脹 3px       0.7706   0.8705    0.9500
%     侵蝕 3px       0.7262   0.8414    0.9454
%     缺一角         0.6071   0.7556    0.6815
%     **平移 5px**   0.5152   0.6801   **0.1802**
%
%   **三個指標的排序完全一致。**
%
%   我原本預期它們會給出相反的排序（第 17 章加分題量到過一次：
%   Jaccard 0.4297／0.5169 對上 BFscore 0.7785／0.7193，排序相反）。
%   **這裡沒有重現那件事——誠實記錄下來。**
%
%   **但「排序一致」不代表「三個指標可以互換」。**
%   看數值的落差：
%
%     平移 5px：Jaccard **0.5152**、BFscore **0.1802**
%       -> 面積指標說「對了一半」，邊界指標說「幾乎全錯」
%     缺一角：  Jaccard **0.6071**、BFscore **0.6815**
%       -> 這次換成邊界指標比較寬鬆
%
%   **哪一個比較嚴格，取決於錯誤的型態**：
%   平移會讓每一段邊界都跑掉（BFscore 崩潰），
%   但大部分面積還是重疊的（Jaccard 還有一半）。
%   缺一角剛好相反：少掉的那塊面積很大，
%   但**剩下的邊界仍然精準地貼合**。
%
%   > **所以指標要照任務選：**
%   > - 量「東西在不在、有多大」-> IoU／Dice
%   > - 量「輪廓準不準」（切割路徑、量測邊長）-> BFscore
%   > - **兩個都報，因為它們對不同的錯敏感**
%
%   Dice 永遠大於等於 Jaccard（$D = 2J/(1+J)$），
%   所以**它們永遠不會互相矛盾**——報兩個等於只報了一個。
%   真正互補的是「面積類」與「邊界類」。
%
%   另見 JACCARD, DICE, BFSCORE, CH20_TRIVIALBASELINE.

arguments
    gtMask (:,:) logical {mustBeNonempty}
    options.DilateRadius (1,1) double {mustBePositive, mustBeInteger} = 3
    options.ErodeRadius  (1,1) double {mustBePositive, mustBeInteger} = 3
    options.ShiftPixels  (1,1) double {mustBePositive} = 5
    options.Seed         (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

rng(options.Seed);

names = ["膨脹 " + options.DilateRadius + "px"
         "侵蝕 " + options.ErodeRadius + "px"
         "平移 " + options.ShiftPixels + "px"
         "邊界雜訊"
         "缺一角"];

masks = { ...
    imdilate(gtMask, strel("disk", options.DilateRadius)), ...
    imerode(gtMask,  strel("disk", options.ErodeRadius)), ...
    imtranslate(gtMask, [options.ShiftPixels options.ShiftPixels]), ...
    noisyBoundary(gtMask), ...
    cutCorner(gtMask) };

n = numel(masks);
J = zeros(n,1); D = zeros(n,1); B = zeros(n,1);
for k = 1:n
    J(k) = jaccard(masks{k}, gtMask);
    D(k) = dice(masks{k}, gtMask);
    B(k) = bfscore(masks{k}, gtMask);
end

tbl = table(names, J, D, B, ...
    VariableNames=["錯誤型態" "Jaccard" "Dice" "BFscore"]);

[~, rJ] = sort(J, "descend");
[~, rD] = sort(D, "descend");
[~, rB] = sort(B, "descend");

info = struct( ...
    "RankJaccard",   names(rJ).', ...
    "RankDice",      names(rD).', ...
    "RankBFscore",   names(rB).', ...
    "SameRankJD",    isequal(rJ, rD), ...
    "SameRankJB",    isequal(rJ, rB), ...
    "MaxGapJB",      max(abs(J - B)));

fprintf("\nJaccard 排序：%s\n", strjoin(names(rJ).', " > "));
fprintf("Dice    排序：%s\n", strjoin(names(rD).', " > "));
fprintf("BFscore 排序：%s\n", strjoin(names(rB).', " > "));

if info.SameRankJB
    fprintf("\n**三個指標的排序一致**——但不要因此以為它們可以互換。\n");
    [~, iGap] = max(abs(J - B));
    fprintf("「%s」的 Jaccard 是 %.4f，BFscore 卻是 %.4f（差 %.4f）：\n", ...
        names(iGap), J(iGap), B(iGap), abs(J(iGap)-B(iGap)));
    fprintf("**面積指標與邊界指標對同一個錯誤的嚴厲程度完全不同。**\n");
else
    fprintf("\n**排序不一致——面積指標與邊界指標給出相反的結論。**\n");
end
end

% ========================================================================
function m = noisyBoundary(gt)
%NOISYBOUNDARY 把邊界隨機啃掉／長出一點，面積幾乎不變但輪廓變毛。
e = bwperim(gt);
n = rand(size(gt)) > 0.5;
m = gt;
m(e & n) = false;
m(imdilate(e, strel("disk",1)) & ~gt & n) = true;
end

% ========================================================================
function m = cutCorner(gt)
%CUTCORNER 砍掉上方三成——面積損失大，但剩下的邊界仍然精準。
m = gt;
[r, ~] = find(gt);
if isempty(r), return, end
m(min(r):min(r)+round(0.3*(max(r)-min(r))), :) = false;
end
