%[text] # 第 12 章　影像品質評估與相機／光學特性
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 選用適當的全參考指標，並說出 PSNR 在什麼情況下會誤導你
%[text] 2. 解釋無參考指標（NIQE／BRISQUE／PIQE）量的到底是什麼，以及它們**為什麼會互相矛盾**
%[text] 3. 用 `fitniqe` 為自己的領域訓練品質模型，並判斷什麼時候**必須**這樣做
%[text] 4. 用斜邊法量測 MTF，並用理論值驗證自己的實作
%[text] 5. 量測色彩準確度，並把 ΔE 拆解成亮度誤差與色度誤差
%[text] 6. 用 R2026a 新增的光學設計與模擬功能建立、對焦與分析一個透鏡系統 \
%[text] ## 前置知識
%[text] 第 04 章（空間域濾波，高斯模糊與雜訊模型）與第 11 章（量測與校正的觀念）。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="12");
hasOptics = exist("opticalSystem", "file") > 0;
if hasOptics
    fprintf("\n光學設計與模擬支援包：已安裝\n");
else
    fprintf("\n光學設計與模擬支援包：未安裝（第 10 節會跳過）\n");
end
rng(0);
%%
%[text] # 1. 這一章的位置
%[text] 前面十一章都在問「**我算得對不對**」。這一章換一個問題：
%[text] **這張影像本身夠不夠好？**
%[text] 這兩件事的關係比想像中緊密。第 08 章的分割失敗、第 10 章的邊緣偵測
%[text] 歸零、第 11 章的量測散布——追到底，很多都是影像品質的問題，
%[text] 而不是演算法的問題。**參數調到死也救不回一張糊掉的影像。**
%[text] 品質評估分兩大類，分界線是「**你手上有沒有正確答案**」：
%[text:table]
%[text] | 類型 | 需要什麼 | 代表函式 | 典型用途 |
%[text] | --- | --- | --- | --- |
%[text] | **全參考** | 原圖 + 劣化圖 | `immse` `psnr` `ssim` `multissim` | 壓縮、去雜訊、超解析度的演算法評比 |
%[text] | **無參考** | 只要一張圖 | `niqe` `brisque` `piqe` | 產線上即時判斷「這張要不要重拍」 |
%[text] | **圖卡量測** | 標準測試圖卡 | `esfrChart` `colorChecker` `measureSharpness` | 相機／鏡頭驗收，可追溯的規格 |
%[text:table]
%[text] 再往下一層，就是**光學本身**——第 10 節。
%%
%[text] # 2. 全參考指標
%[text] 從最基本的開始。這一節先建立直覺，第 3 節再打破它。
I = im2double(im2gray(imread("peppers.png")));

% 每一個用到隨機數的小節都重新設種子，讓各節可以**獨立重現**。
% 否則只要前面多抽一次隨機數，後面所有數字都會位移。
rng(0);
noisy   = min(max(I + 0.05*randn(size(I)), 0), 1);
blurred = imgaussfilt(I, 2);

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(I);       title("原圖")
nexttile; imshow(noisy);   title("加雜訊 \sigma=0.05")
nexttile; imshow(blurred); title("高斯模糊 \sigma=2")

fprintf("\n%-16s %10s %10s %10s %12s\n", "影像", "MSE", "PSNR(dB)", "SSIM", "MultiSSIM");
for nm = ["noisy" "blurred"]
    if nm == "noisy", J = noisy; else, J = blurred; end
    fprintf("%-16s %10.6f %10.4f %10.4f %12.4f\n", nm, ...
        immse(J,I), psnr(J,I), ssim(J,I), multissim(J,I));
end
%[text] 四個指標的性格完全不同：
%[text] - `immse`：均方誤差。**逐像素**相減，對「差多少」誠實，對「差在哪」無感
%[text] - `psnr`：MSE 換成 dB。**它就是 MSE**，只是取了對數，排序完全一樣
%[text] - `ssim`：比較**局部的亮度、對比、結構**三項，較接近人眼
%[text] - `multissim`：SSIM 的多尺度版本，對「在哪個尺度上壞掉」比較敏感
%[text] 注意 `psnr` 與 `immse` 是**同一個排序**。這一點在下一節會變成關鍵。
%%
%[text] # 3. PSNR 的盲點：同樣的 PSNR，天差地遠的品質
%[text] 直接把兩種劣化調到**MSE 完全相同**，看指標怎麼說。
%[text] 用二分搜尋找出與雜訊等 MSE 的模糊強度。
rng(0);
sigmaNoise = 0.05;
Anoise = min(max(I + sigmaNoise*randn(size(I)), 0), 1);
targetMSE = immse(Anoise, I);

lo = 0.1; hi = 8;
for it = 1:40
    mid = (lo + hi)/2;
    if immse(imgaussfilt(I, mid), I) < targetMSE, lo = mid; else, hi = mid; end
end
sigmaBlur = (lo + hi)/2;
Ablur = imgaussfilt(I, sigmaBlur);

fprintf("\n目標 MSE = %.6f\n", targetMSE);
fprintf("雜訊 sigma=%.4f  -> MSE %.6f\n", sigmaNoise, immse(Anoise,I));
fprintf("模糊 sigma=%.4f  -> MSE %.6f\n", sigmaBlur,  immse(Ablur,I));

fprintf("\n%-10s %10s %10s %10s %12s\n", "劣化", "MSE", "PSNR", "SSIM", "MultiSSIM");
fprintf("%-10s %10.6f %10.4f %10.4f %12.4f\n", "雜訊", ...
    immse(Anoise,I), psnr(Anoise,I), ssim(Anoise,I), multissim(Anoise,I));
