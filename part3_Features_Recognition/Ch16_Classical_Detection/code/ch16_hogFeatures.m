function F = ch16_hogFeatures(X, cellSize)
%CH16_HOGFEATURES 對 patch 堆疊批次取 HOG 特徵。
%
%   F = CH16_HOGFEATURES(X, CELLSIZE) 對 H×W×N 的 patch 堆疊逐張取
%   HOG 特徵，回傳 N×D 的矩陣（每列一個樣本），可直接餵給 fitcsvm。
%
%   為什麼要先取一張來決定維度
%   --------------------------
%   HOG 的維度由 patch 大小與 CellSize 共同決定，而且關係是**平方**的
%   （第 14 章第 11 節：64x64 的輸入，CellSize [4 4] 是 8100 維、
%   [32 32] 只有 36 維，差 225 倍）。
%
%   先算第一張取得維度再預先配置，比在迴圈裡讓矩陣長大快得多。
%
%   另見 EXTRACTHOGFEATURES, CH16_MAKEPATCHSET.

arguments
    X {mustBeNumeric, mustBeNonempty}
    cellSize (1,2) double {mustBePositive, mustBeInteger} = [8 8]
end

n = size(X, 3);
probe = extractHOGFeatures(X(:,:,1), CellSize=cellSize);
F = zeros(n, numel(probe));
F(1,:) = probe;

for k = 2:n
    F(k,:) = extractHOGFeatures(X(:,:,k), CellSize=cellSize);
end
end
