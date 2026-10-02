function [count, areas, threshold] = ch30_countGrainsCG(image, backgroundRadius, minArea, thresholdIn) %#codegen
%CH30_COUNTGRAINSCG 第 29 章 ch29_countGrains 的「可以產生 C 程式碼」版本。
%
%   [COUNT, AREAS, THRESHOLD] = CH30_COUNTGRAINSCG(IMAGE, R, MINAREA, T)
%   演算法和 ch29_countGrains 完全一樣，**介面改了**：
%   | ch29_countGrains | ch30_countGrainsCG | 為什麼 |
%   |---|---|---|
%   | 名稱-值引數 + `arguments` 驗證 | **位置引數** | codegen 不支援入口函式的名稱-值驗證 |
%   | 回傳 struct（含 Mask、Params） | **回傳三個數值** | 輸出越簡單，C 介面越好接 |
%   | 接受 RGB、自動轉灰階 | **只接受灰階 uint8** | 型別與大小在編譯時要固定 |
%   | 錯誤訊息用 string 與 `mat2str` | 用 char 與 `assert` | 生成的 C 程式碼不支援 string 物件的部分操作 |
%   | NaN 表示自動門檻 | **負數表示自動門檻** | 避免依賴 NaN 在各平台的行為（見下） |
%
%   ## 為什麼門檻改用負數表示「自動」
%   生成的 C 程式碼在大多數平台上都能正確處理 NaN，
%   **但下游的 PLC 或嵌入式呼叫端常常不能**——很多工業控制器的
%   通訊協定根本沒有 NaN 這個值。介面上用一個「不可能的正常值」
%   表示特殊意義，比用 NaN 安全。
%   這和第 29 章「NaN 存進 JSON 變成 null」是同一類問題：
%   **NaN 是 MATLAB 內部的好工具，但跨系統邊界時常常不存在。**
%
%   另見 CH29_COUNTGRAINS, CODEGEN.

assert(isa(image, "uint8"));
assert(ismatrix(image));
assert(isscalar(backgroundRadius) && backgroundRadius >= 1);
assert(isscalar(minArea) && minArea >= 0);
assert(isscalar(thresholdIn) && thresholdIn <= 1);

gray = im2double(image);
background = imopen(gray, strel("disk", double(backgroundRadius)));
corrected = gray - background;

if thresholdIn < 0
    threshold = graythresh(corrected);
else
    threshold = double(thresholdIn);
end

mask = imbinarize(corrected, threshold);
mask = bwareaopen(mask, double(minArea));

cc = bwconncomp(mask);
count = cc.NumObjects;
areas = zeros(1, count);
for k = 1:count
    areas(k) = numel(cc.PixelIdxList{k});
end
end
