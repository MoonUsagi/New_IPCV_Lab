function D = ch12_makeWaferLike(h, w, seed)
%CH12_MAKEWAFERLIKE 產生合成的工業紋理影像（晶圓／PCB 風格）。
%
%   D = CH12_MAKEWAFERLIKE(H, W, SEED) 產生一張 H×W、double、範圍 [0,1]
%   的合成影像：規則網格 + 週期性線條 + 隨機圓形特徵 + 少量雜訊。
%   SEED 固定隨機種子，所以同一個 SEED 一定產生同一張影像。
%
%   為什麼需要它
%   ------------
%   第 12 章第 7 節要示範 `fitniqe`，而 `fitniqe` 需要一批
%   **同領域的合格品影像**。
%
%   用 MATLAB 內建的自然照片不行——那正好是預設 NIQE 模型的訓練分布，
%   示範不出「領域不匹配」這件事。
%   所以這裡合成一個**刻意不像自然照片**的領域：
%   強週期性、少量灰階層次、邊界銳利。
%
%   實測結果（第 7.1 節）：預設 NIQE 模型給乾淨的本領域影像 **64.68**，
%   卻給模糊 sigma=3 的版本 **12.02**——**排序完全反了**。
%   用本函式產生 24 張訓練後，自訓模型給乾淨 5.22、模糊 8065.89，
%   排序正確。
%
%   為什麼要固定 SEED
%   ------------------
%   訓練集必須可重現，否則第 7 節的數字每次執行都不一樣，
%   讀者無法判斷自己有沒有做對。這與整個課程「每個數字都可重現」
%   的原則一致。
%
%   注意：這是**合成**資料，不是真實晶圓影像。
%   它的用途是示範方法，不是代表真實產線的統計特性。
%   實際專案請用自己產線拍的合格品。
%
%   範例：
%     % 建立訓練集
%     dir0 = fullfile(tempdir, "domain");
%     mkdir(dir0);
%     for k = 1:24
%         imwrite(ch12_makeWaferLike(256,256,k), ...
%             fullfile(dir0, sprintf("w_%02d.png", k)));
%     end
%
%     model = fitniqe(imageDatastore(dir0));
%
%     test = ch12_makeWaferLike(256, 256, 999);
%     fprintf("預設 %.2f、自訓 %.2f\n", niqe(test), niqe(test, model));
%
%   另見 FITNIQE, NIQE, NIQEMODEL, CH12_QUALITYREPORT.

arguments
    h (1,1) double {mustBePositive, mustBeInteger} = 256
    w (1,1) double {mustBePositive, mustBeInteger} = 256
    seed (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

rng(seed);

[X, Y] = meshgrid(1:w, 1:h);

% 規則網格：晶粒陣列
D = 0.45 + 0.12*sin(2*pi*X/18) .* sin(2*pi*Y/18);

% 較細的週期線條：金屬層走線
D = D + 0.08*sin(2*pi*X/5);

% 隨機圓形特徵：接觸孔／焊墊
nFeature = 12;
for k = 1:nFeature
    cx = randi([20, max(21, w-20)]);
    cy = randi([20, max(21, h-20)]);
    r  = randi([4 10]);
    D((X-cx).^2 + (Y-cy).^2 < r^2) = 0.8;
end

% 少量感測器雜訊。刻意保持很小——這批是「合格品」
D = D + 0.01*randn(h, w);

D = min(max(D, 0), 1);
end
