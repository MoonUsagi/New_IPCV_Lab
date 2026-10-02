function report = ch28_blockedFilter(image, options)
%CH28_BLOCKEDFILTER 分塊濾波的接縫研究：BorderSize 要給多少才對。
%
%   REPORT = CH28_BLOCKEDFILTER(IMAGE) 把 IMAGE 包成 blockedImage，
%   用不同的 BorderSize 做分塊高斯濾波，和「整張直接濾」的結果比，
%   回傳 table：
%     BorderSize   每塊往外多讀幾個像素
%     MaxDiff      和整張濾波結果的最大差（灰階）
%     PctWrong     差超過 1 灰階的像素比例（%）
%     Seconds      耗時
%     Exact        MaxDiff == 0
%
%   REPORT.Properties.UserData 含 KernelHalfWidth（核的半寬）
%   與 WholeSeconds（整張直接濾的耗時）。
%
%   ## 為什麼會有接縫
%   分塊處理時，每一塊**只看得到自己的像素**。濾波核在塊的邊緣
%   會伸到塊外——那裡的像素對這一塊來說**不存在**，
%   函式只好用補值（預設是複製邊緣），於是塊與塊之間出現接縫。
%
%   **`BorderSize` 就是「每塊往外多讀幾個像素」。**
%   它必須至少等於**核的半寬**，接縫才會完全消失：
%
%       imgaussfilt 的核大小 = 2*ceil(2*sigma) + 1
%       半寬               = ceil(2*sigma)
%
%   本機實測 σ = 6（半寬 12）：
%   | BorderSize | 最大差 | 錯誤像素 |
%   |---|---|---|
%   | 0 | **38 灰階** | **1.125%** |
%   | 6 | 7 | 0.039% |
%   | **12** | **0** | **0%** |
%
%   **剛好在半寬時變成完全精確。** 少一點就錯、多一點只是浪費。
%
%   > **接縫不會報錯**，而且在縮小的預覽圖上**完全看不出來**——
%   > 1.1% 的像素分布在一條條細線上，要放大到原尺寸才看得到。
%
%   名稱-值引數：
%     Sigma        高斯濾波的 σ，預設 6
%     BlockSize    分塊大小，預設 [256 256]
%     BorderSizes  要測試的邊界，預設 [0 6 12 18 24]
%
%   另見 BLOCKEDIMAGE, APPLY, IMGAUSSFILT.

arguments
    image
    options.Sigma       (1,1) double {mustBePositive} = 6
    options.BlockSize   (1,2) double = [256 256]
    options.BorderSizes (1,:) double = [0 6 12 18 24]
end

if size(image,3) == 3
    image = rgb2gray(image);
end

imgaussfilt(image, options.Sigma);             % 熱身，否則整張的耗時也會失真
t0 = tic;
reference = imgaussfilt(image, options.Sigma);
wholeSeconds = toc(t0);

bim = blockedImage(image, BlockSize=options.BlockSize);
filterFcn = @(block) imgaussfilt(block.Data, options.Sigma);

% **熱身**：第一次呼叫 apply 會付出初始化的代價（本機量到 8 秒 vs 之後 0.2 秒），
% 不先熱身的話，第一個 BorderSize 的耗時會完全失真。
apply(bim, filterFcn, BorderSize=[0 0]);

n = numel(options.BorderSizes);
BorderSize = options.BorderSizes(:);
MaxDiff  = zeros(n,1);
PctWrong = zeros(n,1);
Seconds  = zeros(n,1);
for i = 1:n
    b = options.BorderSizes(i);
    t0 = tic;
    result = gather(apply(bim, filterFcn, BorderSize=[b b]));
    Seconds(i) = toc(t0);
    d = abs(double(result) - double(reference));
    MaxDiff(i)  = max(d(:));
    PctWrong(i) = nnz(d > 1) / numel(d) * 100;
end
Exact = MaxDiff == 0;

report = table(BorderSize, MaxDiff, PctWrong, Seconds, Exact);
report.Properties.UserData = struct( ...
    KernelHalfWidth = ceil(2*options.Sigma), ...
    WholeSeconds    = wholeSeconds, ...
    ImageSize       = size(image), ...
    BlockSize       = options.BlockSize);
end
