function [captions, info] = ch21_caption(files, options)
%CH21_CAPTION 用 Moondream 為一批影像產生文字描述。
%
%   [CAPTIONS, INFO] = CH21_CAPTION(FILES) 對每張影像呼叫 Moondream，
%   回傳字串陣列與計時資訊。
%
%   名稱-值引數：
%     Verbose - 印出每一張的描述（預設 true）
%
%   **Moondream 與 CLIP 的分工完全不同**
%
%   | | CLIP | Moondream |
%   |---|---|---|
%   | 輸入 | 影像 **+ 你提供的候選文字** | 只有影像 |
%   | 輸出 | 每個候選的相似度 | **一段自由文字** |
%   | 你要先知道 | **所有可能的答案** | 什麼都不用 |
%   | 適合 | 分類、檢索 | 圖說、索引、初步理解 |
%
%   **CLIP 只能在你給的選項裡挑**，Moondream 能說出你沒想到的東西。
%   代價是輸出不結構化——你拿到一段話，要自己解析。
%
%   實測（`peppers.png`）：
%
%     "A purple tablecloth holds a vibrant array of red, green, yellow,
%      and white peppers, onions, and garlic, arranged in a visually
%      appealing composition."
%
%   **描述是正確的**，而且提到了顏色、物件種類與擺放方式——
%   那些都不是事先定義的類別。
%
%   **成本**：第一次呼叫（含模型載入）約 14 秒。
%   這比 CLIP 的 0.2 秒／張慢兩個數量級，
%   所以 Moondream 適合**離線批次建索引**，不適合即時查詢。
%
%   **輸出是不可重現的自然語言。** 同一張圖跑兩次可能得到
%   措辭不同的描述，所以**不要拿它的字面輸出去做斷言比對**——
%   要驗證的話得用語意相似度（例如再用 CLIP 的文字嵌入比較）。
%
%   另見 MOONDREAM, CAPTIONIMAGE, CH21_CLIPEMBED.

arguments
    files (1,:) string {mustBeNonempty}
    options.Verbose (1,1) logical = true
end

md = moondream();

n = numel(files);
captions = strings(n,1);
secs = zeros(n,1);

for k = 1:n
    I = imread(files(k));
    t = tic;
    captions(k) = string(captionImage(md, I));
    secs(k) = toc(t);
    if options.Verbose
        [~, nm, ext] = fileparts(files(k));
        fprintf("  %-22s (%.1f 秒)\n    %s\n", nm + ext, secs(k), captions(k));
    end
end

info = struct( ...
    "NumImages",   n, ...
    "SecFirst",    secs(1), ...        % 含模型載入
    "SecPerImage", mean(secs(2:end)), ...
    "SecTotal",    sum(secs));

if n == 1
    info.SecPerImage = secs(1);
end

clear md      % 第 17 章 §10.1：基礎模型用完要釋放顯示記憶體
end