fprintf("%-10s %10.6f %10.4f %10.4f %12.4f\n", "模糊", ...
    immse(Ablur,I), psnr(Ablur,I), ssim(Ablur,I), multissim(Ablur,I));

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile; imshow(Anoise); title(sprintf("雜訊：PSNR %.2f dB、SSIM %.3f", psnr(Anoise,I), ssim(Anoise,I)))
nexttile; imshow(Ablur);  title(sprintf("模糊：PSNR %.2f dB、SSIM %.3f", psnr(Ablur,I),  ssim(Ablur,I)))
%[text] 實測結果（`peppers.png`、`rng(0)`）：
%[text:table]
%[text] | 劣化 | MSE | PSNR | SSIM |
%[text] | --- | --- | --- | --- |
%[text] | 雜訊 σ=0.05 | 0.002483 | **26.0499** | **0.4394** |
%[text] | 模糊 σ=5.2177 | 0.002483 | **26.0499** | **0.8081** |
%[text:table]
%[text] **PSNR 一模一樣到小數第四位，SSIM 差了 1.84 倍。**
%[text] 這不是巧合——我刻意把 MSE 調成相等，而 PSNR 只是 MSE 的對數變換，
%[text] 所以 PSNR 必然相等。
%[text] 那哪一張看起來比較好？把上面兩張圖放大看，多數人會覺得**模糊那張更難用**
%[text] （細節永久消失），但 SSIM 給模糊的分數**更高**。
%[text] > **重點不是「SSIM 比 PSNR 好」。**
%[text] > 重點是：**PSNR 相等不代表品質相等**，而 SSIM 也只是另一種偏好，
%[text] > 它偏好「結構保留」。你要選哪個指標，取決於**你的下游任務在意什麼**。
%[text] > 如果下游是 OCR，模糊比雜訊致命；如果下游是找亮點缺陷，雜訊比模糊致命。
%[text] **實務規則：報告品質時，永遠不要只報一個數字。**
%%
%[text] # 4. 無參考指標
%[text] 產線上沒有「原圖」可以比。這時只能用無參考指標。
fprintf("\n%-10s %10s %10s %10s\n", "影像", "NIQE", "BRISQUE", "PIQE");
fprintf("%-10s %10.4f %10.4f %10.4f\n", "原圖", niqe(I),      brisque(I),      piqe(I));
fprintf("%-10s %10.4f %10.4f %10.4f\n", "雜訊", niqe(Anoise), brisque(Anoise), piqe(Anoise));
fprintf("%-10s %10.4f %10.4f %10.4f\n", "模糊", niqe(Ablur),  brisque(Ablur),  piqe(Ablur));
%[text] 三個指標都是**越低越好**（PIQE 上限 100）。實測：
%[text:table]
%[text] | 劣化 | NIQE | BRISQUE | PIQE |
%[text] | --- | --- | --- | --- |
%[text] | 原圖 | 3.11 | 29.64 | 27.01 |
%[text] | 雜訊 | **12.74** | 40.73 | 60.49 |
%[text] | 模糊 | 6.91 | **66.54** | **100.00** |
%[text:table]
%[text] **三個指標對「哪個比較糟」的答案不一致：**
%[text] - NIQE 說**雜訊更糟**（12.74 > 6.91）
%[text] - BRISQUE 與 PIQE 說**模糊更糟**（66.54 > 40.73、100 > 60.49）
%[text] 同一組影像，同樣「越低越好」，**排序卻相反**。
%[text] 這不是誰有 bug。它們訓練時用的失真類型與人類評分資料集不同，
%[text] 所以各自學到了不同的偏好。
%[text] > **不要把三個無參考指標當成可以互換的東西。**
%[text] > 選一個、固定它、並且知道它偏好什麼。
%%
%[text] # 5. 無參考指標不是絕對品質尺度
%[text] 上一節的矛盾只是開頭。下面這個實測更需要注意。
%[text] **全部都是乾淨、未經任何劣化的影像。**
cleanImgs = ["peppers.png" "cameraman.tif" "text.png" "coins.png" ...
             "rice.png" "circuit.tif" "westconcordorthophoto.png" "pout.tif"];

fprintf("\n%-26s %9s %9s %9s\n", "乾淨影像", "NIQE", "BRISQUE", "PIQE");
for f = cleanImgs
    K = imread(f);
    % 注意順序：text.png 是 logical，im2gray 只吃 numeric，
    % 寫成 im2gray(imread(...)) 會直接報 mustBeNumeric。
    if size(K,3) > 1
        K = im2gray(K);
    end
    K = im2double(K);
    fprintf("%-26s %9.3f %9.3f %9.3f\n", f, niqe(K), brisque(K), piqe(K));
end
%[text] 實測：
%[text:table]
%[text] | 乾淨影像 | NIQE | BRISQUE | PIQE |
%[text] | --- | --- | --- | --- |
%[text] | `peppers.png` | 3.11 | 29.64 | 27.01 |
%[text] | `cameraman.tif` | 4.10 | **6.49** | 31.29 |
%[text] | **`text.png`** | **39.62** | 48.14 | 77.10 |
%[text] | `coins.png` | 6.67 | 30.01 | 21.78 |
%[text] | **`rice.png`** | **26.90** | 43.46 | 30.57 |
%[text] | `pout.tif` | 3.73 | **42.82** | 24.39 |
%[text:table]
%[text] `text.png` 是一張**完全清晰**的文字影像，NIQE 給它 39.62——
%[text] 比 `peppers.png` 差了 **12.8 倍**。`rice.png` 也一樣，乾淨卻得到 26.90。
%[text] 反過來看 BRISQUE：`cameraman.tif` 得 6.49（極好），
%[text] `pout.tif` 得 42.82（很糟）——但兩張都是乾淨的原始影像。
%[text] > **NIQE／BRISQUE 量的不是「品質」，是「與訓練分布的距離」。**
%[text] > 它們的訓練資料是**自然照片**。文字、米粒、電路板、顯微影像的
%[text] > 統計特性本來就不像自然照片，所以分數天生就高。
%[text] 這件事的後果很嚴重：**如果你拿預設 NIQE 當產線的品質門檻，
%[text] 你會系統性地誤判整個領域。** 第 7 節提供解法。
%%
%[text] # 6. 響應曲線：指標對什麼敏感
%[text] 把雜訊與模糊各自掃一遍，看每個指標怎麼反應。
rng(0);
noiseSigmas = [0 0.01 0.02 0.05 0.10 0.20];
blurSigmas  = [0 0.5 1 2 4 8];

nN = numel(noiseSigmas);
resN = zeros(nN, 5);
for k = 1:nN
    s = noiseSigmas(k);
    if s == 0, J = I; else, J = min(max(I + s*randn(size(I)),0),1); end
    resN(k,:) = [psnr(J,I) ssim(J,I) niqe(J) brisque(J) piqe(J)];
end

nB = numel(blurSigmas);
resB = zeros(nB, 5);
for k = 1:nB
    s = blurSigmas(k);
    if s == 0, J = I; else, J = imgaussfilt(I, s); end
    resB(k,:) = [psnr(J,I) ssim(J,I) niqe(J) brisque(J) piqe(J)];
end

fprintf("\n=== 雜訊響應 ===\n");
fprintf("%-8s %9s %9s %9s %9s %9s\n", "sigma", "PSNR", "SSIM", "NIQE", "BRISQUE", "PIQE");
for k = 1:nN
    fprintf("%-8.2f %9.3f %9.4f %9.3f %9.3f %9.3f\n", noiseSigmas(k), resN(k,:));
end

fprintf("\n=== 模糊響應 ===\n");
fprintf("%-8s %9s %9s %9s %9s %9s\n", "sigma", "PSNR", "SSIM", "NIQE", "BRISQUE", "PIQE");
for k = 1:nB
    fprintf("%-8.2f %9.3f %9.4f %9.3f %9.3f %9.3f\n", blurSigmas(k), resB(k,:));
end
%%
%[text] ## 6.1 三個必須知道的異常
figure
tiledlayout(1,2, TileSpacing="compact")

nexttile
plot(noiseSigmas, resN(:,3), "o-", LineWidth=1.6, DisplayName="NIQE")
hold on
plot(noiseSigmas, resN(:,4), "s-", LineWidth=1.6, DisplayName="BRISQUE")
plot(noiseSigmas, resN(:,5), "^-", LineWidth=1.6, DisplayName="PIQE")
yline(resN(1,4), "--", "原圖 BRISQUE", LineWidth=1);
hold off
xlabel("雜訊 \sigma"); ylabel("分數（越低越好）")
title("雜訊響應"); legend(Location="southeast"); grid on

