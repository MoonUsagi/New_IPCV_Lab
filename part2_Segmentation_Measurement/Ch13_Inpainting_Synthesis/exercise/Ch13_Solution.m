%[text] # 第 13 章　練習解答
%[text] 影像修復、合成與資料擴增
assert(exist("ch13_inpaintCompare","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
hasInsert = exist("insertObjectInImage", "file") > 0;
rng(0);
%%
%[text] # 解答 1：每個方法各自的主場
%[text] 在兩個維度上變化（洞的大小、洞的形狀），兩張紋理差異大的影像。
imgs = struct( ...
    "name", {"peppers（紋理豐富）", "pout（大片平滑）"}, ...
    "img",  {imread("peppers.png"), imread("pout.tif")});

holeKinds = ["小方塊 20x20" "中方塊 60x60" "大方塊 120x120" "細長刮痕"];

rows = strings(0); winP = strings(0); winT = strings(0);
psnrAll = zeros(0,3); eRatAll = zeros(0,3);

for ii = 1:numel(imgs)
    I = imgs(ii).img;
    [h, w, ~] = size(I);
    for hk = holeKinds
        m = makeHole(h, w, hk);
        if nnz(m) == 0, continue, end

        [~, det] = ch13_inpaintCompare(I, m);
        T = det.Table;

        [~, iP] = max(T.PSNR);
        [~, iT] = min(abs(T.EnergyRatio - 1));

        rows(end+1)     = imgs(ii).name + " / " + hk;
        winP(end+1)     = T.Method(iP);
        winT(end+1)     = T.Method(iT);
        psnrAll(end+1,:) = T.PSNR';
        eRatAll(end+1,:) = T.EnergyRatio';
    end
end

fprintf("\n%-30s %-18s %-18s\n", "情況", "PSNR 贏家", "紋理贏家");
for k = 1:numel(rows)
    fprintf("%-30s %-18s %-18s\n", rows(k), winP(k), winT(k));
end
%%
%[text] ## 完整數字
methodNames = ["inpaintExemplar" "inpaintCoherent" "regionfill"];
fprintf("\nPSNR（dB）\n%-30s %12s %12s %12s\n", "情況", methodNames);
for k = 1:numel(rows)
    fprintf("%-30s %12.3f %12.3f %12.3f\n", rows(k), psnrAll(k,:));
end
fprintf("\n能量比（目標 1.0）\n%-30s %12s %12s %12s\n", "情況", methodNames);
for k = 1:numel(rows)
    fprintf("%-30s %12.3f %12.3f %12.3f\n", rows(k), eRatAll(k,:));
end

fprintf("\n各方法當 PSNR 贏家的次數：\n");
for m = methodNames
    fprintf("  %-18s %d / %d\n", m, nnz(winP == m), numel(rows));
end
fprintf("各方法當紋理贏家的次數：\n");
for m = methodNames
    fprintf("  %-18s %d / %d\n", m, nnz(winT == m), numel(rows));
end

anyAlways = false;
for m = methodNames
    if nnz(winP == m) == numel(rows) && nnz(winT == m) == numel(rows)
        anyAlways = true;
    end
end
fprintf("\n有方法在所有情況都贏嗎？%s\n", string(anyAlways));
%[text] **第 5 小題的答案：沒有。而且結果比主教材更極端。**
%[text] 八種情況的贏家統計：
%[text:table]
%[text] | 方法 | PSNR 贏家次數 | 紋理贏家次數 |
%[text] | --- | --- | --- |
%[text] | `inpaintExemplar` | **0 / 8** | **5 / 8** |
%[text] | `inpaintCoherent` | 1 / 8 | 2 / 8 |
%[text] | `regionfill` | **7 / 8** | 1 / 8 |
%[text:table]
%[text] **`regionfill` 拿下 7/8 的 PSNR 冠軍，而 `inpaintExemplar` 一次都沒贏。**
%[text] 但紋理判準的排名幾乎是**倒過來的**：exemplar 5/8、regionfill 只有 1/8。
%[text] 兩個判準只在**一種**情況下同意（peppers / 中方塊 60×60），
%[text] 而那一次同意的贏家是 `regionfill`——理由很特別：
%[text] 該情況下 exemplar 的能量比是 **4.127**（超出 313%！），
%[text] coherent 是 1.761，兩者離 1 都比 regionfill 的 0.573 更遠。
%[text] **也就是說 regionfill 不是「紋理對」，而是「其他兩個錯得更多」。**
%[text] **`inpaintCoherent` 唯一的 PSNR 勝利在 peppers / 細長刮痕**
%[text] （43.058 vs regionfill 42.495）——差距只有 0.56 dB，
%[text] 但那也是它兩次紋理勝利之一。**細長刮痕是它的主場。**
%[text] **從原理解釋（第 1 小題）**
%[text] - **`regionfill`（拉普拉斯平滑內插）** 的 PSNR 幾乎總是最高，
%[text]   因為 PSNR 偏好模糊（第 12 章第 3 節）。
%[text]   在 `pout.tif` 這種大片平滑的影像上，它連紋理都不算太離譜——
%[text]   因為「正確答案」本來就接近平滑。
%[text] - **`inpaintCoherent`（沿等照度線傳播）** 在**細長**遮罩上最強：
%[text]   兩側的真實像素距離很近，傳播距離短，誤差來不及累積。
%[text] - **`inpaintExemplar`（複製相似補丁）** 從不贏 PSNR，
%[text]   因為補丁擺錯位置的**逐像素**代價很高，即使紋理看起來合理。
%[text]   它在紋理判準上贏得多，但要小心——
%[text]   贏的方式常常是**超出**（能量比 > 1），不是「剛好」。
%[text] > **實務建議：先看洞的形狀，再看洞的面積。**
%[text] > 細長 → `inpaintCoherent`；大面積強紋理 → `inpaintExemplar`；
%[text] > 平滑影像或小洞 → `regionfill` 就夠了。
%[text] > 而且**任何情況都要兩個指標一起看**，否則你會系統性地選到模糊的答案。
%%
%[text] # 解答 2：Poisson 混合的顏色偏移是**系統性**的
%[text] 準備一組亮度遞增的背景，觀察物件的平均亮度怎麼跟著跑。
P = imread("peppers.png");
fgMask = false(size(P,1), size(P,2));
fgMask(60:200, 40:190) = true;
inner = imerode(fgMask, strel("disk", 10));

bgBase = imresize(imread("saturn.png"), [size(P,1) size(P,2)]);
if size(bgBase,3) == 1, bgBase = repmat(bgBase,1,1,3); end

scales = [0.3 0.6 1.0 1.4 1.8];
fgMean = meanInside(P, inner);
fprintf("\n原始前景在遮罩內的平均 RGB = [%.1f %.1f %.1f]\n\n", fgMean);

fprintf("%-10s %12s %22s %22s\n", "背景倍率", "背景亮度", ...
    "Poisson 物件亮度", "Guided 物件亮度");
bgLum = zeros(size(scales));
poiLum = zeros(size(scales));
guiLum = zeros(size(scales));
poiShift = zeros(numel(scales), 3);
guiShift = zeros(numel(scales), 3);

for k = 1:numel(scales)
    bgK = im2uint8(im2double(bgBase) * scales(k));
    bgLum(k) = mean(im2double(im2gray(bgK)), "all") * 255;

    Bp = imblend(P, bgK, fgMask, Mode="Poisson");
    Bg = imblend(P, bgK, fgMask, Mode="Guided");

    mp = meanInside(Bp, inner);
    mg = meanInside(Bg, inner);
    poiLum(k) = mean(mp);
    guiLum(k) = mean(mg);
    poiShift(k,:) = mp - fgMean;
    guiShift(k,:) = mg - fgMean;

    fprintf("%-10.1f %12.1f %22.1f %22.1f\n", ...
        scales(k), bgLum(k), poiLum(k), guiLum(k));
end
%%
%[text] ## 偏移量與背景亮度的關係
fprintf("\n%-10s %26s %26s\n", "背景倍率", "Poisson 偏移 (R,G,B)", "Guided 偏移 (R,G,B)");
for k = 1:numel(scales)
    fprintf("%-10.1f  %+7.1f %+7.1f %+7.1f      %+7.1f %+7.1f %+7.1f\n", ...
        scales(k), poiShift(k,:), guiShift(k,:));
end

% 線性相關：偏移 vs 背景亮度
rP = corr(bgLum(:), mean(poiShift,2));
rG = corr(bgLum(:), mean(guiShift,2));
pFit = polyfit(bgLum, mean(poiShift,2)', 1);

fprintf("\nPoisson：偏移與背景亮度的相關係數 r = %+.4f\n", rP);
fprintf("        線性斜率 = %+.4f（背景每亮 1 階，物件亮 %.2f 階）\n", ...
    pFit(1), pFit(1));
if isnan(rG)
    fprintf("Guided ：相關係數是 NaN——因為所有偏移都**完全等於 0**，\n");
    fprintf("        變異數為零，相關係數無定義。這正是我們想要的結果。\n");
else
    fprintf("Guided ：偏移與背景亮度的相關係數 r = %+.4f\n", rG);
end
fprintf("        偏移量最大 %.4f 階（實質為零）\n", max(abs(mean(guiShift,2))));

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
plot(bgLum, mean(poiShift,2), "o-", LineWidth=1.8, DisplayName="Poisson")
hold on
plot(bgLum, mean(guiShift,2), "s-", LineWidth=1.8, DisplayName="Guided")
yline(0, "--", "無偏移", LineWidth=1.2);
hold off
xlabel("背景平均亮度"); ylabel("物件亮度偏移")
title("Poisson 的偏移隨背景線性變化"); legend(Location="northwest"); grid on
nexttile
plot(bgLum, poiLum, "o-", LineWidth=1.8, DisplayName="Poisson 物件亮度")
hold on
plot(bgLum, guiLum, "s-", LineWidth=1.8, DisplayName="Guided 物件亮度")
yline(mean(fgMean), ":", "原始前景亮度", LineWidth=1.5);
hold off
xlabel("背景平均亮度"); ylabel("遮罩內平均亮度")
title("Guided 保持不變，Poisson 跟著背景跑"); legend(Location="northwest"); grid on
%[text] **第 5 小題的三個答案**
%[text] **① 偏移是系統性的，不是隨機的。** 相關係數接近 1，
%[text] 而且五個背景的偏移方向完全一致（背景越亮、物件越亮）。
%[text] **② 偏移量與背景亮度近乎線性。**
%[text] 這完全符合演算法：Poisson 混合解的是
%[text] $$\nabla^2 f = \nabla^2 g \quad\text{在區域內}, \qquad f = b \quad\text{在邊界上}$$
%[text] 它只約束**梯度**（來自前景 $g$）與**邊界值**（來自背景 $b$）。
%[text] 區域內部的絕對值是這兩個條件解出來的——
%[text] 邊界值一抬高，整個區域就跟著抬高。
%[text] **③ `Guided` 完全沒有這個問題。** 偏移量實質為零，
%[text] 因為它保留前景的實際像素值，只在邊界附近做導引濾波。
%[text] > **這對合成訓練資料是一個真實的失效模式。**
%[text] > 用 Poisson 產生的資料，物件顏色會與背景亮度**相關**。
%[text] > 模型學到「暗背景裡的物件比較暗」——
%[text] > 而真實世界裡物件的顏色不會因為背景而改變。
%[text] > 這種**虛假相關**（spurious correlation）比雜訊危險得多，
%[text] > 因為它在訓練集與（同樣合成的）驗證集上都成立，
%[text] > 只有上線之後才會爆。
%%
%[text] # 解答 3：擴增之後標註還對不對
%[text] 兩種做法：只變換影像（錯）vs 同時變換遮罩再重算框（對）。
objMask = fgMask;
box0 = ch13_maskToBox(objMask);
fprintf("\n原始邊界框 = %s\n", mat2str(box0));

rng(0);
nTrial = 20;
ious   = zeros(nTrial,1);
rotUsed = zeros(nTrial,1);
R = imref2d(size(P, [1 2]));

for k = 1:nTrial
    rotDeg = -45 + 90*rand;
    rotUsed(k) = rotDeg;
    tf = rigidtform2d(rotDeg, [0 0]);

    % 方式 B（對的）：變換遮罩，重算框
    maskT = imwarp(objMask, tf, OutputView=R);
    if ~any(maskT(:)), ious(k) = NaN; continue, end
    boxRight = ch13_maskToBox(maskT);

    % 方式 A（錯的）：沿用原框
    boxWrong = box0;

    ious(k) = bboxOverlapRatio(boxRight, boxWrong);
end

ok = ~isnan(ious);
fprintf("\n%d 次隨機旋轉（-45 到 +45 度）：\n", nTrial);
fprintf("  正確框 vs 沿用原框的 IoU：平均 %.4f、最小 %.4f、最大 %.4f\n", ...
    mean(ious(ok)), min(ious(ok)), max(ious(ok)));
fprintf("  IoU < 0.5 的次數：%d / %d\n", nnz(ious(ok) < 0.5), nnz(ok));

% 旋轉角度 vs IoU
figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
scatter(abs(rotUsed(ok)), ious(ok), 60, "filled")
yline(0.5, "--", "IoU 0.5", LineWidth=1.2);
xlabel("旋轉角度絕對值（度）"); ylabel("正確框 vs 錯誤框的 IoU")
title("旋轉越大，沿用原框錯得越多"); grid on

% 視覺化一個明顯的例子
[~, worst] = min(ious);
tfW = rigidtform2d(rotUsed(worst), [0 0]);
imgW  = imwarp(P, tfW, OutputView=R);
maskW = imwarp(objMask, tfW, OutputView=R);
boxR  = ch13_maskToBox(maskW);

nexttile
% 標籤用 ASCII：R2026a 的預設字型 Roboto-Regular 不含中日韓字元，
% 傳中文會發出 "default font does not contain one or more characters" 警告。
vis = insertObjectAnnotation(imgW, "rectangle", boxR,  "correct", ...
    Color="green", LineWidth=3);
vis = insertObjectAnnotation(vis,  "rectangle", box0, "stale box", ...
    Color="red", LineWidth=3);
imshow(vis)
title(sprintf("旋轉 %.1f 度，IoU %.3f", rotUsed(worst), ious(worst)))

rho = corr(abs(rotUsed(ok)), ious(ok));
fprintf("\n旋轉角度絕對值與 IoU 的相關係數 = %+.4f（第 6 小題）\n", rho);
%%
%[text] ## 第 7 小題：`insertObjectInImage` 回傳的是哪一種
if ~hasInsert
    fprintf("未安裝 AVI Library，跳過第 7 小題。\n");
else
    dest = imresize(imread("saturn.png"), [500 700]);
    if size(dest,3) == 1, dest = repmat(dest,1,1,3); end

    rng(7);
    [imgIns, boxIns, maskIns] = insertObjectInImage(dest, P, objMask, ...
        GeometricAugmentation=@() randomAffine2d(Rotation=[-40 40], Scale=[0.5 0.7]));

    % 自己從回傳的遮罩重算框，與函式回傳的框比對
    boxRecomputed = ch13_maskToBox(maskIns);
    agreement = bboxOverlapRatio(boxIns, boxRecomputed);

    fprintf("\n函式回傳的框     = %s\n", mat2str(round(boxIns,1)));
    fprintf("由遮罩重算的框   = %s\n", mat2str(boxRecomputed));
    fprintf("兩者 IoU         = %.4f\n", agreement);

    figure
    imshow(insertObjectAnnotation(imgIns, "rectangle", boxIns, "auto", ...
        Color="cyan", LineWidth=3));
    title(sprintf("insertObjectInImage 的框與遮罩一致（IoU %.4f）", agreement))

    assert(agreement > 0.95, "回傳的框與遮罩不一致，請檢查。");
    fprintf("\n**確認：函式回傳的框是「方式 B」——由擴增後的遮罩算出來的。**\n");
end
%[text] **這題的意義**
%[text] 沿用原框的錯誤**不會報錯**，訓練也會正常跑完，
%[text] 只是模型學到的框永遠偏一點。這類 bug 極難察覺。
%[text] `insertObjectInImage` 把幾何擴增放在插入**之前**，
%[text] 所以回傳的框天生就是擴增後的正確位置——
%[text] **這是用它而不是自己寫擴增的主要理由**，
%[text] 不是因為它的混合比較漂亮。
%[text] 若你一定要自己做擴增，規則是：
%[text] **標註與影像必須用同一個 `tform` 變換，而且框要從變換後的遮罩重算**，
%[text] 不能只把框的四個角變換過去（旋轉後的框不再是軸對齊的矩形）。
%%
%[text] # 解答 4：檢查你造出了什麼分布
if ~hasInsert
    fprintf("未安裝 AVI Library，跳過解答 4。\n");
else
    % 目標分布（題目給的「真實場景統計」）
    target = struct("meanObjects", 6, "objRange", [3 10], ...
        "meanArea", 3000, "overlapFraction", 0.30);

    tmpRoot = fullfile(tempdir, "ipcv_ch13_ex4");
    if isfolder(tmpRoot), rmdir(tmpRoot, "s"); end
    bgDir = fullfile(tmpRoot, "bg"); mkdir(bgDir);
    for k = 1:6
        B = imresize(imread("saturn.png"), [420 560]);
        if size(B,3) == 1, B = repmat(B,1,1,3); end
        imwrite(min(B + uint8(10*k), 255), fullfile(bgDir, sprintf("b_%d.png", k)));
    end
    bgFiles = string(fullfile(bgDir, {dir(fullfile(bgDir,"*.png")).name}));

    % --- 第一次嘗試：照直覺設定 ---
    fprintf("\n=== 嘗試 1：MaxOverlap=0.3、物件數 3-10、縮放 0.4-0.8 ===\n");
    rng(0);
    [~, mf1] = ch13_makeSyntheticSet(bgFiles, P, objMask, 30, ...
        OutputDir=fullfile(tmpRoot,"try1"), MaxOverlap=0.3, ...
        ObjectsPerImage=[3 10], Scale=[0.4 0.8], Label="pepper");
    showGap(mf1, target, "嘗試 1");

    % --- 第二次嘗試：物件縮小，才塞得進去 ---
    fprintf("\n=== 嘗試 2：物件縮小到 0.15-0.3 ===\n");
    rng(0);
    [~, mf2] = ch13_makeSyntheticSet(bgFiles, P, objMask, 30, ...
        OutputDir=fullfile(tmpRoot,"try2"), MaxOverlap=0.3, ...
        ObjectsPerImage=[3 10], Scale=[0.15 0.3], Label="pepper");
    showGap(mf2, target, "嘗試 2");

    % --- 第三次：面積夾在兩者之間，瞄準 3000 像素 ---
    % 嘗試 1 的 0.4-0.8 得到 11022、嘗試 2 的 0.15-0.3 得到 1414。
    % 面積隨縮放的平方變化，所以目標縮放約 0.3*sqrt(3000/1414) ≈ 0.44 的下緣
    % 面積隨縮放的**平方**變化。嘗試 2 的 [0.15 0.3] 得到 1414，
    % 要 3000 就把縮放乘上 sqrt(3000/1414) = 1.46
    fprintf("\n=== 嘗試 3：縮放 0.28-0.38（由平方關係反推），瞄準面積 3000 ===\n");
    rng(0);
    [~, mf3] = ch13_makeSyntheticSet(bgFiles, P, objMask, 30, ...
        OutputDir=fullfile(tmpRoot,"try3"), MaxOverlap=0.3, ...
        ObjectsPerImage=[3 10], Scale=[0.28 0.38], Label="pepper");
    showGap(mf3, target, "嘗試 3");

    % --- 第四次：想逼出重疊，把 MaxOverlap 開到最大 ---
    fprintf("\n=== 嘗試 4：MaxOverlap=1（完全不限制），看重疊會不會自己出現 ===\n");
    rng(0);
    [~, mf4] = ch13_makeSyntheticSet(bgFiles, P, objMask, 30, ...
        OutputDir=fullfile(tmpRoot,"try4"), MaxOverlap=1, ...
        ObjectsPerImage=[3 10], Scale=[0.28 0.38], Label="pepper");
    showGap(mf4, target, "嘗試 4");

    fprintf("\n四次嘗試的重疊比例：%.2f / %.2f / %.2f / %.2f（目標 %.2f）\n", ...
        mean(mf1.MaxIoU > 0.1), mean(mf2.MaxIoU > 0.1), ...
        mean(mf3.MaxIoU > 0.1), mean(mf4.MaxIoU > 0.1), target.overlapFraction);
end
%[text] **第 5、6 小題：哪一項最難達成**
%[text] 四次嘗試的結果：
%[text:table]
%[text] | 嘗試 | 設定 | 物件數 | 框面積 | 有重疊比例 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 1 | 縮放 0.4–0.8、MaxOverlap 0.3 | 6.57 ✓ | 11022 ✗ | **0.00** ✗ |
%[text] | 2 | 縮放 0.15–0.3 | 6.67 ✓ | 1414 ✗ | **0.00** ✗ |
%[text] | **3** | 縮放 0.28–0.38 | 7.17 ✓ | **3018 ✓** | **0.00** ✗ |
%[text] | 4 | 縮放 0.28–0.38、**MaxOverlap 1** | 7.27 ✓ | 3057 ✓ | **0.57** ✗ |
%[text:table]
%[text] **物件數與框面積都能調到達標（嘗試 3）。**
%[text] 而且不需要盲試——面積隨縮放的**平方**變化，
%[text] 由嘗試 2 的 1414 反推「乘上 √(3000/1414) = 1.46」
%[text] 就直接命中 3018。
%[text] **真正調不動的是重疊比例，而且失敗方式很特別：**
%[text:table]
%[text] | MaxOverlap 設定 | 實際得到的重疊比例 |
%[text] | --- | --- |
%[text] | 0.3 | **0.00**（完全沒有重疊） |
%[text] | 1.0 | **0.57**（比目標多快一倍） |
%[text:table]
%[text] 目標 0.30 **正好落在兩者之間，而中間沒有旋鈕可以轉。**
%[text] > **關鍵理解：`MaxOverlap` 是一個「上限」，不是「目標值」。**
%[text] > 設 0.3 的意思是「不准超過 0.3」，不是「請製造 0.3 的重疊」。
%[text] > 物件的擺放位置是**隨機**的——在空間充裕的背景上，
%[text] > 隨機擺放本來就很少重疊（所以得到 0.00）；
%[text] > 一旦完全放開，擠了 7 個物件就自然撞成一片（所以跳到 0.57）。
%[text] 要命中 0.30，能用的手段都是**間接**的：
%[text] 調整物件大小、背景尺寸、或物件數——
%[text] 也就是改變「隨機擺放撞到的機率」，而不是去設一個重疊率。
%[text] 若真的需要精確控制，就得**自己寫擺放邏輯**
%[text] （例如先決定哪幾對要重疊、再指定位置），
%[text] 不能靠 `insertObjectInImage` 的隨機擺放。
%[text] > **這題真正的教訓：合成資料的分布是幾何與素材尺寸決定的，
%[text] > 不是「調參數」調出來的。**
%[text] > 而且有些參數的語意是**約束**而非**目標**——
%[text] > 分不清這兩者，就會花很多時間調一個不會生效的旋鈕。
%%
%[text] # 解答 5：移除影像上的文字
Iclean = imread("peppers.png");

% 疊上文字。R2026a 的 insertText 預設字型已變更，外觀與舊教材不同
Idirty = insertText(Iclean, [40 300], "2026-09-18  CAM-01", ...
    FontSize=28, TextColor="white", BoxColor="black", BoxOpacity=0.6);

% 文字遮罩：找出與原圖不同的像素
diffMask = any(abs(double(Idirty) - double(Iclean)) > 10, 3);
fprintf("\n文字汙染了 %d 像素（%.2f%%）\n", ...
    nnz(diffMask), 100*nnz(diffMask)/numel(diffMask));

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(Iclean);  title("原圖（正確答案）")
nexttile; imshow(Idirty);  title("疊上文字")
nexttile; imshow(diffMask); title("文字遮罩（未膨脹）")
%%
%[text] ## 為什麼遮罩要膨脹（第 2 小題）
%[text] 文字邊緣有**反鋸齒**：那些半透明的過渡像素與原圖的差異很小，
%[text] 過不了門檻，所以不會被納入遮罩。
%[text] 但它們**確實被汙染了**。遮罩沒蓋到，修復就不會處理，
%[text] 於是修復後還留著一圈淡淡的文字輪廓。
%[text] **但這裡有一個比膨脹量更重要的陷阱。**
%[text] 掃描膨脹量時，如果每一列都用「當下的遮罩」算指標，
%[text] 評估區域會隨著膨脹一起長大——**不同列就不是在比同一件事**。
%[text] 這個混淆會直接給出錯誤的答案。實測對照：
%[text:table]
%[text] | 評估方式 | 得到的最佳膨脹量 |
%[text] | --- | --- |
%[text] | 用當下遮罩（**錯**） | 5 px，而且 PSNR 在 0–5 單調上升（看不到峰值） |
%[text] | **固定評估區域（對）** | **2 px，有明確的峰值** |
%[text:table]
%[text] 用錯的方式會得到「膨脹越多越好」的結論，
%[text] 因為遮罩越大、外接矩形裡就混進越多容易修的區域。
%[text] 這是主教材第 3.1 節「統計範圍決定結論」的第三次出現——
%[text] 前兩次是整張影像 vs 洞內（第 3.1 節）、第 11 章的碰邊物件排除。
%[text] 下面用**固定評估區域**重新掃描。
dilations = 0:2:16;

% **評估區域必須固定。** 若每次都用當下的遮罩算指標，
% 區域會隨膨脹一起長大，不同列就不是在比同一件事。
% 這裡統一用最大膨脹量的遮罩當評估範圍。
evalMask = imdilate(diffMask, strel("disk", max(dilations)));
fprintf("\n評估範圍固定為最大膨脹的遮罩（%d 像素），所有列可比較\n\n", nnz(evalMask));

fprintf("%-10s %10s %10s %10s %12s\n", ...
    "膨脹量", "遮罩px", "PSNR", "SSIM", "能量比");

refE5 = ch13_gradEnergy(Iclean, evalMask);
bestPS = -Inf; bestD = 0;
psAll = zeros(size(dilations));
for k = 1:numel(dilations)
    d = dilations(k);
    if d == 0
        m = diffMask;
    else
        m = imdilate(diffMask, strel("disk", d));
    end
    J = inpaintCoherent(Idirty, m);
    [ps, ss] = ch13_holeMetrics(Iclean, J, evalMask);   % 固定範圍
    er = ch13_gradEnergy(J, evalMask) / refE5;
    psAll(k) = ps;
    fprintf("%-10d %10d %10.3f %10.4f %12.3f\n", d, nnz(m), ps, ss, er);
    if ps > bestPS, bestPS = ps; bestD = d; end
end
fprintf("\n最佳膨脹量 = %d 像素（PSNR %.3f）\n", bestD, bestPS);
if bestD == max(dilations)
    fprintf("**注意：最佳值落在掃描範圍的邊界**，真正的最佳值可能更大。\n");
    fprintf("但膨脹越多就修掉越多原本good的像素，實務上不會無限加大。\n");
end

figure
plot(dilations, psAll, "o-", LineWidth=1.8)
xline(bestD, "--", sprintf("最佳 %d px", bestD), LineWidth=1.4);
xlabel("遮罩膨脹量（像素）"); ylabel("固定評估區內的 PSNR (dB)")
title("膨脹量掃描（評估範圍固定）"); grid on
%%
%[text] ## 三種方法在文字這種細長遮罩上的表現
[repText, detText] = ch13_inpaintCompare(Idirty, imdilate(diffMask, strel("disk", bestD)));
% 注意：這裡的 ground truth 要用乾淨影像，不是被汙染的那張
mBest = imdilate(diffMask, strel("disk", bestD));
fprintf("\n%-18s %10s %10s %12s\n", "方法", "PSNR", "SSIM", "能量比");
refE = ch13_gradEnergy(Iclean, mBest);
for nm = ["inpaintExemplar" "inpaintCoherent" "regionfill"]
    switch nm
        case "inpaintExemplar", J = inpaintExemplar(Idirty, mBest);
        case "inpaintCoherent", J = inpaintCoherent(Idirty, mBest);
        otherwise
            J = Idirty;
            for c = 1:3, J(:,:,c) = regionfill(Idirty(:,:,c), mBest); end
    end
    [ps, ss] = ch13_holeMetrics(Iclean, J, mBest);
    fprintf("%-18s %10.3f %10.4f %12.3f\n", nm, ps, ss, ...
        ch13_gradEnergy(J, mBest)/refE);
end
%[text] **第 5 小題：文字這種細長遮罩最適合哪個方法？**
%[text] 實測（膨脹 2 px、固定評估區）：
%[text:table]
%[text] | 方法 | PSNR | SSIM | 能量比 |
%[text] | --- | --- | --- | --- |
%[text] | `inpaintExemplar` | 16.881 | 0.5724 | 1.476 |
%[text] | `inpaintCoherent` | 14.931 | 0.6099 | **0.677** |
%[text] | **`regionfill`** | **17.087** | **0.6816** | 0.335 |
%[text:table]
%[text] **兩個判準又不一致**：PSNR 與 SSIM 都選 `regionfill`，
%[text] 紋理判準選 `inpaintCoherent`。
%[text] 這裡要看**用途**來決定，而文字移除的用途很明確：
%[text] 結果是要**給人看的**。
%[text] `regionfill` 的能量比只有 0.335——它會在原本有文字的地方
%[text] 留下一片平滑的色塊，在有紋理的背景上非常顯眼，
%[text] 即使它的逐像素誤差最小。
%[text] 所以實務上會選 **`inpaintCoherent`**：
%[text] 紋理比 0.677 是三者中最接近 1 的，而 PSNR 只差 2.16 dB。
%[text] 理由與解答 1 的細長刮痕相同——文字筆畫細，
%[text] **兩側的真實像素距離很近**，沿等照度線傳播只要跨幾個像素。
%[text] > **洞的形狀比洞的面積更能決定該用哪個方法。**
%[text] > 面積相同的「一個大方塊」與「一條長刮痕」最佳方法不同：
%[text] > 前者要合成紋理，後者只要傳播。
%%
%[text] # 加分題：合成資料的領域落差
if ~hasInsert
    fprintf("未安裝 AVI Library，跳過加分題。\n");
else
    % --- 真實領域：一批 MATLAB 內建照片 ---
    realNames = ["peppers.png" "saturn.png" "football.jpg" "fabric.png" ...
                 "greens.jpg" "hestain.png" "onion.png" "yellowlily.jpg"];
    realRoot = fullfile(tempdir, "ipcv_ch13_bonus_real");
    if isfolder(realRoot), rmdir(realRoot, "s"); end
    mkdir(realRoot);
    nReal = 0;
    for f = realNames
        try
            A = imread(f);
            if size(A,3) == 1, A = repmat(A,1,1,3); end
            A = imresize(A, [300 400]);
            nReal = nReal + 1;
            imwrite(A, fullfile(realRoot, sprintf("r_%02d.png", nReal)));
        catch
            % 這個版本沒有這張內建影像，跳過
        end
    end
    fprintf("\n真實領域取得 %d 張影像\n", nReal);

    dsReal = imageDatastore(realRoot);
    realScores = scoreSet(dsReal);
    fprintf("\n真實領域：NIQE %.2f ± %.2f（中位數 %.2f）\n", ...
        mean(realScores(:,1)), std(realScores(:,1)), median(realScores(:,1)));

    % --- 用真實影像訓練 NIQE 模型 ---
    modelReal = fitniqe(dsReal);

    % --- 三種 BlendMethod 各產一批合成影像 ---
    bgR = fullfile(tempdir, "ipcv_ch13_bonus_bg");
    if isfolder(bgR), rmdir(bgR, "s"); end
    mkdir(bgR);
    for k = 1:4
        B = imresize(imread("saturn.png"), [300 400]);
        if size(B,3) == 1, B = repmat(B,1,1,3); end
        imwrite(min(B + uint8(15*k), 255), fullfile(bgR, sprintf("b_%d.png", k)));
    end
    bgList = string(fullfile(bgR, {dir(fullfile(bgR,"*.png")).name}));

    fprintf("\n%-16s %12s %12s %14s %16s\n", "BlendMethod", ...
        "NIQE平均", "NIQE中位數", "BRISQUE平均", "自訓模型評分");
    fprintf("%-16s %12.2f %12.2f %14.2f %16s\n", "(真實領域)", ...
        mean(realScores(:,1)), median(realScores(:,1)), ...
        mean(realScores(:,2)), "--");

    for bm = ["guidedfilter" "poisson" "none"]
        rng(0);
        outD = fullfile(tempdir, "ipcv_ch13_bonus_" + bm);
        if isfolder(outD), rmdir(outD, "s"); end
        ch13_makeSyntheticSet(bgList, P, objMask, 8, ...
            OutputDir=outD, BlendMethod=bm, MaxOverlap=0.3, ...
            ObjectsPerImage=[2 4], Scale=[0.3 0.5]);
        dsS = imageDatastore(fullfile(outD, "images"));
        sc  = scoreSet(dsS);
        scCustom = scoreSetCustom(dsS, modelReal);
        fprintf("%-16s %12.2f %12.2f %14.2f %16.2f\n", bm, ...
            mean(sc(:,1)), median(sc(:,1)), mean(sc(:,2)), median(scCustom));
    end
end
%[text] **第 6 小題：這個指標能不能用來挑混合方式？**
%[text] **實測的答案是「不能」——三種方式的分數幾乎一樣。**
%[text:table]
%[text] | BlendMethod | NIQE 平均 | NIQE 中位數 | BRISQUE 平均 | **自訓模型評分** |
%[text] | --- | --- | --- | --- | --- |
%[text] | *(真實領域)* | *5.28* | *4.42* | *31.85* | *—* |
%[text] | `guidedfilter` | 5.94 | 6.04 | 46.69 | **4.02** |
%[text] | `poisson` | 6.14 | 6.16 | 49.89 | **4.00** |
%[text] | `none` | 5.92 | 6.00 | 46.99 | **4.06** |
%[text:table]
%[text] 自訓模型的三個分數是 4.02 / 4.00 / 4.06——**差距 1.5%**，
%[text] 而真實領域自己的標準差是 2.11（相對 40%）。
%[text] 換句話說**三種方式的差異完全埋在雜訊裡**。
%[text] **更值得警惕的是排序本身。** `poisson` 拿到最低（最好）的 4.00，
%[text] 而它正是解答 2 證明會產生**虛假顏色相關**的那一個。
%[text] 如果照這個指標挑，你會選到最危險的方法。
%[text] > **一個指標給出的排序，不代表下游任務的排序。**
%[text] > 這與第 12 章加分題（品質指標無法預測計數任務失敗）
%[text] > 是完全同一個結論。
%[text] 那這個指標還有什麼用？**可以用來排除明顯不對的，
%[text] 但不能用來做最終決定。**
%[text] 為什麼「量的是與訓練分布的距離」在這裡剛好是優點（第 12 章的性質）：
%[text] 我們要問的**正好就是**「合成影像離真實影像的分布有多遠」。
%[text] 用真實影像訓練 `fitniqe`，再用它評分合成影像——
%[text] 這個分數的定義就是我們想量的東西。
%[text] **但它的限制也很明確，有三點：**
%[text] 1. **它只看低階統計**（局部亮度與對比的分布），
%[text]    看不到語意。一張把辣椒貼在天空中央的影像，
%[text]    低階統計可能很正常，但它是個不合理的場景。
%[text] 2. **分數接近不代表訓練效果一樣好。**
%[text]    模型會不會學到虛假相關（見解答 2 的 Poisson 顏色偏移）
%[text]    完全不反映在這個分數上。
%[text] 3. **本例的真實領域只有 8 張影像**，而且彼此差異很大
%[text]    （辣椒、土星、布料、洋蔥…）。`fitniqe` 學到的「分布」
%[text]    本身就很鬆散，所以判別力有限。
%[text]    第 12 章練習 3 的教訓在這裡同樣適用：樣本太少時要看中位數，
%[text]    而且要問這個分布到底有多集中。
%[text] > **結論：這個指標適合當一個快速的 sanity check**——
%[text] > 分數差距很大時值得追查，差距不大時不足以做決定。
%[text] > 要真的比較混合方式，唯一可靠的方法是
%[text] > **用各批合成資料各訓練一次，在同一批真實資料上評測**。
%[text] > 那是第 19、22 章的內容。

% ========================================================================
function m = makeHole(h, w, kind)
%MAKEHOLE 產生不同大小與形狀的洞，全部置中放置以便公平比較。
m = false(h, w);
cy = round(h/2); cx = round(w/2);
switch kind
    case "小方塊 20x20",   s = 10;
    case "中方塊 60x60",   s = 30;
    case "大方塊 120x120", s = 60;
    case "細長刮痕"
        % 一條斜的細線，膨脹成刮痕
        n = min(h, w) - 40;
        for t = 0:n-1
            r = cy - round(n/2) + round(0.35*t);
            c = cx - round(n/2) + t;
            if r >= 1 && r <= h && c >= 1 && c <= w
                m(r, c) = true;
            end
        end
        m = imdilate(m, strel("disk", 3));
        return
    otherwise
        error("makeHole:unknownKind", "不認識的洞型態：%s", kind);
end
r1 = max(1, cy-s); r2 = min(h, cy+s-1);
c1 = max(1, cx-s); c2 = min(w, cx+s-1);
m(r1:r2, c1:c2) = true;
end

% ========================================================================
function v = meanInside(I, mask)
%MEANINSIDE 遮罩內每個通道的平均值（0-255 尺度）。
A = double(I);
v = zeros(1, size(A,3));
for c = 1:size(A,3)
    ch = A(:,:,c);
    v(c) = mean(ch(mask));
end
end

% ========================================================================
function showGap(mf, target, tag)
%SHOWGAP 比較合成分布與目標分布。
areas = mf.MeanBoxArea(mf.MeanBoxArea > 0);
overlapFrac = mean(mf.MaxIoU > 0.1);

fprintf("\n%s 與目標的差距：\n", tag);
fprintf("%-18s %14s %14s %10s\n", "項目", "合成", "目標", "達標?");
fprintf("%-18s %14.2f %14.2f %10s\n", "每張物件數", ...
    mean(mf.NumObjects), target.meanObjects, ...
    passFail(abs(mean(mf.NumObjects)-target.meanObjects) < 1.5));
fprintf("%-18s %14.0f %14.0f %10s\n", "框面積", ...
    mean(areas), target.meanArea, ...
    passFail(abs(mean(areas)-target.meanArea)/target.meanArea < 0.3));
fprintf("%-18s %14.2f %14.2f %10s\n", "有重疊的比例", ...
    overlapFrac, target.overlapFraction, ...
    passFail(abs(overlapFrac-target.overlapFraction) < 0.15));
end

function s = passFail(tf)
if tf, s = "OK"; else, s = "未達標"; end
end

% ========================================================================
function sc = scoreSet(ds)
%SCORESET 對 datastore 中每張影像算 NIQE / BRISQUE / PIQE。
reset(ds);
sc = zeros(0,3);
while hasdata(ds)
    A = read(ds);
    G = im2double(A);
    if size(G,3) > 1, G = im2gray(G); end
    sc(end+1,:) = [niqe(G) brisque(G) piqe(G)];
end
reset(ds);
end

function sc = scoreSetCustom(ds, model)
%SCORESETCUSTOM 用自訓模型評分。
reset(ds);
sc = [];
while hasdata(ds)
    A = read(ds);
    G = im2double(A);
    if size(G,3) > 1, G = im2gray(G); end
    sc(end+1) = niqe(G, model);
end
reset(ds);
sc = sc(:);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
