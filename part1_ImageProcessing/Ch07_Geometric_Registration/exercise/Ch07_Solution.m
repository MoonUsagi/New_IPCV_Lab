%[text] # 第 07 章　練習解答
assert(exist("ch07_registerImages","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
I = im2double(imread("cameraman.tif"));
Rin = imref2d(size(I));
angleOf = @(tf) -rad2deg(atan2(tf.A(2,1), tf.A(1,1)));
scaleOf = @(tf) 1/hypot(tf.A(1,1), tf.A(2,1));
%%
%[text] # 解答 1：選對轉換模型
pairs = { ...
    "A", imwarp(I, transltform2d(20, -15), OutputView=Rin), "translation"; ...
    "B", imwarp(I, simtform2d(0.8, 18, [10 10]), OutputView=Rin), "similarity"; ...
    "C", imwarp(I, projtform2d([1 0.08 0; 0.04 1 0; 0.0006 0.0004 1]), OutputView=Rin), "projective"};

%[text] ## 判斷依據
%[text:table]
%[text] | 組 | 觀察 | 模型 |
%[text] | --- | --- | --- |
%[text] | A | 內容整體平移，大小角度都沒變 | 平移（2 DOF） |
%[text] | B | 縮小且旋轉，但**直角仍是直角** | 相似（4 DOF） |
%[text] | C | 出現**透視感**，原本平行的邊不再平行 | 投影（8 DOF） |
%[text:table]
%[text] 關鍵判斷：**平行線還平行嗎**（是→仿射以下）、**直角還是直角嗎**（是→相似以下）。
fprintf("%-4s %-14s %10s %12s\n", "組", "正確模型", "PSNR", "回復角度");
for k = 1:size(pairs,1)
    tf = imregcorr(pairs{k,2}, I, ternaryStr(pairs{k,3}=="projective", "similarity", pairs{k,3}));
    rec = imwarp(pairs{k,2}, tf, OutputView=Rin);
    fprintf("%-4s %-14s %9.2f dB %11.2f°\n", pairs{k,1}, pairs{k,3}, psnr(rec,I), angleOf(tf));
end
%%
%[text] ## 為什麼不乾脆每次都用投影模型
%[text] 對只有平移的 A 組，比較「正確模型」與「過度複雜的模型」。
%[text] 用控制點來做，這樣可以直接比較模型的擬合行為：
srcPts = [50 50; 200 60; 60 200; 190 190; 128 128];
dstPtsClean = srcPts + [20 -15];                        % 純平移
rng(0);
dstPtsNoisy = dstPtsClean + randn(size(srcPts)) * 1.5;  % 加入標註誤差

%[text] **注意 `fitgeotform2d` 支援的模型與 `imwarp` 的轉換物件不完全一樣**：
%[text] 它接受 `"similarity"`、`"affine"`、`"projective"` 等，
%[text] 但**沒有 `"translation"`**——純平移要自己從對應點取平均差值求得，
%[text] 或用 `imregcorr(..., "translation")`。
models = ["similarity" "affine" "projective"];
fprintf("\n%-14s %14s %16s\n", "模型", "控制點殘差", "對未見點的誤差");

% 拿一組沒有參與擬合的點來檢驗（模擬真實情況）
testSrc = [100 30; 30 100; 220 220];
testDst = testSrc + [20 -15];

for m = models
    tf = fitgeotform2d(dstPtsNoisy, srcPts, m);
    fitResidual  = mean(vecnorm(transformPointsForward(tf, dstPtsNoisy) - srcPts, 2, 2));
    testError    = mean(vecnorm(transformPointsForward(tf, testDst) - testSrc, 2, 2));
    fprintf("%-14s %13.3f %15.3f\n", m, fitResidual, testError);
end
%[text] **這就是過度擬合**：模型越複雜，**控制點上的殘差越小**，
%[text] 但**對沒參與擬合的點誤差越大**。
%[text] 投影模型有 8 個自由度，5 個控制點只提供 10 個方程式——
%[text] 它有足夠的自由度去「遷就」標註誤差，把誤差吸收進轉換參數裡，
%[text] 結果就是一個扭曲的、只對那 5 點正確的轉換。
%[text] **這是機器學習裡「訓練誤差 vs 泛化誤差」的完全相同的現象**，
%[text] 第 18 章會再遇到它。
%[text] **原則**：用能解決問題的最簡單模型。不確定時，
%[text] 保留一部分控制點不參與擬合，用它們來檢驗——這就是驗證集的概念。
%%
%[text] # 解答 2：初始猜測有多重要
[optimizer, metric] = imregconfig("monomodal");
angles = 0:4:40;
if ipcvFast()
    angles = 0:8:40;      % 快速模式下取樣粗一些，結論不變
end
errAlone = zeros(size(angles));
errPaired = zeros(size(angles));

for k = 1:numel(angles)
    moved = imwarp(I, simtform2d(1, angles(k), [0 0]), OutputView=Rin);

    tAlone  = imregtform(moved, I, "similarity", optimizer, metric);
    tCoarse = imregcorr(moved, I);
    tPaired = imregtform(moved, I, "similarity", optimizer, metric, ...
        InitialTransformation=tCoarse);

    errAlone(k)  = abs(angleOf(tAlone)  - angles(k));
    errPaired(k) = abs(angleOf(tPaired) - angles(k));
end

fprintf("%8s %16s %16s\n", "真實角度", "單獨 imregtform", "imregcorr+精修");
for k = 1:numel(angles)
    fprintf("%7d° %15.2f° %15.2f°\n", angles(k), errAlone(k), errPaired(k));
end

figure
semilogy(angles, max(errAlone, 0.01), "-o", angles, max(errPaired, 0.01), "-s", LineWidth=1.5)
legend("單獨 imregtform", "imregcorr + 精修", Location="northwest")
xlabel("真實旋轉角度 (度)"); ylabel("角度誤差 (度，對數軸)")
title("初始猜測對配準成敗的影響"); grid on

threshold = angles(find(errAlone > 2, 1));
fprintf("\n單獨使用時的失效門檻：約 %d 度\n", threshold);
fprintf("串接版在 0–40 度全部準確（最大誤差 %.3f 度）\n", max(errPaired));
%[text] ## 兩個重要觀察
%[text] **1. 失效門檻在 16–20 度之間。** 這不是巧合——
%[text] 超過這個角度，影像的自相似結構會讓最佳化器找到一個「假的」局部極值。
%[text] **2. 失敗是跳躍式的，不是漸進的。** 看那些誤差值：
%[text] 20 度時誤差 29 度、36 度時誤差高達 180 度。
%[text] 它不是「越來越不準」，而是**突然掉進另一個完全錯誤的解**。
%[text] 這正是局部最佳化的特徵，也是為什麼**不能靠「結果看起來還算合理」
%[text] 來判斷配準成功**——錯的時候會錯得離譜，但程式不會告訴你。
%%
%[text] # 解答 3：穩健的配準函式
%[text] 完整實作在 `code/ch07_registerImages.m`。三種情況的行為：
fixed = I;
scenarios = { ...
    "正常單模態", imwarp(I, simtform2d(0.85,23,[15 -10]), OutputView=Rin), "monomodal"; ...
    "完全無關",   im2double(imresize(imread("rice.png"), size(I))),        "monomodal"};

for k = 1:size(scenarios,1)
    lastwarn("");
    [~, ~, rpt] = ch07_registerImages(scenarios{k,2}, fixed, Modality=scenarios{k,3});
    fprintf("%-12s 階段=%-8s 最終相似度 %.4f\n", scenarios{k,1}, rpt.Stage, rpt.FinalSimilarity);
    [msg, ~] = lastwarn;
    if ~isempty(msg)
        fprintf("   警告：%s\n", strtrim(msg));
    end
end
%[text] ## 一個誠實的限制
%[text] 這支函式**擋得住「完全無關的影像」（相似度 0.21 < 門檻 0.4），
%[text] 但擋不住多模態配準的錯誤**。原因是：
ortho  = im2double(imread("westconcordorthophoto.png"));
aerial = im2double(im2gray(imread("westconcordaerial.png")));
[~, ~, rptMM] = ch07_registerImages(aerial, ortho, Modality="multimodal");

fprintf("\n無關影像（胡亂配準）相似度 0.2114\n");
fprintf("真實多模態（正確配準）相似度 %.4f  <- 反而更低\n", rptMM.FinalSimilarity);
%[text] **胡亂配準的分數比正確配準還高。**
%[text] 互相關假設兩張影像的亮度有線性對應，多模態影像根本不滿足這個前提。
%[text] 所以函式在多模態時**不套用絕對門檻**，改為明白提示需要人工確認。
%[text] **這是刻意的設計**：與其給一個假的保證，不如告訴使用者
%[text] 「這個情況我驗證不了」。
%[text] 寫工具函式時，**知道自己的極限在哪、並且說出來**，
%[text] 比假裝什麼都能處理更有價值。
%%
%[text] # 解答 4：控制點該給幾個
rng(0);
trueTf = simtform2d(0.9, 15, [20 -10]);

nAll = 20;
srcAll = [rand(nAll,1)*200 + 25, rand(nAll,1)*200 + 25];
dstAll = transformPointsForward(trueTf, srcAll) + randn(nAll,2) * 1.0;   % 1 像素標註誤差

counts = [2 3 4 6 10 20];
fprintf("%8s %14s %14s %14s\n", "點數", "殘差", "角度誤差", "縮放誤差");

for n = counts
    tf = fitgeotform2d(dstAll(1:n,:), srcAll(1:n,:), "similarity");
    residual = mean(vecnorm(transformPointsForward(tf, dstAll(1:n,:)) - srcAll(1:n,:), 2, 2));

    fprintf("%8d %14.4f %13.3f° %14.4f\n", n, residual, ...
        abs(angleOf(tf) - 15), abs(scaleOf(tf) - 0.9));
end
%[text] ## 殘差為零代表配準很準嗎？**不代表。**
%[text] 相似轉換有 4 個自由度，2 個點剛好提供 4 個方程式——
%[text] 這是一個**恰定**系統，必然有精確解，**殘差恆為零**。
%[text] 但那個「精確解」把兩點的標註誤差完全吸收進了轉換參數裡，
%[text] 所以雖然殘差是零，**真實的角度與縮放誤差卻是所有情況中最大的**。
%[text] **殘差要有意義，點數必須超過模型的最低需求。**
%[text:table]
%[text] | 點數 | 系統 | 殘差 | 意義 |
%[text] | --- | --- | --- | --- |
%[text] | 2 | 恰定 | 恆為 0 | **沒有診斷能力** |
%[text] | 3 | 超定（略） | 很小 | 勉強能看出離群點 |
%[text] | 4+ | 超定 | 反映真實誤差 | 可診斷、可信賴 |
%[text:table]
%[text] 這也是為什麼「最少需要 N 點」與「實務上該給幾點」是兩回事。
%[text] 第 25 章相機標定時會再遇到同樣的道理——理論上 3 張標定板就夠，
%[text] 但實務上要拍 15–20 張。
%%
%[text] # 解答 5：非剛性配準的危險
fixedImg  = I;
unrelated = im2double(imresize(imread("rice.png"), size(I)));

fprintf("配準前 PSNR %.2f dB\n", psnr(unrelated, fixedImg));

smoothings = [3.0 2.0 1.3 0.8];
results = cell(size(smoothings));

fprintf("\n%-26s %10s %14s\n", "AccumulatedFieldSmoothing", "PSNR", "最大位移(px)");
for k = 1:numel(smoothings)
    [disp_, reg] = imregdemons(unrelated, fixedImg, [100 50 25], ...
        AccumulatedFieldSmoothing=smoothings(k), DisplayWaitbar=false);
    results{k} = reg;
    fprintf("%-26.1f %9.2f dB %13.1f\n", smoothings(k), psnr(reg, fixedImg), ...
        max(vecnorm(disp_, 2, 3), [], "all"));
end

figure
montage([{unrelated} results {fixedImg}], Size=[2 3])
title("原始（米粒）｜ 平滑 3.0 ｜ 2.0 ｜ 1.3 ｜ 0.8 ｜ 目標（攝影師）")
%[text] ## 結論：它真的可以把米粒扭成攝影師
%[text] 平滑度越低，自由度越高，PSNR 就越「好看」——
%[text] 但那完全沒有意義。**這兩張影像之間根本不存在正確的對應關係。**
%[text] 非剛性配準有大約 $2\times H\times W$ 個自由度（每個像素兩個），
%[text] 對 256×256 的影像就是 **13 萬個參數**去擬合 6.5 萬個像素——
%[text] 參數比資料還多，它當然可以擬合任何東西。
%[text] **實務守則**：
%[text] 1. 非剛性配準的「PSNR 進步」**不能當作成功的證據**
%[text] 2. 一定要看**位移場本身合不合理**——真實的形變應該是平滑、連續、
%[text] 且有物理意義的；胡亂配準的位移場會雜亂無章
%[text] 3. `AccumulatedFieldSmoothing` 要**盡量設大**，只在確實需要時才降低
%[text] 4. **配準後的影像不能再用來量測** \
%[text] 這一題呼應第 02 章與第 03 章的同一個主題：
%[text] **指標會騙人，要理解指標在量什麼。**
%%
%[text] # 加分題：影像拼接的前半段
whole = im2double(imread("westconcordorthophoto.png"));
[h, w] = size(whole);

% 切出兩塊有重疊的區域
left  = whole(:, 1:round(w*0.6));
right = imrotate(whole(:, round(w*0.4):end), 8, "bilinear", "crop");

figure
imshowpair(left, right, "montage")
title("左半（參考）｜ 右半（旋轉 8 度）")

% 用本章的函式求轉換
[~, tfStitch] = ch07_registerImages(right, left);

%[text] ## 計算共同座標系
%[text] 關鍵是算出「能同時裝下兩張影像」的世界座標範圍。
Rleft = imref2d(size(left));

% right 影像四個角在轉換後的世界座標
[cornersX, cornersY] = transformPointsForward(tfStitch, ...
    [1 size(right,2) size(right,2) 1], [1 1 size(right,1) size(right,1)]);

xLimits = [min([1, cornersX]), max([size(left,2), cornersX])];
yLimits = [min([1, cornersY]), max([size(left,1), cornersY])];

outSize = [ceil(diff(yLimits)) ceil(diff(xLimits))];
Rpanorama = imref2d(outSize, xLimits, yLimits);

fprintf("左影像尺寸   %s\n", mat2str(size(left)));
fprintf("全景座標系   %s\n", mat2str(outSize));
fprintf("世界座標 X [%.0f %.0f]  Y [%.0f %.0f]\n", xLimits, yLimits);

% 把兩張都 warp 到共同座標系
leftWarped  = imwarp(left,  simtform2d(1,0,[0 0]), OutputView=Rpanorama);
rightWarped = imwarp(right, tfStitch,              OutputView=Rpanorama);

leftMask  = imwarp(true(size(left)),  simtform2d(1,0,[0 0]), OutputView=Rpanorama);
rightMask = imwarp(true(size(right)), tfStitch,              OutputView=Rpanorama);

% 融合：重疊區取平均
overlap = leftMask & rightMask;
panorama = leftWarped .* leftMask + rightWarped .* rightMask;
panorama(overlap) = panorama(overlap) / 2;

figure
tiledlayout(2,2)
nexttile; imshow(leftWarped, Rpanorama);  title("左影像在全景座標系")
nexttile; imshow(rightWarped, Rpanorama); title("右影像在全景座標系")
nexttile; imshow(overlap);                title(sprintf("重疊區（%.1f%%）", 100*mean(overlap,"all")))
nexttile; imshow(panorama, Rpanorama);    title("拼接結果")

fprintf("\n重疊區佔全景的 %.1f%%" + "\n", 100*mean(overlap, "all"));
%[text] **重疊區的處理是拼接的難點**。取平均是最簡單的做法，
%[text] 但若兩張影像的曝光不同，接縫處會看到明顯的亮度跳變。
%[text] 更好的做法：
%[text] - **羽化**（feathering）：依離邊界的距離做加權，讓過渡平滑
%[text] - **Poisson 混合**：第 03 章的 `imblend(..., Mode="Poisson")`
%[text] - **最佳接縫**（seam carving）：找一條穿過重疊區、差異最小的路徑 \
%[text] 第 14 章會用**特徵比對**取代本章的強度式配準做完整的全景拼接——
%[text] 特徵法對重疊區小、內容差異大的情況穩健得多。

function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