nexttile
plot(blurSigmas, resB(:,3), "o-", LineWidth=1.6, DisplayName="NIQE")
hold on
plot(blurSigmas, resB(:,4), "s-", LineWidth=1.6, DisplayName="BRISQUE")
plot(blurSigmas, resB(:,5), "^-", LineWidth=1.6, DisplayName="PIQE")
yline(100, ":", "PIQE 上限", LineWidth=1);
hold off
xlabel("模糊 \sigma"); ylabel("分數（越低越好）")
title("模糊響應"); legend(Location="southeast"); grid on

fprintf("\n異常 1：加一點雜訊反而讓分數變好\n");
fprintf("  原圖      BRISQUE %.3f、PIQE %.3f\n", resN(1,4), resN(1,5));
fprintf("  雜訊 0.01 BRISQUE %.3f、PIQE %.3f\n", resN(2,4), resN(2,5));
fprintf("\n異常 2：PIQE 在模糊 sigma>=4 時飽和\n");
fprintf("  sigma=4 PIQE %.3f、sigma=8 PIQE %.3f -> 分不出來\n", resB(5,5), resB(6,5));
fprintf("\n異常 3：NIQE 與 BRISQUE 在重度模糊時「回頭」\n");
fprintf("  NIQE    sigma=4 %.3f -> sigma=8 %.3f\n", resB(5,3), resB(6,3));
fprintf("  BRISQUE sigma=4 %.3f -> sigma=8 %.3f\n", resB(5,4), resB(6,4));
%[text] **異常 1：加一點雜訊會讓分數「變好」。**
%[text] 原圖 BRISQUE 29.64、PIQE 27.01；加了 σ=0.01 的雜訊之後
%[text] 變成 BRISQUE **12.94**、PIQE **10.23**——兩個都大幅「改善」。
%[text] 原因：這兩個指標的訓練資料是**相機拍的自然照片**，都帶有感測器雜訊。
%[text] 一張完全乾淨的影像對它們來說「不自然」。
%[text] **所以無參考指標不能用來驗證去雜訊演算法——你去得越乾淨，分數可能越差。**
%[text] **異常 2：PIQE 會飽和。**
%[text] 模糊 σ≥4 時 PIQE 一律是 100，完全分不出 σ=4 與 σ=8。
%[text] 上限存在的指標，在接近上限時就失去了解析能力。
%[text] **異常 3：重度模糊時 NIQE 與 BRISQUE 會「回頭」。**
%[text] NIQE 從 σ=4 的 6.93 降到 σ=8 的 6.65；BRISQUE 從 67.91 降到 61.50。
%[text] 另外注意 NIQE 對雜訊的響應是單調的（3.11 → 19.87），
%[text] 對模糊卻只從 3.11 爬到 6.93——**它對雜訊的敏感度遠高於模糊**。
%[text] 越糊反而「越好」——因為極度模糊的影像幾乎沒有高頻結構可供評估，
%[text] 統計上反而變得平滑而「乾淨」。
%[text] > **三個異常的共同教訓：無參考指標只在一段有效區間內單調。**
%[text] > 用它當自動判斷門檻之前，**一定要先掃出你自己資料的響應曲線**，
%[text] > 確認你關心的劣化範圍落在單調區間裡。
%%
%[text] # 7. `fitniqe`：為自己的領域訓練模型
%[text] 第 5 節的問題有解：用**你自己領域的好影像**重新訓練 NIQE 模型。
%[text] 下面用合成的「晶圓／PCB 紋理」當領域範例。
%[text] 真實專案就把這批換成你產線拍的合格品影像。
domainDir = fullfile(tempdir, "ipcv_ch12_domain");
if isfolder(domainDir), rmdir(domainDir, "s"); end
mkdir(domainDir);

nTrain = 24;
for k = 1:nTrain
    imwrite(ch12_makeWaferLike(256, 256, k), ...
        fullfile(domainDir, sprintf("wafer_%02d.png", k)));
end
fprintf("\n訓練集：%d 張合成晶圓紋理\n", nTrain);

imds  = imageDatastore(domainDir);
model = fitniqe(imds);
fprintf("自訓模型類別 %s，BlockSize %s\n", class(model), mat2str(model.BlockSize));

figure
montage(imds, Size=[3 8])
title("fitniqe 的訓練集：24 張「合格品」影像")
%%
%[text] ## 7.1 預設模型 vs 自訓模型
testClean = ch12_makeWaferLike(256, 256, 999);
rng(0);
cases = struct( ...
    "name", {"乾淨（同領域）", "輕微模糊 s=1", "明顯模糊 s=3", ...
             "雜訊 0.02", "雜訊 0.08", "自然照片 peppers"}, ...
    "img",  {testClean, imgaussfilt(testClean,1), imgaussfilt(testClean,3), ...
             min(max(testClean + 0.02*randn(256),0),1), ...
             min(max(testClean + 0.08*randn(256),0),1), ...
             im2double(im2gray(imread("peppers.png")))});

nc = numel(cases);
scoreDefault = zeros(nc,1); scoreCustom = zeros(nc,1);
fprintf("\n%-22s %14s %14s\n", "測試影像", "預設 NIQE", "自訓 NIQE");
for k = 1:nc
    scoreDefault(k) = niqe(cases(k).img);
    scoreCustom(k)  = niqe(cases(k).img, model);
    fprintf("%-22s %14.4f %14.4f\n", cases(k).name, scoreDefault(k), scoreCustom(k));
