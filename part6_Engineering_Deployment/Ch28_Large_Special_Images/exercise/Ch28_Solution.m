%[text] # 第 28 章　練習解答
%[text] {"align":"left"}大型影像與特殊影像模態　｜　MATLAB R2026b
%[text] > **練習 4 有一個我自己犯的切分錯誤**：第一次把 Pavia 上下切，
%[text] > 屋頂全部在上半部，下半部沒有任何正樣本，召回率是 NaN。
%[text] > 那個錯誤和它的修正都留在解答裡。
assert(exist("ch28_blockedFilter", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
testImage = rgb2gray(imresize(imread("peppers.png"), 2));
testBlocks = blockedImage(testImage, BlockSize=[128 128]);
%%
%[text] # 解答 1　`PadMethod` 要對齊誰
avgKernel = fspecial("average", 15);
ops = { "imfilter（預設邊界）",   @(x) imfilter(x, avgKernel),              7;
        "imfilter（replicate）", @(x) imfilter(x, avgKernel, "replicate"), 7;
        "medfilt2 11×11",        @(x) medfilt2(x, [11 11]),                5 };
padNames = ["replicate" "symmetric" "常數 0"];
padValues = {"replicate", "symmetric", uint8(0)};

Operation = strings(0,1);
Pad       = strings(0,1);
Border    = zeros(0,1);
Wrong     = zeros(0,1);
for k = 1:size(ops,1)
    reference = ops{k,2}(testImage);
    half = ops{k,3};
    for p = 1:3
        for b = [0 half]
            J = gather(apply(testBlocks, @(x) ops{k,2}(x.Data), ...
                BorderSize=[b b], PadMethod=padValues{p}));
            Operation(end+1,1) = ops{k,1};   %#ok<AGROW>
            Pad(end+1,1)       = padNames(p); %#ok<AGROW>
            Border(end+1,1)    = b;           %#ok<AGROW>
            Wrong(end+1,1)     = nnz(J ~= reference); %#ok<AGROW>
        end
    end
end
report1 = table(Operation, Pad, Border, Wrong);
disp(report1(report1.Border > 0, :))
%[text] ## 量到的結果（BorderSize = 半寬時的錯誤像素數）
%[text:table]
%[text] | 運算 | replicate | symmetric | **常數 0** |
%[text] | --- | --- | --- | --- |
%[text] | `imfilter`（**預設邊界**） | 24892 | 24892 | **0** ✅ |
%[text] | `imfilter`（`"replicate"`） | **0** ✅ | 4793 | 24892 |
%[text] | `medfilt2`（**預設邊界**） | 11174 | 11596 | **0** ✅ |
%[text:table]
%[text] **第 2、3 小題：每一種運算都恰好有一個 `PadMethod` 完全精確，
%[text] 而那個就是函式自己處理邊緣的方式。**
%[text] - `imfilter` 預設**補 0** → 常數 0
%[text] - `imfilter(..., "replicate")` → replicate
%[text] - `medfilt2` 預設**補 0** → 常數 0
%[text] - `imgaussfilt` 預設 replicate → replicate（主教材 §3）
%[text] - `imopen` 對二值影像 → symmetric（主教材 §3，實測）
%[text] **第 4 小題：規則**
%[text] > **`PadMethod` 必須模擬原函式在影像外緣的補值方式。**
%[text] > `BorderSize` 管塊與塊之間，`PadMethod` 管影像的外緣——
%[text] > 兩者任何一個錯，結果都會和整張處理不同，而且不報錯。
%[text] **第 5 小題：不知道函式怎麼處理邊緣時**
%[text] 就像上面這樣：**三種都試，挑錯誤數為 0 的那一個**。
%[text] 用一張小影像測就好，幾秒鐘的事。這比讀文件可靠——
%[text] `imopen` 的 symmetric 就不是從文件能直接讀出來的。
%%
%[text] # 解答 2　不能分塊的演算法
globalBinary = imbinarize(testImage);
blockBinary = gather(apply(testBlocks, @(x) imbinarize(x.Data)));
fprintf("逐塊 imbinarize：和整張不同的像素 **%.2f%%**\n", ...
    nnz(blockBinary ~= globalBinary)/numel(globalBinary)*100);

globalT = graythresh(testImage);
blockT = gather(apply(testBlocks, @(x) graythresh(x.Data)));
fprintf("全域門檻 %.3f；各塊門檻 %.3f – %.3f\n", globalT, min(blockT(:)), max(blockT(:)));

fixedBinary = gather(apply(testBlocks, @(x) imbinarize(x.Data, globalT)));
fprintf("先算全域門檻再分塊套用：不同像素 %d\n", nnz(fixedBinary ~= globalBinary));

accumT = blockedGraythresh(testBlocks);
fprintf("\n逐塊累加直方圖算出的 Otsu：%.6f（graythresh：%.6f，差 %.2g）\n", ...
    accumT, globalT, abs(accumT - globalT));
%[text] ## 量到的結果
%[text:table]
%[text] | 做法 | 和整張不同的像素 |
%[text] | --- | --- |
%[text] | 逐塊 `imbinarize` | **23.91%** |
%[text] | 先算全域門檻再分塊套用 | **0** |
%[text:table]
%[text] 各塊自己算的 Otsu 門檻從 **0.173 到 0.569**（全域 0.396）——
%[text] **每一塊都在找「自己這一塊」的最佳分界**，暗的塊門檻低、亮的塊門檻高。
%[text] 結果是一張每塊亮度標準都不一樣的二值圖。
%[text] **第 5、6 小題：放不進記憶體時怎麼算全域門檻**
%[text] Otsu 只需要**直方圖**，而直方圖是可加的：
%[text] 每一塊算自己的 256 格直方圖，全部加起來就是整張的直方圖。
%[text] `blockedGraythresh` 的結果和 `graythresh` **完全一致**。
%[text] > **這是分塊處理的一般原則：**
%[text] > 能寫成「每塊一個可加的統計量，最後合併」的演算法就能分塊
%[text] >（直方圖、總和、最大值、計數）；
%[text] > 需要「看到全部才能決定」的就要分兩趟：**第一趟收統計量，第二趟套用**。
%%
%[text] # 解答 3　用錯單位的 HU 門檻
storedCT = double(dicomread("CT-MONO2-16-ankle.dcm"));
[huCT, ~] = ch28_dicomToPhysical("CT-MONO2-16-ankle.dcm");
for th = [300 700]
    nHU = nnz(huCT > th);
    nRaw = nnz(storedCT > th);
    fprintf("骨頭 > %d：HU 得到 %d 像素，誤用儲存值 %d 像素（**%.2f 倍**）\n", ...
        th, nHU, nRaw, nRaw/nHU);
end
fprintf("空氣 < -500：HU 得到 %d 像素，誤用儲存值 **%d 像素**\n", ...
    nnz(huCT < -500), nnz(storedCT < -500));
checkCTUnits(storedCT, "儲存值");
checkCTUnits(huCT, "HU");
%[text] ## 量到的結果
%[text:table]
%[text] | 門檻 | 用 HU | 誤用儲存值 | 倍數 |
%[text] | --- | --- | --- | --- |
%[text] | 骨頭 > 300 | 57380 | 68838 | **1.20** |
%[text] | 皮質骨 > 700 | 47667 | 65438 | **1.37** |
%[text] | 空氣 < −500 | 195415 | **0** | — |
%[text:table]
%[text] **第 3 小題：門檻越高倍數越大**，因為儲存值 = HU + 1024——
%[text] 「儲存值 > 700」等於「HU > −324」，已經把大部分軟組織都算進來了。
%[text] 門檻越高，偏移 1024 的相對影響越大。
%[text] **第 5 小題：空氣那個錯比較容易發現**——整張圖一個像素都沒有，
%[text] 任何人都會起疑。**骨頭那個錯很難發現**：多算 20–37%，
%[text] 結果「看起來是一張骨頭的分割」，只是邊界偏大。
%[text] > **最危險的錯誤是「結果看起來合理但偏了一點」的那種。**
%[text] > 第 27 章的焦距錯 10%、第 25 章的方格邊長錯 1.6% 都是這一類。
%[text] **第 6 小題：守門函式的根據**
%[text] > **CT 影像裡幾乎一定有空氣**（病人身體周圍、肺、腸道），
%[text] > 空氣是 −1000 HU。所以一張真正的 HU 影像，**最小值應該接近 −1000**。
%[text] > 最小值大於 −100 卻宣稱是 HU，幾乎可以確定沒套 rescale。
%[text] 這又是「用已知的物理事實做合理性檢查」——和練習 5、第 27 章同一種推理。
%%
%[text] # 解答 4　光譜門檻能不能移轉
pavia = load("paviaU.mat");
roofGT = load("paviauRoofingGT.mat").paviauRoofingGT;
cube = pavia.paviaU;
roofSig = pavia.signatures(:,5);
%[text] ## 先檢查切分——**我第一次切錯了**
[roofRows, roofCols] = find(roofGT);
fprintf("屋頂的列範圍 %d–%d，欄範圍 %d–%d（影像 %s）\n", ...
    min(roofRows), max(roofRows), min(roofCols), max(roofCols), mat2str(size(roofGT)));
topHalf = false(size(roofGT)); topHalf(1:305,:) = true;
fprintf("上下切（第 305 列）：上半 %d 個屋頂像素，下半 **%d 個**\n", ...
    nnz(roofGT & topHalf), nnz(roofGT & ~topHalf));
%[text] **屋頂全部在上半部**（它們是同一棟建物），下半部一個正樣本都沒有——
%[text] 在下半部算召回率會得到 `0/0 = NaN`。
%[text] > **切分資料之前，先看正樣本在哪裡。**
%[text] > 這和第 17 章「區塊切分反而洩漏更多」同一類：
%[text] > 空間上的切分會和目標的空間分布互動。
for cut = [150 170]
    left = false(size(roofGT)); left(:,1:cut) = true;
    fprintf("左右切在第 %d 欄：左半 %d、右半 %d 個屋頂像素\n", ...
        cut, nnz(roofGT & left), nnz(roofGT & ~left));
end

methodNames = ["sam" "sid" "sidsam" "jmsam" "ns3"];
scores = cell(1, numel(methodNames));
for m = 1:numel(methodNames)
    scores{m} = feval(methodNames(m), cube, roofSig);
end

for cut = [150 170]
    left = false(size(roofGT)); left(:,1:cut) = true;
    fprintf("\n切在第 %d 欄：左半校準（召回 90%%）→ 右半測試\n", cut);
    for m = 1:numel(methodNames)
        s = scores{m};
        sortedPos = sort(s(left & roofGT));
        thr = sortedPos(ceil(0.9*numel(sortedPos)));
        pred = s(~left) <= thr;
        lab  = roofGT(~left);
        fprintf("  %-7s 門檻 %-10.4g 右半召回 %.3f，精確 %.3f\n", methodNames(m), thr, ...
            nnz(pred & lab)/nnz(lab), nnz(pred & lab)/max(1, nnz(pred)));
    end
end

left = false(size(roofGT)); left(:,1:150) = true;
samScore = scores{1};
sortedPos = sort(samScore(left & roofGT));
samThr = sortedPos(ceil(0.9*numel(sortedPos)));
fprintf("\n把 sam 的門檻 %.4f 直接套到其他方法（右半）：\n", samThr);
for m = [2 5 4]
    pred = scores{m}(~left) <= samThr;
    fprintf("  %-7s 判為屋頂 %.2f%%，召回 %.3f\n", methodNames(m), ...
        nnz(pred)/numel(pred)*100, nnz(pred & roofGT(~left))/nnz(roofGT(~left)));
end
%[text] ## 量到的結果（切在第 150 欄）
%[text:table]
%[text] | 方法 | 右半召回 | 右半精確 |
%[text] | --- | --- | --- |
%[text] | `sam` | 0.929 | 0.647 |
%[text] | `sid` | 0.942 | 0.716 |
%[text] | `sidsam` | 0.938 | **0.788** |
%[text] | `jmsam` | 0.904 | 0.454 |
%[text] | `ns3` | 0.886 | 0.264 |
%[text:table]
%[text] **第 3 小題：召回率移轉得過去**（左半校準在 90%，右半 0.89–0.94）。
%[text] **第 4 小題：精確率移轉不過去。** 切在第 170 欄時，同樣的做法
%[text] `sam` 的右半精確率從 **0.647 掉到 0.280**。
%[text] 門檻幾乎一樣，但右半只剩 98 個屋頂像素、負樣本卻多了一大堆——
%[text] **精確率取決於盛行率**，換一個區域、正樣本比例不同，精確率就跟著變。
%[text] > 召回率只看正樣本自己的分數分布，所以移轉得過去；
%[text] > 精確率還要看負樣本有多少，所以**隨場景而變**。
%[text] > 這和第 22 章「過殺率要用產線的真實瑕疵率算」是同一件事。
%[text] **第 5 小題：跨方法套門檻完全失效。**
%[text:table]
%[text] | 套 `sam` 的門檻到 | 判為屋頂 | 召回 |
%[text] | --- | --- | --- |
%[text] | `sid` | **0.00%** | 0.005 |
%[text] | `ns3` | **0.00%** | 0.000 |
%[text] | `jmsam` | **100.00%** | 1.000 |
%[text:table]
%[text] 分數的尺度差太多，同一個數字在一個方法裡是「很像」，
%[text] 在另一個方法裡是「完全不像」或「什麼都像」。
%[text] **第 6 小題：光譜門檻能移轉到哪裡**
%[text:table]
%[text] | 移轉 | 可以嗎 |
%[text] | --- | --- |
%[text] | 同方法、同場景、不同區域的**召回率** | ✅ |
%[text] | 同方法、不同區域的**精確率** | ❌ 隨盛行率變 |
%[text] | **不同方法之間** | ❌ **完全不行** |
%[text:table]
%%
%[text] # 解答 5　體素間距的合理性檢查
brainInfo = niftiinfo("brain.nii");
checkVoxelSpacing(brainInfo.ImageSize, brainInfo.PixelDimensions, [150 180 130], "brain.nii（成人頭部）");
mriVol = squeeze(load("mri").D);
checkVoxelSpacing(size(mriVol), [1 1 1], [150 180 130], "mri.mat（假設 1 mm）");
kneeInfo = dicominfo("knee1.dcm");
checkVoxelSpacing([kneeInfo.Rows kneeInfo.Columns], double(kneeInfo.PixelSpacing(:))', ...
    [160 160], "knee1.dcm（膝關節視野）");
%[text] **第 2 小題：預期範圍的依據**是解剖學的常識：
%[text] 成人頭部大約 15 × 18 × 13 公分，膝關節的 MR 視野通常 14–18 公分。
%[text] `knee1.dcm` 的 512 × 0.3125 mm = **16 公分**，合理，通過。
%[text] `brain.nii` 與 `mri.mat` 的**層方向**只有 2.1 / 2.7 公分，被抓出來了。
%[text] **第 3 小題：這個檢查能抓到什麼**
%[text:table]
%[text] | 能抓到 | 抓不到 |
%[text] | --- | --- |
%[text] | 間距差好幾倍（預設值、單位 m/mm 搞錯） | **差 10–20% 的錯** |
%[text] | 某個方向明顯荒謬 | 預期值本身填錯 |
%[text:table]
%[text] 它是一個**粗篩**：只能擋住荒謬的數字，擋不住「合理但不對」的數字。
%[text] 要驗證到 10% 以內，只能**掃一個已知尺寸的假體（phantom）**。
%[text] **第 4 小題：和第 27 章是同一種推理嗎？是。**
%[text] > **用一個你獨立知道的物理量，去檢驗系統報出來的數字是否荒謬。**
%[text] > 第 27 章是「標記離相機多遠」，這裡是「一顆頭多大」，
%[text] > 解答 3 是「CT 裡一定有空氣」。
%[text] > 它們都抓不到小錯，但**都能在幾秒內擋住大錯**——而大錯正是
%[text] > 預設值、單位搞錯、欄位缺漏這類「不報錯」的問題最常造成的。
%%
%[text] # 解答 6　處理你自己的大影像
%[text] 這一題沒有標準答案，但**有一個必須做的檢查**：
%[text] **拿一小塊，和整張處理的結果比一次**（主教材 §3）。
%[text] 下面用 `ch28_makeLargeImage` 示範那個檢查的寫法：
[bigImg, bigInfo] = ch28_makeLargeImage(ImageSize=[4096 4096]);
region = [1 1; 1536 1536];                            % [起點; 終點]
crop = getRegion(bigImg, region(1,:), region(2,:));
cropRef = imgaussfilt(crop, 6);
cropBlocks = blockedImage(crop, BlockSize=[512 512]);
cropOut = gather(apply(cropBlocks, @(b) imgaussfilt(b.Data, 6), BorderSize=[12 12]));
fprintf("抽樣檢查 %s 的區域：分塊結果和整張結果的最大差 %d\n", ...
    mat2str(size(crop)), max(abs(double(cropOut(:)) - double(cropRef(:)))));
%[text] **用 `getRegion` 取一塊放得進記憶體的區域**，兩種做法都跑一次比較。
%[text] 那塊區域要**跨過好幾個塊邊界**，檢查才有意義。
%%
%[text] # 加分題　NDVI 的波段是誰決定的
hc = imhypercube("paviaU.dat");
wl = hc.Wavelength;
hsCube = gather(hc);
builtinNDVI = ndvi(hc);
pairs = [670 800; 650 830; 700 760; 620 838];
RedNm = zeros(4,1); NirNm = zeros(4,1); VegPct = zeros(4,1); CorrBuiltin = zeros(4,1);
for i = 1:4
    [~, r] = min(abs(wl - pairs(i,1)));
    [~, n] = min(abs(wl - pairs(i,2)));
    R = hsCube(:,:,r); N = hsCube(:,:,n);
    v = (N - R) ./ (N + R + eps);
    RedNm(i) = wl(r); NirNm(i) = wl(n);
    VegPct(i) = nnz(v > 0.4)/numel(v)*100;
    CorrBuiltin(i) = corr(v(:), builtinNDVI(:));
end
disp(table(RedNm, NirNm, VegPct, CorrBuiltin, ...
    VariableNames=["紅nm" "近紅外nm" "植被覆蓋%" "和內建相關"]))
fprintf("內建 ndvi 的植被覆蓋：%.1f%%" + "\n", nnz(builtinNDVI > 0.4)/numel(builtinNDVI)*100);
%[text] ## 量到的結果
%[text:table]
%[text] | 紅 | 近紅外 | 植被覆蓋 | 和內建相關 |
%[text] | --- | --- | --- | --- |
%[text] | **670** | **798** | **40.8%** | **1.000** |
%[text] | 650 | 830 | 41.2% | 0.995 |
%[text] | 698 | 758 | **28.1%** | 0.987 |
%[text] | 618 | 838 | 43.9% | 0.985 |
%[text:table]
%[text] **第 3 小題：內建 `ndvi` 用的是 670 / 798 nm**——
%[text] 相關係數 1.000、覆蓋率完全一樣（40.8%）。
%[text] **第 4 小題：相關 0.987，覆蓋率卻從 40.8% 變成 28.1%。**
%[text] 相關係數量的是「排序是否一致」，而覆蓋率是**門檻（0.4）之上有多少**。
%[text] 700/760 那組的近紅外波段落在**紅邊**（red edge，植物反射率急遽上升的區間），
%[text] 整體 NDVI 值偏低，同一個 0.4 門檻切下去就少了三分之一。
%[text] > **高相關不代表結論一樣——只要結論依賴一個絕對門檻。**
%[text] > 這和練習 4「分數尺度不同門檻就不能移轉」是同一件事：
%[text] > **排序一致的兩個指標，絕對值可以差很多。**
%[text] **第 5 小題：Hyperion 的波段是 356–2577 nm**，
%[text] 紅與近紅外都在範圍內，但它的波段位置不同，
%[text] **要用最接近 670 / 800 nm 的波段**，而且最好在報告裡寫明用了哪兩個。

% ========================================================================
% 本解答用到的本地函式

function T = blockedGraythresh(bim)
%BLOCKEDGRAYTHRESH 逐塊累加 256 格直方圖，再算 Otsu 門檻。
%   直方圖是可加的，所以放不進記憶體的影像也能算全域門檻。
counts = gather(apply(bim, @(b) imhist(b.Data, 256)'));
total = sum(reshape(counts', 256, []), 2);
T = otsuthresh(total);
end

% ------------------------------------------------------------------------
function checkCTUnits(values, label)
%CHECKCTUNITS CT 影像裡一定有空氣（約 −1000 HU），最小值太高就不是 HU。
mn = min(values(:));
if mn > -100
    fprintf("  ⚠ [%s] 最小值 %.0f > −100：這不像 HU（CT 裡應該有 −1000 的空氣）\n", label, mn);
else
    fprintf("  ✓ [%s] 最小值 %.0f：符合 HU 的預期\n", label, mn);
end
end

% ------------------------------------------------------------------------
function checkVoxelSpacing(sz, spacing, expectedMm, label)
%CHECKVOXELSPACING 物理範圍（體素數 × 間距）和預期差超過 2 倍就警告。
n = min(numel(sz), numel(expectedMm));
extent = double(sz(1:n)) .* double(spacing(1:n));
ratio = extent ./ expectedMm(1:n);
bad = ratio < 0.5 | ratio > 2;
fprintf("\n%s\n", label);
for k = 1:n
    mark = "✓";
    if bad(k), mark = "⚠"; end
    fprintf("  %s 方向 %d：%d × %.4g mm = %.1f mm（預期約 %d mm，比值 %.2f）\n", ...
        mark, k, sz(k), spacing(k), extent(k), expectedMm(k), ratio(k));
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
