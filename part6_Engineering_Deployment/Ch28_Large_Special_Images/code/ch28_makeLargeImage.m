function [bim, info] = ch28_makeLargeImage(options)
%CH28_MAKELARGEIMAGE 在磁碟上逐塊產生一張大影像，整張從不進記憶體。
%
%   [BIM, INFO] = CH28_MAKELARGEIMAGE() 產生一張合成的大影像
%   （預設 8192×8192 uint8），**一塊一塊寫到磁碟**，
%   回傳指向那個檔案的唯讀 blockedImage。
%
%   INFO 含 FileName、FileMB、InMemoryMB、Seconds、ObjectBytes。
%
%   ## 這支函式要示範的一件事
%   `blockedImage` 物件本身**只有幾個位元組**（本機量到 8 bytes）——
%   它只是一個「影像在哪、長多大、怎麼分塊」的描述。
%   真正的像素在磁碟上，**要用哪一塊才讀哪一塊**。
%
%   這讓你可以處理**遠大於記憶體**的影像：病理切片（WSI）常常是
%   100,000 × 100,000 像素、30 GB，衛星影像更大。
%
%   ## 內容是什麼
%   一個低頻的正弦圖樣加上高斯雜訊，以及幾個**亮斑**（模擬要找的目標）。
%   亮斑的位置由 Seed 決定，INFO.Spots 回傳它們的真實中心，
%   所以下游的偵測結果可以和真值比。
%
%   > **注意 TIFF 檔會比原始資料大**（本機量到 81.7 MB vs 67.1 MB）：
%   > 預設不壓縮，而且每一個 tile 都有標頭。加了雜訊的影像
%   > 本來就壓不太下去，所以這裡沒有開壓縮。
%
%   名稱-值引數：
%     ImageSize  影像尺寸，預設 [8192 8192]
%     BlockSize  分塊大小，預設 [1024 1024]
%     NumSpots   亮斑數量，預設 12
%     FileName   輸出檔名，預設 tempdir 下的 ch28_big.tif
%     Seed       亂數種子，預設 0
%
%   另見 BLOCKEDIMAGE, SETBLOCK, MAKEMULTILEVEL2D.

arguments
    options.ImageSize (1,2) double = [8192 8192]
    options.BlockSize (1,2) double = [1024 1024]
    options.NumSpots  (1,1) double {mustBeNonnegative} = 12
    options.FileName  (1,1) string = fullfile(tempdir, "ch28_big.tif")
    options.Seed      (1,1) double = 0
end

rng(options.Seed);
if isfile(options.FileName)
    delete(options.FileName);
end

sz = options.ImageSize;
bs = options.BlockSize;
nBlocks = ceil(sz ./ bs);

% 亮斑的真實中心（避開影像邊緣）。**一半刻意壓在塊的邊界上**——
% 隨機位置未必碰得到邊界，而跨界的目標正是分塊處理最容易出錯的地方。
spots = [randi([200 sz(2)-200], options.NumSpots, 1), ...
         randi([200 sz(1)-200], options.NumSpots, 1)];
nOnEdge = floor(options.NumSpots / 2);
for k = 1:nOnEdge
    col = randi([1 ceil(sz(2)/bs(2))-1]);
    spots(k,1) = col * bs(2) + randi([-5 5]);      % 壓在垂直的塊邊界上
end
spotRadius = 40;

t0 = tic;
bim = blockedImage(options.FileName, sz, bs, uint8(0), Mode="w");
for r = 1:nBlocks(1)
    for c = 1:nBlocks(2)
        y0 = (r-1)*bs(1);
        x0 = (c-1)*bs(2);
        h = min(bs(1), sz(1)-y0);
        w = min(bs(2), sz(2)-x0);
        [X, Y] = meshgrid(x0 + (1:w), y0 + (1:h));
        block = 110 + 40*sin(X/300) .* cos(Y/400) + 12*randn(h, w);
        for s = 1:size(spots,1)
            d2 = (X - spots(s,1)).^2 + (Y - spots(s,2)).^2;
            block = block + 90 * exp(-d2 / (2*spotRadius^2));
        end
        setBlock(bim, [r c], uint8(block));
    end
end
bim.Mode = "r";
seconds = toc(t0);

bim = blockedImage(options.FileName);
w = whos("bim");

info = struct( ...
    FileName    = options.FileName, ...
    FileMB      = dir(options.FileName).bytes / 1e6, ...
    InMemoryMB  = prod(sz) / 1e6, ...
    Seconds     = seconds, ...
    ObjectBytes = w.bytes, ...
    Spots       = spots, ...
    NumOnEdge   = nOnEdge, ...
    SpotRadius  = spotRadius, ...
    NumBlocks   = prod(nBlocks));
end
