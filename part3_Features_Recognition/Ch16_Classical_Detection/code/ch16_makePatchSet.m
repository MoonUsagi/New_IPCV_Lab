function [X, Y] = ch16_makePatchSet(nPerClass, patchSize, seed)
%CH16_MAKEPATCHSET 合成訓練用的 patch（圓／方／三角），內容已知。
%
%   [X, Y] = CH16_MAKEPATCHSET(NPERCLASS, PATCHSIZE, SEED) 回傳
%   PATCHSIZE 大小的灰階 patch 堆疊 X（H×W×N）與標籤 Y（N×1 string）。
%   SEED 固定隨機種子，所以同一個 SEED 一定得到同一組資料。
%
%   為什麼用合成資料
%   ----------------
%   第 16 章要證明一件與**分類器好壞無關**的事：
%   「patch 分類 100% 正確的模型，當成偵測器 precision 只有 0.8%」。
%
%   若用真實資料，分類器不可能 100% 正確，那個結果就會被歸咎於
%   「模型不夠好」——真正的問題（訓練分布 != 推論分布）就看不到了。
%
%   所以這個任務**刻意設計得很簡單**：三種形狀差異極大，
%   線性 SVM 就能 100% 分對。這樣第 6 節的失敗就只有一個可能的解釋。
%
%   **這組 patch 的關鍵性質：每一張都「置中」且「完整」。**
%   ------------------------------------------------------
%   訓練集裡：
%     · 目標一定在中間（只有 ±2 像素的隨機偏移）
%     · 形狀一定完整
%     · **一定有一個形狀**——沒有「空白背景」這一類
%
%   而滑動視窗實際送進分類器的視窗：
%     · 位置任意偏移
%     · 常常只框到一半
%     · **絕大多數是空白背景**
%
%   這個落差就是第 6 節的全部原因。
%   分類器被迫在「圓/方/三角」裡選一個，而一塊空白的 HOG 特徵
%   恰好可能最接近圓。
%
%   > **這不是模型不夠好，是訓練集不完整。**
%   > 與第 12 章「預設 NIQE 在非自然領域失效」是同一件事。
%
%   範例：
%     [Xtr, Ytr] = ch16_makePatchSet(150, [32 32], 1);
%     [Xte, Yte] = ch16_makePatchSet(60,  [32 32], 2);   % 不同種子
%
%   另見 CH16_HOGFEATURES, CH16_MINEHARDNEGATIVES, CH16_SLIDINGWINDOW.

arguments
    nPerClass (1,1) double {mustBePositive, mustBeInteger} = 150
    patchSize (1,2) double {mustBePositive, mustBeInteger} = [32 32]
    seed      (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

rng(seed);
kinds = ["circle" "square" "triangle"];
n = numel(kinds) * nPerClass;

X = zeros(patchSize(1), patchSize(2), n);
Y = strings(n, 1);

idx = 0;
for ki = 1:numel(kinds)
    for k = 1:nPerClass
        idx = idx + 1;
        X(:,:,idx) = drawShape(kinds(ki), patchSize);
        Y(idx) = kinds(ki);
    end
end
end

% ========================================================================
function P = drawShape(kind, sz)
%DRAWSHAPE 畫一個形狀，帶少量隨機位移、大小變化與雜訊。
P = 0.9*ones(sz);
[xx, yy] = meshgrid(1:sz(2), 1:sz(1));

% 只給 +-2 像素的位移：訓練集是「置中」的
cx = sz(2)/2 + 2*randn;
cy = sz(1)/2 + 2*randn;
r  = 0.32*min(sz) * (0.85 + 0.3*rand);

switch kind
    case "circle"
        P((xx-cx).^2 + (yy-cy).^2 < r^2) = 0.15;
    case "square"
        P(abs(xx-cx) < r*0.9 & abs(yy-cy) < r*0.9) = 0.15;
    case "triangle"
        P(yy > cy - r & (yy - (cy - r)) > 1.8*abs(xx - cx)) = 0.15;
end

P = imgaussfilt(P, 0.6) + 0.02*randn(sz);
P = min(max(P, 0), 1);
end
