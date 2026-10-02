function [dsOut, info] = ch17_buildPipeline(imds, pxds, options)
%CH17_BUILDPIPELINE 組裝一條「讀取 -> 擴增 -> 縮放」的資料管線。
%
%   [DSOUT, INFO] = CH17_BUILDPIPELINE(IMDS, PXDS) 把影像 datastore 與
%   像素標籤 datastore combine 起來，再用 transform 接上擴增與縮放。
%
%   名稱-值引數：
%     OutputSize - 網路輸入尺寸（預設 [256 256]）
%     Augment    - 是否加入隨機翻轉與平移（預設 true）
%     Seed       - 隨機種子（預設 0）
%
%   **這個函式的重點在「順序」，不在函式本身。**
%
%   combine 與 transform 都只是把 datastore 包起來，真正的運算
%   發生在 read 的時候。所以管線是**惰性**的：
%   建立管線不會讀任何檔案，也不會吃記憶體。
%
%   **順序錯了會安靜地出錯**，這是我要強調的地方：
%
%     正確：擴增（在原始尺寸）-> 縮放到網路輸入
%     錯誤：縮放到網路輸入 -> 擴增
%
%   為什麼？擴增裡的平移與旋轉會在邊界補值。
%   先縮放再擴增，補出來的邊界就是**網路真正會看到的輸入**，
%   模型會學到「邊界有一條灰帶」這個和任務無關的特徵。
%   先擴增再縮放，補值的部分會被縮放平均掉一部分，影響小得多。
%
%   更嚴重的是**標籤要跟著一起變**。像素標籤與影像必須套用
%   **同一個**隨機變換——所以擴增必須寫在 combine **之後**，
%   在一個同時拿到影像與標籤的函式裡處理。
%   若分別對 imds 和 pxds 各自 transform，兩邊的隨機數不同步，
%   影像被翻了但標籤沒翻——**訓練會跑完、loss 會下降、結果是垃圾**，
%   而且沒有任何錯誤訊息。
%
%   INFO 回傳實際的管線描述，方便寫進實驗紀錄。
%
%   另見 COMBINE, TRANSFORM, IMAGEDATASTORE, PIXELLABELDATASTORE.

arguments
    imds
    pxds
    options.OutputSize (1,2) double {mustBePositive, mustBeInteger} = [256 256]
    options.Augment    (1,1) logical = true
    options.Seed       (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

rng(options.Seed);

% combine 之後每次 read 得到 {影像, 標籤} 的 1x2 cell
dsCombined = combine(imds, pxds);

sz = options.OutputSize;
if options.Augment
    % **影像與標籤在同一個函式裡套用同一個隨機決定**
    dsOut = transform(dsCombined, @(data) augmentPair(data, sz));
    pipeline = "combine -> transform(擴增+縮放，影像與標籤同步)";
else
    dsOut = transform(dsCombined, @(data) resizePair(data, sz));
    pipeline = "combine -> transform(只縮放)";
end

info = struct( ...
    "Pipeline",   pipeline, ...
    "OutputSize", sz, ...
    "Augmented",  options.Augment, ...
    "Lazy",       true);
end

% ========================================================================
function out = augmentPair(data, sz)
%AUGMENTPAIR 對影像與標籤套用**同一個**隨機變換，然後才縮放。
%
%   補值有兩個容易錯的地方：
%
%   ① **categorical 標籤的 FillValues 不能是數字。**
%      `imtranslate(L, shift, FillValues=0)` 會報
%      「FillValue for categorical inputs must be valid category from
%      input data or a missing value」。要傳一個**真的類別名**
%      （這裡是 "background"）或 `missing`（變成 <undefined>）。
%      傳類別名在語意上也才對——平移露出來的那條邊確實是背景。
%
%   ② **影像的補值不要用 0。** 這批影像的背景是亮的，
%      補 0 會製造一條黑邊，而模型會把「黑邊」學成特徵。
%      用影像自己的邊界中位數，補出來的區域才和背景一致。
I = data{1};
L = data{2};

% 一次決定，兩邊共用 —— 這是整個函式存在的理由
doFlip = rand > 0.5;
shift  = randi([-8 8], 1, 2);

if doFlip
    I = fliplr(I);
    L = fliplr(L);
end

% 影像補值：取邊界的中位數，不要寫死 0
border = double([I(1,:) I(end,:) I(:,1).' I(:,end).']);
fillI = cast(median(border), class(I));

I = imtranslate(I, shift, FillValues=fillI, OutputView="same");
% 標籤用 nearest，否則會在類別之間插值出不存在的標籤；
% FillValues 要給真正的類別名
L = imtranslate(L, shift, FillValues="background", ...
    OutputView="same", Method="nearest");

% 擴增完才縮放
out = {imresize(I, sz), imresize(L, sz, Method="nearest")};
end

% ========================================================================
function out = resizePair(data, sz)
out = {imresize(data{1}, sz), imresize(data{2}, sz, Method="nearest")};
end
