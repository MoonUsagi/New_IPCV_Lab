function [pred, S, report] = ch21_zeroShot(clip, E, prompts, classNames, trueLabels)
%CH21_ZEROSHOT 用 CLIP 做零樣本分類，並分析相似度的分布。
%
%   [PRED, S, REPORT] = CH21_ZEROSHOT(CLIP, E, PROMPTS, CLASSNAMES)
%   把 PROMPTS（每個類別一句話）轉成文字嵌入，和影像嵌入 E 算餘弦相似度，
%   取最大的當預測。
%
%   再傳入 TRUELABELS 就會一併算準確率。
%
%   回傳：
%     PRED   - 預測的類別（categorical）
%     S      - 相似度矩陣（類別數 x 影像數）
%     REPORT - struct，含 Accuracy 與**相似度的分布統計**
%
%   **相似度的分布比準確率更值得看，這是本函式的重點。**
%
%   實測（`vit-b-16`、DigitDataset 200 張、提示詞 "a photo of {數字}"）：
%
%     相似度  min 0.2143、max 0.2777、中位數 0.2366、標準差 0.0111
%     第一名與第二名的差距  中位數 **0.0068**、最大 0.0215
%
%   **所有的相似度都擠在 0.21–0.28 這個窄帶裡，
%   而分類的決定是由小數第三位的差距做出來的。**
%
%   這有兩個直接的後果：
%
%   **① 餘弦相似度不是信心分數。**
%   看到 0.28 不要以為「模型很確定」——它的最低值也有 0.21。
%   要當信心用必須**先在你自己的資料上校準**
%   （例如算出「答對時的 top1-top2 差距」的分布）。
%
%   **② 不能用固定的相似度門檻做拒絕判斷。**
%   「相似度低於 0.25 就說不知道」這種規則，在這裡會把
%   一半以上的正確答案也拒絕掉。要用**差距**而不是絕對值。
%
%   **③ 連「差距」也要校準。** CH21_PROMPTSWEEP 量到一件反直覺的事：
%   **最準的樣板，前二名的差距反而最小**（0.00237），
%   最不準的樣板差距最大（0.00681）。
%   所以「差距大 = 比較確定」在這裡是**反的**，
%   而且換樣板會同時改變準確率與差距的分布——
%   校準必須在**固定樣板之後**做。
%
%   > 這是第 09 章「SAM 的信心分數高不代表是你要的」、
%   > 第 17 章「Grounding DINO 分數最高的框 IoU = 0」的第三次現身。
%   > **基礎模型給的分數，都要先驗證才能當信心用。**
%
%   另見 CH21_CLIPEMBED, CH21_PROMPTSWEEP.

arguments
    clip
    E double
    prompts (1,:) string {mustBeNonempty}
    classNames (1,:) string {mustBeNonempty}
    trueLabels = []
end

if numel(prompts) ~= numel(classNames)
    error("ch21_zeroShot:sizeMismatch", ...
        "提示詞有 %d 句、類別有 %d 個——必須一一對應。", ...
        numel(prompts), numel(classNames));
end

T = double(extractTextEmbeddings(clip, prompts));
T = T ./ vecnorm(T);

S = T.' * E;                       % 類別數 x 影像數，就是餘弦相似度
[~, idx] = max(S, [], 1);
pred = categorical(classNames(idx), classNames);

% 第一名與第二名的差距
gap = nan(1, size(S,2));
if size(S,1) >= 2
    Ssort = sort(S, 1, "descend");
    gap = Ssort(1,:) - Ssort(2,:);
end

report = struct( ...
    "Accuracy",   NaN, ...
    "SimMin",     min(S(:)), ...
    "SimMax",     max(S(:)), ...
    "SimMedian",  median(S(:)), ...
    "SimStd",     std(S(:)), ...
    "SimRange",   max(S(:)) - min(S(:)), ...
    "TopGapMedian", median(gap), ...
    "TopGapMax",    max(gap));

if ~isempty(trueLabels)
    report.Accuracy = mean(pred(:) == trueLabels(:));
end

if report.SimRange < 0.15
    warning("ch21_zeroShot:narrowSimilarityBand", ...
        "所有相似度都落在 %.3f–%.3f（全距只有 %.3f），" + ...
        "而第一名與第二名的差距中位數只有 %.4f。" + ...
        "**餘弦相似度在這個任務上不能當信心分數用**——" + ...
        "要拒絕低信心的預測請用「差距」而不是絕對值。", ...
        report.SimMin, report.SimMax, report.SimRange, report.TopGapMedian);
end
end
