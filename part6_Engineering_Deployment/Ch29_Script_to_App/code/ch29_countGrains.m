function result = ch29_countGrains(image, options)
%CH29_COUNTGRAINS 計算影像中的顆粒數（米粒、細胞、零件）。**本章的主角。**
%
%   RESULT = CH29_COUNTGRAINS(IMAGE) 對灰階或 RGB 影像做
%   背景校正 → Otsu 門檻 → 去小區塊 → 連通區域計數，回傳 struct：
%     Count      顆粒數
%     Areas      每個顆粒的面積（像素），行向量
%     Mask       二值遮罩
%     Threshold  實際使用的門檻（0–1）
%     Params     本次使用的全部參數（**可重現性**）
%
%   這支函式是從一段「在命令列跑得好好的腳本」改寫來的。
%   改寫的重點不是演算法，是**介面**：
%   | 腳本 | 函式 |
%   |---|---|
%   | 參數寫死在程式碼裡 | 名稱-值引數，有預設值 |
%   | 假設輸入是灰階 uint8 | **明確檢查並轉換** |
%   | 結果散落在工作區 | 回傳一個 struct |
%   | 不知道用了什麼參數 | `Params` 欄位記錄下來 |
%
%   名稱-值引數：
%     BackgroundRadius  背景估計的 strel 半徑，預設 15
%     MinArea           最小顆粒面積，預設 50
%     Threshold         門檻（0–1）；NaN 表示用 Otsu 自動決定，預設 NaN
%
%   ## 為什麼 Threshold 的預設是 NaN 而不是空的
%   NaN 可以通過 `(1,1) double` 的驗證，而且語意清楚（「沒有指定」）。
%   **但練習 3 會看到它存進 JSON 之後變成 null、讀回來變成 []**——
%   這支函式的設定檔讀寫必須處理這件事（見 `ch29_loadConfig`）。
%
%   ## 型別檢查：`(1,1) double` 不夠
%   主教材 §3 量到 `arguments` 區塊裡的類別宣告是**轉型**不是檢查：
%   `true` 會變成 1、`"0.5"` 會變成 0.5，然後**安靜地執行**。
%   所以這裡另外加了 `mustBeFloat` 與 `mustBeNonLogical`。
%
%   另見 CH29_RUNBATCH, CH29_LOADCONFIG.

arguments
    image {mustBeNumericOrLogical, mustBeNonempty}
    options.BackgroundRadius (1,1) {mustBeNumeric, mustBeNonLogicalLocal, mustBeInteger, mustBePositive} = 15
    options.MinArea          (1,1) {mustBeNumeric, mustBeNonLogicalLocal, mustBeNonnegative} = 50
    options.Threshold        (1,1) {mustBeFloat, mustBeNonLogicalLocal} = NaN
end

if ~isnan(options.Threshold) && (options.Threshold < 0 || options.Threshold > 1)
    error("ipcv:ch29:thresholdRange", ...
        "Threshold 必須介於 0 到 1（或 NaN 表示自動），收到 %g。", options.Threshold);
end

% ---- 輸入正規化：這是腳本最常偷懶的地方
if ndims(image) > 3 || (size(image,3) ~= 1 && size(image,3) ~= 3)
    error("ipcv:ch29:badChannels", ...
        "影像必須是灰階（M×N）或 RGB（M×N×3），收到 %s。", mat2str(size(image)));
end
if size(image,3) == 3
    image = rgb2gray(image);
end
if islogical(image)
    error("ipcv:ch29:alreadyBinary", ...
        "輸入已經是二值影像；這支函式要的是灰階影像。");
end
gray = im2double(image);

% ---- 演算法本體（和原本的腳本一樣）
background = imopen(gray, strel("disk", options.BackgroundRadius));
corrected  = gray - background;
if isnan(options.Threshold)
    T = graythresh(corrected);
else
    T = options.Threshold;
end
mask = imbinarize(corrected, T);
mask = bwareaopen(mask, options.MinArea);

cc    = bwconncomp(mask);
stats = regionprops(cc, "Area");

result = struct( ...
    Count     = cc.NumObjects, ...
    Areas     = [stats.Area], ...
    Mask      = mask, ...
    Threshold = T, ...
    Params    = options);
end

% ========================================================================
function mustBeNonLogicalLocal(x)
%MUSTBENONLOGICALLOCAL logical 會被 (1,1) double 安靜地轉成 0／1，所以明確擋掉。
if islogical(x)
    error("ipcv:ch29:logicalParam", ...
        "這個參數不能是 logical（true 會被當成 1）。");
end
end