end

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(testClean);                title("乾淨")
nexttile; imshow(imgaussfilt(testClean,3)); title("明顯模糊 s=3")
nexttile
bar([scoreDefault(1:3) scoreCustom(1:3)])
set(gca, XTickLabel=["乾淨" "模糊1" "模糊3"])
set(gca, YScale="log")
ylabel("NIQE（對數軸）"); legend(["預設模型" "自訓模型"], Location="northwest")
title("預設模型把模糊判成「更好」")
%[text] 實測結果：
%[text:table]
%[text] | 測試影像 | 預設 NIQE | 自訓 NIQE |
%[text] | --- | --- | --- |
%[text] | 乾淨（同領域） | 64.68 | **5.22** |
%[text] | 輕微模糊 σ=1 | 58.19 | 428.03 |
%[text] | **明顯模糊 σ=3** | **12.02** | 8065.89 |
%[text] | 雜訊 0.02 | 31.01 | 149.83 |
%[text] | 雜訊 0.08 | 21.55 | 10067.65 |
%[text] | 自然照片 peppers | 3.11 | 312.63 |
%[text:table]
%[text] 看第三列。**預設模型給「明顯模糊」的分數是 12.02，
%[text] 比「乾淨」的 64.68 好了 5.4 倍。**
%[text] 也就是說，**預設 NIQE 在這個領域上把排序完全弄反了**——
%[text] 拿它當產線門檻，會主動挑掉清晰的影像、留下糊掉的。
%[text] 自訓模型則正確：乾淨 5.22 → 模糊 σ=3 是 8065.89，**增加 1545 倍**，
%[text] 而且對雜訊也單調（149.83 → 10067.65）。
%[text] 順帶注意預設模型對雜訊的反應也是反的：0.02 得 31.01、0.08 得 **21.55**——
%[text] **雜訊加重，預設模型反而覺得變好了。**
%[text] 最後一列是另一個驗證：自然照片在自訓模型下得 312.63。
%[text] 這是**正確的**——peppers 確實離「晶圓」這個領域很遠。
%[text] 模型忠實地回報「這不是我認識的東西」。
%[text] > **自訓 NIQE 的分數沒有絕對意義，只有相對意義。**
%[text] > 5.22 與 8065.89 這兩個數字本身不能跨專案比較，
%[text] > 但在**同一個模型、同一個領域**內，它們的排序是可信的。
%[text] > 這與第 11 章的校正係數是同一個原則：
%[text] > **數字要帶著它的來歷（哪個模型、哪批訓練影像）一起流動。**
%%
%[text] # 8. 斜邊法量測 MTF
%[text] MTF（調變轉換函數）是鏡頭銳利度的**可追溯規格**，
%[text] 比「看起來很利」精確得多。
%[text] 標準做法是拍 eSFR 測試圖卡，用 `esfrChart` + `measureSharpness` 自動量。
%[text] **但那需要一張真實的圖卡照片**（`eSFRTestImage.jpg` 不在本機 MATLAB 安裝中）。
%[text] 所以這裡用合成斜邊自己實作一次——流程與圖卡量測**完全相同**，
%[text] 而且自己寫過一次，才知道圖卡量出來的數字是什麼意思。
%[text] **為什麼要斜邊而不是正邊？**
%[text] 正對齊的邊只能在整數像素位置取樣，解析度被像素格點限制。
%[text] 斜邊讓每一列的邊緣落在**不同的次像素位置**，把所有列對齊疊合之後，
%[text] 就得到一條**超取樣**的邊緣剖面（ESF）。這是斜邊法的全部精髓。
edgeImg = ch12_makeSlantedEdge(256, 256, 5, 0.6);

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile; imshow(edgeImg); title("合成斜邊（傾斜 5 度）")
nexttile; imshow(imcrop(edgeImg, [108 108 40 40])); title("放大：邊界穿過不同的次像素位置")
%%
%[text] ## 8.1 量測並與理論值對照
%[text] 這是本節最重要的一步：**自己寫的量測程式，必須先用已知答案驗證。**
%[text] 合成邊的模糊量是我們自己給的，所以理論 MTF 可以算出來：
%[text] 高斯模糊的 MTF 是 $\exp(-2\pi^2\sigma^2 f^2)$，
%[text] 令它等於 0.5 可解出 $f_{50} = \sqrt{\ln 2 / (2\pi^2\sigma^2)}$。
sensorSigma = 0.6;                      % 合成時加的「感測器」模糊
addedBlur   = [0 0.5 1 2 3];

fprintf("\n%-12s %10s %10s %12s %10s\n", ...
    "額外模糊", "MTF50實測", "MTF50理論", "實測/理論", "MTF20");
measured50 = zeros(size(addedBlur));
theory50   = zeros(size(addedBlur));
for k = 1:numel(addedBlur)
    s = addedBlur(k);
    if s == 0, E = edgeImg; else, E = imgaussfilt(edgeImg, s); end
    [measured50(k), m20] = ch12_measureMTF(E);

    sigTotal    = hypot(sensorSigma, s);        % 兩個高斯相疊
    theory50(k) = sqrt(log(2) / (2*pi^2*sigTotal^2));

    fprintf("%-12.1f %10.4f %10.4f %12.3f %10.4f\n", ...
        s, measured50(k), theory50(k), measured50(k)/theory50(k), m20);
end

figure
plot(addedBlur, theory50, "k-", LineWidth=2, DisplayName="理論 f_{50}")
hold on
plot(addedBlur, measured50, "o", MarkerSize=9, LineWidth=1.6, DisplayName="斜邊法實測")
hold off
xlabel("額外高斯模糊 \sigma（像素）"); ylabel("MTF50（cycles/pixel）")
title("自寫 MTF 量測 vs 理論值"); legend; grid on
ylim([0 0.35])
%[text] 實測（`sensorSigma = 0.6`）：
%[text:table]
%[text] | 額外模糊 σ | MTF50 實測 | MTF50 理論 | 實測/理論 |
%[text] | --- | --- | --- | --- |
%[text] | 0 | 0.2845 | 0.3123 | **0.911** |
%[text] | 0.5 | 0.2335 | 0.2399 | 0.973 |
%[text] | 1 | 0.1578 | 0.1607 | 0.982 |
%[text] | 2 | 0.0941 | 0.0897 | 1.049 |
%[text] | 3 | 0.0671 | 0.0613 | **1.095** |
%[text:table]
%[text] **中間段吻合到 2–5%，兩端各差約 9–10%。**
%[text] 這個誤差分布本身有意義，而且方向相反：
%[text] - **最銳利那端（σ=0）實測偏低 8.9%。** MTF50 已經到 0.28 cycles/pixel，
%[text]   逼近 Nyquist（0.5）。我的估計器用**有限差分**求 LSF，
%[text]   而差分本身是一個低通濾波器——頻率越高，它壓得越多。
%[text] - **最模糊那端（σ=3）實測偏高 9.5%。** 此時 LSF 很寬，
%[text]   加窗（Hann）會截掉尾部，等效於讓 LSF 變窄、MTF 變高。
%[text] > **不要跳過這個對照表。** 一支沒有用已知答案驗證過的量測程式，
%[text] > 產生的數字沒有意義。這也是為什麼產線要用**標準圖卡**——
%[text] > 圖卡的作用就是提供已知答案。
%[text] 用 `ch12_measureMTF` 時務必記住它的有效範圍：
%[text] **MTF50 落在大約 0.05–0.25 cycles/pixel 時最可信。**
%%
%[text] # 9. 色彩準確度：ΔE 與它的拆解
%[text] `colorChecker` 自動定位 24 色塊，`measureColor` 回報每一塊的
%[text] 實測 RGB、參考 Lab 與 **ΔE**（CIE 色差）。
%[text] 經驗門檻：ΔE < 1 人眼幾乎看不出；ΔE > 5 明顯不同色。
Icc = imread("colorCheckerTestImage.jpg");
cc  = colorChecker(Icc);

figure
imshow(Icc); title("colorCheckerTestImage.jpg")

colorTbl = measureColor(cc);
fprintf("\n色塊數 %d\n", height(colorTbl));
fprintf("平均 Delta_E = %.3f，最大 %.3f\n", mean(colorTbl.Delta_E), max(colorTbl.Delta_E));
disp(head(colorTbl(:, ["Color" "Measured_R" "Measured_G" "Measured_B" ...
                       "Reference_L" "Delta_E"]), 6))
