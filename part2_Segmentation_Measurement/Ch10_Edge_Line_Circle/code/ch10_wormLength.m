function [medianLength, lines] = ch10_wormLength(BW, options)
%CH10_WORMLENGTH 用骨架化＋霍夫變換量測線狀物件的長度分布。
%
%   MEDIANLENGTH = CH10_WORMLENGTH(BW) 對二值影像 BW 做骨架化，
%   用霍夫變換擬合直線段，回傳線段長度的中位數。
%
%   [MEDIANLENGTH, LINES] = CH10_WORMLENGTH(___) 另外回傳 houghlines 的
%   線段結構陣列。
%
%   名稱-值引數：
%     SkeletonMethod  "bwskel"（預設）或 "bwmorph"。見下方的重要說明
%     NumPeaks        霍夫峰值數上限，預設 30
%     NHoodSize       峰值之間的最小間隔，預設 [55 11]
%     PeakThreshold   峰值門檻佔最大值的比例，預設 0.4
%
%   兩種骨架化方法**不能互換**
%   --------------------------
%   `bwskel`（現行建議）與 `bwmorph(BW,"skel",Inf)`（舊版）用的是不同的
%   細化演算法，產生的骨架不同，連帶讓霍夫偵測到的線段數與長度都不同。
%
%   第 10 章對 wormsBW1／wormsBW2 的實測：
%
%     樣本    bwmorph 中位長度 / 線段數    bwskel 中位長度 / 線段數
%       1          69.3 / 19                   71.5 / 17
%       2          46.6 / 13                   58.7 /  5
%
%   樣本 2 的中位長度從 46.6 跳到 58.7，**跨過了原版教材寫死的門檻 58**——
%   同一張影像，分類結論相反。
%
%   **這代表任何依賴此函式輸出的門檻，都與 SkeletonMethod 綁定。**
%   換方法就必須重新校正門檻，並重跑驗證。預設保留為 "bwskel"（現行建議），
%   但提供 "bwmorph" 以便重現舊版結果與做對照。
%
%   範例：
%     bw = logical(imread("wormsBW1.png"));
%
%     [len, lines] = ch10_wormLength(bw);
%     fprintf("中位長度 %.1f，共 %d 條線段\n", len, numel(lines));
%
%     % 重現舊版結果
%     lenOld = ch10_wormLength(bw, SkeletonMethod="bwmorph");
%
%   另見 BWSKEL, HOUGH, HOUGHPEAKS, HOUGHLINES.

arguments
    BW {mustBeA(BW, ["logical" "numeric"])}
    options.SkeletonMethod (1,1) string ...
        {mustBeMember(options.SkeletonMethod, ["bwskel" "bwmorph"])} = "bwskel"
    options.NumPeaks      (1,1) double {mustBePositive, mustBeInteger} = 30
    options.NHoodSize     (1,2) double {mustBePositive}                = [55 11]
    options.PeakThreshold (1,1) double {mustBeInRange(options.PeakThreshold, 0, 1)} = 0.4
end

if ~islogical(BW)
    BW = imbinarize(im2gray(BW));      % 取代舊版的 im2bw
end

% --- 骨架化 -----------------------------------------------------------
switch options.SkeletonMethod
    case "bwskel"
        skeleton = bwskel(BW);
    case "bwmorph"
        % 舊版寫法。R2026a 仍可執行，但官方已建議改用 bwskel。
        skeleton = bwmorph(BW, "skel", Inf);
end

% --- 霍夫直線擬合 -----------------------------------------------------
[H, T, R] = hough(skeleton);

% NHoodSize 要夠大，否則同一條線會被偵測成多條（rho 與 theta 相近的峰值）
peaks = houghpeaks(H, options.NumPeaks, ...
    NHoodSize = options.NHoodSize, ...
    Threshold = options.PeakThreshold * max(H(:)));

lines = houghlines(skeleton, T, R, peaks);

% --- 長度統計 ---------------------------------------------------------
if isempty(lines)
    medianLength = NaN;
    return
end

lengths = arrayfun(@(l) norm(double(l.point2) - double(l.point1)), lines);
medianLength = median(lengths);
end
