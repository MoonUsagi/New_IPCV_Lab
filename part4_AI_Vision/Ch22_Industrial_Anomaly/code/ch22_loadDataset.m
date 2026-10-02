function data = ch22_loadDataset(options)
%CH22_LOADDATASET 取得本章的資料——**換成你自己的資料就改這一個函式**。
%
%   DATA = CH22_LOADDATASET() 預設回傳**合成**的良品／瑕疵影像，
%   讓整章不需要外部資料就能跑完、而且有精確的 ground truth。
%
%   DATA = CH22_LOADDATASET(Source="folder", GoodDir=..., BadDir=...)
%   改讀你自己的影像資料夾。
%
%   回傳的 DATA 是 struct：
%     GoodTrain - H×W×3×N uint8，訓練用的良品
%     GoodTest  - H×W×3×N uint8，測試用的良品
%     Bad       - H×W×3×M uint8，瑕疵品
%     BadMasks  - H×W×M logical，瑕疵的位置（沒有就是空的）
%     Synthetic - 是不是合成資料
%
%   ============================================================
%   **要換成你自己的資料，只要改這裡。**
%
%   本章的設計刻意把「資料來源」和「方法」分開：
%   §4 之後的所有程式碼都只看 DATA 這個 struct，
%   不在乎它是合成的還是真實的。
%
%   最小的改法：
%
%     data = ch22_loadDataset(Source="folder", ...
%         GoodDir="D:\產線\良品", ...
%         BadDir ="D:\產線\瑕疵");
%
%   若你有瑕疵位置的標註（像素遮罩），再補 MaskDir，
%   §7 的定位評估就會自動啟用。沒有的話那一節會跳過。
%
%   **要注意的三件事**（換真實資料時最容易出問題）：
%
%   **① 影像尺寸要一致。** 異常偵測器吃固定尺寸的輸入，
%   而產線影像常常因為裁切而大小不一。這個函式會縮放到
%   `ImageSize`，但**縮放會改變瑕疵的相對大小**——
%   很小的瑕疵縮完可能只剩幾個像素（第 19 章 §9 的老問題）。
%
%   **② 良品要「夠正常」。** 異常偵測學的是「正常長什麼樣」，
%   訓練集裡混進一張瑕疵品，模型就會把那種瑕疵當成正常。
%   **這是這個方法最脆弱的地方**，而它不會報錯。
%
%   **③ 訓練集只放良品。** 不要把瑕疵品放進 GoodTrain，
%   那不是這個方法的用法（要用瑕疵品訓練請看 FCDD，§8）。
%   ============================================================
%
%   **合成資料的設計**（預設）
%
%   良品是均勻的亮面加上輕微雜訊；瑕疵是隨機位置的暗方塊。
%   這刻意做得很簡單，因為本章要示範的是**流程與指標**，
%   不是「PatchCore 有多強」。
%   真實瑕疵（刮痕、色差、缺件）難得多，
%   所以**合成資料上的分數不能當成對你產線的預期**。
%
%   另見 CH22_TRAINANOMALY, CH22_THRESHOLDANALYSIS.

