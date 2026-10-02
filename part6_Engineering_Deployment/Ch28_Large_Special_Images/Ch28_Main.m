%[text] # 第 28 章　大型影像與特殊影像模態
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出什麼時候**真的需要** `blockedImage`，以及它的代價
%[text] 2. 設定正確的 `BorderSize`，並知道它**剛好要等於核的半寬**
%[text] 3. 處理跨越塊邊界的目標：**不被切半、也不被重複計數**
%[text] 4. 把 DICOM 的儲存值轉成物理單位，並檢查檔案**缺了什麼**
%[text] 5. 對體積資料的體素間距做合理性檢查
%[text] 6. 用高光譜資料做光譜比對，並知道**AUC 在類別不平衡時會說謊**
%[text] ## 前置知識
%[text] 第 4 章（濾波與核）、第 8 章（門檻）、第 20 章（類別不平衡）、
%[text] 第 25–27 章（外部長度的結論）。
%[text] ## 環境需求
%[text] Image Processing Toolbox。§7 需要 **Hyperspectral Imaging Library for
%[text] Image Processing Toolbox**；§6 的 `medicalVolume` 需要 Medical Imaging Toolbox。
%[text] > ## **本章的一句話**
%[text] > **「換一種影像」最危險的地方不是新的函式，是新的單位。**
%[text] > DICOM 的儲存值差 1024、體積標頭的間距是預設值、
%[text] > 光譜分數的尺度差五個數量級——**全部不報錯。**
assert(exist("ch28_blockedFilter", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 1. 這一章的位置：影像不再是「一張放得進記憶體的 RGB」
%[text:table]
%[text] | 類型 | 典型大小 | 問題 |
%[text] | --- | --- | --- |
%[text] | 病理切片（WSI） | 100,000 × 100,000，30 GB | **放不進記憶體** |
%[text] | 衛星影像 | 更大，多波段 | 同上 |
%[text] | CT／MR | 512 × 512 × 數百層 | **單位與間距** |
%[text] | 高光譜 | 610 × 340 × **103 個波段** | 每個像素是一條光譜，不是一個顏色 |
%[text:table]
%[text] 前 27 章的所有技巧**原則上都能用**——
%[text] 本章處理的是「換了資料型態之後，哪些假設不成立了」。
%%
%[text] # 2. `blockedImage`：什麼時候才需要它
peppersBig = rgb2gray(imresize(imread("peppers.png"), 4));
fprintf("測試影像 %dx%d（%.1f MB，放得進記憶體）\n", ...
    size(peppersBig,2), size(peppersBig,1), numel(peppersBig)/1e6);

filterFcn = @(block) imgaussfilt(block.Data, 6);
imgaussfilt(peppersBig, 6);                             % 熱身
t0 = tic; imgaussfilt(peppersBig, 6); tWhole = toc(t0);

blockSizes = [64 128 256 512 1024]';
Seconds = zeros(numel(blockSizes),1);
NumBlocks = zeros(numel(blockSizes),1);
for i = 1:numel(blockSizes)
    b = blockSizes(i);
    bi = blockedImage(peppersBig, BlockSize=[b b]);
    % **每個物件都要先熱身。** 第一次對一個新的 blockedImage 呼叫 apply
    % 會付出初始化成本；不熱身時塊大小 64 量到 6.1 秒，熱身後不到 1 秒。
    apply(bi, filterFcn, BorderSize=[12 12]);
    t0 = tic;
    apply(bi, filterFcn, BorderSize=[12 12]);
    Seconds(i) = toc(t0);
    NumBlocks(i) = prod(ceil(size(peppersBig) ./ [b b]));
end
disp(table(blockSizes, NumBlocks, Seconds, Seconds/tWhole, ...
    VariableNames=["塊大小" "塊數" "秒" "相對整張"]))
fprintf("整張直接 imgaussfilt：%.3f 秒\n", tWhole);
%[text] **放得進記憶體的時候，`blockedImage` 永遠比較慢**——
%[text] 塊越小越慢（每一塊都有讀取、補邊、呼叫、寫回的固定成本）。
%[text] > **`blockedImage` 不是加速工具，是「放不進記憶體時唯一的辦法」。**
%[text] > 影像放得進記憶體，就直接處理。
%[text] > 這和第 23 章「`parfor` 在這裡沒用」是同一種判斷：
%[text] > **切開來處理有固定成本，只有在不切就做不到時才值得付。**
%%
%[text] # 3. 接縫：`BorderSize` 要剛好等於核的半寬
seamReport = ch28_blockedFilter(peppersBig, Sigma=6, BorderSizes=[0 6 11 12 18]);
disp(seamReport)
fprintf("高斯核（σ=6）的半寬：%d 像素\n", seamReport.Properties.UserData.KernelHalfWidth);
%[text:table]
%[text] | BorderSize | 最大差 | 錯誤像素 |
%[text] | --- | --- | --- |
%[text] | **0** | **38 灰階** | **1.125%** |
%[text] | 6 | 7 | 0.039% |
%[text] | **12（= 半寬）** | **0** | **0%** |
%[text:table]
%[text] **剛好在核的半寬（`ceil(2σ)` = 12）時變成完全精確。**
%[text] 少一點就錯，多一點只是多讀資料。
%[text] > ## **接縫不會報錯，而且在縮小的預覽上完全看不出來。**
%[text] > 1.1% 的錯誤像素排成一條條細線，
%[text] > 要放大到原尺寸、而且剛好看在塊邊界上才看得到。
%[text] > **做完分塊處理，一定要拿一小塊和整張處理的結果比一次。**
%[text] ## 換成形態學：兩個我原本會寫錯的地方
binaryBig = rgb2gray(imresize(imread("peppers.png"), 2)) > 110;
se5 = strel("disk", 5);
fprintf("strel(""disk"", 5) 的鄰域：%s（半寬 %d，**不是 5**）\n", ...
    mat2str(size(se5.Neighborhood)), (size(se5.Neighborhood,1)-1)/2);
openRef = imopen(binaryBig, se5);
binBlocks = blockedImage(binaryBig, BlockSize=[128 128]);
openFcn = @(x) imopen(x.Data, se5);
fprintf("\n%-28s %s\n", "設定", "錯誤像素");
for b = [0 4 8]
    J = gather(apply(binBlocks, openFcn, BorderSize=[b b]));
    fprintf("%-28s %d\n", sprintf("BorderSize=%d", b), nnz(J ~= openRef));
end
Jsym = gather(apply(binBlocks, openFcn, BorderSize=[8 8], PadMethod="symmetric"));
fprintf("%-28s %d\n", "BorderSize=8 + symmetric", nnz(Jsym ~= openRef));
%[text:table]
%[text] | 設定 | 錯誤像素 |
%[text] | --- | --- |
%[text] | `BorderSize=0` | 569 |
%[text] | `BorderSize=8`（= 2 × 半寬） | **65**（卡住了） |
%[text] | `BorderSize=8` + `PadMethod="symmetric"` | **0** |
%[text:table]
%[text] **第一個錯**：`strel("disk", 5)` 的鄰域是 **9×9**（半寬 4），
%[text] 因為預設用了近似分解。**不要從參數猜核的大小，要看 `Neighborhood`。**
%[text] **第二個錯**：邊界給夠之後還剩 65 個錯誤像素，而且**全部在影像外緣 3 像素內**。
%[text] 那不是塊之間的接縫，是 `apply` 在**影像外緣**補值的規則（預設複製）
%[text] 和 `imopen` 自己處理邊緣的規則不同。改成 `"symmetric"` 就完全一致。
%[text] > **分塊處理要對齊兩件事：**
%[text] > **塊與塊之間**靠 `BorderSize`（要涵蓋整個運算鏈的影響範圍——
%[text] > 開運算是侵蝕再膨脹，所以是 2 × 半寬）；
%[text] > **影像外緣**靠 `PadMethod` 對齊原函式的補邊規則。
%[text] > 高斯濾波剛好兩者預設都是複製，所以 §3 沒有碰到第二個問題。
%[text:table]
%[text] | 運算 | 需要的 BorderSize | PadMethod |
%[text] | --- | --- | --- |
%[text] | `imgaussfilt(I, σ)` | `ceil(2σ)` | 預設即可（實測完全精確） |
%[text] | `imfilter(I, h)` | `floor(size(h)/2)` | 要對齊 `imfilter` 的邊界選項 |
%[text] | `imopen(I, se)` | **2 × 鄰域半寬** | **`"symmetric"`**（實測） |
%[text] | 任何**非局部**運算（全域門檻、`graythresh`） | **沒有夠大的值** | — |
%[text:table]
%[text] 最後一列最容易踩到：**`imbinarize(block.Data)` 在每一塊算出不同的 Otsu 門檻**，
%[text] 結果是一張「每塊亮度都不一致」的二值圖。這不是接縫，是**演算法本身不能分塊**。
%%
%[text] # 4. 真的放不進記憶體：在磁碟上逐塊產生、逐塊處理
[bigImage, bigInfo] = ch28_makeLargeImage();
fprintf("大影像 %s，%d 塊，寫檔 %.1f 秒\n", mat2str(bigImage.Size), ...
    bigInfo.NumBlocks, bigInfo.Seconds);
fprintf("磁碟上 %.1f MB（原始資料 %.1f MB）\n", bigInfo.FileMB, bigInfo.InMemoryMB);
fprintf("**blockedImage 物件本身：%d bytes**\n", bigInfo.ObjectBytes);
%[text] 物件只是一個描述：「影像在哪個檔、多大、怎麼分塊」。
%[text] **像素在磁碟上，用到哪一塊才讀哪一塊。**
%[text] 這張 8192×8192 只有 67 MB，是為了讓教材能在幾秒內跑完；
%[text] **程式碼對 100,000×100,000 的影像完全一樣**。
if ipcvFast()
    disp("（快速模式：略過多解析度金字塔的建置）")
else
    % **makeMultiLevel2D 預設寫到「原檔名_multiLevel.tiff」而且拒絕覆寫**，
    % 教材第二次執行就會報「already exists. Cannot overwrite.」。
    % 要給明確的 OutputLocation，並先清掉舊檔。
    pyramidFile = fullfile(tempdir, "ch28_pyramid.tif");
    if isfile(pyramidFile), delete(pyramidFile); end
    t0 = tic;
    pyramid = makeMultiLevel2D(bigImage, Scales=[1 0.25 0.0625], ...
        OutputLocation=pyramidFile);
    fprintf("\n多解析度金字塔：%d 層，%.1f 秒\n", pyramid.NumLevels, toc(t0));
    disp(pyramid.Size)
end
%[text] **金字塔是看大影像的標準做法**：`bigimageshow` 會依縮放程度
%[text] 自動挑適合的層，縮小時讀 512×512 的那層，放大時才讀原解析度。
%[text] 病理切片的檔案格式（SVS、NDPI）本身就內建好幾層。
%%
%[text] # 5. 跨越塊邊界的目標：被切半，或被重複計數
fprintf("真值：%d 個亮斑，其中 **%d 個刻意壓在塊邊界上**\n", ...
    size(bigInfo.Spots,1), bigInfo.NumOnEdge);
truth  = bigInfo.Spots;
onEdge = (1:size(truth,1))' <= bigInfo.NumOnEdge;

settings = {0 false; 64 false; 64 true};
Setting  = strings(3,1);
Detected = zeros(3,1);
Matched  = zeros(3,1);
Duplicates = zeros(3,1);
EdgeError  = zeros(3,1);
for i = 1:3
    [cents, ~] = ch28_findSpots(bigImage, BorderSize=settings{i,1}, ...
        KeepCoreOnly=settings{i,2});
    d = pdist2(truth, cents);
    nearest = min(d, [], 2);
    matchedTruth = nearest < 10;
    closeDet = min(d, [], 1) < 10;
    Setting(i)    = sprintf("Border=%d, 只留核心=%d", settings{i,1}, settings{i,2});
    Detected(i)   = size(cents,1);
    Matched(i)    = nnz(matchedTruth);
    Duplicates(i) = nnz(closeDet) - nnz(matchedTruth);
    EdgeError(i)  = median(nearest(onEdge));
end
disp(table(Setting, Detected, Matched, Duplicates, EdgeError, ...
    VariableNames=["設定" "偵測數" "配到真值" "重複" "邊界斑誤差px"]))
%[text:table]
%[text] | 設定 | 偵測數 | 配到真值 | 問題 |
%[text] | --- | --- | --- | --- |
%[text] | Border = 0 | 13 | **7 / 12** | 邊界斑被切成兩半，**錯位 24.5 px** |
%[text] | Border = 64 | 13 | 9 / 12 | 位置對了，但 **4 個重複計數** |
%[text] | **Border = 64 + 只留核心** | **9** | **9 / 12** | 正確 |
%[text:table]
%[text] > ## **修好一個問題，換來另一個問題。**
%[text] > 加 `BorderSize` 讓每塊看得到鄰居的邊緣——跨界的斑不再被切半，
%[text] > 但**同一個斑被兩塊各找到一次**。
%[text] > 正確的做法是：**每塊只保留質心落在自己核心區的偵測**。
%[text] > **一個 API 坑**：設了 `BorderSize` 之後，`block.Start`／`block.End`
%[text] > **是含邊界的範圍**。本機實測 100×100 的塊、`BorderSize=10`，
%[text] > 第 [2 2] 塊的核心是 101–200，但 `Start`=91、`End`=210。
%[text] > 我第一版以為 `Start` 是核心起點而多減了一次邊界，
%[text] > 結果**每個偵測都偏了 $b\sqrt{2}$**（64 → 91.8 像素）——不報錯。
%[text] ## 那 3 個漏掉的呢？
d = pdist2(truth, ch28_findSpots(bigImage, BorderSize=64, KeepCoreOnly=true));
missed = find(min(d, [], 2) >= 10);
for k = missed'
    bg = 110 + 40*sin(truth(k,1)/300)*cos(truth(k,2)/400);
    fprintf("漏掉 (%d, %d)：背景 %.0f，峰值約 %.0f（門檻 170）\n", ...
        truth(k,1), truth(k,2), bg, bg + 90);
end
%[text] **三個都在背景最暗的地方**，峰值低於門檻。
%[text] 三種分塊設定都漏了同樣的三個——**那是第 8 章的全域門檻問題，
%[text] 不是分塊的問題**。把兩種失敗分開診斷，才不會去調錯的參數。
%%
%[text] # 6. 醫學影像：儲存值不是物理值
[huValues, ctReport] = ch28_dicomToPhysical("CT-MONO2-16-ankle.dcm");
fprintf("CT 踝關節：%s，%s\n", ctReport.Modality, mat2str(ctReport.Size));
fprintf("  dicomread 的儲存值：%s（%s）\n", mat2str(ctReport.StoredRange), ctReport.StoredClass);
fprintf("  RescaleSlope %g，RescaleIntercept %g\n", ctReport.Slope, ctReport.Intercept);
fprintf("  **轉換後的 HU：%s**\n", mat2str(ctReport.PhysicalRange));
for w = ctReport.Warnings'
    fprintf("  ⚠ %s\n", w);
end
%[text:table]
%[text] | | 值 |
%[text] | --- | --- |
%[text] | `dicomread` 的範圍 | **32 .. 4080** |
%[text] | RescaleIntercept | **−1024** |
%[text] | 轉換後（Hounsfield Unit） | **−992 .. 3056** |
%[text:table]
%[text] > ## **`dicomread` 回傳的是儲存值，不是 HU。**
%[text] > 直接拿來當 HU 用，**所有數字都偏 1024**：空氣（−1000 HU）讀成 24，
%[text] > 水（0 HU）讀成 1024。用 HU 門檻分骨頭或肺的程式**完全失效，而且不報錯**。
%[text] **而且這個檔案沒有 `PixelSpacing`。** 沒有間距就不能量長度。
%[text] `ch28_dicomToPhysical` 把缺漏列成警告，**不會安靜地假設 1 mm**。
figure;
tiledlayout(1,2, TileSpacing="compact");
nexttile; imshow(dicomread("CT-MONO2-16-ankle.dcm"), []); title("儲存值")
nexttile; imshow(huValues, [-200 1500]); title("HU（窗寬 −200..1500）")
colorbar
for f = ["knee1.dcm" "US-PAL-8-10x-echo.dcm"]
    [~, r] = ch28_dicomToPhysical(f);
    fprintf("%-24s %s，%s，間距 %s，警告 %d 條\n", f, r.Modality, ...
        mat2str(r.Size), mat2str(r.PixelSpacing), numel(r.Warnings));
end
%[text] 超音波檔是 `430×600×1×10`——**第四維是時間**（10 幀）。
%[text] DICOM 的維度意義要看標頭，不能假設第三維是深度。
%[text] ## 體積資料：標頭說的間距，可以不是真的
mriVol = squeeze(load("mri").D);
mv = medicalVolume("brain.nii");
fprintf("\nbrain.nii：%s，VoxelSpacing %s，SpaceUnits %s\n", ...
    mat2str(size(mv.Voxels)), mat2str(mv.VoxelSpacing), niftiinfo("brain.nii").SpaceUnits);
fprintf("mri.mat：%s（沒有任何間距資訊）\n", mat2str(size(mriVol)));
%[text] 兩個檔案都宣稱（或預設）體素是 **1 × 1 × 1 mm**。**做一次合理性檢查：**
%[text:table]
%[text] | 方向 | 體素數 × 1 mm | 一顆成人頭部 |
%[text] | --- | --- | --- |
%[text] | 左右 | 128 → **12.8 cm** | 約 15 cm |
%[text] | 上下（層） | 27 → **2.7 cm** | 約 20 cm |
%[text:table]
%[text] **27 層 × 1 mm 裝不下一顆腦。** 標頭裡的 `[1 1 1]` 是**預設值**，不是量測值。
%[text] 真實的層間距大概是好幾公釐——但**從這個檔案無法得知**。
%[text] > ## **這是第 25–27 章那個結論在醫學影像上的版本。**
%[text] > 體素間距是**從外面來的資訊**。檔案沒有，或只給預設值，
%[text] > 所有體積與距離的量測就**差一個未知的比例**。
%[text] > **能做的只有合理性檢查**：用你已知的物理尺寸（一顆頭多大）
%[text] > 去檢驗標頭的數字是否荒謬。
%[text] > 這一招對所有「外部長度」都適用——第 27 章量標記距離時，
%[text] > 「標記離相機 50 公分」合不合理，也是同樣的檢查。
if ~ipcvFast()
    figure;
    volshow(mriVol);
end
%[text] `volshow` 建立的是 `images.ui.graphics.Volume` 物件，
%[text] R2026a 的 Volume Viewer APP 大改版（電影級渲染、最小強度投影、
%[text] 切片平面、`linkviewers` 多視圖同步）。**互動式的部分本章無法自動驗證**。
%%
%[text] # 7. 高光譜：每個像素是一條光譜
hc = imhypercube("paviaU.dat");
cube = gather(hc);
fprintf("Pavia University：%s，%d 個波段，%.0f – %.0f nm\n", ...
    mat2str(size(cube)), numel(hc.Wavelength), min(hc.Wavelength), max(hc.Wavelength));
fprintf("類別：%s\n", class(hc));
figure;
tiledlayout(1,2, TileSpacing="compact");
nexttile; imshow(colorize(hc, Method="rgb")); title("colorize：挑三個波段當 RGB")
nexttile; imshow(ndvi(hc), [-1 1]); colormap(gca, parula); colorbar; title("NDVI")
%[text] > **R2026a 的 `imhypercube` 回傳 `hyper.io.hypercube`**，
%[text] > `colorize` 是它的**方法**（`exist("colorize")` 回傳 0）。
%[text] ## 光譜比對：五種方法，同一個問題
%[text] 目標：找出屋頂。Pavia 附了 9 類材料的光譜特徵，以及一張屋頂的真值遮罩。
pavia = load("paviaU.mat");
roofGT = load("paviauRoofingGT.mat").paviauRoofingGT;
fprintf("屋頂像素 %d（**%.1f%%**）\n", nnz(roofGT), nnz(roofGT)/numel(roofGT)*100);

classAUC = zeros(1,9);
for k = 1:9
    s = sam(cube, pavia.signatures(:,k));
    [~, ~, ~, classAUC(k)] = perfcurve(roofGT(:), -s(:), true);
end
disp(array2table(round(classAUC,3), VariableNames="類別" + string(1:9)))
[~, roofClass] = max(classAUC);
fprintf("屋頂最像類別 %d（塗漆金屬板），AUC %.3f\n", roofClass, classAUC(roofClass));
%[text] 類別 2（草地）的 AUC 是 **0.012**——那不是「很差」，
%[text] 是「**非常確定地相反**」：草地和屋頂是最不像的兩種材料。
%[text] AUC 遠離 0.5 的**任一邊**都是資訊，符號約定搞反就會解讀錯。
specReport = ch28_spectralCompare(cube, pavia.signatures(:,roofClass), roofGT);
disp(specReport)
%[text] ## 量到的結果
%[text:table]
%[text] | 方法 | AUC | **AP** | **召回 90% 時精確率** | 分數範圍 | 耗時 |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | `sam` | 0.997 | 0.923 | 0.683 | 0.010 – 1.09 | 0.17 s |
%[text] | `sid` | 0.997 | 0.926 | 0.747 | 0.066 – 1082 | 0.24 s |
%[text] | **`sidsam`** | **0.998** | **0.936** | **0.792** | 0.0008 – 1757 | **7.5 s** |
%[text] | `jmsam` | 0.994 | 0.794 | 0.443 | 1.5e-09 – 0.036 | 0.14 s |
%[text] | `ns3` | 0.975 | **0.665** | **0.261** | 38.6 – 4424 | 0.09 s |
%[text:table]
%[text] **三件事：**
%[text] 1. **AUC 在類別不平衡時說謊。** 五個方法的 AUC 都在 0.975 以上，
%[text]    看起來都很好；但**召回 90% 時，`ns3` 的清單裡只有 26% 是屋頂**。
%[text]    屋頂只佔 1.1%——把 98.9% 的非屋頂排到後面就能拿到很高的 AUC。
%[text]    **這是第 20 章的同一個問題。**
%[text] 2. **分數的尺度差五個數量級**（`jmsam` 最大 0.036、`ns3` 最大 4424）。
%[text]    **一個方法上調好的門檻，換另一個方法完全沒有意義**——
%[text]    第 21 章「CLIP 的門檻轉移不過去」同源。
%[text] 3. **`sidsam` 最好，但慢 44 倍**，只比 `sid` 多 0.013 的 AP。
%[text] 最後一個對照：用**真值區域的平均光譜**當參考（等於偷看答案），
%[text] AUC 反而是 0.9971，**比光譜庫的特徵（0.9973）還低**。
%[text] 光譜庫的特徵已經和場景內的平均一樣好——**偷看答案沒有幫助。**
%%
%[text] # 8. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 處理 |
%[text] | --- | --- | --- |
%[text] | 放得進記憶體還用 `blockedImage` | 慢 1.7–100 倍（塊越小越慢） | 直接處理 |
%[text] | `BorderSize` 小於核半寬 | 接縫，1% 像素錯，**預覽看不出來** | 至少 `ceil(2σ)`；和整張結果比一次 |
%[text] | 從參數猜形態學核的大小 | `disk` 5 其實是 9×9 | 看 `se.Neighborhood` |
%[text] | 邊界夠了還是差一點 | 錯誤全在影像外緣 | `PadMethod` 對齊原函式（形態學用 `"symmetric"`） |
%[text] | 在每塊做全域門檻 | 每塊亮度不一致 | 先算全域統計量再分塊套用 |
%[text] | 以為 `block.Start` 是核心起點 | 每個偵測偏 $b\sqrt{2}$ | **設了 BorderSize 後 Start/End 含邊界** |
%[text] | 有 BorderSize 但沒過濾核心區 | 跨界目標被重複計數 | 只留質心在核心的偵測 |
%[text] | `apply` 的函式回傳 cell | 「Unsupported output」 | 回傳數值、logical、scalar struct 或 categorical |
%[text] | `makeMultiLevel2D` 不給輸出位置 | **第二次執行**報「Cannot overwrite」 | 給 `OutputLocation` 並先刪舊檔 |
%[text] | 計時沒先熱身 | 第一個設定慢 6 倍以上 | 每個新物件先 `apply` 一次 |
%[text] | 把 `apply` 的拼接結果直接 `reshape` | x、y 交錯錯位，**不報錯** | 奇偶欄分開取 |
%[text] | `dicomread` 當成 HU | 所有值偏 1024 | 套 RescaleSlope／Intercept |
%[text] | 假設 DICOM 有 PixelSpacing | 量測沒有單位 | 檢查欄位是否存在 |
%[text] | 相信體積標頭的 `[1 1 1]` | 體積差一個未知比例 | **用已知物理尺寸做合理性檢查** |
%[text] | 只看光譜比對的 AUC | 1% 正樣本時看不出清單很髒 | **看 AP 與固定召回下的精確率** |
%[text] | 跨方法套用同一個門檻 | 分數尺度差五個數量級 | 每個方法各自校準 |
%[text:table]
%%
%[text] # 9. 練習
%[text] 練習在 `exercise/Ch28_Exercise.m`。
%%
%[text] # 10. 延伸閱讀
%[text] - `doc blockedImage` / `doc apply` / `doc bigimageshow` / `doc makeMultiLevel2D`
%[text] - `doc blockedImageDatastore` / `doc selectBlockLocations`（深度學習用的分塊取樣）
%[text] - `doc dicominfo` / `doc dicomCollection` / `doc medicalVolume`
%[text] - `doc niftiread` / `doc volshow` / `doc sliceViewer`
%[text] - `doc imhypercube` / `doc spectralMatch` / `doc ndvi`
%[text] - 第 20 章：類別不平衡與逐類別指標
%[text] - 第 29 章：把本章的檢查寫成可重複執行的測試

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
