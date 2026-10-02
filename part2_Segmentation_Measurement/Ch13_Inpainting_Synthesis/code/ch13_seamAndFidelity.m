function [seam, fidelity] = ch13_seamAndFidelity(blended, fg, bg, mask, options)
%CH13_SEAMANDFIDELITY 量化混合結果的接縫品質與內部保真度。
%
%   [SEAM, FIDELITY] = CH13_SEAMANDFIDELITY(BLENDED, FG, BG, MASK)
%     SEAM      遮罩邊界附近的平均梯度。越小越接縫不明顯
%     FIDELITY  遮罩內縮之後，混合結果與原始前景的 PSNR。越大越忠實
%
%   名稱-值引數：
%     SeamWidth   接縫帶的寬度（邊界往內外各幾像素），預設 3
%     ErodeWidth  計算保真度時遮罩內縮幾像素，預設 8
%
%   為什麼需要**兩個**數字
%   ----------------------
%   「看起來無縫」不是評估。而且接縫好不等於混合正確——
%   這兩個目標其實**互相衝突**。
%
%   第 13 章第 6.1、7 節實測（peppers 貼到 saturn）：
%
%     Mode                  接縫梯度   內部保真PSNR
%     Poisson                0.15218      19.542    <- 接縫最好
%     PoissonMixGradients    0.16570      13.296
%     Guided                 0.33765         Inf    <- 物件完全沒變
%     Alpha (0.7 預設)        0.36967      21.630
%     (硬貼，不混合)           0.50274         Inf
%     (純背景基準線)           0.10522          --
%
%   **Poisson 的接縫最好，但內部保真只有 19.5 dB。**
%   原因在演算法：Poisson 混合只保留前景的**梯度**，不保留絕對值。
%   它解一個泊松方程，邊界值取自背景——於是物件的顏色**被背景拉走**。
%
%   `Guided` 的保真度是 Inf（像素完全相同），代價是接縫明顯。
%
%   這對合成訓練資料是真實的風險：用 Poisson 產生的訓練影像，
%   物件顏色會隨背景改變，而真實場景不會這樣。
%
%   怎麼讀這兩個數字
%   ----------------
%   接縫梯度要跟兩個參考值比：
%     · **純背景基準線**（下限）：接縫帶在還沒貼東西時的梯度
%     · **硬貼**（上限）：完全不混合時的梯度
%   落在兩者之間才有意義；接近下限代表接縫幾乎看不出來。
%
%   範例：
%     B = imblend(fg, bg, mask, Mode="Poisson");
%     [s, f] = ch13_seamAndFidelity(B, fg, bg, mask);
%     fprintf("接縫 %.5f、保真 %.3f dB\n", s, f);
%
%   另見 CH13_COMPOSITEOBJECT, IMBLEND.

arguments
    blended {mustBeNumeric, mustBeNonempty}
    fg      {mustBeNumeric, mustBeNonempty}
    bg      {mustBeNumeric, mustBeNonempty}
    mask    {mustBeA(mask, ["logical" "numeric"])}
    options.SeamWidth  (1,1) double {mustBePositive, mustBeInteger} = 3
    options.ErodeWidth (1,1) double {mustBePositive, mustBeInteger} = 8
end

if ~islogical(mask), mask = logical(mask); end

% --- 接縫：遮罩邊界往內外各 SeamWidth 像素 --------------------------
seamBand = imdilate(bwperim(mask), strel("disk", options.SeamWidth));
if ~any(seamBand(:))
    error("ch13_seamAndFidelity:noSeam", "遮罩沒有邊界，無法量測接縫。");
end

G = im2double(blended);
if size(G,3) > 1, G = im2gray(G); end
Gmag = imgradient(G);               % 不能對函式回傳值直接索引
seam = mean(Gmag(seamBand));

% --- 保真度：遮罩內縮，避開混合過渡區 ------------------------------
inner = imerode(mask, strel("disk", options.ErodeWidth));
if ~any(inner(:))
    warning("ch13_seamAndFidelity:maskTooThin", ...
        "遮罩內縮 %d 像素之後就空了（物件太小或太細）。" + ...
        "改用未內縮的遮罩計算保真度，但數字會被混合過渡區汙染。", ...
        options.ErodeWidth);
    inner = mask;
end

A = im2double(fg);
B = im2double(blended);
m3 = repmat(inner, 1, 1, size(A,3));
mse = mean((A(m3) - B(m3)).^2);

if mse == 0
    fidelity = Inf;                 % 像素完全相同（例如 Guided 或硬貼）
else
    fidelity = 10*log10(1/mse);
end
end