%[text] 平均 ΔE = **21.23**，最大 33.34。這遠超過「明顯不同色」的門檻。
%[text] 直覺的下一步是「做白平衡」。**先別急。**
%%
%[text] ## 9.1 先拆解，再修正
%[text] ΔE 是 Lab 空間的歐氏距離，包含**亮度**（L）與**色度**（a、b）兩部分。
%[text] 不拆開看，你不知道該修哪個。
measRGB = [colorTbl.Measured_R colorTbl.Measured_G colorTbl.Measured_B];
measLab = rgb2lab(double(measRGB)/255);
refLab  = [colorTbl.Reference_L colorTbl.Reference_a colorTbl.Reference_b];

dL  = measLab(:,1) - refLab(:,1);
dab = hypot(measLab(:,2) - refLab(:,2), measLab(:,3) - refLab(:,3));

fprintf("\n平均 |dL|  = %7.3f  （亮度誤差）\n", mean(abs(dL)));
fprintf("平均  dL   = %+7.3f  （帶符號：正值代表影像比參考亮）\n", mean(dL));
fprintf("平均 |dab| = %7.3f  （色度誤差）\n", mean(dab));
fprintf("dL 的範圍  = %+.2f 到 %+.2f（%d / %d 個色塊同號）\n", ...
    min(dL), max(dL), nnz(dL > 0), numel(dL));

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
bar([dL dab])
xlabel("色塊編號"); ylabel("誤差")
legend(["\DeltaL（亮度）" "\Deltaab（色度）"], Location="northeast")
title("誤差來源拆解"); grid on
nexttile
scatter(dab, abs(dL), 60, "filled")
hold on; plot([0 30],[0 30], "k--", DisplayName="等權線"); hold off
xlabel("|\Deltaab| 色度誤差"); ylabel("|\DeltaL| 亮度誤差")
title("所有色塊都在亮度側"); grid on; axis equal
%[text] 實測拆解：
%[text:table]
%[text] | 項目 | 數值 |
%[text] | --- | --- |
%[text] | 平均 ΔL 絕對值（亮度） | **18.83** |
%[text] | 平均 ΔL（帶符號） | **+18.83** |
%[text] | 平均 Δab 絕對值（色度） | 9.17 |
%[text:table]
%[text] 兩件事同時成立：
%[text] 1. 亮度誤差是色度誤差的 **2.1 倍**
%[text] 2. ΔL 的絕對值平均與帶符號平均完全相同 → **24 個色塊全部同號**，影像一律偏亮
%[text] 全部同號代表這是一個**系統性偏移**，不是隨機誤差。
%[text] 前六個色塊的實測 L 值是 56.6 / 82.8 / 75.9 / 62.9 / 76.9 / 87.1，
%[text] 對應的參考值是 37.5 / 64.7 / 49.3 / 43.5 / 54.9 / 70.5——每一塊都高出 16 到 27。
%[text] 全部 24 塊的 ΔL 範圍是 **+4.52 到 +29.61**：大小不一，但**沒有一塊是負的**。
%[text] > **ΔE 很大 ≠ 顏色不對。** 這裡的 ΔE 有 89% 來自曝光，不是色偏。
%%
%[text] ## 9.2 驗證這個結論：兩種「修正」的效果
%[text] 診斷要能被檢驗。如果診斷正確，那麼**白平衡應該幾乎沒用，
%[text] 而亮度修正應該明顯有用**。
illum = measureIlluminant(cc);
fprintf("\nmeasureIlluminant = %s\n", mat2str(illum, 5));
fprintf("（三通道相當接近，本來就沒什麼色偏可修）\n");

Iwb   = chromadapt(Icc, illum, ColorSpace="linear-rgb");
ccWB  = colorChecker(Iwb);
tblWB = measureColor(ccWB);

scaleL  = mean(refLab(:,1)) / mean(measLab(:,1));
labFix  = measLab; labFix(:,1) = measLab(:,1) * scaleL;
dEfixed = sqrt(sum((labFix - refLab).^2, 2));

fprintf("\n%-28s %12s\n", "處理", "平均 Delta_E");
fprintf("%-28s %12.3f\n", "原始", mean(colorTbl.Delta_E));
fprintf("%-28s %12.3f\n", "白平衡（chromadapt）", mean(tblWB.Delta_E));
fprintf("%-28s %12.3f\n", "只修亮度（scale L）", mean(dEfixed));
fprintf("\n亮度縮放係數 = %.4f\n", scaleL);
%[text] 實測驗證：
%[text:table]
%[text] | 處理 | 平均 ΔE | 改善 |
%[text] | --- | --- | --- |
%[text] | 原始 | 21.23 | — |
%[text] | 白平衡（`chromadapt`） | 19.85 | 僅 6.5% |
%[text] | **只修亮度** | **12.34** | **41.9%** |
%[text:table]
%[text] **診斷得到證實。** `measureIlluminant` 回報 `[173.94 185.19 193.40]`，
%[text] 三個通道很接近，本來就沒什麼色偏——所以白平衡只改善了 6.5%。
%[text] 而單純把亮度縮放 0.7426 倍，就讓 ΔE 掉了 41.9%。
%[text] > **這一節的方法論比數字重要：**
%[text] > 1. 量到一個大誤差
%[text] > 2. **先拆解**它的組成
%[text] > 3. 由拆解結果**預測**哪種修正有效
%[text] > 4. **實際做兩種修正來驗證預測**
%[text] > 少了第 2、4 步，你會花一整天調白平衡，然後只換到 6.5%。
%[text] 附帶一個實務提醒：剩下的 12.34 修不掉，因為 ΔE 是對**絕對**參考值比較的。
%[text] 要得到有意義的絕對 ΔE，拍攝時的曝光與照明必須是受控的。
%[text] 做不到的話，就該誠實地只報**相對**色差——這與第 11 章
%[text] 「沒有參考物就只報像素」是同一個原則。
%%
%[text] # 10. R2026a：光學設計與模擬
%[text] R2026a 新增 **Optical Design and Simulation Library for Image Processing
%[text] Toolbox** 支援包，把光學設計搬進 MATLAB：
%[text] 建立透鏡系統、光線追跡、點列圖、像差／畸變／場曲分析、
%[text] 玻璃與鍍膜庫、ZMX 匯入，以及 **Optical System Designer** APP。
%[text] 這對做影像的人為什麼重要？因為**前面九章的所有問題都源自這裡**。
if ~hasOptics
    fprintf("\n未安裝光學支援包，跳過第 10 節。\n");
    fprintf("安裝方式：附加功能 > 取得附加功能 > 搜尋 Optical Design and Simulation\n");
