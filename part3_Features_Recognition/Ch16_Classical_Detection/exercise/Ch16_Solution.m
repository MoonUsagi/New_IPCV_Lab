%[text] # 第 16 章　練習解答
%[text] 傳統物件偵測
assert(exist("ch16_slidingWindow","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

patchSize = [32 32];
cellSize  = [8 8];
% 多數實驗用步長 16（約 1.8 秒/張）而不是 8（約 8.5 秒/張），
% 因為下面要跑數十次滑動視窗。結論不受影響——
% 主教材第 8 節已證明步長只影響速度，不影響精確度（挖掘後都是 4 個框）。
STRIDE = 16;
%%
%[text] # 解答 1：把「背景」變成第四類
%[text] 產生三種背景 patch：純背景、只框到一半、框到兩個形狀邊緣。
[Xtr3, Ytr3] = ch16_makePatchSet(150, patchSize, 1);
[Xte3, Yte3] = ch16_makePatchSet(60,  patchSize, 2);

Xbg = makeBackgroundPatches(150, patchSize, 11);
Xbg_te = makeBackgroundPatches(60, patchSize, 12);
fprintf("\n背景 patch：訓練 %d 個、測試 %d 個\n", size(Xbg,3), size(Xbg_te,3));

figure
tiledlayout(2,6, TileSpacing="compact")
for k = 1:12
    nexttile; imshow(Xbg(:,:,k));
end
sgtitle("第四類：background（純背景、半個形狀、兩形狀邊緣）")

% --- 四類訓練集 ---
X4 = cat(3, Xtr3, Xbg);
Y4 = [Ytr3; repmat("background", size(Xbg,3), 1)];
F4 = ch16_hogFeatures(X4, cellSize);
y4 = categorical(Y4);

model4 = fitcecoc(F4, y4);

% patch 準確率（含背景類）
X4te = cat(3, Xte3, Xbg_te);
Y4te = [Yte3; repmat("background", size(Xbg_te,3), 1)];
F4te = ch16_hogFeatures(X4te, cellSize);
acc4 = mean(predict(model4, F4te) == categorical(Y4te));
fprintf("四類 patch 準確率 = %.4f\n", acc4);
%%
%[text] ## 三種做法的偵測表現
[scene, gtBoxes] = ch16_makeSceneWithTruth(480, 640);

% (a) 原始三類
F3 = ch16_hogFeatures(Xtr3, cellSize);
y3bin = categorical(Ytr3 == "circle", [false true], ["other" "circle"]);
model3 = fitcsvm(F3, y3bin, KernelFunction="linear");
[bA, ~, nwA] = ch16_slidingWindow(scene, model3, patchSize, ...
    Stride=STRIDE, CellSize=cellSize);
[pA, rA] = ch16_evalDetections(bA, gtBoxes);

% (b) 硬負樣本挖掘
hard = ch16_mineHardNegatives(scene, gtBoxes, model3, patchSize, ...
    Stride=STRIDE, CellSize=cellSize, MaxSamples=400);
Fh = ch16_hogFeatures(hard, cellSize);
modelB = fitcsvm([F3; Fh], ...
    [y3bin; repmat(categorical("other", ["other" "circle"]), size(Fh,1), 1)], ...
    KernelFunction="linear");
[bB, ~, ~] = ch16_slidingWindow(scene, modelB, patchSize, ...
    Stride=STRIDE, CellSize=cellSize);
[pB, rB] = ch16_evalDetections(bB, gtBoxes);

% (c) 四類（含 background）
[bC, ~, ~] = ch16_slidingWindow(scene, model4, patchSize, ...
    Stride=STRIDE, CellSize=cellSize);
[pC, rC] = ch16_evalDetections(bC, gtBoxes);

fprintf("\n%-24s %10s %12s %12s\n", "做法", "偵測框", "precision", "recall");
fprintf("%-24s %10d %11.1f%% %11.1f%%" + "\n", "(a) 原始三類", size(bA,1), pA, rA);
fprintf("%-24s %10d %11.1f%% %11.1f%%" + "\n", "(b) 硬負樣本挖掘", size(bB,1), pB, rB);
fprintf("%-24s %10d %11.1f%% %11.1f%%" + "\n", "(c) 四類含 background", size(bC,1), pC, rC);
fprintf("\n（真實目標 %d 個，步長 %d）\n", size(gtBoxes,1), STRIDE);
%[text] ## 量到的結果
%[text:table]
%[text] | 做法 | 偵測框 | precision | recall |
%[text] | --- | --- | --- | --- |
%[text] | (a) 原始三類 | 328 | 0.9% | 75.0% |
%[text] | (b) 硬負樣本挖掘 | 4 | **100.0%** | **100.0%** |
%[text] | (c) 四類含 background | 4 | **100.0%** | **100.0%** |
%[text:table]
%[text] **兩種做法都修好了。** 四類版本和挖掘版本都是 4 個框、100%／100%。
%[text] 順便注意 (a) 的 recall 是 **75.0%**，不是主教材的 100.0%——
%[text] 因為這裡用步長 16 而主教材用 8，有一個目標剛好沒被任何視窗
%[text] 對準到 IoU ≥ 0.5。
%[text] > **這修正了一個容易被誤讀的說法。** 主教材第 8 節說
%[text] > 「步長只影響速度，不影響對錯」，那句話的前提是
%[text] > **挖掘之後**——(b) 和 (c) 在步長 16 下確實還是 4 個框。
%[text] > 但對**還沒挖掘的爛模型**，步長會影響 recall。
%[text] **第 5 小題：哪一種做法比較好？**
%[text] 光看上表會說「一樣好」。**但那個結論靠不住，理由在方法論上。**
%[text:table]
%[text] | 做法 | 怎麼取得背景樣本 | 可靠性 |
%[text] | --- | --- | --- |
%[text] | 四類 | **事先猜**背景長什麼樣 | 取決於你猜得準不準 |
%[text] | 硬負樣本挖掘 | **事後找**模型真正會錯的地方 | 直接針對真實誤差 |
%[text:table]
%[text] 我設計背景 patch 時做了三個假設（純背景、半個形狀、兩形狀邊緣）。
%[text] 它們**剛好全中**——但那不是因為我猜得準，
%[text] 是因為**場景也是我自己產生的**：
%[text] `ch16_makeSceneWithTruth` 只會畫圓、方、三角形，
%[text] 所以「兩個形狀的邊緣同時入框」必然涵蓋了絕大多數誤判。
%[text] **我有內線消息。** 真實影像上你沒有。
%[text] **所以答案是硬負樣本挖掘更可靠，理由不是它今天贏了
%[text] （它沒有），而是它不需要猜。**
%[text] 挖掘直接去問模型：「你在哪裡錯了？」然後把那些收進來。
%[text] 若你的假設漏掉某一種誤判模式，四類版本就補不到；
%[text] 挖掘一定會找到——因為它是從實際的誤判收集的。
%[text] > **實務上兩者搭配最好**：先用四類建立基本的背景概念，
%[text] > 再用挖掘補上你沒想到的失敗模式。
%[text] 而且**四類版本有一個額外優點**：它能回答「這是什麼」
%[text] （圓/方/三角/背景），而二元 SVM 只能回答「是不是圓」。
%%
%[text] # 解答 2：`MinSize` 的正確設法——先量再設
%[text] **不要試誤。先偵測一次，量出框的尺寸分布，再依分布設定。**
I1 = imread("visionteam.jpg");
det0 = vision.CascadeObjectDetector("FrontalFaceLBP");
det0(I1);                                 % 暖機
t = tic; bb0 = det0(I1); tBefore = toc(t);

sizes0 = bb0(:,3);                        % 框的寬度（正方形，寬=高）
fprintf("\n預設參數：找到 %d 張臉、%.4f 秒\n", size(bb0,1), tBefore);
fprintf("框寬度：最小 %.0f、中位數 %.0f、最大 %.0f 像素\n", ...
    min(sizes0), median(sizes0), max(sizes0));

% 依量到的分布設定，留 20% 的餘裕
minS = round(0.8 * min(sizes0));
maxS = round(1.2 * max(sizes0));
fprintf("\n依分布設定：MinSize [%d %d]、MaxSize [%d %d]（各留 20%% 餘裕）\n", ...
    minS, minS, maxS, maxS);

det1 = vision.CascadeObjectDetector("FrontalFaceLBP", ...
    MinSize=[minS minS], MaxSize=[maxS maxS]);
det1(I1);
t = tic; bb1 = det1(I1); tAfter = toc(t);
fprintf("設定後：找到 %d 張臉、%.4f 秒（加速 %.2f 倍）\n", ...
    size(bb1,1), tAfter, tBefore/tAfter);
%%
%[text] ## 第 5、6 小題：搬到別張影像上會怎樣
I2 = imread("visionteam1.jpg");

detDefault = vision.CascadeObjectDetector("FrontalFaceLBP");
detDefault(I2);
t = tic; bbDef2 = detDefault(I2); tDef2 = toc(t);

det1(I2);
t = tic; bbTuned2 = det1(I2); tTuned2 = toc(t);

fprintf("\n%-26s %10s %10s %12s\n", "影像 / 設定", "偵測數", "秒數", "框寬中位數");
fprintf("%-26s %10d %10.4f %12.0f\n", "visionteam  預設", ...
    size(bb0,1), tBefore, median(bb0(:,3)));
fprintf("%-26s %10d %10.4f %12.0f\n", "visionteam  調過", ...
    size(bb1,1), tAfter, median(bb1(:,3)));
fprintf("%-26s %10d %10.4f %12.0f\n", "visionteam1 預設", ...
    size(bbDef2,1), tDef2, medianOrNaN(bbDef2));
fprintf("%-26s %10d %10.4f %12.0f\n", "visionteam1 調過", ...
    size(bbTuned2,1), tTuned2, medianOrNaN(bbTuned2));
%[text] **第 6 小題：不能直接搬。**
%[text] `MinSize` 與 `MaxSize` 的單位是**像素**，
%[text] 而同一張臉在不同解析度的影像上佔的像素數不同。
%[text] 若第二張影像的人臉比較小（或影像整體較小），
%[text] 調過的 `MinSize` 就會把它們全部濾掉。
%[text] > **這個參數必須帶著它的來歷一起流動**——
%[text] > 與第 11 章的「校正指紋」完全同一個原則。
%[text] **而且比例式的寫法有一個硬性下限。** 上面量到：
%[text:table]
%[text] | 在縮小一半的影像上 | 結果 |
%[text] | --- | --- |
%[text] | 預設設定 | **0 個**（連預設都失效了） |
%[text] | 調過的 `MinSize=[28 28]` | **0 個** |
%[text] | 比例式 `MinSize=[20 20]` | **直接報錯** |
%[text] | 把影像放大 2 倍 + 預設設定 | 找回來了 |
%[text:table]
%[text] `MinSize` 不能小於**模型自己的訓練尺寸**
%[text] （`FrontalFaceLBP` 是 24×24，設 20 就報
%[text] 「MinSize value must be greater than or equal to [24 24]」）。
%[text] **所以「比例式縮放」只在放大的方向有效，縮小的方向會撞到地板。**
%[text] 目標在影像上小於 24 像素時，唯一的辦法是
%[text] **把影像放大**（或換一個用更小尺寸訓練的模型），
%[text] 不是把 `MinSize` 調小——那條路是封死的。
%[text] 要記錄的資訊至少包含：
%[text] 1. **影像解析度**（或感測器規格 + 鏡頭焦距）
%[text] 2. **拍攝距離範圍**
%[text] 3. **目標的實體尺寸**
%[text] 有了這三項才能換算到新的設定。
%[text] **看起來更穩健的做法**：把 `MinSize` 寫成影像尺寸的**比例**
%[text] 而不是絕對像素，例如 `MinSize = round(0.05 * size(I,1)) * [1 1]`。
%[text] 下一節會測試這個想法——**它有一個上限，而且會直接報錯。**
%%
%[text] ## 把設定「操壞」——縮小影像就失效
%[text] 上面兩張影像的人臉尺寸剛好接近，所以調過的設定還能用。
%[text] **不要因此以為它安全。** 直接把影像縮小一半來驗證。
I2small = imresize(I2, 0.5);
detDefault(I2small);
bbSmallDef   = detDefault(I2small);
bbSmallTuned = det1(I2small);

fprintf("\n縮小一半（%dx%d -> %dx%d）：\n", size(I2,1), size(I2,2), ...
    size(I2small,1), size(I2small,2));
fprintf("  預設設定：%d 個\n", size(bbSmallDef,1));
fprintf("  調過的 MinSize=[%d %d]：%d 個\n", minS, minS, size(bbSmallTuned,1));

% 比例式設定：跟著影像尺寸自動縮放
ratio   = minS / size(I1,1);
wantMin = round(ratio * size(I2small,1));
fprintf("  比例式想設 MinSize=[%d %d]（%.4f x 影像高）\n", ...
    wantMin, wantMin, ratio);
try
    detRatio = vision.CascadeObjectDetector("FrontalFaceLBP", ...
        MinSize=wantMin*[1 1]);
    bbSmallRatio = detRatio(I2small);
    fprintf("  比例式：%d 個\n", size(bbSmallRatio,1));
catch ME
    fprintf("  **比例式直接報錯**：%s\n", ME.message);
end

% 正確的補救：把影像**放大**，而不是把 MinSize 調小
bbUp = detDefault(imresize(I2small, 2));
fprintf("  改成把縮小的影像放大 2 倍、用預設設定：%d 個\n", size(bbUp,1));
%%
%[text] # 解答 3：資料洩漏——主教材高估了多少
%[text] **主教材在同一張場景上挖掘並評估。這是資料洩漏。**
%[text] 先做最小的對照：在 A 上挖掘、在 B 上評估。
[sceneA, gtA] = ch16_makeSceneWithTruth(480, 640, Seed=7);
[sceneB, gtB] = ch16_makeSceneWithTruth(480, 640, Seed=99);

% 在 A 上挖掘
hardA = ch16_mineHardNegatives(sceneA, gtA, model3, patchSize, ...
    Stride=STRIDE, CellSize=cellSize, MaxSamples=400);
FhA = ch16_hogFeatures(hardA, cellSize);
modelA = fitcsvm([F3; FhA], ...
    [y3bin; repmat(categorical("other", ["other" "circle"]), size(FhA,1), 1)], ...
    KernelFunction="linear");

% 在 A 上評估（洩漏）與在 B 上評估（乾淨）
[bAA, ~, ~] = ch16_slidingWindow(sceneA, modelA, patchSize, ...
    Stride=STRIDE, CellSize=cellSize);
[pAA, rAA] = ch16_evalDetections(bAA, gtA);
[bAB, ~, ~] = ch16_slidingWindow(sceneB, modelA, patchSize, ...
    Stride=STRIDE, CellSize=cellSize);
[pAB, rAB] = ch16_evalDetections(bAB, gtB);

fprintf("\n在場景 A 上挖掘，然後：\n");
fprintf("  在 **A** 上評估（洩漏）：%d 框、precision %.1f%%、recall %.1f%%" + "\n", ...
    size(bAA,1), pAA, rAA);
fprintf("  在 **B** 上評估（乾淨）：%d 框、precision %.1f%%、recall %.1f%%" + "\n", ...
    size(bAB,1), pAB, rAB);
%%
%[text] ## 五折交叉驗證
%[text] 產生 5 張場景，輪流留一張當測試，其餘四張挖掘。
nFold = 5;
seeds = [7 99 123 456 789];
scenes = cell(nFold,1); gts = cell(nFold,1);
for k = 1:nFold
    [scenes{k}, gts{k}] = ch16_makeSceneWithTruth(480, 640, Seed=seeds(k));
end

precLeak = zeros(nFold,1); recLeak = zeros(nFold,1);
precHold = zeros(nFold,1); recHold = zeros(nFold,1);

% 下面要挖掘 20 次，每次都會觸發 maxSamplesReached 警告。
% 警告本身是對的（模型還很差），但在迴圈裡會蓋掉真正的輸出。
wState = warning("off", "ch16_mineHardNegatives:maxSamplesReached");
restoreW = onCleanup(@() warning(wState));

for testIdx = 1:nFold
    trainIdx = setdiff(1:nFold, testIdx);

    % 在四張訓練場景上挖掘
    Fall = F3;
    yAll = y3bin;
    for k = trainIdx
        h = ch16_mineHardNegatives(scenes{k}, gts{k}, model3, patchSize, ...
            Stride=STRIDE, CellSize=cellSize, MaxSamples=150);
        if size(h,3) > 0
            Fh2 = ch16_hogFeatures(h, cellSize);
            Fall = [Fall; Fh2];
            yAll = [yAll; repmat(categorical("other", ["other" "circle"]), ...
                size(Fh2,1), 1)];
        end
    end
    mdl = fitcsvm(Fall, yAll, KernelFunction="linear");

    % 洩漏版：在其中一張**訓練**場景上評估
    [bl, ~, ~] = ch16_slidingWindow(scenes{trainIdx(1)}, mdl, patchSize, ...
        Stride=STRIDE, CellSize=cellSize);
    [precLeak(testIdx), recLeak(testIdx)] = ...
        ch16_evalDetections(bl, gts{trainIdx(1)});

    % 乾淨版：在留出的測試場景上評估
    [bh, ~, ~] = ch16_slidingWindow(scenes{testIdx}, mdl, patchSize, ...
        Stride=STRIDE, CellSize=cellSize);
    [precHold(testIdx), recHold(testIdx)] = ...
        ch16_evalDetections(bh, gts{testIdx});
end

fprintf("\n五折結果（每折在 4 張場景上挖掘）：\n");
fprintf("%-22s %16s %16s\n", "評估方式", "precision", "recall");
fprintf("%-22s %8.1f%% ± %-5.1f %8.1f%% ± %-5.1f\n", "在訓練場景上（洩漏）", ...
    mean(precLeak), std(precLeak), mean(recLeak), std(recLeak));
fprintf("%-22s %8.1f%% ± %-5.1f %8.1f%% ± %-5.1f\n", "在留出場景上（乾淨）", ...
    mean(precHold), std(precHold), mean(recHold), std(recHold));
fprintf("\n**precision 高估了 %.1f 個百分點**\n", mean(precLeak) - mean(precHold));
clear restoreW      % 還原警告狀態
%[text] **第 6 小題：主教材高估了多少**
%[text:table]
%[text] | 評估方式 | precision | recall |
%[text] | --- | --- | --- |
%[text] | 在訓練場景上（洩漏） | 100.0% ± 0.0 | 70.0% ± 27.4 |
%[text] | 在留出場景上（乾淨） | **80.0% ± 44.7** | **60.0% ± 37.9** |
%[text:table]
%[text] **主教材的 precision 高估了 20.0 個百分點。**
%[text] 但**更值得看的是標準差**：洩漏版是 ± 0.0（五折全部 100%），
%[text] 乾淨版是 ± 44.7——五折裡有**一折整個垮掉**（0%）。
%[text] 洩漏不只讓平均值變好看，還**讓變異數消失**，
%[text] 於是你會誤以為結果很穩定。
%[text] 前面那個最小對照更極端：只在**一張**場景上挖掘，
%[text] 在同一張上是 100%／100%，換一張新場景就是 **0%／0%**。
%[text] 挖 4 張才拉到 80%——
%[text] **泛化能力來自挖掘場景的多樣性，不是挖掘本身。**
%[text] **為什麼會高估**：硬負樣本是從那張場景上收集的，
%[text] 模型因此**背下了那張場景的所有誤判位置**。
%[text] 換一張新場景，背景的紋理與物件位置都不同，
%[text] 那些被背下來的負樣本不一定有用。
%[text] > **這與第 12 章練習 3 是同一個錯誤在偵測任務上的版本：**
%[text] > **拿訓練資料評估，量到的是記憶不是泛化。**
%[text] 注意合成場景的「泛化落差」可能比真實資料小——
%[text] 因為所有場景都用同一個程式產生，統計特性相近。
%[text] 真實專案的落差通常大得多。
%%
%[text] # 解答 4：自訓 cascade 偵測器
%[text] 用 MATLAB 內建的停止標誌資料集做一次小規模訓練。
data = load("stopSignsAndCars.mat");
tbl = data.stopSignsAndCars;
fprintf("\n資料集：%d 張影像，欄位 %s\n", height(tbl), ...
    strjoin(string(tbl.Properties.VariableNames), ", "));

%[text] > **第二個坑**：`imageFilename` 欄位存的是**相對路徑，而且已經
%[text] > 含了子資料夾**（`stopSignImages/image001.jpg`）。
%[text] > 再用 `fullfile(..., "stopSignImages", name)` 就會變成
%[text] > `stopSignImages/stopSignImages/image001.jpg`——
%[text] > 檔案全部找不到，`positiveInstances` 變成空的，
%[text] > 而錯誤訊息只會說「positiveInstances 不能為空」，
%[text] > **不會告訴你路徑錯了**。
%[text] > 正確做法是用 `.mat` 檔自己的位置當基準目錄。
dataDir = fileparts(which("stopSignsAndCars.mat"));
fprintf("資料目錄：%s\n", dataDir);

positiveInstances = struct("imageFilename", {}, "objectBoundingBoxes", {});
nMissing = 0;
for k = 1:height(tbl)
    f = fullfile(dataDir, tbl.imageFilename{k});   % 相對路徑已含子資料夾
    if ~isfile(f)
        nMissing = nMissing + 1;
        continue
    end
    positiveInstances(end+1) = struct( ...
        "imageFilename", f, ...
        "objectBoundingBoxes", tbl.stopSign{k});
end
fprintf("正樣本：%d 個（找不到 %d 個）\n", numel(positiveInstances), nMissing);
assert(~isempty(positiveInstances), "正樣本是空的——先檢查路徑，不要急著調參數。");

negDir = fullfile(dataDir, "nonStopSigns");
negFiles = dir(fullfile(negDir, "*.jpg"));
fprintf("負樣本影像：%d 張（%s）\n", numel(negFiles), negDir);
%%
%[text] ## 訓練
%[text] **刻意把級數與誤警率調小以加快實驗。**
%[text] 正式訓練應該用更多級數（預設 20）與更嚴格的誤警率。
%[text] > **一個會讓人卡住的 API 限制（我第一次就撞到）：**
%[text] > `trainCascadeObjectDetector` 的第一個引數**必須是純檔名**，
%[text] > 不能含任何路徑分隔符號。傳 `fullfile(tempdir, "x.xml")` 會直接報
%[text] > 「must be filename without any prefixed folder name」。
%[text] > 要輸出到別的資料夾，**只能先把那個資料夾設成當前工作目錄**。
xmlName = "ch16_stopSignDetector.xml";
outXML  = fullfile(tempdir, xmlName);
if isfile(outXML), delete(outXML); end

trainedOK = false;
oldDir = cd(tempdir);              % 因為上面那個檔名限制
try
    t = tic;
    trainCascadeObjectDetector(xmlName, positiveInstances, negDir, ...
        NumCascadeStages=3, FalseAlarmRate=0.2, TruePositiveRate=0.995, ...
        FeatureType="HOG", ObjectTrainingSize=[32 32]);
    trainSec = toc(t);
    trainedOK = true;
catch ME
    warning("Ch16_Solution:cascadeTrainFailed", "訓練失敗：%s", ME.message);
end
cd(oldDir);                        % 一定要換回來，後面的段落靠相對路徑
if trainedOK
    fprintf("\n訓練耗時 %.1f 秒（3 級、HOG、%d 個正樣本）\n", ...
        trainSec, numel(positiveInstances));
end
%%
%[text] ## 測試
if ~trainedOK
    disp("（上一節訓練失敗，略過測試。）")
else
    customDet = vision.CascadeObjectDetector(outXML);

    % 在訓練用的影像上測（會偏樂觀）
    trainImg = imread(positiveInstances(1).imageFilename);
    bbTrain = customDet(trainImg);
    fprintf("\n在**訓練用**影像上：找到 %d 個（標註有 %d 個）\n", ...
        size(bbTrain,1), size(positiveInstances(1).objectBoundingBoxes,1));

    % 在獨立的測試影像上測
    testImg = imread("stopSignTest.jpg");
    bbTest = customDet(testImg);
    fprintf("在**獨立測試**影像上：找到 %d 個\n", size(bbTest,1));

    figure
    tiledlayout(1,2, TileSpacing="compact")
    nexttile
    if isempty(bbTrain)
        imshow(trainImg); title("訓練影像：沒找到")
    else
        imshow(insertObjectAnnotation(trainImg, "rectangle", bbTrain, "stop", ...
            Color="yellow", LineWidth=3));
        title(sprintf("訓練影像：%d 個", size(bbTrain,1)))
    end
    nexttile
    if isempty(bbTest)
        imshow(testImg); title("測試影像：沒找到")
    else
        imshow(insertObjectAnnotation(testImg, "rectangle", bbTest, "stop", ...
            Color="cyan", LineWidth=3));
        title(sprintf("測試影像：%d 個", size(bbTest,1)))
    end
end
%[text] ## 量到的結果
%[text:table]
%[text] | 項目 | 數字 |
%[text] | --- | --- |
%[text] | 正樣本 | 41 張影像（`stopSign` 標註） |
%[text] | 負樣本影像 | 5 張 |
%[text] | 訓練耗時 | 6.3 秒（3 級、HOG、32×32） |
%[text] | 在**訓練用**影像上 | **86 個框**（標註只有 1 個） |
%[text] | 在獨立測試影像上 | 3 個框 |
%[text:table]
%[text] **86 個框、1 個真實目標——而且那是它訓練過的影像。**
%[text] 這不是「過擬合」，這是**根本沒學會**。
%[text] 訓練訊息裡有直接的證據：
%[text] ```
%[text] Using at most 42 of 42 positive samples per stage
%[text] Using at most 84 negative samples per stage
%[text] ```
%[text] **每一級只有 84 個負樣本可用。** 三級都是同一批。
%[text] **第 6 小題：41 張正樣本夠嗎？為什麼官方要數百到數千？**
%[text] **不夠，而且原因是結構性的。**
%[text] cascade 的訓練方式是**逐級進行**，
%[text] 而且**後面的級只看得到「前面的級沒拒絕掉的」樣本**：
%[text:table]
%[text] | 級 | 看到的負樣本 |
%[text] | --- | --- |
%[text] | 第 1 級 | 全部負樣本 |
%[text] | 第 2 級 | 只有第 1 級**誤判為正**的那些 |
%[text] | 第 3 級 | 只有前兩級都誤判的那些 |
%[text:table]
%[text] 每一級的 `FalseAlarmRate` 若是 0.5，
%[text] 第 n 級能看到的負樣本就只有原始的 $0.5^{n-1}$。
%[text] **20 級的話是 $0.5^{19} \approx 2\times10^{-6}$**——
%[text] 要讓最後一級還有一千個負樣本可訓練，
%[text] 一開始就需要**五億**個候選視窗。
%[text] 這就是為什麼 `trainCascadeObjectDetector` 需要
%[text] 「負樣本**影像**」而不是「負樣本 patch」：
%[text] 它會自己在那些影像上採樣大量視窗。
%[text] 5 張負樣本影像能提供的視窗數遠遠不足——
%[text] 上面量到的「84 個負樣本」就是這個上限的實際值。
%[text] 正樣本同理：每一級都要重新訓練一個分類器，
%[text] 41 個正樣本在高維的 HOG 空間裡什麼都撐不住。
%[text] > **順便回答一個常見的誤解。** 有人看到 86 個假陽性會想
%[text] > 「加更多級數就好了」。不會——級數變多只會讓後面的級
%[text] > **更沒有負樣本可訓練**。瓶頸在資料，不在級數。
%[text] > **這是傳統 cascade 的一個實務門檻：**
%[text] > 它不是「小資料方法」——它需要的**負樣本**數量非常大，
%[text] > 只是負樣本比較容易取得（隨便拍背景就有）。
%%
%[text] # 解答 5：把成本降下來
%[text] 三種加速手段，各自量測。
baseModel = modelB;      % 用挖掘後的模型當基準
[sceneT, gtT] = ch16_makeSceneWithTruth(480, 640, Seed=7);

% --- 基準：步長 8、單尺度 ---
t = tic;
[bBase, ~, nwBase] = ch16_slidingWindow(sceneT, baseModel, patchSize, ...
    Stride=8, CellSize=cellSize);
tBase = toc(t);
[pBase, rBase] = ch16_evalDetections(bBase, gtT);
fprintf("\n基準（步長 8）：%d 視窗、%.2f 秒、precision %.1f%%、recall %.1f%%" + "\n", ...
    nwBase, tBase, pBase, rBase);

results = struct("name", {}, "sec", {}, "speedup", {}, "prec", {}, "rec", {}, "win", {});
results(end+1) = struct("name","基準（步長 8）", "sec",tBase, "speedup",1, ...
    "prec",pBase, "rec",rBase, "win",nwBase);

% --- 手段 1：限制搜尋區域 ---
t = tic;
[b1, nw1] = detectWithRegions(sceneT, baseModel, patchSize, cellSize);
t1 = toc(t);
[p1, r1] = ch16_evalDetections(b1, gtT);
results(end+1) = struct("name","手段1 候選區域", "sec",t1, ...
    "speedup",tBase/t1, "prec",p1, "rec",r1, "win",nw1);

% --- 手段 2：提早拒絕（標準差過低就跳過）---
t = tic;
[b2, nw2] = detectWithEarlyReject(sceneT, baseModel, patchSize, cellSize, 8, 0.05);
t2 = toc(t);
[p2, r2] = ch16_evalDetections(b2, gtT);
results(end+1) = struct("name","手段2 提早拒絕", "sec",t2, ...
    "speedup",tBase/t2, "prec",p2, "rec",r2, "win",nw2);

% --- 手段 3：加大 CellSize ---
for cs = {[16 16]}
    csv = cs{1};
    Fc = ch16_hogFeatures(Xtr3, csv);
    mdlC = fitcsvm(Fc, y3bin, KernelFunction="linear");
    hc = ch16_mineHardNegatives(sceneT, gtT, mdlC, patchSize, ...
        Stride=8, CellSize=csv, MaxSamples=400);
    if size(hc,3) > 0
        Fhc = ch16_hogFeatures(hc, csv);
        mdlC = fitcsvm([Fc; Fhc], ...
            [y3bin; repmat(categorical("other",["other" "circle"]), size(Fhc,1),1)], ...
            KernelFunction="linear");
    end
    t = tic;
    [b3, ~, nw3] = ch16_slidingWindow(sceneT, mdlC, patchSize, ...
        Stride=8, CellSize=csv);
    t3 = toc(t);
    [p3, r3] = ch16_evalDetections(b3, gtT);
    results(end+1) = struct("name", sprintf("手段3 CellSize [%d %d]", csv), ...
        "sec",t3, "speedup",tBase/t3, "prec",p3, "rec",r3, "win",nw3);
    fprintf("CellSize [%d %d] -> HOG 維度 %d（原 %d）\n", ...
        csv, size(Fc,2), size(F3,2));
end

fprintf("\n%-26s %10s %10s %12s %12s\n", "手段", "秒數", "加速", "precision", "recall");
for k = 1:numel(results)
    fprintf("%-26s %10.2f %9.2fx %11.1f%% %11.1f%%" + "\n", results(k).name, ...
        results(k).sec, results(k).speedup, results(k).prec, results(k).rec);
end
%[text] ## 量到的結果
%[text] 兩次獨立執行的結果（**絕對秒數依機器而異，加速倍數才是重點**）：
%[text:table]
%[text] | 手段 | 加速 | precision | recall |
%[text] | --- | --- | --- | --- |
%[text] | 基準（步長 8，3.8–8.7 秒） | 1.0x | 100.0% | 100.0% |
%[text] | 手段1 候選區域 | **20–30x** | 100.0% | 100.0% |
%[text] | 手段2 提早拒絕 | **8x** | 100.0% | 100.0% |
%[text] | 手段3 CellSize [16 16] | 1.1–1.3x | **57.1%** | 100.0% |
%[text:table]
%[text] **目標（10 倍）達成：手段 1 穩定超過 20 倍。**
%[text] 手段 2 的 8 倍差一點，兩者疊起來就遠遠超過。
%[text] 但這張表有兩個地方會誤導人，**都值得停下來想。**
%[text] ## 誤導一：手段 3 幾乎沒有變快
%[text] `CellSize` 從 [8 8] 加大到 [16 16]，
%[text] HOG 維度從 **324 掉到 36**——少了 9 倍。
%[text] **結果只快了 1.1–1.3 倍，而 precision 從 100% 掉到 57.1%。**
%[text] 為什麼？因為**成本不在 SVM 的內積上**。
%[text] 每個視窗的時間花在 `extractHOGFeatures` 的梯度計算與
%[text] 每次呼叫的固定開銷上，那些不隨維度縮小。
%[text] > **降低特徵維度是在最便宜的地方省錢。**
%[text] > 這是一個很常見的最佳化直覺陷阱——
%[text] > 先量，再決定要省哪裡。
%[text] ## 誤導二：手段 1 看起來完勝
%[text] 30.3 倍、精確度零損失。**但那是因為這個場景是合成的。**
%[text] 背景固定 0.9、物件固定 0.15，一個全域門檻就能完美切出候選。
%[text] **候選產生器的 recall 是整條流程的天花板**——
%[text] 在真實影像上（陰影、遮擋、低對比）它會先漏掉目標，
%[text] 而漏掉的東西後面再怎麼分類都救不回來。
%[text] 三種手段的本質差異：
%[text:table]
%[text] | 手段 | 為什麼快 | 風險 |
%[text] | --- | --- | --- |
%[text] | **候選區域** | 完全跳過空白區域 | 候選產生器漏掉目標就永遠找不到 |
%[text] | **提早拒絕** | 用極便宜的判斷擋掉大部分視窗 | 門檻設太高會漏掉低對比的目標 |
%[text] | **加大 CellSize** | HOG 維度降低 | 形狀細節損失（實測掉到 57.1%） |
%[text:table]
%[text] **「加速 / 風險」比值最好的是手段 2「提早拒絕」**，因為：
%[text] - 它的判斷（標準差）成本幾乎為零
%[text] - 它**不改變分類器**，所以對通過的視窗完全沒有精確度損失
%[text] - 門檻可以設得極保守（只擋「絕對是空白」的），
%[text]   於是它的風險可以**調到趨近於零**——另兩種手段做不到
%[text] > **這正是 cascade 的核心想法**：
%[text] > 用一連串**越來越貴**的判斷，讓便宜的判斷先擋掉大部分候選。
%[text] > Viola-Jones 的第一級只用 2 個 Haar 特徵，
%[text] > 就能拒絕約 50% 的視窗。
%[text] 做完這題就能理解為什麼 `FrontalFaceLBP` 能快 500 倍——
%[text] 它不是特徵比較好，是**大部分視窗根本沒算完整的特徵**。
%%
%[text] # 加分題：資料量曲線與飽和點
%[text] 訓練樣本從每類 5 個掃到 300 個，每次都完整跑
%[text] 訓練 → 挖掘 → **在獨立場景上**評估。
%[text] > **這裡有一個設計決定，是被上一題的結果逼出來的。**
%[text] > 解答 3 量到「只在**一張**場景上挖掘，換到新場景 precision 就是 0%」。
%[text] > 若加分題也只挖一張，整條曲線會全部是 0——
%[text] > 那量到的是「單張挖掘不夠」，**不是**「樣本數不夠」。
%[text] > 所以這裡固定在**三張**場景上挖掘，只讓訓練樣本數變動，
%[text] > 這樣曲線才真的在回答加分題的問題。
nPerList = [5 20 50 100 300];
precCurve = zeros(size(nPerList));
recCurve  = zeros(size(nPerList));
patchAcc  = zeros(size(nPerList));

mineSeeds = [7 123 456];
mineScenes = cell(numel(mineSeeds),1); mineGts = cell(numel(mineSeeds),1);
for k = 1:numel(mineSeeds)
    [mineScenes{k}, mineGts{k}] = ch16_makeSceneWithTruth(480, 640, Seed=mineSeeds(k));
end
[sceneEval, gtEval] = ch16_makeSceneWithTruth(480, 640, Seed=99);

wState2 = warning("off", "ch16_mineHardNegatives:maxSamplesReached");
restoreW2 = onCleanup(@() warning(wState2));

Fte = ch16_hogFeatures(Xte3, cellSize);
yte = categorical(Yte3 == "circle", [false true], ["other" "circle"]);

for k = 1:numel(nPerList)
    nPer = nPerList(k);
    [Xn, Yn] = ch16_makePatchSet(nPer, patchSize, 1);
    Fn = ch16_hogFeatures(Xn, cellSize);
    yn = categorical(Yn == "circle", [false true], ["other" "circle"]);
    mdl = fitcsvm(Fn, yn, KernelFunction="linear");

    patchAcc(k) = mean(predict(mdl, Fte) == yte);

    % 在三張場景上挖掘
    Fcur = Fn; ycur = yn;
    for j = 1:numel(mineSeeds)
        h = ch16_mineHardNegatives(mineScenes{j}, mineGts{j}, mdl, patchSize, ...
            Stride=STRIDE, CellSize=cellSize, MaxSamples=150);
        if size(h,3) > 0
            Fh3 = ch16_hogFeatures(h, cellSize);
            Fcur = [Fcur; Fh3];
            ycur = [ycur; repmat(categorical("other",["other" "circle"]), ...
                size(Fh3,1), 1)];
        end
    end
    mdl = fitcsvm(Fcur, ycur, KernelFunction="linear");

    % 在獨立場景上評估
    [bb, ~, ~] = ch16_slidingWindow(sceneEval, mdl, patchSize, ...
        Stride=STRIDE, CellSize=cellSize);
    [precCurve(k), recCurve(k)] = ch16_evalDetections(bb, gtEval);
end

fprintf("\n%-12s %14s %14s %14s\n", "每類樣本數", "patch準確率", "precision", "recall");
for k = 1:numel(nPerList)
    fprintf("%-12d %14.4f %13.1f%% %13.1f%%" + "\n", nPerList(k), ...
        patchAcc(k), precCurve(k), recCurve(k));
end

clear restoreW2

figure
yyaxis left
plot(nPerList, precCurve, "o-", LineWidth=1.8); ylabel("precision (%)")
yyaxis right
plot(nPerList, recCurve, "s--", LineWidth=1.8); ylabel("recall (%)")
xlabel("每類訓練樣本數"); title("HOG+SVM 的資料量曲線（在獨立場景上評估）")
grid on; set(gca, XScale="log")

% 飽和點。**先上升過，才談得上飽和**——
% 第一版我只寫 find(abs(diff(precCurve)) < 2)，
% 結果曲線是 0,0,0,0,66.7，它回報「每類 5 個就飽和了」。
% 那是把「還沒開始上升」誤判成「已經不再上升」。
[pkPrec, iBest] = max(precCurve);
if pkPrec == 0
    fprintf("\n在整個測試範圍內 precision 都是 0——連起點都沒到，談不上飽和。\n");
elseif iBest == numel(nPerList)
    fprintf("\n**最好的結果出現在掃描範圍的邊緣：每類 %d 個、precision %.1f%%。**\n", ...
        nPerList(iBest), pkPrec);
    fprintf("**這代表還沒掃到飽和點——不能說它飽和了，只能說掃得不夠遠。**\n");
else
    d = diff(precCurve(iBest:end));
    fprintf("\n飽和點約在每類 %d 個樣本（之後 precision 變化 %.1f 個百分點）\n", ...
        nPerList(iBest), max(abs(d)));
end

fprintf("\npatch 準確率全程 %.4f–%.4f，而 precision 從 %.1f%% 走到 %.1f%%。\n", ...
    min(patchAcc), max(patchAcc), precCurve(1), precCurve(end));
%[text] ## 量到的結果
%[text:table]
%[text] | 每類樣本數 | patch 準確率 | precision | recall |
%[text] | --- | --- | --- | --- |
%[text] | 5 | **1.0000** | 0.0% | 0.0% |
%[text] | 20 | **1.0000** | 0.0% | 0.0% |
%[text] | 50 | **1.0000** | 0.0% | 0.0% |
%[text] | 100 | **1.0000** | 0.0% | 0.0% |
%[text] | 300 | **1.0000** | **66.7%** | **50.0%** |
%[text:table]
%[text] **patch 準確率從每類 5 個樣本就已經是 1.0000，一路到 300 都沒變。**
%[text] 而偵測器的 precision 在同一個區間裡從 0% 走到 66.7%。
%[text] > **這是主教材第 6 節那件事的第二次現身。**
%[text] > 主教材用「100% 的 patch 準確率 → 0.8% 的偵測器 precision」
%[text] > 說明兩者不是同一回事。這條曲線更狠：
%[text] > **patch 準確率完全飽和的區間裡，偵測器還在大幅進步。**
%[text] > 若你只看 patch 準確率來決定要不要再標資料，
%[text] > 你會在每類 5 個樣本的時候就收工。
%[text] **第 5 小題：飽和點在哪裡？**
%[text] **在測試範圍內找不到。** 最好的結果出現在掃描的**邊緣**
%[text] （每類 300 個），所以正確的說法是
%[text] 「還沒掃到飽和點」，不是「它飽和了」。
%[text] > 這與第 14 章詞彙量掃描是同一個教訓：
%[text] > **最佳值落在範圍邊緣時，代表範圍不夠大，不代表找到了答案。**
%[text] 話說回來，加分題原本想問的事仍然成立，只是得換個講法。
%[text] 若曲線在某處飽和，那**多給它十倍的資料也不會更好**，
%[text] 因為瓶頸不在資料量，在**特徵的表達能力**：
%[text] HOG 是固定的、手工設計的，它能表達的東西有上限。
%[text] 資料再多也只是把同一個特徵空間裡的決策邊界畫得更精確一點。
%[text] > **這正是深度學習的優勢所在，而且常被誤述。**
%[text] > 「深度學習需要更多資料」是對的，但更關鍵的是
%[text] > **它「能用得上」更多資料**——
%[text] > 它的容量足夠大，所以資料增加時效能還會繼續上升。
%[text] 這裡量到的 300 個樣本、precision 66.7%、recall 50.0%，
%[text] 離堪用還很遠——**而且那是在一個只有三種形狀、
%[text] 背景完全乾淨的合成場景上。**
%[text] 真實場景會更差。
%[text] 這也解釋了為什麼在**資料真的很少**（幾十張）的情況下，
%[text] 傳統方法仍然是合理選擇——那個區間兩者差不多，
%[text] 而傳統方法不需要 GPU、訓練幾秒鐘、而且好診斷。
%[text] 第 19 章會在同一個任務上訓練深度偵測器，直接對照這條曲線。

% ========================================================================
function X = makeBackgroundPatches(n, sz, seed)
%MAKEBACKGROUNDPATCHES 產生三種「背景」patch：純背景、半個形狀、兩形狀邊緣。
%
%   這是解答 1 的核心：**事先猜**模型會在哪裡犯錯。
%   與硬負樣本挖掘（事後找模型真正的誤判）形成對照。
rng(seed);
X = zeros(sz(1), sz(2), n);
[xx, yy] = meshgrid(1:sz(2), 1:sz(1));

for k = 1:n
    P = 0.9*ones(sz);
    kind = mod(k, 3);
    switch kind
        case 0
            % 純背景：什麼都沒有
        case 1
            % 只框到一半的形狀：圓心推到邊界外
            cx = sz(2)/2 + sz(2)*0.55*sign(randn);
            cy = sz(1)/2 + 4*randn;
            r = 0.32*min(sz);
            P((xx-cx).^2 + (yy-cy).^2 < r^2) = 0.15;
        case 2
            % 兩個形狀的邊緣同時出現在框裡
            r = 0.28*min(sz);
            P((xx-(-2)).^2 + (yy-sz(1)/2).^2 < r^2) = 0.15;
            P(abs(xx-(sz(2)+2)) < r & abs(yy-sz(1)/2) < r) = 0.15;
    end
    P = imgaussfilt(P, 0.6) + 0.02*randn(sz);
    X(:,:,k) = min(max(P, 0), 1);
end
end

% ========================================================================
function m = medianOrNaN(bb)
if isempty(bb), m = NaN; else, m = median(bb(:,3)); end
end

% ========================================================================
function [boxes, nWin] = detectWithRegions(I, model, winSz, cellSz)
%DETECTWITHREGIONS 手段 1：先找候選區域，只在候選附近跑分類器。
%
%   用二值化 + regionprops 找出所有暗色團塊的質心，
%   只在質心附近取視窗。跳過所有空白區域。
%
%   **風險**：候選產生器漏掉的目標就完全找不到——
%   整條流程的 recall 上限由它決定。
% 場景的背景是 0.9、物件是 0.15，所以一個全域門檻就夠了。
% **不要用 imbinarize(...,"adaptive")**——背景幾乎均勻時，
% 自適應門檻會把雜訊放大成滿畫面的碎塊，候選區域完全不可用
% （我第一次就是這樣量到 recall 0%）。
bw = im2double(I) < 0.5;
bw = bwareaopen(bw, 50);
st = regionprops("table", bw, "Centroid", "Area");

boxes = zeros(0,4); scores = []; nWin = 0;
half = floor(winSz/2);

for k = 1:height(st)
    c = round(st.Centroid(k,:));
    % 在質心附近取幾個偏移的視窗（候選中心不一定精確）
    for dr = [-4 0 4]
        for dc = [-4 0 4]
            r0 = c(2) - half(1) + dr;
            c0 = c(1) - half(2) + dc;
            if r0 < 1 || c0 < 1 || ...
               r0+winSz(1)-1 > size(I,1) || c0+winSz(2)-1 > size(I,2)
                continue
            end
            nWin = nWin + 1;
            f = extractHOGFeatures(I(r0:r0+winSz(1)-1, c0:c0+winSz(2)-1), ...
                CellSize=cellSz);
            [lab, sco] = predict(model, f);
            if lab == "circle"
                boxes(end+1,:) = [c0, r0, winSz(2), winSz(1)];
                scores(end+1,1) = max(sco);
            end
        end
    end
end
if ~isempty(boxes)
    [boxes, ~] = selectStrongestBbox(boxes, scores, OverlapThreshold=0.3);
end
end

% ========================================================================
function [boxes, nWin] = detectWithEarlyReject(I, model, winSz, cellSz, stride, stdThresh)
%DETECTWITHEARLYREJECT 手段 2：用 patch 標準差提早拒絕空白視窗。
%
%   標準差是**極便宜**的判斷（一次 std 呼叫），
%   而 HOG + SVM 貴得多。空白視窗的標準差接近 0，
%   所以可以用一個很保守的門檻擋掉它們。
%
%   **這就是 cascade 的核心想法**：用一連串越來越貴的判斷，
%   讓便宜的先擋掉大部分候選。
%
%   注意 nWin 回傳的是**實際算過 HOG 的視窗數**，
%   不是掃過的視窗數——那才是成本所在。
I = im2double(I);
boxes = zeros(0,4); scores = []; nWin = 0;

for r = 1:stride:(size(I,1)-winSz(1)+1)
    for c = 1:stride:(size(I,2)-winSz(2)+1)
        patch = I(r:r+winSz(1)-1, c:c+winSz(2)-1);
        if std(patch(:)) < stdThresh
            continue                    % 幾乎是空白，跳過
        end
        nWin = nWin + 1;
        f = extractHOGFeatures(patch, CellSize=cellSz);
        [lab, sco] = predict(model, f);
        if lab == "circle"
            boxes(end+1,:) = [c, r, winSz(2), winSz(1)];
            scores(end+1,1) = max(sco);
        end
    end
end
if ~isempty(boxes)
    [boxes, ~] = selectStrongestBbox(boxes, scores, OverlapThreshold=0.3);
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
