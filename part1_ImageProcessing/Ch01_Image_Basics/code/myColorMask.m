function mask = myColorMask(RGB, hueRange, minSat, options)
%MYCOLORMASK 依色相與飽和度建立顏色遮罩。
%
%   MASK = MYCOLORMASK(RGB, HUERANGE, MINSAT) 把 RGB 影像轉到 HSV 空間，
%   回傳色相落在 HUERANGE 之內、且飽和度不低於 MINSAT 的像素遮罩。
%
%   HUERANGE 為 [lo hi]，數值介於 0–1。若 lo > hi，表示色相範圍跨越 0／1
%   邊界（紅色即屬此類），函式會自動以「或」的邏輯處理。
%
%   MASK = MYCOLORMASK(___, MinValue=v) 另外要求明度不低於 v，用來排除
%   陰影區。預設 0，即不限制。
%
%   MASK = MYCOLORMASK(___, MinArea=n) 移除面積小於 n 個像素的雜點。
%   預設 0，即不清理。
%
%   為什麼要用飽和度過濾：低飽和度（接近灰白）的像素，其色相值幾乎是
%   隨機的。只用色相篩選，白色與灰色區域會大量誤判為目標顏色。
%
%   範例：
%     RGB = imread("peppers.png");
%
%     % 黃色：一般情況
%     yellow = myColorMask(RGB, [0.10 0.20], 0.4);
%
%     % 紅色：色相跨越 0／1 邊界
%     red = myColorMask(RGB, [0.95 0.05], 0.4, MinValue=0.2, MinArea=200);
%
%     montage({RGB, yellow, red})
%
%   另見 RGB2HSV, IMBINARIZE, BWAREAOPEN, LABELOVERLAY.

arguments
    RGB               {mustBeNumeric, mustBeNonempty}
    hueRange (1,2)    double {mustBeInRange(hueRange, 0, 1)}
    minSat   (1,1)    double {mustBeInRange(minSat, 0, 1)} = 0
    options.MinValue (1,1) double {mustBeInRange(options.MinValue, 0, 1)} = 0
    options.MinArea  (1,1) double {mustBeNonnegative, mustBeInteger}      = 0
end

if size(RGB, 3) ~= 3
    error("myColorMask:notRGB", ...
        "輸入必須是三通道 RGB 影像，但收到 %d 個通道。", size(RGB, 3));
end

HSV = rgb2hsv(RGB);
H = HSV(:,:,1);
S = HSV(:,:,2);
V = HSV(:,:,3);

lo = hueRange(1);
hi = hueRange(2);

if lo <= hi
    inHue = (H >= lo) & (H <= hi);
else
    % 跨越 0／1 邊界：例如紅色的 [0.95 0.05]
    inHue = (H >= lo) | (H <= hi);
end

mask = inHue & (S >= minSat) & (V >= options.MinValue);

if options.MinArea > 0
    mask = bwareaopen(mask, options.MinArea);
end
end