end
%%
%[text] ## 10.1 建立一個單透鏡
if hasOptics
    singlet = opticalSystem;
    fprintf("\n預設波長 = %s nm\n", mat2str(singlet.Wavelengths, 6));
    fprintf("主波長   = %.4f nm（d 線，黃綠光）\n", singlet.PrimaryWavelength);

    % 等凸單透鏡，目標焦距 100 mm。薄透鏡近似：R = 2(n-1)f
    nBK7 = 1.5168;
    R    = 2*(nBK7 - 1)*100;
    SD   = 5;                       % 半口徑 -> f/10

    addRefractiveSurface(singlet, Radius=R,  Material="N-BK7", ...
        DistanceToNext=4, SemiDiameter=SD);
    addRefractiveSurface(singlet, Radius=-R, ...
        DistanceToNext=100, SemiDiameter=SD);
    addImagePlane(singlet);

    fprintf("\n設計半徑 R = %.3f mm\n", R);
    disp(singlet.SurfaceTable(:, ["Radius" "MaterialName" "Position"]))
end
%[text] 兩個 API 細節很容易踩到：
%[text] **① 第二個面不要給 `Material`。**
%[text] 玻璃庫裡**沒有 `"air"`**，寫 `Material="air"` 會直接報
%[text] `optics:glassLibrary:glassNotFound`。
%[text] `Material` 指的是「這個面**之後**的介質」，省略就會用環境介質
%[text] （`SurfaceTable` 裡顯示為 `"Vacuum"`）。
%[text] **② 參數全部是名稱-值。**
%[text] `addRefractiveSurface(sys, 50, 5, "N-BK7")` 這種位置引數寫法不成立，
%[text] 必須寫 `Radius=50, DistanceToNext=5, Material="N-BK7"`。
%%
%[text] ## 10.2 陷阱：`opticalSystem` 是 handle 物件
%[text] 這是本節最重要的一件事，而且它與課程中**其他所有影像函式的行為相反**。
if hasOptics
    demo  = opticalSystem;
    addRefractiveSurface(demo, Radius=50, Material="N-BK7", ...
        DistanceToNext=5, SemiDiameter=10);

    alias = demo;               % 只是同一個物件的另一個名字
    clone = copy(demo);         % 真正獨立的複本

    addRefractiveSurface(alias, Radius=-50, DistanceToNext=95, SemiDiameter=10);

    fprintf("\n對 alias 加了一個面之後：\n");
    fprintf("  demo  有 %d 個面\n", numel(demo.Surfaces));
    fprintf("  alias 有 %d 個面\n", numel(alias.Surfaces));
    fprintf("  clone 有 %d 個面\n", numel(clone.Surfaces));
    fprintf("  demo == alias（同一個 handle）？%d\n", demo == alias);
end
%[text] 實測：改 `alias`，`demo` 也跟著變成 2 個面。`clone` 維持 1 個。
%[text] `imgaussfilt`、`regionprops` 這些函式都是**值語意**：
%[text] 傳進去的東西不會被改。`opticalSystem` 是 **handle 語意**：
%[text] 傳進去的物件**會被就地修改**。
%[text] 要做參數掃描或「改一版留一版」，**必須用 `copy()`**。
%[text] ### 一個會安靜出錯的寫法
if hasOptics
    trial = copy(demo);
    addImagePlane(trial);
    result = focus(trial);           % 看起來像「回傳新系統」
    fprintf("\nresult 的類別 = %s\n", class(result));
    fprintf("focus 其實已經就地改掉 trial，而回傳值是點列圖物件。\n");
end
%[text] `result = focus(trial)` **不會報錯**，但回傳的是
%[text] `optics.result.Spot`，**不是**光學系統。
%[text] 真正被對焦的是 `trial` 本身。
%[text] 如果你照著值語意的直覺寫：
%[text] ```matlab
%[text] focused = focus(sys);      % 以為 sys 沒變
%[text] spot(focused)              % 其實 focused 是 Spot 物件
%[text] ```
%[text] 你會拿到一個難以理解的錯誤，而且**`sys` 已經被改掉了**。
%[text] > **判斷方法**：物件有 `copy`、`delete`、`isvalid` 這些方法，
%[text] > 它就是 handle 類別。看到就假設所有方法都會就地修改。
%%
%[text] ## 10.3 對焦與點列圖
if hasOptics
    infoBefore = paraxialInfo(singlet);
    zBefore    = singlet.SurfaceTable.Position(end,3);

    focus(singlet);                 % 就地把像面移到 RMS 點徑最小處
    zAfter = singlet.SurfaceTable.Position(end,3);

    fprintf("\n焦距        %.4f mm\n", infoBefore.FocalLength);
    fprintf("F 數        f/%.3f\n",   infoBefore.FNumber);
    fprintf("後焦距 BFL  %.4f mm\n",  infoBefore.BackFocalLength);
    fprintf("像面位置    %.3f -> %.3f mm（focus 移動了 %.3f）\n", ...
        zBefore, zAfter, zAfter - zBefore);

    spotSinglet = spot(singlet);
    fprintf("\n各波長的 RMS 點徑（mm）：\n");
    for k = 1:numel(singlet.Wavelengths)
        fprintf("  %7.2f nm : %.6f\n", singlet.Wavelengths(k), spotSinglet.RMS(k));
    end
    fprintf("平均 %.6f、全距 %.6f\n", ...
        mean(spotSinglet.RMS), max(spotSinglet.RMS)-min(spotSinglet.RMS));

    figure
    view2d(singlet, Parent=gcf);
    title("單透鏡：2D 光路")

    figure
    spotDiagram(spotSinglet, Parent=gcf);
    title("單透鏡的點列圖（三個波長分不開）")
