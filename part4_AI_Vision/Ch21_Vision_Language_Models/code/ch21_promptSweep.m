function tbl = ch21_promptSweep(clip, E, templates, classNames, trueLabels)
%CH21_PROMPTSWEEP 掃描提示詞樣板，量它對零樣本準確率的影響。
%
%   TBL = CH21_PROMPTSWEEP(CLIP, E, TEMPLATES, CLASSNAMES, TRUELABELS)
%   TEMPLATES 是 cell 陣列，每格 {樣板名稱, 樣板字串}，
%   樣板字串裡用 "{}" 代表類別名稱的位置。
%
%   例如 {"標準樣板", "a photo of {}"} 會展開成
%   "a photo of 0"、"a photo of 1"…
%
%   **這是第 17 章「提示詞是超參數」在 CLIP 上的版本，
%   而且結果更極端。**
%
%   實測（`vit-b-16`、DigitDataset 200 張測試、10 類手寫數字）：
%
%     樣板                                  準確率
%     只有類別名（"0"、"1"…）               **0.4900**
%     "the digit {}"                        0.4500
%     "a handwritten digit {}"              0.3550
%     "a black and white image of ... {}"   0.2850
%     **"a photo of {}"**                   **0.1800**
%
%   **最好 0.49、最差 0.18，差 31 個百分點。**
%
%   **而最差的那個正是 OpenAI 官方建議的標準樣板 `"a photo of {}"`。**
%
%   為什麼？合理的推測是：`"a photo of 3"` 會讓文字編碼器
%   把重點放在「**照片**」這個概念上，而手寫數字是
%   黑白線條圖，不是照片。樣板引入的字詞**把嵌入推離了目標領域**。
%
%   **但這只是推測。** 重點是你不能從語意直覺推出哪個樣板好，
%   **只能掃**——而掃一次很便宜（影像嵌入只要算一次，
%   換樣板只要重算文字嵌入，10 句話不到一秒）。
%
%   > **官方建議的樣板是在 ImageNet 那類自然照片上調出來的。**
%   > 你的領域不同，那個建議就不一定成立。
%
%   實作上的效率重點：**影像嵌入只算一次**（那是昂貴的部分，
%   0.2 秒／張），掃描樣板只需要重算文字嵌入。
%   所以這個函式接收已經算好的 E，而不是檔案清單。
%
%   另見 CH21_ZEROSHOT, CH21_CLIPEMBED.

arguments
    clip
    E double
    templates cell
    classNames (1,:) string {mustBeNonempty}
    trueLabels
end

n = size(templates, 1);
name = strings(n,1); acc = zeros(n,1);
simLo = zeros(n,1); simHi = zeros(n,1); gapMed = zeros(n,1);

ws = warning("off", "ch21_zeroShot:narrowSimilarityBand");
for k = 1:n
    tmpl = string(templates{k,2});
    if contains(tmpl, "{}")
        % **要逐個展開。** 直接寫 replace(tmpl, "{}", classNames) 會報
        % 「Replacement text must be either scalar or the same size as
        % the match text」——因為 tmpl 是純量而 classNames 有 N 個。
        prompts = arrayfun(@(c) replace(tmpl, "{}", c), classNames);
    else
        prompts = classNames;          % 樣板是空的 = 直接用類別名
    end

    [~, ~, r] = ch21_zeroShot(clip, E, prompts, classNames, trueLabels);

    name(k)   = templates{k,1};
    acc(k)    = r.Accuracy;
    simLo(k)  = r.SimMin;
    simHi(k)  = r.SimMax;
    gapMed(k) = r.TopGapMedian;
end
warning(ws);

tbl = table(name, acc, simLo, simHi, gapMed, ...
    VariableNames=["樣板" "準確率" "相似度最低" "相似度最高" "前二名差距中位數"]);

spread = max(acc) - min(acc);
[~, iB] = max(acc); [~, iW] = min(acc);
fprintf("\n最好「%s」%.4f、最差「%s」%.4f，**差 %.1f 個百分點**。\n", ...
    name(iB), acc(iB), name(iW), acc(iW), 100*spread);

if contains(lower(name(iW)), ["photo" "標準"])
    fprintf("**注意最差的那個是常被推薦的標準樣板**——" + ...
        "官方建議是在自然照片上調出來的，換領域不一定成立。\n");
end
end