arguments
    options.Source     (1,1) string {mustBeMember(options.Source, ...
        ["synthetic" "folder"])} = "synthetic"
    options.GoodDir    (1,1) string = ""
    options.BadDir     (1,1) string = ""
    options.MaskDir    (1,1) string = ""
    options.ImageSize  (1,2) double {mustBePositive, mustBeInteger} = [64 64]
    options.NumGoodTrain (1,1) double {mustBePositive, mustBeInteger} = 24
    options.NumGoodTest  (1,1) double {mustBePositive, mustBeInteger} = 12
    options.NumBad       (1,1) double {mustBePositive, mustBeInteger} = 12
    options.Seed       (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

if options.Source == "folder"
    data = loadFromFolders(options);
    return
end

% ---------- 合成資料 ----------
rng(options.Seed);
sz = options.ImageSize;

nGtr = options.NumGoodTrain;
nGte = options.NumGoodTest;
nB   = options.NumBad;

data.GoodTrain = makeGood(sz, nGtr);
data.GoodTest  = makeGood(sz, nGte);

data.Bad = zeros(sz(1), sz(2), 3, nB, "uint8");
data.BadMasks = false(sz(1), sz(2), nB);
for k = 1:nB
    [I, m] = makeBad(sz);
    data.Bad(:,:,:,k) = I;
    data.BadMasks(:,:,k) = m;
end

data.Synthetic = true;
data.ImageSize = sz;
end

% ========================================================================
function G = makeGood(sz, n)
G = zeros(sz(1), sz(2), 3, n, "uint8");
for k = 1:n
    base = 200 + 8*randn(sz);
    G(:,:,:,k) = repmat(uint8(base), 1, 1, 3);
end
end

% ========================================================================
function [I, m] = makeBad(sz)
base = 200 + 8*randn(sz);
I = repmat(uint8(base), 1, 1, 3);

% 隨機位置、隨機大小的暗斑
r = randi([6, sz(1)-20]);
c = randi([6, sz(2)-20]);
h = randi([5 13]);
w = randi([5 13]);
patch = uint8(60 + 10*randn(h+1, w+1));
I(r:r+h, c:c+w, :) = repmat(patch, 1, 1, 3);

m = false(sz);
m(r:r+h, c:c+w) = true;
end

% ========================================================================
function data = loadFromFolders(options)
%LOADFROMFOLDERS 讀真實資料。**這是換成你自己資料的入口。**
if options.GoodDir == "" || ~isfolder(options.GoodDir)
    error("ch22_loadDataset:noGoodDir", ...
        "Source=""folder"" 需要有效的 GoodDir（良品資料夾）。");
end

imdsGood = imageDatastore(options.GoodDir);
nGood = numel(imdsGood.Files);
if nGood < 8
    warning("ch22_loadDataset:fewGoodSamples", ...
        "良品只有 %d 張。PatchCore 至少要幾十張才穩定——" + ...
        "**太少的話模型會把正常的變異也當成異常**。", nGood);
end

sz = options.ImageSize;
allGood = readAllResized(imdsGood, sz);

% 良品切成訓練與測試（訓練集**只放良品**）
nTr = max(1, round(0.7*nGood));
data.GoodTrain = allGood(:,:,:,1:nTr);
data.GoodTest  = allGood(:,:,:,nTr+1:end);

if options.BadDir ~= "" && isfolder(options.BadDir)
    imdsBad = imageDatastore(options.BadDir);
    data.Bad = readAllResized(imdsBad, sz);
else
    data.Bad = zeros(sz(1), sz(2), 3, 0, "uint8");
    warning("ch22_loadDataset:noBadDir", ...
        "沒有提供瑕疵影像，只能算良品的分數分布，" + ...
        "**無法決定門檻也無法評估**（見 §5）。");
end

% 像素遮罩（選用）
nB = size(data.Bad, 4);
if options.MaskDir ~= "" && isfolder(options.MaskDir)
    imdsMask = imageDatastore(options.MaskDir);
    M = readAllResized(imdsMask, sz);
    data.BadMasks = squeeze(M(:,:,1,:)) > 0;
else
    data.BadMasks = false(sz(1), sz(2), 0);
end

data.Synthetic = false;
data.ImageSize = sz;

fprintf("讀入真實資料：良品訓練 %d、良品測試 %d、瑕疵 %d、遮罩 %d\n", ...
    size(data.GoodTrain,4), size(data.GoodTest,4), nB, size(data.BadMasks,3));
end

% ========================================================================
function A = readAllResized(imds, sz)
n = numel(imds.Files);
A = zeros(sz(1), sz(2), 3, n, "uint8");
for k = 1:n
    I = imread(imds.Files{k});
    if size(I,3) == 1
        I = repmat(I, 1, 1, 3);
    end
    A(:,:,:,k) = imresize(I, sz);
end
end