end
%[text] 單透鏡實測：焦距 **100.66 mm**、**f/10.07**、後焦距 99.34 mm。
%[text] 像面的起始位置是 104 mm（透鏡厚 4 mm + `DistanceToNext=100`），
%[text] `focus` 把它移到 **102.895 mm**，也就是往前拉了 1.105 mm。
%[text] 注意 `DistanceToNext` 是**相對於前一個面**的距離，不是絕對座標——
%[text] 所以「給 100」不等於「像面在 100」。
%[text] 三個波長的 RMS 點徑：
%[text:table]
%[text] | 波長 | RMS 點徑（mm） |
%[text] | --- | --- |
%[text] | 486.13 nm（藍） | 0.035209 |
%[text] | 587.56 nm（黃綠） | **0.006611** |
%[text] | 656.28 nm（紅） | 0.023620 |
%[text:table]
%[text] **藍光的點徑是黃綠光的 5.3 倍。** 這就是**色差**：
%[text] 玻璃對不同波長的折射率不同，所以焦點不在同一個位置。
%[text] `focus` 只能折衷——它讓主波長最利，其他波長就得妥協。
%%
%[text] ## 10.4 消色差雙合透鏡
%[text] 色差的古典解法：把**冕牌玻璃**（低色散）與**火石玻璃**（高色散）
%[text] 黏在一起，讓兩者的色散互相抵消。
%[text] 薄透鏡消色差條件：$\phi_1/V_1 + \phi_2/V_2 = 0$，
%[text] 其中 $V$ 是阿貝數，$\phi = 1/f$ 是光焦度。
if hasOptics
    [doublet, designNote] = ch12_makeAchromat(100, SD);
    disp(designNote)

    focus(doublet);
    infoDbl  = paraxialInfo(doublet);
    spotDbl  = spot(doublet);

    fprintf("\n%-26s %13s %13s %9s\n", "", "單透鏡", "消色差鏡", "倍數");
    fprintf("%-26s %13.4f %13.4f %9s\n", "焦距 (mm)", ...
        infoBefore.FocalLength, infoDbl.FocalLength, "--");
    fprintf("%-26s %13.4f %13.4f %9s\n", "F 數", ...
        infoBefore.FNumber, infoDbl.FNumber, "--");
    for k = 1:3
        fprintf("%-26s %13.6f %13.6f %9.2f\n", ...
            sprintf("RMS 點徑 %g nm", round(singlet.Wavelengths(k))), ...
            spotSinglet.RMS(k), spotDbl.RMS(k), spotSinglet.RMS(k)/spotDbl.RMS(k));
    end
    fprintf("%-26s %13.6f %13.6f %9.2f\n", "RMS 平均", ...
        mean(spotSinglet.RMS), mean(spotDbl.RMS), ...
        mean(spotSinglet.RMS)/mean(spotDbl.RMS));
    fprintf("%-26s %13.6f %13.6f %9.2f\n", "RMS 全距（色差）", ...
        max(spotSinglet.RMS)-min(spotSinglet.RMS), ...
        max(spotDbl.RMS)-min(spotDbl.RMS), ...
        (max(spotSinglet.RMS)-min(spotSinglet.RMS)) / ...
        (max(spotDbl.RMS)-min(spotDbl.RMS)));

    figure
    view2d(doublet, Parent=gcf);
    title("消色差雙合透鏡：2D 光路")

    figure
    spotDiagram(spotDbl, Parent=gcf);
    title("消色差鏡的點列圖（注意座標尺度比單透鏡小得多）")
end
%[text] **這個比較是公平的**——兩支鏡的焦距（100.66 vs 100.71 mm）
%[text] 與 F 數（f/10.07 vs f/10.07）幾乎完全相同。
%[text] 光學比較最常見的錯誤就是拿不同 F 數的鏡頭比點徑：
%[text] 光圈越小，球面像差越小，這時「更好」只是因為光圈比較小。
%[text:table]
%[text] | 項目 | 單透鏡 | 消色差鏡 | 改善 |
%[text] | --- | --- | --- | --- |
%[text] | 焦距 (mm) | 100.6638 | 100.7019 | — |
%[text] | F 數 | f/10.07 | f/10.07 | — |
%[text] | RMS 點徑 486 nm | 0.035209 | 0.001772 | **19.87×** |
%[text] | RMS 點徑 588 nm | 0.006611 | 0.001156 | 5.72× |
%[text] | RMS 點徑 656 nm | 0.023620 | 0.001443 | 16.36× |
%[text] | RMS 平均 | 0.021813 | 0.001457 | **14.97×** |
%[text] | RMS 全距（色差指標） | 0.028598 | 0.000617 | **46.38×** |
%[text:table]
%[text] 兩個數字要分開讀：
%[text] - **RMS 平均改善 15.0 倍**：整體成像變利了
%[text] - **RMS 全距改善 46.4 倍**：波長之間的差異幾乎消失了——這才是「消色差」
%[text] 注意改善最大的是**藍光**（19.9×），最小的是主波長（5.7×）。
%[text] 這完全合理：單透鏡的 `focus` 本來就是對主波長最佳化的，
%[text] 所以主波長本來就還不錯，能改善的空間最小。
%%
%[text] ## 10.5 縱向色差：焦點位移多少 mm
%[text] 點徑是「結果」，焦點位移是「原因」。分別量一次。
%[text] 做法：把系統複製一份、只留一個波長、各自對焦，再比像面位置。
if hasOptics
    fprintf("\n%-12s %14s %14s\n", "波長 (nm)", "單透鏡像面 z", "消色差鏡像面 z");
    zS = zeros(1,3); zD = zeros(1,3);
    for k = 1:3
        a = copy(singlet); a.Wavelengths = singlet.Wavelengths(k); focus(a);
        b = copy(doublet); b.Wavelengths = doublet.Wavelengths(k); focus(b);
        zS(k) = a.SurfaceTable.Position(end,3);
        zD(k) = b.SurfaceTable.Position(end,3);
        fprintf("%-12.2f %14.4f %14.4f\n", singlet.Wavelengths(k), zS(k), zD(k));
    end
    fprintf("%-12s %14.4f %14.4f\n", "焦點位移", max(zS)-min(zS), max(zD)-min(zD));
    fprintf("改善 %.1f 倍\n", (max(zS)-min(zS))/(max(zD)-min(zD)));
end
%[text] 實測：
%[text:table]
%[text] | 波長 | 單透鏡像面 z | 消色差鏡像面 z |
%[text] | --- | --- | --- |
%[text] | 486.13 nm | 102.0328 | 104.1181 |
%[text] | 587.56 nm | 103.0980 | 104.0703 |
%[text] | 656.28 nm | 103.5788 | 104.1204 |
%[text] | **焦點位移** | **1.5461 mm** | **0.0501 mm** |
%[text:table]
%[text] 單透鏡的藍光與紅光焦點差 **1.55 mm**。
%[text] 對一支後焦距 99 mm 的鏡頭，那是 1.6% 的偏移——**遠超過景深**。
%[text] 消色差鏡降到 0.050 mm，改善 **30.9 倍**。
%[text] **注意這裡必須用 `copy()`。** 如果直接改 `singlet.Wavelengths`，
%[text] 原始系統就永久壞掉了——正是第 10.2 節的陷阱。
%[text] **這一節要用 `copy` 的地方，就是前面警告會出事的地方。**
%%
%[text] ## 10.6 畸變與視場
if hasOptics
    fprintf("\n%-12s %10s %16s %16s\n", "系統", "半視場(度)", "畸變型態", "最大畸變(%)");
    for nm = ["單透鏡" "消色差鏡"]
        if nm == "單透鏡", s = singlet; else, s = doublet; end
        s.FieldPoints = fieldPoint(Angles=[0 0; 0 1; 0 2; 0 2.5]);
        ld = lensDistortion(s);
        fprintf("%-12s %10.4f %16s %16.5f\n", nm, halfFieldOfView(s), ...
            string(ld.Type), max(abs(ld.Distortion(:,2))));
    end
