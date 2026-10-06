%[text] # 第 18 章　練習解答
%[text] 影像分類與遷移學習
assert(exist("ch18_transferSVM","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

vd = fullfile(toolboxdir("vision"), "visiondata");
digitDir = fullfile(matlabroot, "toolbox", "nnet", "nndemos", ...
    "nndatasets", "DigitDataset");
imdsDigits = imageDatastore(digitDir, IncludeSubfolders=true, ...
    LabelSource="foldernames");
net = imagePretrainedNetwork("resnet18");

% 重複次數：完整執行用 5，快速模式用 3
if ipcvFast()
    NREP = 3;
    disp("（快速模式：重複次數降為 3。）")
else
    NREP = 5;
end
%%
%[text] # 解答 1：領域距離——用公平的方式比
%[text] 先建自然照片的二分類任務（車 vs 停止標誌，各 41 張）。
carFiles = string(fullfile(vd, "vehicles", ...
    {dir(fullfile(vd,"vehicles","*.jpg")).name})).';
signFiles = string(fullfile(vd, "stopSignImages", ...
    {dir(fullfile(vd,"stopSignImages","*.jpg")).name})).';
nPer = min(numel(carFiles), numel(signFiles));
rng(0);
carFiles  = carFiles(randperm(numel(carFiles), nPer));
signFiles = signFiles(randperm(numel(signFiles), nPer));

filesNat  = [carFiles; signFiles];
labelsNat = categorical([repmat("car", nPer, 1); repmat("stopSign", nPer, 1)]);
imdsNat = imageDatastore(filesNat);
imdsNat.Labels = labelsNat;
fprintf("\n自然照片任務：%d 類、每類 %d 張、共 %d 張\n", ...
    numel(categories(labelsNat)), nPer, numel(filesNat));

[natTr, natTe] = splitEachLabel(imdsNat, 0.67, "randomized");
ws = warning("off", "ch18_transferSVM:weakClass");
[~, rNat] = ch18_transferSVM(net, natTr, natTe, "pool5");
warning(ws);
fprintf("自然照片（2 類）準確率 = %.4f（測試 %d 張）\n", ...
    rNat.Accuracy, rNat.NumTest);
%%
%[text] ## 兩種公平的比法
%[text] **比法一：把數字也限制成兩類**（隨機基準一致）。
% 挑兩個視覺上最不像的數字，避免挑到最難的一對
rng(0);
keep2 = ismember(imdsDigits.Labels, categorical(["0" "1"]));
imds2 = subset(imdsDigits, find(keep2));
imds2 = splitEachLabel(imds2, nPer, "randomized");   % 每類和自然任務一樣多
[d2Tr, d2Te] = splitEachLabel(imds2, 0.67, "randomized");
ws = warning("off", "ch18_transferSVM:weakClass");
[~, rD2] = ch18_transferSVM(net, d2Tr, d2Te, "pool5");
warning(ws);

%[text] **比法二：超越隨機的幅度** $(acc - chance)/(1 - chance)$。
[~, rD10] = ch18_transferSVM(net, ...
    subsetSplit(imdsDigits, 60, 0.67, 1), subsetSplit(imdsDigits, 60, 0.67, 2), ...
    "pool5");

tasks   = ["自然照片 2 類"; "手寫數字 2 類"; "手寫數字 10 類"];
accs    = [rNat.Accuracy; rD2.Accuracy; rD10.Accuracy];
chances = [1/2; 1/2; 1/10];
nTests  = [rNat.NumTest; rD2.NumTest; rD10.NumTest];
aboveCh = (accs - chances) ./ (1 - chances);
ses     = sqrt(accs.*(1-accs)./nTests);

fprintf("\n%-16s %8s %8s %12s %10s\n", "任務", "準確率", "隨機基準", ...
    "超越隨機幅度", "±95%CI");
for k = 1:numel(tasks)
    fprintf("%-16s %8.4f %8.2f %12.4f %9.1f%%" + "\n", tasks(k), accs(k), ...
        chances(k), aboveCh(k), 100*1.96*ses(k));
end
%[text] **第 5 小題：支持還是反駁？——都不是，這個實驗答不了。**
%[text] 實測（某次執行）：
%[text:table]
%[text] | 任務 | 準確率 | 隨機基準 | 超越隨機幅度 | ±95%CI |
%[text] | --- | --- | --- | --- | --- |
%[text] | 自然照片 2 類 | **1.0000** | 0.50 | 1.0000 | 0.0% |
%[text] | 手寫數字 2 類 | **1.0000** | 0.50 | 1.0000 | 0.0% |
%[text] | 手寫數字 10 類 | 0.8100 | 0.10 | 0.7889 | 5.4% |
%[text:table]
%[text] **兩個二分類任務都拿到滿分——這叫天花板效應（ceiling effect）。**
%[text] 兩個 1.0000 之間沒有差異可言，所以
%[text] **這個實驗無法比較「自然照片」與「手寫數字」的領域距離。**
%[text] 注意「±95%CI = 0.0%」也是假的：
%[text] 二項標準誤公式在 $p=1$ 時退化成 0，
%[text] 但那不代表我們很確定——只代表 28 張測試影像
%[text] **不足以看到任何錯誤**。真正的信賴上界要用
%[text] Wilson 或 Clopper–Pearson 區間，$p=1$、$n=28$ 時
%[text] 下界大約是 0.88，**離 1.0 差很遠**。
%[text] > **要修好這個實驗，得讓任務難到不會撞天花板**：
%[text] > 加入更多類別、加入更難的影像、或減少訓練樣本
%[text] > 直到準確率落在 0.6–0.9 的可測區間。
%[text] > **在天花板上比較兩個方法，永遠比不出東西。**
%[text] 而就算修好了，還有一個更根本的問題（見下面第 ③ 點）。
%[text] > **這一題最重要的收穫是「怎麼比」而不是「誰比較高」。**
%[text] 三個陷阱都在這一題裡：
%[text] **① 類別數不同時，準確率不可直接比。**
%[text] 二分類的 0.75 和十分類的 0.75 是完全不同的成就。
%[text] **② 樣本數不同時，信賴區間不同。**
%[text] 自然照片任務只有 28 張測試影像，
%[text] 它的 95% 信賴區間比十分類數字（200 張）**寬得多**——
%[text] 看上表的最後一欄。**小資料集的高分最不可信。**
%[text] **③ 「領域距離」不是唯一的變數。**
%[text] 車與停止標誌**本身就比手寫數字好分**（顏色、形狀、背景全都不同），
%[text] 而數字彼此高度相似。所以即使自然照片任務贏，
%[text] 也**不能全部歸因於領域距離**——任務難度也變了。
%[text] > **要乾淨地驗證「領域距離」，得固定任務難度只改領域**，
%[text] > 例如拿同一批影像做風格轉換。這一題的設計做不到那件事，
%[text] > 所以它的結論只能是「與領域距離的說法一致」，
%[text] > **不能說「證明了」**。
%%
%[text] # 解答 2：把骨幹比較做對——配對比較
%[text] 主教材 §6 的排名站不住。這裡用**同一批切分**評估所有骨幹，
%[text] 讓切分造成的變異可以被抵消。
backbones = ["resnet18" "mobilenetv2" "resnet50" "darknet19"];
accMat = nan(NREP, numel(backbones));

for s = 1:NREP
    rng(100 + s);
    subS = splitEachLabel(imdsDigits, 60, "randomized");
    [trS, teS] = splitEachLabel(subS, 0.67, "randomized");
    for b = 1:numel(backbones)
        try
            nb = imagePretrainedNetwork(backbones(b));
            layer = lastPoolName(nb);
            ws = warning("off", "ch18_transferSVM:weakClass");
            [~, rb] = ch18_transferSVM(nb, trS, teS, layer);
            warning(ws);
            accMat(s, b) = rb.Accuracy;
            clear nb          % 第 17 章 §10.1：用完一定要釋放
        catch
            % 缺支援包的骨幹跳過
        end
    end
    fprintf("  切分 %d 完成\n", s);
end

fprintf("\n%-14s %10s %10s %10s\n", "骨幹", "平均", "標準差", "全距");
for b = 1:numel(backbones)
    a = accMat(:,b); a = a(~isnan(a));
    if isempty(a), continue, end
    fprintf("%-14s %10.4f %10.4f %10.4f\n", backbones(b), ...
        mean(a), std(a), max(a)-min(a));
end
%%
%[text] ## 配對比較：為什麼它更有力
%[text] 每一個切分上，所有骨幹面對**完全一樣的測試影像**。
%[text] 所以「切分好壞」這個變異在**配對差值**裡會抵消。
ref = 1;      % 以 resnet18 為基準
fprintf("\n配對差值（相對於 %s，每列一個切分）：\n", backbones(ref));
fprintf("%-10s", "切分");
for b = 1:numel(backbones)
    if b == ref, continue, end
    fprintf("%16s", backbones(b));
end
fprintf("\n");
for s = 1:NREP
    fprintf("%-10d", s);
    for b = 1:numel(backbones)
        if b == ref, continue, end
        fprintf("%16.4f", accMat(s,b) - accMat(s,ref));
    end
    fprintf("\n");
end

% **臨界值要依自由度算，不能用一個記憶中的數字。**
% 我第一版寫「大約超過 2.5 就值得相信」——那是大樣本的直覺，
% 而這裡只有 3 個切分（自由度 2），臨界值其實是 4.30。
fprintf("\n%-26s %10s %10s %8s %8s %8s\n", ...
    "比較", "平均差值", "差值SD", "t", "臨界t", "p");
for b = 1:numel(backbones)
    if b == ref, continue, end
    d = accMat(:,b) - accMat(:,ref);
    d = d(~isnan(d));
    if numel(d) < 2, continue, end
    df = numel(d) - 1;
    seD = std(d)/sqrt(numel(d));
    tStat = mean(d)/max(seD, eps);
    tCrit = tinv(0.975, df);
    pVal = 2*(1 - tcdf(abs(tStat), df));
    fprintf("%-26s %10.4f %10.4f %8.2f %8.2f %8.3f %s\n", ...
        backbones(b) + " - " + backbones(ref), mean(d), std(d), ...
        tStat, tCrit, pVal, string(pVal < 0.05));
end
fprintf("（自由度 = 切分數 - 1 = %d）\n", NREP-1);
%[text] ## 量到的結果（3 個切分，快速模式）
%[text] 各自的平均：
%[text:table]
%[text] | 骨幹 | 平均 | 標準差 | 全距 |
%[text] | --- | --- | --- | --- |
%[text] | `resnet18` | 0.8283 | 0.0076 | 0.0150 |
%[text] | **`mobilenetv2`** | **0.8950** | 0.0350 | 0.0700 |
%[text] | `resnet50` | 0.8400 | 0.0361 | 0.0700 |
%[text] | `darknet19` | 0.8467 | 0.0104 | 0.0200 |
%[text:table]
%[text] 配對差值（相對於 `resnet18`，3 個切分 → 自由度 2）：
%[text:table]
%[text] | 比較 | 平均差值 | 差值 SD | t | 臨界 t | p |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | `mobilenetv2` − `resnet18` | **+0.0667** | 0.0382 | **3.02** | 4.30 | 0.094 |
%[text] | `resnet50` − `resnet18` | +0.0117 | 0.0333 | 0.61 | 4.30 | 0.60 |
%[text] | `darknet19` − `resnet18` | +0.0183 | 0.0161 | 1.98 | 4.30 | 0.19 |
%[text:table]
%[text] **配對比較把訊號拉出來了，但 3 個切分還是不夠。**
%[text] `mobilenetv2` 的 t = 3.02 看起來很大，
%[text] **但自由度只有 2，臨界值是 4.30**，所以 p ≈ 0.094——
%[text] **還是不能宣稱有差異。**
%[text] > **我第一版在這裡寫錯了。** 我憑印象寫「t 超過 2.5 就值得相信」，
%[text] > 那是**大樣本**的直覺。自由度 2 的 t 分布尾巴厚得多，
%[text] > 臨界值是 4.30；自由度 4（5 個切分）才降到 2.78。
%[text] > **臨界值要用 `tinv(0.975, df)` 算，不要憑記憶。**
%[text] 不過方向是有意義的：配對之後
%[text] `mobilenetv2` − `resnet18` 的差值標準差是 0.0382，
%[text] 而未配對時各自的標準差是 0.0076 與 0.0350；
%[text] **配對讓我們能看見一個 6.7 個百分點的效應**，
%[text] 而主教材跑一次只能看到雜訊。
%[text] > **同樣的資料，換一個比較方法，
%[text] > 從「完全分不出來」變成「差一點就能下結論」。**
%[text] > 差別只在於有沒有讓所有模型面對同一批測試影像。
%[text] 完整執行（`NREP=5`，自由度 4，臨界值 2.78）會更有機會達標；
%[text] 若還是不夠，就照第 4、5 小題的算法加切分數。
%[text] **第 3 小題：為什麼配對比較更有力**
%[text] 不配對時，兩個骨幹各自的平均值都帶著**切分變異**
%[text] （§6.1 量到標準差 0.0344），那個變異進到兩者的比較裡。
%[text] 配對之後，每個切分上的差值只剩下**骨幹造成的差異**加上
%[text] GPU 非決定性（0.0203）——切分那一項被減掉了。
%[text] 看上表的 `t` 欄，並且**一定要和同一列的「臨界 t」比**：
%[text:table]
%[text] | 切分數 | 自由度 | 95% 臨界 t |
%[text] | --- | --- | --- |
%[text] | 3 | 2 | **4.30** |
%[text] | 5 | 4 | 2.78 |
%[text] | 10 | 9 | 2.26 |
%[text] | 30 | 29 | 2.05 |
%[text:table]
%[text] **小樣本的臨界值高得驚人**，這是最容易被忽略的地方。
%[text] **第 4、5 小題：現在能分辨了嗎？**
%[text] 以 3 個切分而言：**還不能**（最大的 t 是 3.02，臨界值 4.30）。
%[text] 要再進步需要：
%[text] 1. **更多切分**（降低差值的標準誤，成本線性）
%[text] 2. **更大的測試集**（降低每次評估的雜訊，效果更直接）
%[text] 要可靠分辨 2 個百分點：差值的標準誤要小於約 0.01／2 ≈ 0.005。
%[text] 配對差值的標準差約 0.02–0.03，所以需要
%[text] $n \ge (0.025/0.005)^2 = 25$ 個切分。
%[text] > **25 次評估 × 4 個骨幹 = 100 次**，每次約 8 秒——約 13 分鐘。
%[text] > **這才是「比較四個骨幹」的真實成本。**
%[text] > 主教材跑一次就下結論，花了 30 秒，得到一個錯的答案。
%%
%[text] # 解答 3：資料量曲線（深度特徵版）
%[text] 測試集固定，只改訓練樣本數。每個點重複 NREP 次。
nPerList = [5 10 20 40 100 200];
if ipcvFast()
    nPerList = [5 20 100];
    disp("（快速模式：只掃 3 個點。）")
end

% 固定的測試集（每類 40 張，全程不動）
rng(7);
[dsPool, dsTestFixed] = splitEachLabel(imdsDigits, 400, "randomized");
dsTestFixed = splitEachLabel(dsTestFixed, 40, "randomized");

mu = zeros(numel(nPerList),1);
sd = zeros(numel(nPerList),1);
for k = 1:numel(nPerList)
    a = zeros(NREP,1);
    for r = 1:NREP
        rng(1000*k + r);
        trK = splitEachLabel(dsPool, nPerList(k), "randomized");
        ws = warning("off", "ch18_transferSVM:weakClass");
        [~, rr] = ch18_transferSVM(net, trK, dsTestFixed, "pool5");
        warning(ws);
        a(r) = rr.Accuracy;
    end
    mu(k) = mean(a); sd(k) = std(a);
    fprintf("  每類 %3d 張：%.4f ± %.4f\n", nPerList(k), mu(k), sd(k));
end

figure
errorbar(nPerList, mu, sd, "o-", LineWidth=1.8, MarkerSize=7)
set(gca, XScale="log"); grid on
xlabel("每類訓練樣本數"); ylabel("測試準確率")
title("深度特徵（resnet18 pool5）的資料量曲線")
%[text] 量到的結果（快速模式 3 個點、每點重複 3 次）：
%[text:table]
%[text] | 每類訓練張數 | 準確率 | 標準差 |
%[text] | --- | --- | --- |
%[text] | 5 | 0.5917 | 0.0406 |
%[text] | 20 | 0.8125 | **0.0025** |
%[text] | 100 | **0.9258** | 0.0113 |
%[text:table]
%[text] **從 5 張到 20 張，準確率跳了 22 個百分點；
%[text] 從 20 張到 100 張，還有 11 個百分點。**
%[text] 兩段的提升都遠大於誤差棒，所以**在 100 張這裡還沒飽和**。
%[text] 注意「每類 5 張」那一點的標準差（0.0406）
%[text] 比「每類 20 張」（0.0025）大 16 倍——
%[text] **訓練樣本少的時候，結果也最不穩定。**
%[text] 這很直觀但常被忽略：小資料的實驗**必須**重複多次，
%[text] 而那正是最容易被省略的時候。
%[text] **第 5 小題：飽和點與瓶頸**
%[text] 看曲線與誤差棒。判斷飽和的標準是
%[text] **「下一個點的提升小於誤差棒」**——
%[text] 而不是「看起來平了」。
%[text] 對照第 16 章加分題的 HOG+SVM：那條曲線在每類 300 張時
%[text] precision 才 66.7%，**飽和點在掃描範圍之外**。
%[text] 深度特徵在每類幾十張就接近它的上限。
%[text] **飽和之後瓶頸在哪裡？在骨幹。**
%[text] 策略一凍結了骨幹，所以它的天花板是
%[text] **「ImageNet 的特徵能不能表達手寫數字的差異」**。
%[text] 資料再多也不會改變那件事——
%[text] 那要靠策略二／三去**改變特徵本身**。
%[text] > **這是一個很實際的判斷點。**
%[text] > 曲線飽和 + 準確率還不夠 → **不要再標資料了，去微調。**
%[text] > 曲線還在爬 → **先標更多資料，那比微調便宜也安全。**
%%
%[text] # 解答 4：用可解釋性找出模型為什麼錯
%[text] 先找出最常被混淆的一對類別。
rng(0);
[trE, teE] = splitEachLabel(splitEachLabel(imdsDigits, 60, "randomized"), ...
    0.67, "randomized");
ws = warning("off", "ch18_transferSVM:weakClass");
[mdlE, rE] = ch18_transferSVM(net, trE, teE, "pool5");
warning(ws);

C = rE.ConfusionMatrix;
Coff = C - diag(diag(C));          % 只看非對角線
[~, idx] = max(Coff(:));
[iTrue, iPred] = ind2sub(size(Coff), idx);
cls = rE.ClassNames;
fprintf("\n整體準確率 %.4f\n", rE.Accuracy);
fprintf("最常見的混淆：真實「%s」被判成「%s」，共 %d 次\n", ...
    cls(iTrue), cls(iPred), Coff(iTrue, iPred));
%%
%[text] ## 一個必須先講清楚的事：你在解釋哪個模型？
%[text] **這是這一題真正的考點。**
%[text] `ch18_explain`（`gradCAM` 等）解釋的是**網路自己的分類頭**，
%[text] 也就是 ImageNet 的 1000 類輸出。
%[text] 但我們的預測是 **SVM 接在 `pool5` 特徵上**做的。
%[text] **兩者是不同的模型。**
%[text] 所以直接對錯分的數字影像跑 `gradCAM`，
%[text] 得到的是「ImageNet 分類頭覺得哪裡像某個 ImageNet 類別」，
%[text] 而**不是** 「我的 SVM 為什麼把 7 判成 1」。
%[text] 要解釋 SVM，可以用**遮擋敏感度的手作版**：
%[text] 逐塊遮住輸入，看 SVM 的決策分數掉多少。
%[text] 這是黑箱方法，所以不在意下游是 SVM 還是 softmax。
% 找一張被錯分的影像與一張被正確分類的影像
FteE = ch18_extractFeatures(net, teE, "pool5");
predE = predict(mdlE, FteE);
trueE = teE.Labels;
isWrong = predE ~= trueE;
iBad = find(isWrong & trueE == cls(iTrue), 1);
iGood = find(~isWrong & trueE == cls(iTrue), 1);

if isempty(iBad) || isempty(iGood)
    disp("這次切分找不到同時有對有錯的樣本，略過視覺化。")
else
    files = teE.Files;
    Ibad  = imread(files{iBad});
    Igood = imread(files{iGood});
    mapBad  = svmOcclusion(net, mdlE, Ibad,  cls(iTrue));
    mapGood = svmOcclusion(net, mdlE, Igood, cls(iTrue));

    figure
    tiledlayout(2,2, TileSpacing="compact")
    nexttile; imshow(Ibad, InitialMagnification="fit")
    title(sprintf("錯分：真實 %s -> 判成 %s", cls(iTrue), string(predE(iBad))))
    nexttile; imagesc(mapBad); axis image off; colorbar
    title("SVM 遮擋敏感度（錯分）")
    nexttile; imshow(Igood, InitialMagnification="fit")
    title(sprintf("正確：%s", cls(iTrue)))
    nexttile; imagesc(mapGood); axis image off; colorbar
    title("SVM 遮擋敏感度（正確）")

    fprintf("\n錯分影像的敏感度：最大 %.4f、平均 %.4f\n", ...
        max(mapBad(:)), mean(mapBad(:)));
    fprintf("正確影像的敏感度：最大 %.4f、平均 %.4f\n", ...
        max(mapGood(:)), mean(mapGood(:)));
end
%[text] **第 5 小題：這個分析能證明因果嗎？**
%[text] **不能。** 遮擋敏感度顯示的是
%[text] 「遮住這一塊，分數會掉多少」——那是**輸出對輸入的敏感度**，
%[text] 是一種相關性。它不能排除：
%[text] - 遮擋本身製造了**分布外的輸入**（灰色方塊在訓練資料裡不存在），
%[text]   所以分數下降可能是因為「這張圖變得很奇怪」，
%[text]   而不是因為「那塊區域重要」
%[text] - 多個區域**冗餘**編碼同一個資訊時，單獨遮任一塊都不會掉分，
%[text]   於是重要的區域看起來不重要
%[text] **更接近因果的設計**：
%[text] 1. **反事實編輯**：把筆劃做最小的修改，讓預測翻面，
%[text]    看需要改哪裡、改多少
%[text] 2. **用資料集層級的介入**：系統性移除某個特徵
%[text]    （例如把所有 7 的橫槓去掉）重新訓練，看效能怎麼變
%[text] 3. **遮擋要用分布內的內容填補**（例如用同類別其他影像的對應區塊），
%[text]    而不是灰色方塊
%[text] > **可解釋性圖是產生假設的工具，不是驗證假設的工具。**
%%
%[text] # 解答 5：把微調真的跑起來
%[text] > **本課程的教材預設不執行訓練**（主教材 §8 說明了原因），
%[text] > 所以這一題的解答提供**完整可執行的程式碼**與**判讀方式**，
%[text] > 但預設不跑。把 `DO_TRAIN` 改成 `true` 就會真的訓練。
DO_TRAIN = false;     % ← 改成 true 才會訓練

rng(0);
sub20 = splitEachLabel(imdsDigits, 40, "randomized");
[ftTr, ftVal] = splitEachLabel(sub20, 0.5, "randomized");   % 每類 20／20
prep = @(ds) transform(ds, @(I) {imresize(repmat(I,1,1,3), [224 224])});

fprintf("\n微調資料：訓練 %d 張、驗證 %d 張\n", ...
    numel(ftTr.Files), numel(ftVal.Files));

% --- 策略一的基準（這個一定會跑，很快）---
ws = warning("off", "ch18_transferSVM:weakClass");
tS1 = tic;
[~, rS1] = ch18_transferSVM(net, ftTr, ftVal, "pool5");
secS1 = toc(tS1);
warning(ws);
fprintf("策略一：準確率 %.4f、耗時 %.1f 秒\n", rS1.Accuracy, secS1);

% --- 策略二：正常學習率 ---
[netS2, infoS2] = ch18_fineTune("resnet18", prep(ftTr), prep(ftVal), 10, ...
    DoTrain=DO_TRAIN, FreezeBackbone=true, MaxEpochs=3, ...
    MiniBatchSize=8, InitialLearnRate=1e-4);

% --- 第 5 小題：故意把學習率調大 100 倍 ---
[netBad, infoBad] = ch18_fineTune("resnet18", prep(ftTr), prep(ftVal), 10, ...
    DoTrain=DO_TRAIN, FreezeBackbone=true, MaxEpochs=3, ...
    MiniBatchSize=8, InitialLearnRate=1e-2);

if DO_TRAIN
    accS2  = evalNet(netS2,  prep(ftVal), ftVal.Labels);
    accBad = evalNet(netBad, prep(ftVal), ftVal.Labels);
    fprintf("\n%-26s %10s %10s\n", "做法", "準確率", "訓練秒數");
    fprintf("%-26s %10.4f %10.1f\n", "策略一（特徵+SVM）", rS1.Accuracy, secS1);
    fprintf("%-26s %10.4f %10.1f\n", "策略二 lr=1e-4", accS2, infoS2.SecTrain);
    fprintf("%-26s %10.4f %10.1f\n", "策略二 lr=1e-2（故意調壞）", ...
        accBad, infoBad.SecTrain);
else
    fprintf("\n（DO_TRAIN=false，未訓練。上面兩組設定已組好可直接用。）\n");
end
clear netS2 netBad
%[text] **第 5、6 小題：你應該會看到什麼**
%[text] `lr=1e-2`（大 100 倍）的典型症狀，按出現順序：
%[text] 1. **前幾個 iteration 的 loss 就衝高**，而不是下降
%[text] 2. 驗證準確率停在**接近隨機**（十類 → 約 0.10）
%[text] 3. 有時直接變成 `NaN`
%[text] 原因是預訓練權重已經在一個好的位置，
%[text] 大步長會把它們**直接推出那個盆地**。
%[text] 這裡凍結了骨幹，所以被破壞的是分類頭；
%[text] 若連骨幹一起解凍（策略三），破壞會更徹底。
%[text] **第 6 小題：這個資料量下策略二值得嗎？**
%[text] 每類 20 張的情況下，**大概不值得**，理由有三個：
%[text:table]
%[text] | | 策略一 | 策略二 |
%[text] | --- | --- | --- |
%[text] | 耗時 | 數秒 | 數分鐘 |
%[text] | 需要 GPU | 不用 | 實務上要 |
%[text] | 會不會發散 | **不會**（凸問題） | 會（要調學習率） |
%[text] | 上限 | 骨幹的表達能力 | 可以突破骨幹 |
%[text:table]
%[text] 每類 20 張時，**策略二能多學到的東西很少**
%[text] （新分類頭的參數量已經比樣本數多了），
%[text] 但成本高了兩個數量級。
%[text] > **判斷準則在解答 3 的曲線裡**：
%[text] > 策略一的資料量曲線**還在爬** → 先去標更多資料；
%[text] > 曲線**已經飽和但準確率不夠** → 這時候才該微調。
%%
%[text] # 解答 6：特徵空間分得開不開——量化版
%[text] 先抽兩層的特徵。
rng(0);
[vTr, vTe] = splitEachLabel(splitEachLabel(imdsDigits, 40, "randomized"), ...
    0.5, "randomized");
Fshallow = ch18_extractFeatures(net, vTe, "res2b_relu");
Fdeep    = ch18_extractFeatures(net, vTe, "pool5");
yv = vTe.Labels;
fprintf("\n淺層 %s、深層 %s、樣本 %d\n", ...
    mat2str(size(Fshallow)), mat2str(size(Fdeep)), numel(yv));

%[text] **第 4 小題：在原始特徵空間算類內／類間距離比值。**
%[text] **不要在 2 維投影上算**——降維會扭曲距離。
rShallow = withinBetweenRatio(Fshallow, yv);
rDeep    = withinBetweenRatio(Fdeep, yv);
fprintf("\n%-14s %16s\n", "層", "類內/類間比值");
fprintf("%-14s %16.4f\n", "res2b_relu", rShallow);
fprintf("%-14s %16.4f\n", "pool5", rDeep);
fprintf("\n比值越小越好（類內緊、類間遠）。改善了 %.1f%%" + "\n", ...
    100*(rShallow - rDeep)/rShallow);
%%
%[text] ## 視覺化（只是輔助，結論靠上面的數字）
Z1 = pcaTo2(Fshallow);
Z2 = pcaTo2(Fdeep);
figure
tiledlayout(1,2, TileSpacing="compact")
nexttile; gscatter(Z1(:,1), Z1(:,2), yv); title(sprintf("res2b\\_relu（比值 %.3f）", rShallow))
legend(Location="eastoutside")
nexttile; gscatter(Z2(:,1), Z2(:,2), yv); title(sprintf("pool5（比值 %.3f）", rDeep))
legend(Location="eastoutside")
%[text] 量到的結果：
%[text:table]
%[text] | 層 | 類內／類間比值 |
%[text] | --- | --- |
%[text] | `res2b_relu`（主教材量到約 0.21 準確率） | 1.3277 |
%[text] | `pool5`（約 0.83 準確率） | **0.9055** |
%[text:table]
%[text] **比值改善 31.8%，而準確率從 0.21 跳到 0.83。**
%[text] 注意兩者**不成比例**：比值只改善三成，準確率卻翻了四倍。
%[text] 這正是下面要講的「比值不是準確率的代理」。
%[text] 另外，`res2b_relu` 的比值 **1.33 > 1** 意味著
%[text] **類內的平均距離比類間還大**——
%[text] 在那個特徵空間裡，同一個數字的兩張影像
%[text] 平均而言比不同數字的兩張還遠。難怪分類器做不了事。
%[text] **第 5 小題：比值和準確率的關係**
%[text] 比值越小 → 類別在特徵空間裡分得越開 → 線性分類器越容易切開
%[text] → 準確率越高。上面的數字和主教材 §5 的準確率排序一致。
%[text] **但這個關係不是單調保證的**，有兩個理由：
%[text] **① 比值是全域平均，準確率取決於最難的那幾對類別。**
%[text] 一對類別完全重疊、其他都分得很開，平均比值還是會很好看。
%[text] **② 比值用歐氏距離，SVM 用的是（可能加權的）超平面。**
%[text] 特徵維度的尺度不同時，歐氏距離的「開」和分類器看到的「開」不一樣。
%[text] > **所以這個比值是一個好用的診斷指標，不是準確率的代理。**
%[text] > 要知道準確率，還是得訓練一個分類器來量。
%%
%[text] # 加分題：策略一的隱藏假設
%[text] 策略一假設「骨幹特徵對我的類別是線性可分的」。**檢驗它。**
rng(0);
[bTr, bTe] = splitEachLabel(splitEachLabel(imdsDigits, 60, "randomized"), ...
    0.67, "randomized");
Ftr = ch18_extractFeatures(net, bTr, "pool5");
Fte = ch18_extractFeatures(net, bTe, "pool5");
ytr = bTr.Labels; yte = bTe.Labels;

names = ["線性 SVM"; "RBF 核 SVM"; "淺層神經網路"];
accs2 = zeros(3,1); secs2 = zeros(3,1);

t = tic; m1 = fitcecoc(Ftr, ytr, Learners="linear");
secs2(1) = toc(t); accs2(1) = mean(predict(m1, Fte) == yte);

t = tic;
tmpl = templateSVM(KernelFunction="rbf", KernelScale="auto", Standardize=true);
m2 = fitcecoc(Ftr, ytr, Learners=tmpl);
secs2(2) = toc(t); accs2(2) = mean(predict(m2, Fte) == yte);

t = tic; m3 = fitcnet(Ftr, ytr, LayerSizes=64, Verbose=0);
secs2(3) = toc(t); accs2(3) = mean(predict(m3, Fte) == yte);

fprintf("\n%-16s %10s %12s\n", "分類器", "準確率", "訓練秒數");
for k = 1:3
    fprintf("%-16s %10.4f %12.2f\n", names(k), accs2(k), secs2(k));
end
fprintf("\n最好 - 線性 = %+.4f 個（%.1f 個百分點）\n", ...
    max(accs2) - accs2(1), 100*(max(accs2) - accs2(1)));
%[text] 量到的結果：
%[text:table]
%[text] | 分類器 | 準確率 | 訓練秒數 |
%[text] | --- | --- | --- |
%[text] | 線性 SVM | 0.8100 | 0.55 |
%[text] | RBF 核 SVM | 0.8550 | 0.82 |
%[text] | 淺層神經網路（64 單元） | **0.8700** | 2.03 |
%[text:table]
%[text] **最好的比線性高 6.0 個百分點，訓練時間貴 3.7 倍（仍然只有 2 秒）。**
%[text] （R2026a 量到淺層網路 0.8650、差距 5.5 個百分點；線性與 RBF 兩版相同。）
%[text] **第 5 小題（一）：換更強的分類器能不能取代微調？**
%[text] 先看上面的差距，並用 §6.1 的標準判斷它是不是雜訊。
%[text] **6.0 個百分點只比雜訊的上緣略高一點**（主教材量到重跑的全距是
%[text] 2–5 個百分點），而且只量了一次，所以**這個結果是暗示，不是證據**。
%[text] 換個版本差距就從 5.5 變成 6.0，本身就說明了這個數字還在雜訊裡晃。
%[text] 要確認必須用解答 2 的配對比較重複多次。
%[text] 不過方向是合理的：非線性分類器更好，
%[text] 代表 `pool5` 的特徵**不是完全線性可分**的，
%[text] 所以「換分類器」確實能拿到一部分微調的好處，
%[text] 而且成本是**秒**，不是分鐘。
%[text] 若 RBF 或神經網路明顯更好，代表特徵**不是線性可分**的，
%[text] 那麼「換分類器」確實能拿到一部分微調的好處，
%[text] 而且**便宜得多**（幾秒 vs 幾分鐘）。
%[text] **但它有一個硬上限。**
%[text] **第 5 小題（二）：什麼時候必須微調？**
%[text] 換分類器只能改變「**怎麼切**特徵空間」；
%[text] 微調能改變「特徵空間**長什麼樣**」。
%[text] **當你需要的資訊根本沒被骨幹編碼進去時，任何分類器都救不回來。**
%[text] 三個具體的例子：
%[text:table]
%[text] | 情況 | 為什麼分類器救不了 |
%[text] | --- | --- |
%[text] | **極細微的紋理差異**（晶圓上的微裂紋） | ImageNet 骨幹在早期就把高頻細節池化掉了，資訊已經遺失 |
%[text] | **醫學影像的灰階窗位** | 骨幹的輸入正規化是為自然照片設計的，微弱的灰階差異被壓縮掉 |
%[text] | **需要極高空間精度的任務** | `pool5` 把 7×7 的空間資訊平均成一個向量，位置資訊整個消失 |
%[text:table]
%[text] **判準**：資訊遺失發生在**特徵抽取階段**時，必須微調
%[text] （或換一個領域相近的骨幹）；
%[text] 資訊還在、只是**排列方式不利於線性切割**時，換分類器就夠了。
%[text] > **怎麼分辨這兩種情況？**
%[text] > 用解答 6 的類內／類間比值。
%[text] > 若比值很差（類別在特徵空間裡整片重疊），
%[text] > 那是資訊遺失，換分類器沒用。
%[text] > 若比值不錯但線性分類器表現不佳，那是排列問題，換分類器有用。
%[text] 第 22 章（工業瑕疵檢測）會正面處理第一種情況。

% ========================================================================
function ds = subsetSplit(imds, nPerClass, frac, which)
%SUBSETSPLIT 取每類 nPerClass 張再切分，回傳第 which 份（1=訓練 2=測試）。
rng(0);
sub = splitEachLabel(imds, nPerClass, "randomized");
[a, b] = splitEachLabel(sub, frac, "randomized");
if which == 1, ds = a; else, ds = b; end
end

% ========================================================================
function layer = lastPoolName(net)
%LASTPOOLNAME 用層的類別找最後的全域池化層（不靠層名）。
cls = arrayfun(@(L) string(class(L)), net.Layers);
nm  = string({net.Layers.Name});
idx = find(contains(cls, "GlobalAveragePooling"), 1, "last");
if isempty(idx)
    idx = find(contains(cls, "AveragePooling2D"), 1, "last");
end
layer = nm(idx);
end

% ========================================================================
function map = svmOcclusion(net, mdl, I, targetClass)
%SVMOCCLUSION 手作的遮擋敏感度，解釋的是**SVM**而不是網路的分類頭。
%
%   逐塊遮住輸入，看 SVM 對 targetClass 的決策分數掉多少。
%   這是黑箱方法，所以下游是 SVM 還是 softmax 都適用。
%
%   **注意它的已知缺陷**：灰色方塊是分布外的輸入，
%   分數下降有一部分來自「這張圖變奇怪了」，不是「那塊區域重要」。
sz = size(I, [1 2]);
blk = max(4, round(min(sz)/8));
fillVal = cast(median(double(I(:))), class(I));

base = svmScore(net, mdl, I, targetClass);
map = zeros(sz);
for r = 1:blk:sz(1)
    for c = 1:blk:sz(2)
        J = I;
        r2 = min(r+blk-1, sz(1));
        c2 = min(c+blk-1, sz(2));
        J(r:r2, c:c2, :) = fillVal;
        s = svmScore(net, mdl, J, targetClass);
        map(r:r2, c:c2) = base - s;    % 掉得越多 = 越重要
    end
end
end

% ========================================================================
function s = svmScore(net, mdl, I, targetClass)
%SVMSCORE 取 SVM 對指定類別的決策分數。
%
%   **單張影像不要繞 datastore。** 我第一版用
%   `arrayDatastore(I, IterationDimension=4, OutputType="cell")`
%   再餵給 ch18_extractFeatures，結果 transform 收到的是 cell，
%   `imresize` 報「Invalid input syntax; input image missing from
%   argument list」——一個完全指不出真正原因的訊息。
%   單張影像直接呼叫網路最單純。
inputSize = net.Layers(1).InputSize;
J = I;
if size(J,3) == 1 && inputSize(3) == 3
    J = repmat(J, 1, 1, 3);
end
J = single(imresize(J, inputSize(1:2)));

A = predict(net, dlarray(J, "SSCB"), Outputs="pool5");
F = squeeze(mean(mean(extractdata(A), 1), 2)).';

[~, score] = predict(mdl, F);
cls = string(mdl.ClassNames);
s = score(cls == string(targetClass));
if isempty(s), s = 0; end
end

% ========================================================================
function r = withinBetweenRatio(F, y)
%WITHINBETWEENRATIO 類內平均距離 / 類間平均距離（在原始特徵空間算）。
%
%   比值越小 = 類別分得越開。**在原始空間算，不要在降維後算**——
%   PCA／t-SNE 都會扭曲距離，2 維圖上的「分得開」不可靠。
cats = categories(y);
mu = zeros(numel(cats), size(F,2));
within = zeros(numel(cats),1);
for k = 1:numel(cats)
    Fk = F(y == cats{k}, :);
    mu(k,:) = mean(Fk, 1);
    if size(Fk,1) > 1
        within(k) = mean(vecnorm(Fk - mu(k,:), 2, 2));
    end
end
D = pdist(mu);
r = mean(within) / mean(D);
end

% ========================================================================
function Z = pcaTo2(F)
%PCATO2 用 PCA 降到 2 維（只為了畫圖）。
Fc = F - mean(F, 1);
[~, S, V] = svd(Fc, "econ");
Z = Fc * V(:, 1:2);
if size(S,1) < 2, Z = [Z zeros(size(Z,1),1)]; end
end

% ========================================================================
function acc = evalNet(net, ds, labels)
%EVALNET 用 minibatchpredict 評估一個訓練好的分類網路。
scores = minibatchpredict(net, ds, MiniBatchSize=8);
pred = scores2label(scores, categories(labels));
acc = mean(pred == labels);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
