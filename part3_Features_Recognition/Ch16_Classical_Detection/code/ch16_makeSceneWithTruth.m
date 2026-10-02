function [scene, gtBoxes] = ch16_makeSceneWithTruth(H, W, options)
%CH16_MAKESCENEWITHTRUTH 合成測試場景並回傳目標的 ground truth 框。
%
%   [SCENE, GTBOXES] = CH16_MAKESCENEWITHTRUTH(H, W) 產生含圓（目標）與
%   方/三角（干擾物）的場景，並回傳圓的邊界框。
%
%   名稱-值引數：
%     NumTargets      圓的數量，預設 4
%     NumDistractors  干擾物數量，預設 6
%     Radius          形狀半徑，預設 15
%     Seed            隨機種子，預設 7
%
%   為什麼要自己回傳 ground truth
%   -----------------------------
%   偵測任務的評估需要**框的座標**，而不只是「有幾個」。
%   自己合成場景就能免費得到精確的框——這與第 14 章
%   「自己套一個已知變換」、第 15 章「用 insertText 寫上已知字串」
%   是同一個手法：**能自己造正確答案就一定要造。**
%
%   有了 GTBOXES 才能算 IoU，才能分辨
%   「找到了目標」與「剛好框在附近」。
%
%   干擾物為什麼重要
%   ----------------
%   若場景裡只有目標，滑動視窗的假陽性只會來自「框到一半」或「空白」。
%   加入方形與三角形之後，還會多一種假陽性：**其他類別的物件**。
%
%   第 16 章第 6 節實測：4 個目標 + 6 個干擾物的場景，
%   未經硬負樣本挖掘的偵測器吐出 **509** 個框（precision 0.8%）。
%
%   另見 CH16_SLIDINGWINDOW, CH16_EVALDETECTIONS, CH16_MINEHARDNEGATIVES.

arguments
    H (1,1) double {mustBePositive, mustBeInteger} = 480
    W (1,1) double {mustBePositive, mustBeInteger} = 640
    options.NumTargets     (1,1) double {mustBeNonnegative, mustBeInteger} = 4
    options.NumDistractors (1,1) double {mustBeNonnegative, mustBeInteger} = 6
    options.Radius         (1,1) double {mustBePositive} = 15
    options.Seed           (1,1) double {mustBeNonnegative, mustBeInteger} = 7
end

rng(options.Seed);
scene = 0.9*ones(H, W);
[xx, yy] = meshgrid(1:W, 1:H);
r = options.Radius;
half = round(r) + 1;

gtBoxes = zeros(0, 4);

% --- 目標：圓 ---------------------------------------------------------
for k = 1:options.NumTargets
    cx = randi([60, W-60]);
    cy = randi([60, H-60]);
    scene((xx-cx).^2 + (yy-cy).^2 < r^2) = 0.15;
    % 框的大小與訓練用的 patch 一致，這樣 IoU 才有意義
    gtBoxes(end+1,:) = [cx-half, cy-half, 2*half, 2*half];
end

% --- 干擾物：方形與三角形 --------------------------------------------
for k = 1:options.NumDistractors
    cx = randi([60, W-60]);
    cy = randi([60, H-60]);
    if mod(k,2) == 0
        scene(abs(xx-cx) < r & abs(yy-cy) < r) = 0.15;
    else
        scene(yy > cy - r & (yy-(cy-r)) > 1.8*abs(xx-cx) & yy < cy + r) = 0.15;
    end
end

scene = imgaussfilt(scene, 0.6) + 0.02*randn(H, W);
scene = min(max(scene, 0), 1);
end