end
%[text] 兩支鏡的半視場都是 **2.851°**，畸變都小於 **0.006%**——完全可以忽略。
%[text] 這個結果本身是個提醒：**這兩支鏡的問題不是畸變，是色差與球面像差。**
%[text] 半視場只有 2.85° 的長焦鏡本來就不太會有畸變；
%[text] 畸變是**廣角鏡**的問題。
%[text] 拿這兩支鏡去「研究畸變校正」會得到一個沒有訊號的實驗——
%[text] 這與第 10 章「設計對照實驗時要確認你的困難案例真的困難」是同一件事。
%[text] 實際要處理畸變，請看第 25 章的相機標定
%[text] （`estimateCameraParameters` 的徑向／切向畸變係數）。
%%
%[text] # 11. 從光學到演算法
%[text] 把這一章與前面串起來。下面每一列都是前面章節真實遇到的現象。
%[text:table]
%[text] | 光學／品質問題 | 在演算法端看到的症狀 | 相關章節 |
%[text] | --- | --- | --- |
%[text] | 失焦（MTF50 掉一半） | 邊緣偵測歸零、量測值偏小 | 第 10、11 章 |
%[text] | 色差（藍光點徑 5 倍） | 彩色影像的通道邊界不對齊、去馬賽克偽色 | 第 03 章 |
%[text] | 照明不均 | Otsu 單一門檻失效、計數跳動 | 第 08 章 |
%[text] | 感測器雜訊 | 自動門檻升高、真實邊緣被一起丟掉 | 第 04、10 章 |
%[text] | 曝光偏移 | ΔE 很大但顏色其實是對的 | 本章第 9 節 |
%[text] | 像素取樣不足 | 次像素量測的改善無法傳遞到最終結果 | 第 10、11 章 |
%[text:table]
%[text] > **這張表的用法是反過來讀。**
%[text] > 看到症狀時，先問「是不是影像品質問題」，
%[text] > 再開始調演算法參數。順序錯了會浪費很多時間——
%[text] > 第 08 章實測過：照明不均造成的分割失敗，
%[text] > **調參數會讓計數從 9 跳到 5，直接跳過正確答案 6。**
%%
%[text] # 12. 常見陷阱
%[text] **① 用 PSNR 比較不同類型的劣化。**
%[text] PSNR 就是 MSE，對「差在哪」完全無感。同 PSNR 的雜訊與模糊，
%[text] SSIM 可以差 1.84 倍（第 3 節）。
%[text] **② 把無參考指標當絕對品質。**
%[text] 乾淨的 `text.png` NIQE 是 39.62，乾淨的 `peppers.png` 是 3.11。
%[text] 分數反映的是「與自然照片統計的距離」（第 5 節）。
%[text] **③ 用無參考指標驗證去雜訊演算法。**
%[text] 加 σ=0.01 的雜訊會讓 BRISQUE 從 29.64 「改善」到 12.94（第 6.1 節）。
%[text] 你去得越乾淨，分數可能越差。
%[text] **④ 在飽和區或非單調區使用指標。**
%[text] PIQE 在模糊 σ≥4 一律 100；NIQE 與 BRISQUE 在重度模糊時會回頭（第 6.1 節）。
%[text] **⑤ 直接用預設 NIQE 模型做產線門檻。**
%[text] 在合成晶圓領域上，預設模型把模糊 σ=3（12.02）判得比乾淨（64.68）**好 5.4 倍**。
%[text] 非自然影像領域**必須** `fitniqe`（第 7 節）。
%[text] **⑥ 看到 ΔE 大就去調白平衡。**
%[text] 先拆解。實測 89% 的 ΔE 來自曝光，白平衡只改善 6.5%，
%[text] 亮度修正改善 41.9%（第 9 節）。
%[text] **⑦ 對 `opticalSystem` 使用值語意。**
%[text] 它是 handle 物件，方法會**就地修改**。
%[text] `result = focus(sys)` 不報錯，但回傳 `Spot` 而不是系統，
%[text] 而 `sys` 已經被改掉了。要留版本就用 `copy()`（第 10.2 節）。
%[text] **⑧ 給 `Material="air"`。**
%[text] 玻璃庫沒有 air。省略 `Material` 就是環境介質（第 10.1 節）。
%[text] **⑨ 比較不同 F 數的鏡頭點徑。**
%[text] 光圈小本來就點徑小。要比像差，先讓焦距與 F 數一致（第 10.4 節）。
%[text] **⑩ 沒有驗證過就相信自己寫的量測程式。**
%[text] `ch12_measureMTF` 在最銳利端偏低 8.9%、最模糊端偏高 9.5%，
%[text] 只有中間段可信到 2–5%（第 8.1 節）。
%%
%[text] # 13. 本章小結
%[text] **三類指標，三種前提**
%[text] 全參考要有原圖；無參考要知道自己的領域在訓練分布裡；
%[text] 圖卡量測要有真實圖卡。前提不成立，數字就沒有意義。
%[text] **無參考指標是「相對」工具**
%[text] 這一章最大的實測結果是：預設 NIQE 模型在非自然領域上**把排序弄反了**。
%[text] `fitniqe` 不是選配，在工業影像上是必要步驟。
%[text] **診斷要先拆解**
%[text] ΔE 21.23 看起來像色彩問題，拆開之後 89% 是曝光。
%[text] 拆解 → 預測 → 驗證，這個循環比記住哪個指標「比較好」有用得多。
%[text] **自己寫的量測要先驗證**
%[text] 斜邊法 MTF 與高斯理論對照之後，才知道它在哪個範圍可信。
%[text] 沒有已知答案可比的量測程式，產生的數字不可信。
%[text] **光學是所有影像問題的源頭**
%[text] 單透鏡的藍光焦點與紅光焦點差 1.55 mm，
%[text] 消色差設計把它降到 0.050 mm。
%[text] 很多「演算法問題」其實在這一層就決定了。
%[text] **R2026a 的新東西**
%[text] 光學設計與模擬支援包（`opticalSystem`、`traceRays`、`spot`、
%[text] `lensDistortion`、`chromaticAberration`、Optical System Designer APP）
%[text] 讓成像鏈的分析第一次可以完整留在 MATLAB 裡。
%[text] 代價是要習慣 **handle 語意**。
%%
%[text] # 14. 練習
%[text] 練習題在 `exercise/Ch12_Exercise.m`，解答在 `exercise/Ch12_Solution.m`。
%[text] 五題 + 一題加分題，建議 60 分鐘。
%%
%[text] # 15. 延伸閱讀與下一章
%[text] **本章函式**
%[text:table]
%[text] | 檔案 | 用途 |
%[text] | --- | --- |
%[text] | `code/ch12_measureMTF.m` | 斜邊法 MTF，含有效範圍說明 |
%[text] | `code/ch12_makeSlantedEdge.m` | 產生已知模糊量的合成斜邊（驗證用） |
%[text] | `code/ch12_makeWaferLike.m` | 產生合成工業紋理（`fitniqe` 訓練用） |
%[text] | `code/ch12_makeAchromat.m` | 由焦距與口徑算出消色差雙合透鏡並回傳設計說明 |
%[text] | `code/ch12_qualityReport.m` | 品質報告，**會檢查指標是否用在有效區間** |
%[text:table]
%[text] **官方文件**
%[text] `doc niqe`、`doc fitniqe`、`doc esfrChart`、`doc colorChecker`、
%[text] `doc opticalSystem`、`doc opticalSystemDesigner`
%[text] **下一章**
%[text] 第 13 章　影像修復、合成與資料擴增——把壞掉的影像補起來，
%[text] 並用合成的方式產生訓練資料（含 R2026a 的 `imblend` Poisson 混合與 `uipaint`）。

% ========================================================================
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
