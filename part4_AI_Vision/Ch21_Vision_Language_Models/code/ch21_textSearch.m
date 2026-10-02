function [ranked, report] = ch21_textSearch(clip, E, files, query, options)
%CH21_TEXTSEARCH 以文搜圖：用一句話在影像庫裡檢索。
%
%   [RANKED, REPORT] = CH21_TEXTSEARCH(CLIP, E, FILES, QUERY) 把 QUERY
%   轉成文字嵌入，和影像嵌入 E 算相似度，回傳由高到低排序的結果。
%
%   名稱-值引數：
%     TopK       - 回傳前幾名（預設 5）
%     TrueLabels - 若提供，會一併算 precision@K
%     Relevant   - 哪些類別算「相關」（配合 TrueLabels 使用）
%
%   **以文搜圖為什麼「免費」**
%
%   影像嵌入只要算**一次**，之後任何查詢都只是
%   「算一句話的嵌入 + 一次矩陣乘法」。
%   十萬張影像的資料庫，查詢時間仍然是毫秒等級。
%
%   這是 CLIP 最實用的能力，而且**不需要任何標註**——
%   對照第 17 章：那裡要用 Grounding DINO 產生框再人工修，
%   這裡連類別清單都不用事先定義。
%
%   **但它的排序品質受限於同一個問題**（見 CH21_ZEROSHOT）：
%   相似度擠在一個窄帶裡，所以**排名是可信的、絕對分數不是**。
%   檢索的介面應該呈現「前 K 名」，而不是「相似度超過 X 的全部」。
%
%   另見 CH21_CLIPEMBED, CH21_ZEROSHOT.

arguments
    clip
    E double
    files (1,:) string
    query (1,1) string {mustBeNonzeroLengthText}
    options.TopK       (1,1) double {mustBePositive, mustBeInteger} = 5
    options.TrueLabels = []
    options.Relevant   (1,:) string = string.empty
end

t = tic;
q = double(extractTextEmbeddings(clip, query));
q = q ./ vecnorm(q);
sims = (q.' * E).';                    % N x 1
secQuery = toc(t);

[sorted, ord] = sort(sims, "descend");
K = min(options.TopK, numel(ord));

ranked = table(ord(1:K), files(ord(1:K)).', sorted(1:K), ...
    VariableNames=["索引" "檔案" "相似度"]);

report = struct( ...
    "Query",      query, ...
    "SecQuery",   secQuery, ...
    "NumImages",  numel(files), ...
    "SimTop",     sorted(1), ...
    "SimMedian",  median(sims), ...
    "PrecisionAtK", NaN);

if ~isempty(options.TrueLabels) && ~isempty(options.Relevant)
    lab = options.TrueLabels(ord(1:K));
    hit = ismember(string(lab), options.Relevant);
    report.PrecisionAtK = mean(hit);
end
end
