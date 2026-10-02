function e = ch13_gradEnergy(I, mask)
%CH13_GRADENERGY 遮罩內的平均梯度強度，用來量化「有沒有紋理」。
%
%   E = CH13_GRADENERGY(I, MASK) 回傳 MASK 範圍內 imgradient 的平均值。
%
%   為什麼需要這個指標
%   ------------------
%   PSNR 與 SSIM 都**偏好模糊**（第 12 章第 3 節已證明）。
%   評估影像修復時這個偏好會造成嚴重的誤導：平滑內插的逐像素誤差小，
%   所以 PSNR 高，但它產生的是一塊**沒有紋理的色斑**。
%
%   第 13 章第 4.1 節實測（peppers.png、90x90 的洞，
%   原圖洞內梯度能量 = 0.21132）：
%
%     方法               PSNR     梯度能量   能量比
%     inpaintExemplar   12.981    0.28307   1.340   <- 紋理**超出** 34%
%     inpaintCoherent   16.135    0.16573   0.784   <- 最接近 1
%     regionfill        16.503    0.06807   0.322   <- 只有原圖的 32%
%
%   **PSNR 的第一名（regionfill）在紋理上是最後一名。**
%   兩個指標一起看，才會選到真正合適的 inpaintCoherent。
%
%   怎麼讀這個數字
%   --------------
%   目標是**能量比接近 1**，不是越大越好：
%     · 遠小於 1 -> 填補太平滑，是一塊糊掉的色斑
%     · 遠大於 1 -> 補丁接不齊，接縫產生了**假的**梯度
%
%   注意這個指標**無法單獨使用**：一張隨機雜訊的能量比可能剛好是 1，
%   但它顯然不是好的修復結果。必須與 PSNR/SSIM 併用。
%
%   範例：
%     ref = ch13_gradEnergy(I, mask);            % 原圖（正確答案）
%     got = ch13_gradEnergy(inpaintCoherent(I, mask), mask);
%     fprintf("能量比 %.3f（目標接近 1）\n", got/ref);
%
%   另見 CH13_HOLEMETRICS, CH13_INPAINTCOMPARE, IMGRADIENT, STDFILT.

arguments
    I {mustBeNumeric, mustBeNonempty}
    mask {mustBeA(mask, ["logical" "numeric"])}
end

if ~islogical(mask), mask = logical(mask); end
if ~any(mask(:))
    error("ch13_gradEnergy:emptyMask", "遮罩是空的。");
end

G = im2double(I);
if size(G,3) > 1
    G = im2gray(G);
end

% MATLAB 不能對函式的回傳值直接索引，必須先存成變數
Gmag = imgradient(G);
e = mean(Gmag(mask));
end
