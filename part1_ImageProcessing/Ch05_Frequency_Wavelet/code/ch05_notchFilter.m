function [out, info] = ch05_notchFilter(I, options)
%CH05_NOTCHFILTER 自動偵測並移除影像中的週期性干擾。
%
%   OUT = CH05_NOTCHFILTER(I) 在頻譜中找出最強的干擾峰值，用 notch 濾波
%   把它們挖掉，回傳處理後的影像。
%
%   [OUT, INFO] = CH05_NOTCHFILTER(___) 另外回傳診斷 struct：
%     PeakRows / PeakCols  找到的峰值位置
%     PeakMagnitudes       各峰值的振幅
%     RemovedEnergyRatio   被移除的能量佔總能量的比例
%
%   名稱-值引數：
%     NumPairs        要移除幾**對**峰值，預設 2。實數影像的頻譜共軛對稱，
%                     干擾必定成對出現，所以單位是「對」而不是「個」
%     NotchRadius     每個 notch 的半徑（像素），預設 8
%     ExcludeRadius   中心低頻的排除半徑，預設 20。太小會把影像本身的
%                     低頻結構當成干擾挖掉
%     AutoDetect      true（預設）自動找峰值；false 時需提供 PeakLocations
%     PeakLocations   手動指定的峰值位置，N×2 矩陣 [row col]
%
%   為什麼一定要成對處理
%   --------------------
%   實數影像的傅立葉頻譜滿足共軛對稱：F(-u,-v) = conj(F(u,v))。
%   只挖掉一側的峰值會破壞這個對稱性，`ifft2` 的結果就會有不可忽略的虛部，
%   影像出現奇怪的條紋。本函式以 maxk 取 2*NumPairs 個峰值，對稱的一對
%   會自然一起被選中。
%
%   什麼時候不該用
%   --------------
%   notch 濾波的前提是干擾在頻域**集中在少數幾個點**。若干擾的頻率會隨
%   位置變化（例如漸變的摩爾紋），頻譜上會是一片模糊的區域而非銳利的點，
%   這時 notch 會挖掉太多或挖不乾淨，該改用小波或其他方法。
%
%   範例：
%     I = im2double(imread("cameraman.tif"));
%     [rows, cols] = size(I);
%     [xx, yy] = meshgrid(1:cols, 1:rows);
%     stripes = 0.25 * sin(2*pi*(xx*0.12 + yy*0.06));
%     noisy = min(max(I + stripes, 0), 1);
%
%     [clean, info] = ch05_notchFilter(noisy);
%     fprintf("PSNR %.2f -> %.2f dB\n", psnr(noisy,I), psnr(clean,I));
%     fprintf("移除了 %.3f%% 的能量\n", 100*info.RemovedEnergyRatio);
%     montage({noisy, clean})
%
%   另見 FFT2, FFTSHIFT, IFFT2, MAXK.

arguments
    I {mustBeNumeric, mustBeNonempty}
    options.NumPairs      (1,1) double {mustBePositive, mustBeInteger}    = 2
    options.NotchRadius   (1,1) double {mustBePositive}                   = 8
    options.ExcludeRadius (1,1) double {mustBeNonnegative}                = 20
    options.AutoDetect    (1,1) logical                                   = true
    options.PeakLocations (:,2) double                                    = zeros(0,2)
end

if size(I,3) == 3
    % 彩色影像逐通道處理，但**用同一組峰值位置**——干擾在三個通道是同步的，
    % 各通道各自偵測可能找到不一致的峰值，造成色偏。
    Ig = im2gray(I);
    [~, info] = ch05_notchFilter(Ig, ...
        NumPairs=options.NumPairs, NotchRadius=options.NotchRadius, ...
        ExcludeRadius=options.ExcludeRadius);

    peaks = [info.PeakRows(:), info.PeakCols(:)];
    out = I;
    for c = 1:3
        out(:,:,c) = ch05_notchFilter(I(:,:,c), AutoDetect=false, ...
            PeakLocations=peaks, NotchRadius=options.NotchRadius);
    end
    return
end

Id = im2double(I);
[rows, cols] = size(Id);

F = fftshift(fft2(Id));

centerRow = floor(rows/2) + 1;
centerCol = floor(cols/2) + 1;
[xx, yy]  = meshgrid(1:cols, 1:rows);
distFromCenter = sqrt((xx - centerCol).^2 + (yy - centerRow).^2);

% --- 找峰值 -----------------------------------------------------------
if options.AutoDetect
    candidates = abs(F);
    candidates(distFromCenter < options.ExcludeRadius) = 0;

    nPeaks = 2 * options.NumPairs;          % 成對，所以取兩倍
    [~, idx] = maxk(candidates(:), nPeaks);
    [peakRows, peakCols] = ind2sub([rows cols], idx);
else
    if isempty(options.PeakLocations)
        error("ch05_notchFilter:noPeaks", ...
            "AutoDetect=false 時必須提供 PeakLocations。");
    end
    peakRows = options.PeakLocations(:,1);
    peakCols = options.PeakLocations(:,2);
end

% --- 挖掉 -------------------------------------------------------------
totalEnergy = sum(abs(F).^2, "all");
Fclean = F;

for k = 1:numel(peakRows)
    d = sqrt((xx - peakCols(k)).^2 + (yy - peakRows(k)).^2);
    Fclean(d < options.NotchRadius) = 0;
end

removedEnergy = totalEnergy - sum(abs(Fclean).^2, "all");

% --- 轉回空間域 -------------------------------------------------------
out = real(ifft2(ifftshift(Fclean)));      % 取實部：虛部只有浮點誤差
out = min(max(out, 0), 1);

if ~isa(I, "double")
    out = cast(out * double(intmax(class(I))), class(I));
end

info = struct( ...
    "PeakRows",           peakRows, ...
    "PeakCols",           peakCols, ...
    "PeakMagnitudes",     abs(F(sub2ind([rows cols], peakRows, peakCols))), ...
    "RemovedEnergyRatio", removedEnergy / totalEnergy);
end
