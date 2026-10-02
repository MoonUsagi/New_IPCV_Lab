%[text] # 第 22 章　工業瑕疵檢測與異常偵測
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[產業\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出異常偵測與監督式分類的取捨，以及什麼時候只能用前者
%[text] 2. 用 PatchCore 建立一個只需要良品樣本的檢測器
%[text] 3. **用過殺率與漏檢率決定門檻**，而不是用 F1
%[text] 4. 用異常圖（anomaly map）定位瑕疵，不只判斷有沒有
%[text] 5. 說出四種異常偵測方法的 API 差異與各自的前提
%[text] 6. **把整套流程換到你自己的資料上** \
%[text] ## 前置知識
%[text] 第 18 章（遷移學習、雜訊分析）、第 20 章（類別不平衡與逐類別指標）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox、Deep Learning Toolbox，以及
%[text] **Automated Visual Inspection Library for Computer Vision Toolbox**。
%[text] > ## **關於本章的資料——請先讀這一段**
%[text] > **本章預設使用合成的良品／瑕疵影像**，理由有兩個：
%[text] > 1. MATLAB 沒有內建的瑕疵資料集（`pillQC` 等都要下載）
%[text] > 2. 合成資料的 ground truth 是精確的，流程與指標可以完整驗證
%[text] >
%[text] > **但合成資料上的分數不能當成對你產線的預期。**
%[text] > 本章的重點是**流程與決策方法**，不是「PatchCore 有多強」。
%[text] >
%[text] > **要換成你自己的資料，只要改一個函式**（`ch22_loadDataset`），
%[text] > §10 會說明怎麼做。後面所有的程式碼都不必動。
assert(exist("ch22_loadDataset","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

addons = matlab.addons.installedAddons;
hasAVI = any(contains(addons.Name, "Automated Visual Inspection"));
fprintf("AVI Library：%s\n", string(hasAVI));
%%
%[text] # 1. 這一章的位置：只有良品樣本
%[text] 前面四章都假設你有各個類別的標註。**產線上通常沒有。**
%[text:table]
%[text] | 情況 | 現實 |
%[text] | --- | --- |
%[text] | 良品樣本 | **要多少有多少**（產線每天生產） |
%[text] | 瑕疵樣本 | **很少**，而且新的瑕疵型態會不斷出現 |
%[text] | 瑕疵的像素標註 | **幾乎沒有**（要人工描輪廓） |
%[text:table]
%[text] 這讓監督式分類（第 18 章）在一開始就不可行——
%[text] 你沒有足夠的瑕疵樣本去訓練「瑕疵」這一類。
%[text] **異常偵測換一個問法**：
%[text] > 不問「這是哪一種瑕疵」，只問「**這張和我看過的良品像不像**」。
%[text:table]
%[text] | | 監督式分類 | **異常偵測** |
%[text] | --- | --- | --- |
%[text] | 需要瑕疵樣本 | **要，每類數十張** | **不用** |
%[text] | 能偵測沒見過的瑕疵型態 | **不能** | **能** |
%[text] | 能說出是哪一種瑕疵 | 能 | **不能**（只給分數與位置） |
%[text] | 資料準備成本 | 高 | **低** |
%[text:table]
%[text] > **能不能列出所有瑕疵型態？** 答不出來的話，
%[text] > 監督式分類從一開始就不適用——
%[text] > 這和第 21 章 §2「CLIP 只能在你給的選項裡挑」是同一個限制。
%%
%[text] # 2. 資料
data = ch22_loadDataset();      % 預設：合成資料
fprintf("\n良品訓練 %d 張、良品測試 %d 張、瑕疵 %d 張\n", ...
    size(data.GoodTrain,4), size(data.GoodTest,4), size(data.Bad,4));
fprintf("影像尺寸 %s、合成資料：%s\n", ...
    mat2str(data.ImageSize), string(data.Synthetic));

figure
tiledlayout(2,4, TileSpacing="compact")
for k = 1:4
    nexttile; imshow(data.GoodTrain(:,:,:,k)); title("良品 " + k)
end
for k = 1:4
    nexttile
    imshow(data.Bad(:,:,:,k));
    title("瑕疵 " + k)
end
%[text] 瑕疵是隨機位置、隨機大小的暗斑。
%[text] **刻意做得很簡單**——本章要示範的是流程與指標。
%[text] > **真實瑕疵（刮痕、色差、缺件、毛邊）難得多。**
%[text] > 換上你自己的資料之後，第一件事就是重看 §4 的兩個分數分布
%[text] > 有沒有重疊。
%%
%[text] # 3. 訓練：只用良品
%[text] PatchCore **不需要梯度訓練**——它把良品的特徵存成一個
%[text] 精簡的集合（coreset），推論時看新影像的特徵離那個集合多遠。
%[text] 所以**沒有學習率、不會發散**，和第 18 章的策略一同一個道理。
[detector, trainInfo] = ch22_trainAnomaly(data, "patchcore", ...
    Backbone="resnet18");
fprintf("\n訓練耗時 %.1f 秒（%d 張良品）\n", ...
    trainInfo.SecTrain, trainInfo.NumGoodTrain);
%[text] **API 有一個會誤導人的地方：**
%[text] ```matlab
%[text] patchCoreAnomalyDetector("resnet18")        % ← 錯
%[text] patchCoreAnomalyDetector(Backbone="resnet18")  % ← 對
%[text] ```
%[text] `Backbone` 是**名稱-值引數**。傳成位置引數會報
%[text] 「Invalid argument at position 1」——
%[text] **那個訊息看起來像缺套件，其實只是引數形式錯。**
%%
%[text] # 4. 分數分布：先看它們有沒有分開
nG = size(data.GoodTest,4);
nB = size(data.Bad,4);
sGood = zeros(nG,1);
for k = 1:nG, sGood(k) = predict(detector, data.GoodTest(:,:,:,k)); end
sBad = zeros(nB,1);
for k = 1:nB, sBad(k) = predict(detector, data.Bad(:,:,:,k)); end

fprintf("\n良品分數 %.3f ± %.3f（最大 %.3f）\n", ...
    mean(sGood), std(sGood), max(sGood));
fprintf("瑕疵分數 %.3f ± %.3f（最小 %.3f）\n", ...
    mean(sBad), std(sBad), min(sBad));

figure
histogram(sGood, 15, FaceAlpha=0.6); hold on
histogram(sBad, 15, FaceAlpha=0.6); hold off
legend(["良品" "瑕疵"], Location="best")
xlabel("異常分數"); ylabel("次數"); grid on
title("分數分布——第一件要看的事")
%[text] 實測（合成資料、24 張良品訓練、5.8 秒）：
%[text:table]
%[text] | | 平均 | 標準差 | 極值 |
%[text] | --- | --- | --- | --- |
%[text] | 良品 | **1.17** | 0.03 | 最大 1.22 |
%[text] | 瑕疵 | **22.93** | 0.96 | 最小 21.37 |
%[text:table]
%[text] **兩個分布完全分開——間隔相當於 609 個良品標準差。**
%[text] 中間從 1.22 到 21.37 是一整段空白。
%[text] > **這是合成資料給的，不是 PatchCore 的實力證明。**
%[text] > 真實產線上這兩個分布**一定會重疊**，
%[text] > 而重疊的程度就決定了你能做到多好。
%[text] **換上你的資料之後，這張圖是第一件要看的東西。**
%[text] 完全分開 → 任何中間的門檻都行；
%[text] 重疊嚴重 → 先回去看資料（良品夠不夠乾淨？瑕疵夠不夠明顯？），
%[text] 不要急著調參數。
%%
%[text] # 5. 門檻決策：過殺率 vs 漏檢率
%[text] **產線上這兩種錯的代價完全不對稱。**
[thTbl, thInfo] = ch22_thresholdAnalysis(sGood, sBad);
disp(head(thTbl, 8))

figure
plot(thTbl.("門檻"), thTbl.("過殺率百分比"), "o-", LineWidth=1.8); hold on
plot(thTbl.("門檻"), thTbl.("漏檢率百分比"), "s--", LineWidth=1.8); hold off
grid on; legend(["過殺率" "漏檢率"], Location="best")
xlabel("門檻"); ylabel("%"); title("門檻的取捨")

fprintf("\nYouden 建議門檻 %.3f\n", thInfo.ThresholdYouden);
fprintf("限制過殺率 ≤1%% 的門檻 %.3f\n", thInfo.ThresholdMaxFPR);
fprintf("零漏檢門檻 %.3f（過殺率 %.1f%%）\n", ...
    thInfo.ThresholdZeroEscape, 100*thInfo.OverkillAtZeroEscape);
%[text:table]
%[text] | 錯誤 | 產線上的後果 |
%[text] | --- | --- |
%[text] | **過殺**（良品判成瑕疵） | 多一道人工複檢；成本可算、可控 |
%[text] | **漏檢**（瑕疵放過去） | 流到客戶端；召回、賠償、商譽 |
%[text:table]
%[text] **幾乎沒有產線會用「平衡」的門檻。**
%[text] 典型做法是**先定一個可接受的漏檢率**（常常是 0%），
%[text] 再看那個條件下的過殺率能不能接受。
%[text] > 這和第 17 章 §11「刪框比畫框便宜」、
%[text] > 第 19 章 §6「分數門檻要看下游」是同一個原則：
%[text] > **門檻由成本決定，不是由 F1 決定。**
%[text] **`anomalyThreshold` 的引數順序很容易搞錯：**
%[text] ```matlab
%[text] t = anomalyThreshold(gtLabels, scores, anomalyLabels)
%[text] ```
%[text] 第三個引數是「**哪些標籤值代表異常**」，**不是每個樣本的標籤**。
%[text] `gtLabels` 是 logical 時就傳 `true`。傳錯會得到
%[text] 「Expected input number 3, anomalyLabels, to be integer-valued」——
%[text] **訊息完全指不到真正的問題。**
%%
%[text] # 6. 評估
th = thInfo.ThresholdMaxFPR;
predLabels = [sGood; sBad] >= th;          % **必須是 logical**
gtLabels   = [false(nG,1); true(nB,1)];

metrics = evaluateAnomalyDetection(predLabels, gtLabels, true, Verbose=false);
disp(metrics.DataSetMetrics)
disp(metrics.ClassMetrics)
%[text] `evaluateAnomalyDetection(predLabels, gtLabels, anomalyLabels)`：
%[text] - `predLabels` **必須是 logical 向量**（傳 categorical 會報型別錯）
%[text] - 第三個引數同樣是「哪些值代表異常」
%[text] > **和第 20 章一樣，不要只看整體準確率。**
%[text] > 瑕疵通常是少數類，整體準確率會被良品支配
%[text] > （第 20 章 §3：什麼都不預測就有 95.4%）。
%%
%[text] # 7. 異常圖：不只說有沒有，還說在哪
%[text] 產線上「這片有問題」不夠——**要知道問題在哪**才能回饋製程。
amap = anomalyMap(detector, data.Bad(:,:,:,1));
fprintf("\nanomalyMap -> %s、範圍 %.2f–%.2f\n", ...
    mat2str(size(amap)), min(amap(:)), max(amap(:)));

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(data.Bad(:,:,:,1)); title("瑕疵影像")
nexttile; imagesc(amap); axis image off; colorbar; title("異常圖")
nexttile; imshow(data.BadMasks(:,:,1)); title("真實瑕疵位置")

% 定位品質：異常圖的高分區域和真實瑕疵重疊嗎？
if size(data.BadMasks,3) > 0
    nEval = min(size(data.Bad,4), size(data.BadMasks,3));
    ious = zeros(nEval,1);
    for k = 1:nEval
        m = anomalyMap(detector, data.Bad(:,:,:,k));
        % 用該圖自己的高分區當預測（取前 N 個像素，N = 真實瑕疵面積）
        gt = data.BadMasks(:,:,k);
        nPix = nnz(gt);
        [~, ord] = sort(m(:), "descend");
        pred = false(size(m)); pred(ord(1:nPix)) = true;
        ious(k) = jaccard(pred, gt);
    end
    fprintf("定位 IoU（前 N 個像素 vs 真實遮罩）：%.3f ± %.3f\n", ...
        mean(ious), std(ious));
end
%[text] **`anomalyMap` 是偵測器的方法，不是自由函式**
%[text] （`exist("anomalyMap")` 回傳 0）。
%[text] 實測的定位 IoU 是 **0.604 ± 0.081**。
%[text] 上面的定位評估用了一個**刻意偏樂觀**的做法：
%[text] 取異常圖分數最高的 N 個像素，N 等於真實瑕疵的面積。
%[text] **那等於告訴模型瑕疵有多大**——所以它量的是
%[text] 「**異常圖的排序品質**」，不是端到端的分割效能。
%[text] > 真正的定位要自己決定一個像素層級的門檻，
%[text] > 而那又是一次 §5 的過殺／漏檢取捨——只是變成逐像素的。
%[text] > 第 20 章的 IoU／Dice／BFscore 在這裡全部適用。
%%
%[text] # 8. 四種方法的 API 差異
%[text] **這是本章最實際的一個坑：四種方法的介面完全不一致。**
%[text:table]
%[text] | 方法 | 建構 | 訓練 | 需要瑕疵樣本？ |
%[text] | --- | --- | --- | --- |
%[text] | **PatchCore** | `patchCoreAnomalyDetector(Backbone=...)` | `train...(normalData, detector)` | **不用** |
%[text] | FastFlow | `fastFlowAnomalyDetector(Name=Value)` | `train...(normalData, detector, **options**)` | 不用 |
%[text] | **FCDD** | `fcddAnomalyDetector(**network**)` | `train...(normalData, **anomalyData**, detector, options)` | **要** |
%[text] | EfficientAD | `efficientADAnomalyDetector` | — | 不用 |
%[text:table]
%[text] 三個要注意的地方：
%[text] **① `fastFlowAnomalyDetector` 的 `Backbone` 要 `dlnetwork`**，
%[text] 不吃字串名稱（PatchCore 吃字串）。
%[text] **② FCDD 需要瑕疵樣本。**
%[text] `trainFCDDAnomalyDetector(normalData, **anomalyData**, detector, options)`
%[text] ——**它不是單類別方法**，和本章「只有良品」的前提不同。
%[text] 這個差別常被忽略，因為它被歸在同一組 API 裡。
%[text] **③ 只有 PatchCore 不需要梯度訓練**，所以只有它在本機驗證過。
%[text] > **FastFlow／FCDD／EfficientAD 的訓練路線在本機沒有跑過**
%[text] > （開發機器是 T550，4.29 GB）。
%[text] > `ch22_trainAnomaly` 對它們會丟出明確的錯誤訊息，
%[text] > 而不是安靜地失敗。README 有待驗證清單。
%%
%[text] # 9. 物件計數：CounTR
%[text] AVI Library 還提供 `counTRObjectCounter`——
%[text] 給**一個範例 patch**就能數出畫面裡有幾個同類物件，**不需要訓練**。
if ipcvFast()
    disp("（快速模式：略過 CounTR。完整執行約 10 秒。）")
else
    I = imread("peppers.png");
    exemplar = {I(160:230, 200:280, :)};     % 一顆椒當範例
    t = tic;
    counter = counTRObjectCounter(exemplar);
    cnt = countObjects(counter, I);
    fprintf("\nCounTR：數到 %.1f 個（%.1f 秒）\n", cnt, toc(t));
    clear counter
end
%[text] 實測：用一顆椒當範例，在 `peppers.png` 上數到 **26.4** 個。
%[text] **注意回傳值是小數**（`single`）——它是密度圖的積分，
%[text] 不是整數計數。要整數就自己四捨五入，
%[text] 但**那個小數本身帶有資訊**：26.4 比 26 更誠實地表達了
%[text] 「大約 26 個，而且有一些不確定」。
%[text] 簽章有兩種：
%[text] ```matlab
%[text] counter = counTRObjectCounter(exemplarPatches)         % cell 陣列
%[text] counter = counTRObjectCounter(exemplarImage, exemplarBBoxes)
%[text] ```
%[text] 而 `countObjects` **只有一個輸出**（要第二個輸出會報 TooManyOutputs）。
%%
%[text] # 10. 換成你自己的資料
%[text] **本章刻意把「資料來源」和「方法」分開。**
%[text] §3 之後的所有程式碼都只看 `data` 這個 struct，
%[text] 不在乎它是合成的還是真實的。
%[text] 所以要換資料**只要改一個呼叫**：
%[text] ```matlab
%[text] data = ch22_loadDataset(Source="folder", ...
%[text]     GoodDir = "D:\產線\良品", ...
%[text]     BadDir  = "D:\產線\瑕疵", ...
%[text]     MaskDir = "D:\產線\瑕疵遮罩", ...   % 選用
%[text]     ImageSize = [256 256]);
%[text] ```
%[text] **換真實資料時最容易出問題的三件事：**
%[text] **① 影像尺寸要一致，而縮放會改變瑕疵的相對大小。**
%[text] 很小的瑕疵縮完可能只剩幾個像素
%[text] （第 19 章 §9 的同一個問題）。**先量瑕疵在原圖上佔幾個像素。**
%[text] **② 良品必須「夠正常」。**
%[text] 訓練集裡混進一張瑕疵品，模型就會把那種瑕疵當成正常。
%[text] **這是這個方法最脆弱的地方，而且它不會報錯**——
%[text] 症狀是那一類瑕疵的分數異常地低。
%[text] **③ 訓練集只放良品。** 要用瑕疵樣本訓練請改用 FCDD（§8）。
%[text] > **換完資料之後要重做的事，依重要性排序：**
%[text] > 1. **§4 的分數分布圖**——有沒有重疊決定了一切
%[text] > 2. **§5 的門檻表**——用你的過殺／漏檢成本決定
%[text] > 3. §7 的定位品質（若你有像素標註）
%%
%[text] # 11. R2026a 注意事項
%[text] 1. **`patchCoreAnomalyDetector` 的 `Backbone` 是名稱-值引數。**
%[text]    傳位置引數會報「Invalid argument at position 1」，
%[text]    **那個訊息看起來像缺套件**。
%[text] 2. **`anomalyThreshold(gtLabels, scores, anomalyLabels)`**
%[text]    的第三個引數是「哪些值代表異常」，不是每個樣本的標籤。
%[text] 3. **`evaluateAnomalyDetection` 的 `predLabels` 必須是 logical 向量。**
%[text] 4. **`anomalyMap` 是偵測器的方法**（`exist` 回傳 0）。
%[text] 5. **`fastFlowAnomalyDetector` 的 `Backbone` 要 `dlnetwork`**，
%[text]    不吃字串（和 PatchCore 不同）。
%[text] 6. **FCDD 需要瑕疵樣本**，不是單類別方法。
%[text] 7. `counTRObjectCounter` 的 `countObjects` **只有一個輸出**，
%[text]    回傳 `single` 小數。
%[text] 8. **MATLAB 沒有內建的瑕疵資料集**（`pillQC`、`concreteCrackDataset`
%[text]    等都要另外下載）。
%%
%[text] # 12. 常見陷阱
%[text] 1. **訓練集混進瑕疵品** → 不報錯，那類瑕疵的分數會異常低。
%[text] 2. **用 F1 或 Youden 決定產線門檻** → 兩種錯的代價不對稱（§5）。
%[text] 3. **只報整體準確率** → 瑕疵是少數類（第 20 章 §3 的老問題）。
%[text] 4. **看到合成資料上分離很好就以為方法很強** → §4 的警告。
%[text] 5. **把 `Backbone` 當位置引數** → 錯誤訊息會誤導你以為缺套件。
%[text] 6. **`anomalyThreshold` 的第三個引數傳成比例值** → 型別錯誤。
%[text] 7. **以為四種方法可以互換** → API 與前提都不同（§8）。
%[text] 8. **用 FCDD 卻沒有瑕疵樣本** → 它不是單類別方法。
%[text] 9. **縮放影像而沒檢查瑕疵剩幾個像素** → §10 第 ① 點。
%[text] 10. **拿定位 IoU 當端到端效能** → §7 的評估偏樂觀。
%%
%[text] # 13. 本章小結
%[text:table]
%[text] | 主題 | 一句話 |
%[text] | --- | --- |
%[text] | 為什麼用異常偵測 | 產線有很多良品、很少瑕疵，而且瑕疵型態會變 |
%[text] | PatchCore | **不需要梯度訓練**，24 張良品約 6 秒 |
%[text] | **第一件要看的事** | **分數分布有沒有重疊**，不是準確率 |
%[text] | **門檻** | **由過殺／漏檢的成本決定，不是 F1** |
%[text] | 異常圖 | 能定位，但端到端的定位要另一次門檻取捨 |
%[text] | 四種方法 | **API 與前提都不同**，FCDD 甚至需要瑕疵樣本 |
%[text] | 換你的資料 | 只改 `ch22_loadDataset`，其餘不動 |
%[text:table]
%[text] > **本章的合成資料讓流程可以驗證，但它的分數沒有參考價值。**
%[text] > 真正的結論要等你把自己的資料接上去之後才會出現——
%[text] > 而那時候第一張要看的圖，是 §4 的分數分布。
%%
%[text] # 14. 練習
%[text] 練習在 `exercise/Ch22_Exercise.m`。
%%
%[text] # 15. 延伸閱讀
%[text] - `doc patchCoreAnomalyDetector` / `doc anomalyThreshold`
%[text] - `doc evaluateAnomalyDetection` / `doc viewAnomalyDetectionResults`
%[text] - `doc counTRObjectCounter` — 少樣本計數
%[text] - `doc uiselectboxes` / `doc extractpatches` — R2026a 新增的互動式取樣

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
