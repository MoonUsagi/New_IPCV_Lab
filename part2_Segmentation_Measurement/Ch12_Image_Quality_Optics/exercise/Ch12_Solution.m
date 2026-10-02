%[text] # 第 12 章　練習解答
%[text] 影像品質評估與相機／光學特性
assert(exist("ch12_measureMTF","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
hasOptics = exist("opticalSystem", "file") > 0;
rng(0);
I = im2double(im2gray(imread("peppers.png")));
%%
%[text] # 解答 1：PSNR 與 SSIM 排序相反
%[text] 策略來自兩個指標的本質差異：
%[text] - **PSNR** 只看逐像素差值的**總量**，不管它集中在哪裡
%[text] - **SSIM** 看**局部**的亮度／對比／結構，然後對全圖平均
%[text] 所以要製造反轉，就做一個**集中在小區域的嚴重破壞**
%[text] 對上一個**散布全圖的輕微劣化**：
%[text] - 局部破壞：MSE 總量不大（只有一小塊），但那一塊結構全毀
%[text] - 全圖雜訊：MSE 總量可以更小，但**每一個局部**的結構都被擾動
rng(0);

% A：局部嚴重破壞——把一塊區域換成平均灰階
A = I;
blk = 70;
r0 = 120; c0 = 150;
A(r0:r0+blk-1, c0:c0+blk-1) = mean(I(:));

% B：全圖輕微雜訊，強度調到「MSE 比 A 小、SSIM 也比 A 小」
% 掃一個範圍找出可行的 sigma
fprintf("尋找能造成排序反轉的雜訊強度：\n");
fprintf("%-10s %10s %10s %10s %10s %8s\n", ...
    "sigma", "MSE_B", "MSE_A", "SSIM_B", "SSIM_A", "反轉?");
best = NaN;
for sg = 0.02:0.005:0.09
    B = min(max(I + sg*randn(size(I)), 0), 1);
    flip = immse(B,I) < immse(A,I) && ssim(B,I) < ssim(A,I);
    fprintf("%-10.3f %10.6f %10.6f %10.4f %10.4f %8d\n", ...
        sg, immse(B,I), immse(A,I), ssim(B,I), ssim(A,I), flip);
    if flip && isnan(best), best = sg; end
end

assert(~isnan(best), "找不到能反轉的 sigma，請擴大搜尋範圍。");
fprintf("\n採用 sigma = %.3f\n", best);

rng(1);
B = min(max(I + best*randn(size(I)), 0), 1);
%%
%[text] ## 驗證反轉
fprintf("\n%-18s %12s %12s\n", "劣化", "PSNR(dB)", "SSIM");
fprintf("%-18s %12.4f %12.4f\n", "A 局部嚴重破壞", psnr(A,I), ssim(A,I));
fprintf("%-18s %12.4f %12.4f\n", "B 全圖輕微雜訊", psnr(B,I), ssim(B,I));

fprintf("\nPSNR 認為比較好的是：%s\n", ternary(psnr(A,I) > psnr(B,I), "A", "B"));
fprintf("SSIM 認為比較好的是：%s\n", ternary(ssim(A,I) > ssim(B,I), "A", "B"));

reversed = (psnr(A,I) > psnr(B,I)) ~= (ssim(A,I) > ssim(B,I));
fprintf("排序是否相反：%d\n", reversed);
assert(reversed, "排序沒有反轉。");

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(I); title("原圖")
nexttile; imshow(A)
title(sprintf("A 局部破壞\nPSNR %.2f、SSIM %.3f", psnr(A,I), ssim(A,I)))
nexttile; imshow(B)
title(sprintf("B 全圖雜訊\nPSNR %.2f、SSIM %.3f", psnr(B,I), ssim(B,I)))
%[text] **為什麼會反轉（第 4 小題）**
%[text] 關鍵在**誤差的空間分布**，兩個指標對它的處理方式完全不同：
%[text] - A 的誤差全部集中在一個 70×70 的方塊裡，只占全圖約 2.5%
%[text]   （4900 / 196608 像素）。PSNR 把它平均到整張圖，所以總量被稀釋。
%[text]   但 SSIM 是**先算局部相似度再平均**，圖上絕大多數視窗**完全沒被動過**，
%[text]   相似度是 1，所以平均下來依然很高。
%[text] - B 的雜訊散布在**每一個**視窗裡。每個視窗的局部對比與結構都被擾動，
%[text]   所以 SSIM 全面下降，即使總誤差量比 A 小。
%[text] > **一句話：PSNR 對「誤差在哪」無感，SSIM 對「誤差有多集中」無感。**
%[text] > A 在人眼看來有一塊明顯的死區，B 在人眼看來是均勻的顆粒感。
%[text] > 哪一個更糟？**取決於下游任務**——
%[text] > 要做 OCR 的話 A 那塊字全沒了；要做整體紋理分類的話 B 更麻煩。
%%
%[text] # 解答 2：指標的有效區間
%[text] 用 21 個取樣點掃 NIQE 對模糊的響應。
%[text] **取樣要夠密**：主教材只用 6 點，會漏掉細節。
blurGrid = linspace(0, 10, 21);
niqeCurve = zeros(size(blurGrid));
piqeCurve = zeros(size(blurGrid));
for k = 1:numel(blurGrid)
    if blurGrid(k) == 0, J = I; else, J = imgaussfilt(I, blurGrid(k)); end
    niqeCurve(k) = niqe(J);
    piqeCurve(k) = piqe(J);
end

% 單調區間：從頭開始，直到第一次下降
d = diff(niqeCurve);
firstDrop = find(d < 0, 1, "first");
if isempty(firstDrop)
    monoEnd = blurGrid(end);
else
    monoEnd = blurGrid(firstDrop);
end

% 飽和點：PIQE 第一次達到 100
satIdx = find(piqeCurve >= 99.5, 1, "first");

fprintf("\n%-10s %10s %10s\n", "blur sigma", "NIQE", "PIQE");
for k = 1:numel(blurGrid)
    fprintf("%-10.2f %10.3f %10.3f\n", blurGrid(k), niqeCurve(k), piqeCurve(k));
end

fprintf("\nNIQE 的峰值在 sigma = %.2f（值 %.3f）\n", ...
    blurGrid(niqeCurve == max(niqeCurve)), max(niqeCurve));
fprintf("NIQE 單調上升到 sigma = %.2f，之後開始回頭\n", monoEnd);
if ~isempty(satIdx)
    fprintf("PIQE 在 sigma = %.2f 觸及 100（飽和）\n", blurGrid(satIdx));
end

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
plot(blurGrid, niqeCurve, "o-", LineWidth=1.6)
xline(monoEnd, "--", sprintf("反轉點 \\sigma=%.1f", monoEnd), LineWidth=1.4);
xlabel("模糊 \sigma"); ylabel("NIQE"); title("NIQE：注意曲線會回頭"); grid on
nexttile
plot(blurGrid, piqeCurve, "s-", LineWidth=1.6)
yline(100, ":", "上限", LineWidth=1.2);
if ~isempty(satIdx)
    xline(blurGrid(satIdx), "--", sprintf("飽和 \\sigma=%.1f", blurGrid(satIdx)), LineWidth=1.4);
end
xlabel("模糊 \sigma"); ylabel("PIQE"); title("PIQE：飽和之後失去解析力"); grid on
%[text] ## 可以放進工程文件的結論（第 4 小題）
fprintf("\n--- 工程結論 ---\n");
fprintf("NIQE 對高斯模糊在 sigma = 0 至 %.1f 的範圍內單調上升；\n", monoEnd);
fprintf("超過 sigma = %.1f 之後分數開始下降，不可用於排序劣化程度。\n", monoEnd);
if ~isempty(satIdx)
    fprintf("PIQE 在 sigma >= %.1f 時固定為 100，該範圍內不具解析能力。\n", ...
        blurGrid(satIdx));
end
%[text] **為什麼取樣密度重要——這裡有一個具體的代價**
%[text] 主教材用 6 點取樣（0、0.5、1、2、4、8），得出「PIQE 在 σ≥4 飽和」。
%[text] 21 點的掃描顯示它**其實在 σ=2.5 就已經到 100 了**。
%[text] 主教材的結論**低估了失效範圍 1.6 倍**——
%[text] 如果照它去設計一個「PIQE 可用到 σ=4」的系統，在 σ=2.5 到 4 之間
%[text] 你會拿到一堆相同的 100 分，卻以為指標還在工作。
%[text] NIQE 也一樣：6 點取樣只在 σ=8 看到回頭，
%[text] 21 點才看出單調性**從 σ=4 就斷了**（4.0 是 6.929，4.5 掉到 6.833），
%[text] 而且之後整段都在 6.6–7.1 之間震盪，全域最大值出現在 σ=5。
%[text] > **取樣太疏不只是「少了細節」，而是會給出一個偏向樂觀的錯誤邊界。**
%%
%[text] # 解答 3：新領域的 NIQE 模型（含獨立測試集）
%[text] 換一個領域：**條紋 + 文字方塊**，並且**嚴格切開訓練與測試**。
domainRoot = fullfile(tempdir, "ipcv_ch12_ex3");
if isfolder(domainRoot), rmdir(domainRoot, "s"); end
trainDir = fullfile(domainRoot, "train");
testDir  = fullfile(domainRoot, "test");
mkdir(trainDir); mkdir(testDir);

nTrainEx = 20; nTestEx = 10;
for k = 1:nTrainEx
    imwrite(makeStripeDomain(256, 256, k), ...
        fullfile(trainDir, sprintf("s_%02d.png", k)));
end
for k = 1:nTestEx
    imwrite(makeStripeDomain(256, 256, 1000+k), ...   % 種子完全不重疊
        fullfile(testDir, sprintf("t_%02d.png", k)));
end
fprintf("\n訓練 %d 張、測試 %d 張（種子不重疊）\n", nTrainEx, nTestEx);

modelEx = fitniqe(imageDatastore(trainDir));

figure
montage(imageDatastore(trainDir), Size=[4 5])
title("解答 3 的訓練集（條紋領域）")
%%
%[text] ## 對 10 張未見過的測試影像做統計
testFiles = dir(fullfile(testDir, "*.png"));
nT = numel(testFiles);

rng(0);
condNames = ["乾淨" "模糊 s=2" "雜訊 0.05"];
scoreD = zeros(nT, 3);      % 預設模型
scoreC = zeros(nT, 3);      % 自訓模型

for i = 1:nT
    T = im2double(imread(fullfile(testDir, testFiles(i).name)));
    vers = {T, imgaussfilt(T,2), min(max(T + 0.05*randn(size(T)),0),1)};
    for c = 1:3
        scoreD(i,c) = niqe(vers{c});
        scoreC(i,c) = niqe(vers{c}, modelEx);
    end
end

fprintf("\n%-12s %22s %22s\n", "狀態", "預設模型 (mean±std)", "自訓模型 (mean±std)");
for c = 1:3
    fprintf("%-12s %12.3f ± %-7.3f %12.3f ± %-7.3f\n", condNames(c), ...
        mean(scoreD(:,c)), std(scoreD(:,c)), ...
        mean(scoreC(:,c)), std(scoreC(:,c)));
end

% 哪個模型能把「乾淨」排第一？
cleanBestD = mean(scoreD(:,1)) < mean(scoreD(:,2)) && mean(scoreD(:,1)) < mean(scoreD(:,3));
cleanBestC = mean(scoreC(:,1)) < mean(scoreC(:,2)) && mean(scoreC(:,1)) < mean(scoreC(:,3));
fprintf("\n預設模型把「乾淨」排在最前面？%d\n", cleanBestD);
fprintf("自訓模型把「乾淨」排在最前面？%d\n", cleanBestC);

% 逐張（而不是只看平均）的正確率
perImageD = sum(scoreD(:,1) < scoreD(:,2) & scoreD(:,1) < scoreD(:,3));
perImageC = sum(scoreC(:,1) < scoreC(:,2) & scoreC(:,1) < scoreC(:,3));
fprintf("\n逐張判斷「乾淨最好」的正確張數：預設 %d/%d、自訓 %d/%d\n", ...
    perImageD, nT, perImageC, nT);

fprintf("\n自訓模型對 10 張未見過的乾淨影像：\n");
fprintf("  平均 %.3f、標準差 %.3f、變異係數 %.1f%%" + "\n", ...
    mean(scoreC(:,1)), std(scoreC(:,1)), ...
    100*std(scoreC(:,1))/mean(scoreC(:,1)));
fprintf("  中位數 %.3f、範圍 %.3f 到 %.3f\n", ...
    median(scoreC(:,1)), min(scoreC(:,1)), max(scoreC(:,1)));
fprintf("  各張分數：%s\n", join(string(round(scoreC(:,1)',2)), ", "));

% 變異係數很大時，平均值本身就不可信——先確認是不是單一離群值
mad0 = median(abs(scoreC(:,1) - median(scoreC(:,1))));
outlier = abs(scoreC(:,1) - median(scoreC(:,1))) > 5*max(mad0, eps);
fprintf("  以中位數 ± 5*MAD 判定的離群張數：%d / %d\n", nnz(outlier), nT);
if any(outlier)
    fprintf("  排除離群值後：中位數 %.3f、變異係數 %.1f%%" + "\n", ...
        median(scoreC(~outlier,1)), ...
        100*std(scoreC(~outlier,1))/mean(scoreC(~outlier,1)));
end

figure
boxchart(scoreC)                    % 每一欄一個盒；不要傳矩陣給 xgroupdata
set(gca, XTickLabel=condNames, YScale="log")
ylabel("自訓 NIQE（對數軸）")
title("自訓模型在獨立測試集上的分布"); grid on
%[text] **第 5 小題：自訓模型對同領域的乾淨影像穩定嗎？**
%[text] **答案是「排序可用，但絕對值不穩」——而且這兩件事要分開回答。**
%[text] 實測（10 張獨立測試影像）：
%[text:table]
%[text] | 狀態 | 預設模型 | 自訓模型 |
%[text] | --- | --- | --- |
%[text] | 乾淨 | 505.54 ± 87.13 | **22.19 ± 35.49** |
%[text] | 模糊 σ=2 | 194.42 ± 134.96 | 1570.31 ± 1845.12 |
%[text] | 雜訊 0.05 | 344.91 ± 167.22 | 2216.93 ± 3886.97 |
%[text:table]
%[text] **排序方面，自訓模型明顯勝出：**
%[text] 逐張判斷「乾淨最好」的正確率是 **9/10**，
%[text] 而預設模型是 **0/10**——它把乾淨影像排在**最差**（505.54 比模糊的 194.42 高）。
%[text] 這比主教材的結果更嚴重：主教材是「排序反轉」，
%[text] 這裡是**十張全錯**。條紋領域離自然照片統計更遠。
%[text] **但絕對值的平均很不穩：** 乾淨影像的變異係數高達 **159.9%**，
%[text] 標準差（35.49）比平均值（22.19）還大。
%[text] **不要在這裡停下來說「模型不穩」。** 看逐張分數：
%[text] `122.87、9.95、14.85、9.60、9.69、9.23、17.32、8.41、9.59、10.39`
%[text] 十張裡有**九張**落在 8.4 到 17.3 之間，中位數 **9.82**；
%[text] 只有一張是 **122.87**。
%[text] 用中位數 ± 5×MAD 檢定，排除離群值後的變異係數是 **6.5%**——**非常穩定**。
%[text] > **所以正確的結論不是「模型不穩」，而是「平均值不該用在這種分布上」。**
%[text] > 一個離群值就讓平均值從 9.8 漂到 22.2，變異係數從 6.5% 膨脹到 159.9%。
%[text] 實務做法有三點：
%[text] 1. **用中位數與 MAD，不要用平均與標準差。** 品質分數的分布經常有長尾
%[text] 2. **離群值要去看那張圖**，不要只當雜訊丟掉——它可能是真的有問題，
%[text]    也可能是你的合成程式在那個種子下產生了異常的紋理
%[text] 3. 門檻要設在中位數的幾倍 MAD 上，而不是平均值的幾倍標準差
%[text] 這與第 11 章「平均值一定要配離散程度」是同一件事再深一層：
%[text] **配對的離散程度也要選對——有長尾時，標準差本身就是誤導。**
%[text] **為什麼一定要留出測試集**
%[text] `fitniqe` 學的是訓練影像的特徵分布。
%[text] 拿訓練集裡的影像去評分，分數當然低——那是**記住**，不是**泛化**。
%[text] 主教材用一張訓練集外的圖測試，樣本數是 1，
%[text] 無法區分「模型真的泛化」與「剛好那張運氣好」。
%[text] 這裡用 10 張獨立影像，並報平均 ± 標準差，才有說服力。
%%
%[text] # 解答 4：從 MTF50 反推等效模糊量
%[text] **推導（第 1 小題）**
%[text] 從 $f_{50} = \sqrt{\ln 2 / (2\pi^2\sigma^2)}$ 兩邊平方：
%[text] $$f_{50}^2 = \frac{\ln 2}{2\pi^2\sigma^2} \quad\Rightarrow\quad
%[text] \sigma = \frac{1}{\pi f_{50}}\sqrt{\frac{\ln 2}{2}}$$
sensorSigma = 0.6;
trueExtra   = [0.5 1 1.5 2 2.5 3];

fprintf("\n%-10s %10s %12s %12s %10s\n", ...
    "真實額外", "MTF50", "反推總sigma", "反推額外", "誤差%");
recovered = zeros(size(trueExtra));
for k = 1:numel(trueExtra)
    E = ch12_makeSlantedEdge(256, 256, 5, sensorSigma);
    E = imgaussfilt(E, trueExtra(k));

    f50 = ch12_measureMTF(E);

    sigTotal = sqrt(log(2)/2) / (pi * f50);          % 反推式
    % 感測器模糊與額外模糊是兩個獨立高斯，變異數相加
    sigExtra = sqrt(max(sigTotal^2 - sensorSigma^2, 0));
    recovered(k) = sigExtra;

    fprintf("%-10.2f %10.4f %12.4f %12.4f %10.2f\n", trueExtra(k), f50, ...
        sigTotal, sigExtra, 100*(sigExtra/trueExtra(k) - 1));
end

figure
plot([0 3.5], [0 3.5], "k--", LineWidth=1.2, DisplayName="y = x（完美）")
hold on
plot(trueExtra, recovered, "o", MarkerSize=9, LineWidth=1.6, DisplayName="反推結果")
hold off
xlabel("真實額外模糊 \sigma（像素）"); ylabel("由 MTF50 反推的 \sigma")
title("MTF50 反推等效模糊量"); legend(Location="southeast"); grid on
axis equal; xlim([0 3.5]); ylim([0 3.5])
%[text] **第 5 小題：哪個範圍可信？**
%[text] 主教材第 8.1 節量到 `ch12_measureMTF` 的偏差：
%[text] 最銳利端偏低 8.9%、最模糊端偏高 9.5%，中間段 2–5%。
%[text] 這些偏差會**直接傳遞**到反推的 σ 上，而且因為 σ 與 $1/f_{50}$
%[text] 成正比，**相對誤差是一比一傳遞的**：MTF50 偏高 9.5%，σ 就偏低約 8.7%。
%[text] 另外還有一個**只在小 σ 時出現**的放大效應：
%[text] 因為要做 $\sqrt{\sigma_{總}^2 - \sigma_{感測器}^2}$，
%[text] 當額外模糊接近感測器模糊時，兩個相近的數相減會**放大相對誤差**。
%[text] 上表最小的那一列最不準，就是這個原因。
%[text] > **結論**：額外模糊明顯大於感測器模糊（本例 σ > 1.2 左右）時反推可信；
%[text] > 接近或小於感測器模糊時，只能說「沒有明顯額外失焦」，不要報具體數字。
%%
%[text] # 解答 5：光圈掃描與模型的極限
if ~hasOptics
    fprintf("未安裝光學支援包，跳過解答 5。\n");
else
    lambdaNm = 587.5618;
    nBK7 = 1.5168;
    Rlens = 2*(nBK7-1)*100;
    sdGrid = [0.5 1 1.2 1.5 2 3 4 5 6 8 10 12];

    geomRMS = nan(size(sdGrid));
    fnum    = nan(size(sdGrid));
    focalL  = nan(size(sdGrid));
    for k = 1:numel(sdGrid)
        % 每次都**重建**——handle 物件不能重複使用同一個實例
        sys = opticalSystem;
        addRefractiveSurface(sys, Radius=Rlens,  Material="N-BK7", ...
            DistanceToNext=4, SemiDiameter=sdGrid(k));
        addRefractiveSurface(sys, Radius=-Rlens, ...
            DistanceToNext=100, SemiDiameter=sdGrid(k));
        addImagePlane(sys);
        focus(sys);

        info = paraxialInfo(sys);
        sp   = spot(sys);
        focalL(k)  = info.FocalLength;
        fnum(k)    = info.FNumber;
        geomRMS(k) = mean(sp.RMS);
    end

    % --- 先檢查結果是否有效，再開始分析 -----------------------------
    % 小口徑時 paraxialInfo 會退化：FocalLength = Inf、FNumber = 0。
    % 它**不會報錯**，所以必須自己檢查。
    valid = isfinite(focalL) & fnum > 0;

    fprintf("\n%-10s %14s %10s %14s %8s\n", ...
        "半口徑", "FocalLength", "F 數", "幾何RMS(mm)", "有效?");
    for k = 1:numel(sdGrid)
        fprintf("%-10.1f %14.4f %10.3f %14.6f %8d\n", ...
            sdGrid(k), focalL(k), fnum(k), geomRMS(k), valid(k));
    end

    nBad = nnz(~valid);
    if nBad > 0
        fprintf("\n**%d 組結果無效**（半口徑 <= %.1f）：\n", ...
            nBad, max(sdGrid(~valid)));
        fprintf("paraxialInfo 回傳 FocalLength = Inf、FNumber = 0，\n");
        fprintf("但**沒有發出任何警告**。這些點必須排除，否則後續分析全錯。\n");
    end

    % 斜率只用有效點
    pfit = polyfit(log(fnum(valid)), log(geomRMS(valid)), 1);
    fprintf("\nlog-log 斜率（三波長平均）= %.3f\n", pfit(1));
    fprintf("球面像差的理論指數是 -3。差這麼多，必須追下去。\n");

    % --- 追查：是不是色差把球面像差的斜率蓋掉了 -------------------
    % 把波長縮到只剩一個，就只剩單色像差（主要是球面像差）
    monoRMS = nan(size(sdGrid));
    for k = 1:numel(sdGrid)
        if ~valid(k), continue; end
        m = opticalSystem;
        m.Wavelengths = 587.5618;               % 只留主波長
        addRefractiveSurface(m, Radius=Rlens,  Material="N-BK7", ...
            DistanceToNext=4, SemiDiameter=sdGrid(k));
        addRefractiveSurface(m, Radius=-Rlens, ...
            DistanceToNext=100, SemiDiameter=sdGrid(k));
        addImagePlane(m);
        focus(m);
        monoRMS(k) = mean(spot(m).RMS);
    end

    pmono = polyfit(log(fnum(valid)), log(monoRMS(valid)), 1);
    fprintf("log-log 斜率（單一波長）  = %.3f   <- 幾乎正好是 -3\n", pmono(1));

    fprintf("\n%-8s %14s %14s %10s\n", ...
        "F 數", "三波長RMS", "單波長RMS", "倍數");
    fv = fnum(valid); gv = geomRMS(valid); mv = monoRMS(valid);
    for k = 1:numel(fv)
        fprintf("%-8.2f %14.6f %14.6f %10.1f\n", fv(k), gv(k), mv(k), gv(k)/mv(k));
    end
end
%[text] **第 4 小題的斜率：一個必須追下去的矛盾**
%[text] 三波長平均的 log-log 斜率是 **−1.14**，
%[text] 但球面像差的理論指數是 **−3**。差了將近三倍，不能就這樣算了。
%[text] 把波長縮到只剩一個之後，斜率變成 **−3.015**——**理論值幾乎完全吻合。**
%[text] 所以答案是：**三波長的曲線被色差主宰了。**
%[text] 看倍數那一欄就很清楚：
%[text:table]
%[text] | F 數 | 三波長 RMS | 單波長 RMS | 倍數 |
%[text] | --- | --- | --- | --- |
%[text] | f/41.94 | 0.005247 | 0.000061 | **85.5×** |
%[text] | f/16.78 | 0.013035 | 0.000961 | 13.6× |
%[text] | f/10.07 | 0.021813 | 0.004468 | 4.9× |
%[text] | f/4.19 | 0.081567 | 0.063947 | **1.28×** |
%[text:table]
%[text] 小光圈時球面像差幾乎消失（0.000061 mm），
%[text] 剩下的 0.005247 mm **全部是色差**——而色差的點徑隨口徑**線性**增長，
%[text] 所以斜率被拉到 −1。
%[text] 大光圈時球面像差暴增（F^−3 成長），終於蓋過色差，倍數降到 1.28。
%[text] > **這一小題的方法論價值最高：**
%[text] > 量到的指數與理論不符時，那通常不是「理論錯了」或「量錯了」，
%[text] > 而是**你量的東西裡混了不只一種效應**。
%[text] > 分離的方法就是**一次只改一個變因**——這裡是把波長數從 3 降到 1。
%[text] 這也回頭解釋了第 10.4 節：單透鏡在 f/10 的點徑有 4.9 倍來自色差，
%[text] 所以消色差設計能改善 15 倍是合理的。
%[text] **先講一個必須先處理的坑。**
%[text] 半口徑 ≤ 1 mm 時，`paraxialInfo` 回傳
%[text] `FocalLength = Inf`、`FNumber = 0`、`EntrancePupilRadius = 0`，
%[text] **而且完全不報錯也不警告**。
%[text] 如果直接把這些值餵進 `polyfit(log(fnum), ...)`，
%[text] `log(0) = -Inf` 會讓擬合回傳 `NaN`；
%[text] 若拿去找「最小點徑」，還會選出 `f/0.00` 這種不存在的光圈。
%[text] 上面的程式因此**先算 `valid` 再分析**。
%[text] 這是本章第 12 節第 ⑦ 條（handle 語意）的同類問題：
%[text] **工具在被誤用時給出的是安靜的壞值，不是錯誤訊息。**
%%
%[text] ## 第 5 小題的陷阱與第 6–8 小題
%[text] 純幾何追跡的曲線是**單調下降**的：光圈越小，點徑越小，
%[text] 所以「最佳光圈」會是你掃到的最小值。**這個答案是錯的。**
%[text] 幾何光線追跡**不含繞射**。真實鏡頭縮到小光圈時，
%[text] 繞射會讓點徑重新變大。艾里斑半徑約 $1.22\lambda N$。
if hasOptics
    lambdaMM = lambdaNm * 1e-6;                 % nm -> mm

    % 只用有效點
    fn  = fnum(valid);
    gr  = geomRMS(valid);
    air = 1.22 * lambdaMM * fn;
    tot = hypot(gr, air);

    fprintf("\n%-8s %10s %12s %12s %12s\n", ...
        "F 數", "幾何RMS", "艾里半徑", "總點徑", "主導項");
    for k = 1:numel(fn)
        if gr(k) > air(k), dom = "球面像差"; else, dom = "繞射"; end
        fprintf("%-8.2f %10.6f %12.6f %12.6f %12s\n", ...
            fn(k), gr(k), air(k), tot(k), dom);
    end

    [~, iGeom] = min(gr);
    [~, iTot]  = min(tot);
    fprintf("\n幾何模型的「最佳」光圈：f/%.2f（總點徑 %.6f mm）\n", ...
        fn(iGeom), gr(iGeom));
    fprintf("加入繞射後的最佳光圈：f/%.2f（總點徑 %.6f mm）\n", ...
        fn(iTot), tot(iTot));
    fprintf("兩者相差 %.1f 個光圈級數\n", log2(fn(iGeom)/fn(iTot))*2);

    figure
    loglog(fn, gr,  "o-",  LineWidth=1.6, DisplayName="幾何 RMS（球面像差）")
    hold on
    loglog(fn, air, "s--", LineWidth=1.6, DisplayName="艾里斑半徑（繞射）")
    loglog(fn, tot, "^-",  LineWidth=2,   DisplayName="總點徑")
    xline(fn(iTot),  ":",  sprintf("含繞射最佳 f/%.1f", fn(iTot)),  LineWidth=1.4);
    xline(fn(iGeom), "--", sprintf("純幾何最佳 f/%.1f", fn(iGeom)), LineWidth=1.4);
    hold off
    xlabel("F 數"); ylabel("點徑（mm）")
    title("球面像差 vs 繞射：最佳光圈在兩者交會處")
    legend(Location="north"); grid on
end
%[text] **第 8 小題：模型沒告訴你的事**
%[text] 幾何追跡給出的曲線**完全正確**——在它自己的假設裡。
%[text] 它的假設是「光沿直線傳播」，而那個假設在小光圈時就不成立了。
%[text] 危險的地方在於：
%[text] - 模型**不會報錯**。它會給你一條漂亮、平滑、單調的曲線
%[text] - 曲線**看起來**有明確的結論（光圈越小越好）
%[text] - 那個結論**在物理上是錯的**，而且錯在模型的假設層，不是數值層
%[text] > **一個模型最危險的時候，是它在自己的適用範圍外依然給出乾淨答案的時候。**
%[text] 這與本章第 6.1 節（指標在飽和區仍回報數字）、
%[text] 第 7 節（預設 NIQE 在錯誤領域仍給出排序）、
%[text] 以及第 11 章練習 4（`Width=21` 的 caliper 在 d=0 給出漂亮的 −0.01 偏差）
%[text] 是**完全同一個教訓的四個版本**：
%[text] **工具不會告訴你它正在被誤用。你必須自己知道它的邊界在哪裡。**
%%
%[text] # 加分題：品質指標能預測任務失敗嗎
%[text] 用 `coins.png` 的計數任務當下游，看品質分數能不能預測它什麼時候壞掉。
Icoin = imread("coins.png");
fprintf("\n乾淨影像的計數 = %d（正解 10）\n", countCoins(Icoin));
assert(countCoins(Icoin) == 10, "乾淨影像就數錯了，請檢查流程。");
%%
%[text] ## 掃描兩種劣化
rng(0);
% 掃描範圍必須**掃到真的失敗**，否則找不到臨界點。
% 第一版的雜訊只掃到 0.20，計數全程都是 10——結論無從得出。
blurLevels  = [0 0.25 0.5 0.75 1 1.25 1.5 2 3 4 5 6];
noiseLevels = [0 0.05 0.10 0.15 0.20 0.30 0.40 0.50 0.70];

resBlur  = runDegradation(Icoin, blurLevels,  "blur");
resNoise = runDegradation(Icoin, noiseLevels, "noise");

fprintf("\n=== 模糊 ===\n");
printSweep(blurLevels, resBlur);
fprintf("\n=== 雜訊 ===\n");
printSweep(noiseLevels, resNoise);

failBlur  = firstFailure(blurLevels,  resBlur);
failNoise = firstFailure(noiseLevels, resNoise);
fprintf("\n模糊的失敗臨界點：sigma = %.2f\n", failBlur.level);
fprintf("  在那一點 NIQE %.2f、BRISQUE %.2f、PIQE %.2f、MTF50 %.4f\n", ...
    failBlur.niqe, failBlur.brisque, failBlur.piqe, failBlur.mtf);
fprintf("雜訊的失敗臨界點：sigma = %.2f\n", failNoise.level);
fprintf("  在那一點 NIQE %.2f、BRISQUE %.2f、PIQE %.2f、MTF50 %.4f\n", ...
    failNoise.niqe, failNoise.brisque, failNoise.piqe, failNoise.mtf);
%%
%[text] ## 同一個門檻能同時管住兩種劣化嗎
figure
tiledlayout(2,2, TileSpacing="compact")

nexttile
plot(blurLevels, resBlur.count, "o-", LineWidth=1.6, DisplayName="天真計數")
hold on
plot(blurLevels, resBlur.good, "s-", LineWidth=1.8, DisplayName="真硬幣數")
yline(10, ":", "正解", LineWidth=1.2);
hold off
xlabel("模糊 \sigma"); ylabel("個數"); title("模糊：兩種判準的差異")
legend(Location="southwest"); grid on

nexttile
plot(noiseLevels, resNoise.count, "o-", LineWidth=1.6, DisplayName="天真計數")
hold on
plot(noiseLevels, resNoise.good, "s-", LineWidth=1.8, DisplayName="真硬幣數")
yline(10, ":", "正解", LineWidth=1.2);
hold off
xlabel("雜訊 \sigma"); ylabel("個數"); title("雜訊：兩種判準的差異")
legend(Location="southwest"); grid on

nexttile
plot(resBlur.niqe, resBlur.good, "o-", LineWidth=1.6, DisplayName="模糊")
hold on
plot(resNoise.niqe, resNoise.good, "s-", LineWidth=1.6, DisplayName="雜訊")
yline(10, ":", "正解", LineWidth=1.2);
hold off
xlabel("NIQE"); ylabel("真硬幣數")
title("同一個 NIQE，兩種劣化的任務結果不同")
legend(Location="best"); grid on

nexttile
plot(resBlur.mtf, resBlur.good, "o-", LineWidth=1.6, DisplayName="模糊")
hold on
plot(resNoise.mtf, resNoise.good, "s-", LineWidth=1.6, DisplayName="雜訊")
yline(10, ":", "正解", LineWidth=1.2);
hold off
xlabel("MTF50"); ylabel("真硬幣數"); title("MTF50 vs 任務結果")
legend(Location="best"); grid on

fprintf("\n--- 天真計數 vs 嚴格判準：差在哪 ---\n");
mismatchB = resBlur.count == 10 & resBlur.good ~= 10;
mismatchN = resNoise.count == 10 & resNoise.good ~= 10;
fprintf("模糊序列中「計數=10 但其實有碎片」的級數：%d / %d", ...
    nnz(mismatchB), numel(blurLevels));
if any(mismatchB)
    fprintf("（sigma = %s）", join(string(blurLevels(mismatchB)), ", "));
end
fprintf("\n雜訊序列中同樣情況：%d / %d\n", nnz(mismatchN), numel(noiseLevels));
fprintf("**只看計數，這些級數會被誤判為成功。**\n");

fprintf("\n--- 用模糊校正出來的 NIQE 門檻，套到雜訊上 ---\n");
thr = failBlur.niqe;
passNoise = resNoise.niqe <= thr;
fprintf("門檻：NIQE <= %.2f（由模糊的臨界點得到）\n", thr);
fprintf("雜訊序列中被判為「通過」的級數：%d / %d\n", ...
    nnz(passNoise), numel(passNoise));
fprintf("其中任務真的成功（真硬幣=10）的有 %d 級\n", ...
    nnz(passNoise & resNoise.good == 10));
fprintf("**被門檻放過但任務其實已失敗：%d 級**\n", ...
    nnz(passNoise & resNoise.good ~= 10));
fprintf("**被門檻擋掉但任務其實還好好的：%d 級**  <- 誤殺\n", ...
    nnz(~passNoise & resNoise.good == 10));

fprintf("\n--- 換成 MTF50 門檻呢 ---\n");
thrM = failBlur.mtf;
passM = resNoise.mtf >= thrM;
fprintf("門檻：MTF50 >= %.4f（由模糊的臨界點得到）\n", thrM);
fprintf("雜訊序列中被判為「通過」：%d / %d，誤殺 %d 級\n", ...
    nnz(passM), numel(passM), nnz(~passM & resNoise.good == 10));
%[text] ## 最重要的發現：「計數正確」是個會騙人的成功判準
%[text] 先看第 3、4 小題之前，比較兩欄「計數」與「真硬幣」：
%[text:table]
%[text] | 雜訊 σ | 天真計數 | 真硬幣 | NIQE |
%[text] | --- | --- | --- | --- |
%[text] | 0 | 10 | **10** | 6.67 |
%[text] | 0.05 | 10 | 9 | 14.98 |
%[text] | **0.10** | **10** | **1** | 18.57 |
%[text] | 0.15 | 10 | 0 | 18.15 |
%[text] | 0.20 | 10 | 0 | 29.19 |
%[text:table]
%[text] **在 σ=0.10 時，流程回報「找到 10 個物件」，但其中只有 1 個是硬幣。**
%[text] 到了 σ=0.15，計數還是漂亮的 10，而真硬幣是 **0 個**。
%[text] 雜訊產生的碎片剛好補上被破壞的硬幣，**兩個錯誤互相抵消**。
%[text] 模糊序列也有同樣情形：12 級中有 **5 級**（σ=0.75、1、1.5、2、3）
%[text] 「計數=10 但其實只有 9 枚真硬幣」。
%[text] > **只看一個匯總數字，會看不到互相抵消的錯誤。**
%[text] > 這與第 11 章「2 像素的雜點圓形度是 0.97」是同一個陷阱：
%[text] > **判準要能排除退化的解，不能只數個數。**
%[text] 加上嚴格判準後，真正的失敗臨界點差很多：
%[text:table]
%[text] | 劣化 | 只看計數的臨界點 | **嚴格判準的臨界點** |
%[text] | --- | --- | --- |
%[text] | 模糊 | σ = 1.25 | **σ = 0.75** |
%[text] | 雜訊 | σ = 0.30 | **σ = 0.05** |
%[text:table]
%[text] 雜訊的真實容許量比天真判準所顯示的**小了 6 倍**。
%[text] ## 第 5、6 小題：門檻能跨劣化類型嗎
%[text] **不能。** 用模糊校正出來的門檻套到雜訊上：
%[text:table]
%[text] | 門檻（由模糊臨界點得到） | 套到雜訊序列的結果 |
%[text] | --- | --- |
%[text] | NIQE ≤ 6.50 | 通過 0 / 9 級，**誤殺 1 級**（任務其實還好的被擋掉） |
%[text] | MTF50 ≥ 0.1859 | 通過 1 / 9 級，誤殺 0 級 |
%[text:table]
%[text] 兩個門檻都**過度嚴格**。原因在第三、四張圖：
%[text] 模糊與雜訊的兩條曲線**不重疊**，
%[text] 代表「NIQE 值」與「任務是否成功」之間**沒有與劣化類型無關的對應關係**。
%[text] MTF50 還有一個更糟的問題：**雜訊一出現它就崩到地板值。**
%[text] 從 σ=0 的 0.2845 直接掉到 σ=0.05 的 0.0334，
%[text] 之後整段都在 0.029–0.045 之間亂跳。
%[text] 雜訊會污染邊緣剖面的微分，斜邊法因此完全失效——
%[text] **MTF50 能管失焦，不能管雜訊。**
%[text] ## 所以門檻該怎麼設（第 5 小題的實務答案）
%[text] 1. **先確定你的失效模式。** 機構固定、照明穩定的產線主要只會失焦，
%[text]    那就用 MTF50 管失焦，並在文件中**寫明這個前提**
%[text] 2. **不同劣化用不同指標**：MTF50 管銳利度、
%[text]    獨立的雜訊估計量（如第 04 章的 Immerkær 拉普拉斯估計）管雜訊，
%[text]    任一項不過就重拍
%[text] 3. **用下游任務校正門檻，而不是憑經驗猜**。
%[text]    而且要用**嚴格**的成功判準去校正，否則校出來的門檻會太鬆
%[text]    （本例會鬆 6 倍）
%[text] > **這題的真正結論**：品質指標不是任務表現的代理。
%[text] > 門檻只在**你校正過的那種劣化**上有效，
%[text] > 而且只在**你用來校正的那個成功判準**下有效。
%[text] > 這與第 11 章的校正指紋是同一件事：
%[text] > **門檻要帶著它的來歷（哪種劣化、哪個判準）一起流動。**

% ========================================================================
function out = ternary(cond, a, b)
%TERNARY 小工具：MATLAB 沒有三元運算子。
if cond, out = a; else, out = b; end
end

% ========================================================================
function D = makeStripeDomain(h, w, seed)
%MAKESTRIPEDOMAIN 合成「條紋 + 方塊」領域，刻意與自然照片統計不同。
%
%   與 ch12_makeWaferLike 不同的紋理，用來確認第 7 節的結論
%   （預設模型在非自然領域失效）不是只對某一種合成影像成立。
rng(seed);
[X, Y] = meshgrid(1:w, 1:h);

period = 6 + mod(seed, 5);
D = 0.5 + 0.35*sign(sin(2*pi*X/period));        % 硬邊條紋

% 幾個反相的方塊
for k = 1:6
    r0 = randi([10 h-40]); c0 = randi([10 w-40]);
    hh = randi([15 35]);   ww = randi([15 35]);
    D(r0:r0+hh, c0:c0+ww) = 1 - D(r0:r0+hh, c0:c0+ww);
end

D = imgaussfilt(D, 0.5);        % 輕微抗鋸齒
D = D + 0.008*randn(h, w);
D = min(max(D, 0), 1);
end

% ========================================================================
function [n, nGood] = countCoins(I)
%COUNTCOINS 第 08／11 章的硬幣計數流程，並回報「真的是硬幣」的個數。
%
%   N     通過流程的物件數（天真的計數）
%   NGOOD 其中同時滿足「圓形度 > 0.9」與「面積在合理範圍」的個數
%
%   為什麼需要第二個輸出
%   --------------------
%   實測（模糊 sigma=1.0）：流程回報 N = 10，**看起來完全正確**。
%   但檢查各物件的屬性會發現其中一個的面積只有 1074、圓形度只有 0.122——
%   那是一塊碎片，不是硬幣。也就是說**一枚真硬幣消失了，
%   同時多出一塊碎片，兩個錯誤剛好互相抵消。**
%
%   乾淨影像的面積範圍是 1810–2753、圓形度全部約 0.99。
%
%   > **「計數正確」不等於「任務成功」。**
%   > 只看一個匯總數字，會漏掉互相抵消的錯誤。
%   > 這與第 11 章「先用面積排除屬性不可信的物件」是同一個教訓。

if size(I,3) > 1, I = im2gray(I); end
if ~isfloat(I), I = im2double(I); end

bw = imbinarize(I);
bw = imfill(bw, "holes");
bw = bwareaopen(bw, 100);
bw = imclearborder(bw);

L = bwlabel(bw);
n = max(L, [], "all");
if isempty(n), n = 0; end

if n == 0
    nGood = 0;
    return
end

st = regionprops("table", bw, "Area", "Circularity");
isCoin = st.Circularity > 0.9 & st.Area > 1500 & st.Area < 3200;
nGood = nnz(isCoin);
end

% ========================================================================
function res = runDegradation(I, levels, kind)
%RUNDEGRADATION 對影像逐級劣化，記錄計數與各品質指標。
%
%   MTF50 的量法：另外合成一條斜邊，施加**同樣**的劣化。
%   直接在 coins.png 上量 MTF 不可行——硬幣邊緣是曲線，
%   而斜邊法需要一條直的、貫穿影像的邊。

n = numel(levels);
res = struct("count", zeros(1,n), "good", zeros(1,n), "niqe", zeros(1,n), ...
             "brisque", zeros(1,n), "piqe", zeros(1,n), "mtf", zeros(1,n));

baseEdge = ch12_makeSlantedEdge(256, 256, 5, 0.6);
G0 = im2double(im2gray(I));

for k = 1:n
    L = levels(k);
    if L == 0
        J = G0;
        E = baseEdge;
    elseif kind == "blur"
        J = imgaussfilt(G0, L);
        E = imgaussfilt(baseEdge, L);
    else
        J = min(max(G0 + L*randn(size(G0)), 0), 1);
        E = min(max(baseEdge + L*randn(size(baseEdge)), 0), 1);
    end

    % 全程保持 double。轉成 uint8 再二值化會改變 Otsu 門檻，
    % 實測會讓同一個 sigma 的計數結果不同（sigma=1.0 得 10 或 11）。
    [res.count(k), res.good(k)] = countCoins(J);
    res.niqe(k)    = niqe(J);
    res.brisque(k) = brisque(J);
    res.piqe(k)    = piqe(J);
    res.mtf(k)     = ch12_measureMTF(E);
end
end

% ========================================================================
function printSweep(levels, res)
fprintf("%-8s %8s %8s %9s %9s %9s %9s\n", ...
    "level", "計數", "真硬幣", "NIQE", "BRISQUE", "PIQE", "MTF50");
for k = 1:numel(levels)
    fprintf("%-8.2f %8d %8d %9.3f %9.3f %9.3f %9.4f\n", levels(k), ...
        res.count(k), res.good(k), res.niqe(k), res.brisque(k), ...
        res.piqe(k), res.mtf(k));
end
end

% ========================================================================
function f = firstFailure(levels, res)
%FIRSTFAILURE 找出計數第一次不等於 10 的那一級，並回報該點的各項指標。
%
%   注意取的是**第一次**失敗。計數可能在更高的劣化下巧合地回到 10
%   （例如兩枚硬幣糊成一坨、同時另一枚被切掉），
%   取最後一次或取最小值都會低估失敗門檻。

% 用**嚴格**判準：必須恰好 10 個物件，且 10 個都是真硬幣。
% 只看 res.count 會被「碎片頂替真硬幣」騙過去。
idx = find(res.count ~= 10 | res.good ~= 10, 1, "first");
if isempty(idx)
    idx = numel(levels);      % 整個掃描範圍內都沒失敗
    warning("Ch12_Solution:noFailure", ...
        "在掃描範圍內任務始終成功，回報的是最後一級而非真正的臨界點。" + ...
        "請把劣化範圍加大。");
end

f = struct("level", levels(idx), "index", idx, ...
           "niqe",    res.niqe(idx), ...
           "brisque", res.brisque(idx), ...
           "piqe",    res.piqe(idx), ...
           "mtf",     res.mtf(idx));
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
