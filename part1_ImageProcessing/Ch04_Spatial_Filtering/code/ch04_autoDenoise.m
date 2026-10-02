function [out, report] = ch04_autoDenoise(I, options)
%CH04_AUTODENOISE 自動判斷雜訊類型並選用適當的濾波器去雜訊。
%
%   OUT = CH04_AUTODENOISE(I) 分析影像的雜訊特性，選用適當的濾波器，
%   回傳去雜訊後的影像。
%
%   [OUT, REPORT] = CH04_AUTODENOISE(___) 另外回傳判斷過程的 struct：
%     NoiseType      判定的雜訊類型："salt & pepper"、"gaussian"、"none"
%     Filter         實際使用的濾波器名稱
%     ExtremeRatio   孤立極值像素佔比（椒鹽雜訊的判斷依據）
%     NoiseEstimate  雜訊強度估計（高斯雜訊的判斷依據）
%
%   名稱-值引數：
%     Quality    "fast"（預設）或 "best"。"best" 對高斯雜訊改用 NLM，
%                品質較好但慢約 50 倍
%     Verbose    是否列印判斷過程，預設 false
%
%   判斷邏輯
%   --------
%   1. 椒鹽雜訊的特徵是有異常多的像素**既是極值（0 或 1）、又明顯偏離
%      局部中值**。只數極值像素是不夠的——imnoise 加高斯雜訊會裁切到
%      [0,1]，讓原本就很暗或很亮的區域產生大量極值。實測門檻 0.5%：
%        乾淨影像 0.00%、高斯雜訊 0.05–0.35%、斑點 0.16%、
%        椒鹽(密度0.01) 0.78%、椒鹽(密度0.03) 2.37%
%
%   2. 若不是椒鹽雜訊，用 Immerkær 的 Laplacian 法估計雜訊 sigma。
%      高於 0.03 就判定為高斯／斑點雜訊，用 Wiener 或 NLM 處理。
%
%   3. 兩者都不符合就判定為「幾乎無雜訊」，原樣回傳——
%      **不要對乾淨的影像做去雜訊**，那只會損失細節。
%
%   這個判斷不是萬無一失的。已知的失敗情況：
%     · 二值影像或高對比線稿：大量像素既是極值又偏離局部中值，
%       會被誤判為椒鹽雜訊
%     · 高斯與斑點雜訊在此無法區分，兩者都走同一條路徑
%   實務上若已知雜訊來源，直接指定濾波器會比自動判斷可靠。
%
%   範例：
%     I  = im2double(imread("cameraman.tif"));
%     sp = imnoise(I, "salt & pepper", 0.05);
%
%     [J, r] = ch04_autoDenoise(sp, Verbose=true);
%     fprintf("判定為 %s，使用 %s，PSNR %.2f dB\n", ...
%         r.NoiseType, r.Filter, psnr(J, I));
%
%   另見 MEDFILT2, WIENER2, IMNLMFILT, IMNOISE.

arguments
    I {mustBeNumeric, mustBeNonempty}
    options.Quality (1,1) string {mustBeMember(options.Quality, ["fast" "best"])} = "fast"
    options.Verbose (1,1) logical = false
end

if size(I,3) == 3
    % 彩色影像逐通道處理。這裡是安全的——去雜訊是鄰域運算，
    % 不像第 03 章的點運算會改變通道間的比例關係。
    out = I;
    for c = 1:3
        [out(:,:,c), report] = ch04_autoDenoise(I(:,:,c), ...
            Quality=options.Quality, Verbose=false);
    end
    if options.Verbose
        fprintf("彩色影像，逐通道處理。最後一個通道判定為 %s。\n", report.NoiseType);
    end
    return
end

Id = im2double(I);

% --- 判斷 1：椒鹽雜訊 --------------------------------------------------
% 只數「等於 0 或 1 的像素」是不夠的。imnoise 加高斯雜訊時會把結果裁切到
% [0,1]，影像本來就很暗或很亮的區域會產生大量極值像素——實測 cameraman
% 加 variance=0.008 的高斯雜訊後，極值像素高達 5.9%，會被誤判成椒鹽雜訊。
%
% 真正的差別在於「孤不孤立」：椒鹽雜訊點與周圍鄰居差異極大，
% 裁切造成的極值則與鄰居相近（因為那整片本來就是暗的或亮的）。
% 所以要求極值像素同時**明顯偏離局部中值**才算數。
isExtreme    = (Id == 0) | (Id == 1);
localMedian  = medfilt2(Id, [3 3]);
isIsolated   = isExtreme & abs(Id - localMedian) > 0.3;

extremeRatio = mean(isIsolated, "all");
isSaltPepper = extremeRatio > 0.005;

% --- 判斷 2：高斯雜訊強度（Immerkær 的 Laplacian 估計法）---------------
noiseEstimate = estimateNoiseSigma(Id);

% --- 決策 --------------------------------------------------------------
if isSaltPepper
    noiseType  = "salt & pepper";
    filterName = "medfilt2 3×3";
    out        = medfilt2(Id, [3 3]);

elseif noiseEstimate > 0.03
    noiseType = "gaussian";
    if options.Quality == "best"
        filterName = "imnlmfilt";
        out        = imnlmfilt(Id);
    else
        filterName = "wiener2 5×5";
        out        = wiener2(Id, [5 5]);
    end

else
    noiseType  = "none";
    filterName = "（不處理）";
    out        = Id;
end

% 保持與輸入相同的資料型別
if ~isa(I, "double")
    out = cast(out * double(intmax(class(I))), class(I));
end

report = struct( ...
    "NoiseType",     noiseType, ...
    "Filter",        filterName, ...
    "ExtremeRatio",  extremeRatio, ...
    "NoiseEstimate", noiseEstimate);

if options.Verbose
    fprintf("孤立極值像素佔比 %.3f%%（門檻 0.5%%）\n", 100*extremeRatio);
    fprintf("雜訊 sigma 估計 %.4f（門檻 0.03）\n", noiseEstimate);
    fprintf("判定為 %s，使用 %s\n", noiseType, filterName);
end
end

% ========================================================================
function sigma = estimateNoiseSigma(X)
%ESTIMATENOISESIGMA 估計影像的高斯雜訊標準差。
%
%   使用 Immerkær (1996) 的方法：把影像與一個對「平滑結構」響應為零、
%   但對雜訊高度敏感的核做卷積，再取絕對值的平均。
%
%   這個核是兩個 Laplacian 的差，設計上會抵消掉線性變化的亮度梯度，
%   所以估計值不容易被影像本身的結構綁架。
%
%   實測（cameraman.tif）：乾淨影像估得 0.016，加入 sigma=0.089 的高斯
%   雜訊後估得 0.089——相當準確。紋理較粗的影像（如 rice.png）在無雜訊時
%   會估到約 0.020，因此門檻設在 0.03 以上才安全。
%
%   參考：J. Immerkær, "Fast Noise Variance Estimation",
%   Computer Vision and Image Understanding, 1996.

M = [ 1 -2  1
     -2  4 -2
      1 -2  1];

[h, w] = size(X);
if h < 3 || w < 3
    sigma = 0;
    return
end

sigma = sqrt(pi/2) / (6 * (w-2) * (h-2)) * sum(abs(conv2(X, M, "valid")), "all");
end
