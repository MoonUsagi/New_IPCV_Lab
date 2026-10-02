function [count, areas, threshold] = ch30_countGrainsGPU(image, backgroundRadius, minArea, thresholdIn) %#codegen
%CH30_COUNTGRAINSGPU 給 GPU Coder 用的顆粒計數（介面同 ch30_countGrainsCG）。
%
%   [COUNT, AREAS, THRESHOLD] = CH30_COUNTGRAINSGPU(IMAGE, BACKGROUNDRADIUS, MINAREA, THRESHOLDIN)
%   在 MATLAB 裡直接呼叫時，結果與 ch30_countGrainsCG 完全相同。
%
%   ## 為什麼 ch30_countGrainsCG 不能直接給 GPU Coder
%   用 coder.gpuConfig 產生程式碼時，第一版失敗在：
%       Invalid structure field 'PixelIdxList'.
%   **GPU 碼生成的 `bwconncomp` 不提供 PixelIdxList**。C 碼生成可以、GPU 不行——
%   「支援 codegen」要看是哪一種 codegen。
%
%   這個版本改用 `bwlabel` 產生標籤影像，再逐像素累加面積。
%   `bwlabel` 與 `bwconncomp` 都以**行為主的掃描順序**編號，所以面積的順序也相同。
%
%   `coder.gpu.kernelfun` 告訴 GPU Coder 盡量把迴圈與逐元素運算對應成 CUDA kernel。
%   面積累加是一個「很多像素寫同一個位置」的迴圈，有資料相依，**不會**變成平行 kernel——
%   這一段在產生的程式碼裡仍在 CPU 上跑。
%
%   另見 CH30_COUNTGRAINSCG, CODER.GPUCONFIG, CODER.GPU.KERNELFUN, BWLABEL.

coder.gpu.kernelfun;
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

labels = bwlabel(mask);
count = max(labels(:));
areas = zeros(1, count);
for k = 1:numel(labels)
    if labels(k) > 0
        areas(labels(k)) = areas(labels(k)) + 1;
    end
end
end
