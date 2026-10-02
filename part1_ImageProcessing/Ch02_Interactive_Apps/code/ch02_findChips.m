function [stats, mask] = ch02_findChips(RGB, options)
%CH02_FINDCHIPS 在彩色影像中找出指定顏色的圓形物件並量測。
%
%   STATS = CH02_FINDCHIPS(RGB) 以預設的紅色門檻找出圓形物件，回傳每個
%   物件的量測結果 table（面積、質心、等效直徑、圓形度）。
%
%   [STATS, MASK] = CH02_FINDCHIPS(___) 另外回傳清理後的二值遮罩。
%
%   這是第 02 章「五步驟工作流」第 ③ 步的成果：把 Color Thresholder
%   產生的 ch02_createMask_generated 重構成可重用的函式。相較於原版：
%     · 所有門檻改為可調參數，並有預設值
%     · 參數名稱說明它是什麼（HueRange 而非 channel1Min）
%     · 有輸入驗證，非 RGB 影像會得到清楚的錯誤訊息
%     · 把「產生遮罩」與「清理遮罩」「量測」分成三個明確步驟
%     · 回傳資料而非印出結果，由呼叫端決定怎麼用
%
%   名稱-值引數：
%     HueRange      色相範圍 [lo hi]，0–1。lo > hi 表示跨越 0／1 邊界
%                   （紅色屬此類）。預設 [0.90 0.04]
%     MinSaturation 最低飽和度，排除灰白區域。預設 0.45
%     MinValue      最低明度，排除陰影。預設 0.30
%     MinArea       最小面積（像素），濾掉雜點。預設 500
%     MinCircularity 最低圓形度，只保留夠圓的物件。預設 0.90
%                   設為 0 可關閉此篩選
%     SmoothRadius  形態學開運算的結構元素半徑，用於斷開細連結。預設 4
%
%   範例：
%     RGB = imread("coloredChips.png");
%
%     % 預設（紅色）
%     [s, m] = ch02_findChips(RGB);
%     fprintf("找到 %d 個紅色圓片\n", height(s));
%
%     % 黃色，且放寬圓形度
%     sy = ch02_findChips(RGB, HueRange=[0.10 0.18], MinCircularity=0.8);
%
%     % 視覺化
%     imshow(labeloverlay(RGB, m))
%
%   另見 CH02_CREATEMASK_GENERATED, CH02_BATCHCOUNT, REGIONPROPS, BWPROPFILT.

arguments
    RGB {mustBeNumeric, mustBeNonempty}
    options.HueRange       (1,2) double {mustBeInRange(options.HueRange,0,1)}       = [0.90 0.04]
    options.MinSaturation  (1,1) double {mustBeInRange(options.MinSaturation,0,1)}  = 0.45
    options.MinValue       (1,1) double {mustBeInRange(options.MinValue,0,1)}       = 0.30
    options.MinArea        (1,1) double {mustBeNonnegative}                         = 500
    options.MinCircularity (1,1) double {mustBeNonnegative}                         = 0.90
    options.SmoothRadius   (1,1) double {mustBeNonnegative, mustBeInteger}          = 4
end

if size(RGB,3) ~= 3
    error("ch02_findChips:notRGB", ...
        "輸入必須是三通道 RGB 影像，但收到 %d 個通道。", size(RGB,3));
end

% --- 步驟 1：依顏色產生原始遮罩 ---------------------------------------
HSV = rgb2hsv(RGB);
H = HSV(:,:,1);  S = HSV(:,:,2);  V = HSV(:,:,3);

lo = options.HueRange(1);
hi = options.HueRange(2);
if lo <= hi
    inHue = (H >= lo) & (H <= hi);
else
    inHue = (H >= lo) | (H <= hi);       % 跨越 0／1 邊界
end

raw = inHue & (S >= options.MinSaturation) & (V >= options.MinValue);

% --- 步驟 2：清理遮罩 --------------------------------------------------
mask = raw;
if options.SmoothRadius > 0
    mask = imopen(mask, strel("disk", options.SmoothRadius));  % 斷開細連結、去毛邊
end
mask = imfill(mask, "holes");                                  % 補內部破洞
if options.MinArea > 0
    mask = bwareaopen(mask, options.MinArea);                  % 濾掉雜點
end
if options.MinCircularity > 0
    mask = bwpropfilt(mask, "Circularity", [options.MinCircularity Inf]);
end

% --- 步驟 3：量測 ------------------------------------------------------
stats = regionprops("table", mask, ...
    "Area", "Centroid", "EquivDiameter", "Circularity");

if ~isempty(stats)
    stats = sortrows(stats, "Area", "descend");
end
end
