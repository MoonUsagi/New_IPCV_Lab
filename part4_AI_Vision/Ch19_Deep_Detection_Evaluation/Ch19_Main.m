%[text] # 第 19 章　深度學習物件偵測與模型評估
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：5 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 用預訓練偵測器在自己的資料上推論，並用 `evaluateObjectDetection` 評估
%[text] 2. **說出一個 mAP 數字裡有多少是你自己決定的**
%[text] 3. 處理**類別體系不對齊**——實務上最常見、最少被寫出來的問題
%[text] 4. 把偵測誤差拆成定位／重複／背景／漏標，並知道各自要用什麼修
%[text] 5. 選擇 IoU 門檻與分數門檻，並說出它們各自影響什麼
%[text] 6. 讀懂偵測訓練與分類訓練的四個差異 \
%[text] ## 前置知識
%[text] 第 16 章（偵測器評估、硬負樣本）、第 17 章（datastore）、第 18 章（遷移學習）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox、Deep Learning Toolbox。
%[text] > **關於訓練：本章的訓練段落預設不執行**（見 §9）。
%[text] > 本章**所有的量化結論都來自預訓練偵測器的推論與評估**，
%[text] > 那條路線每張影像只要 0.07 秒。
assert(exist("ch19_runDetector","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

vd = fullfile(toolboxdir("vision"), "visiondata");
v = load("vehicleTrainingData.mat");
fn = fieldnames(v);
vehicleTbl = v.(fn{1});
fprintf("資料集：%d 張影像，每張有人工標註的車輛框\n", height(vehicleTbl));
%%
%[text] # 1. 這一章的位置：從「是什麼」到「在哪裡」
%[text] 第 18 章的輸出是一個類別標籤。這一章的輸出是
%[text] **一組框 + 每個框的類別 + 每個框的分數**——三樣東西，
%[text] 而且數量事先不知道。
%[text] 評估也跟著變複雜。分類的準確率只要比對兩個標籤；
%[text] 偵測要先決定**哪個框對到哪個真實目標**，而那需要：
%[text:table]
%[text] | 選擇 | 決定什麼 | 本章的哪一節 |
%[text] | --- | --- | --- |
%[text] | **類別對應** | 偵測器的 `car` 算不算你的 `vehicle` | §3 |
%[text] | **IoU 門檻** | 多接近才算配對成功 | §5 |
%[text] | **分數門檻** | 低於多少分的框直接丟掉 | §6 |
%[text:table]
%[text] **這三個都不是模型的性質，是你的決定。**
%[text] 而它們對最終數字的影響，比大多數人以為的大得多。
%[text] > **本章的主軸就是這件事：一個 mAP 數字裡，
%[text] > 有多少是模型的能力，有多少是你的定義。**
%%
%[text] # 2. 預訓練偵測器：先看它到底輸出什麼
%[text] `yoloxObjectDetector` 提供在 COCO 上訓練好的權重，可以直接用。
detector = yoloxObjectDetector("small-coco");
fprintf("\nYOLOX small-coco：%d 個類別\n", numel(detector.ClassNames));

if ipcvFast()
    N = 20;
    disp("（快速模式：用 20 張影像。完整執行用 40 張。）")
else
    N = 40;
end
idx = round(linspace(1, height(vehicleTbl), N));
files = fullfile(vd, string(vehicleTbl.imageFilename(idx))).';
gtBoxes = vehicleTbl.vehicle(idx);

[raw, runInfo] = ch19_runDetector(detector, files);
fprintf("推論 %.3f 秒/張，共 %d 張、%d 個框\n", ...
    runInfo.SecPerImage, runInfo.NumImages, runInfo.NumBoxes);
fprintf("GT 總數 %d\n", sum(cellfun(@(x) size(x,1), gtBoxes)));
%%
%[text] ## 2.1 它偵測到了什麼？
disp(runInfo.ClassCounts)
%[text] 實測（40 張）：
%[text:table]
%[text] | COCO 類別 | 次數 |
%[text] | --- | --- |
%[text] | `car` | 141 |
%[text] | `truck` | 39 |
%[text] | `bus` | 10 |
%[text] | `traffic light` | 8 |
%[text] | `train` / `boat` / `stop sign` / `parking meter` | 各 1 |
%[text:table]
%[text] **總共 202 個框，而真實的車只有 46 台。**
%[text] 而且它輸出的是 **COCO 的 80 個類別**，
%[text] 我們的 ground truth 只有一個類別叫 `vehicle`。
%[text] > **這就是類別體系不對齊（taxonomy mismatch）。**
%[text] > 它在每一個「拿預訓練模型用在自己資料上」的專案都會出現，
%[text] > 而教科書幾乎不談。
%[text] 先看一張圖：
I1 = imread(files(1));
figure
if isempty(raw.Boxes{1})
    imshow(I1); title("第 1 張：沒有偵測到任何東西")
else
    lbl = compose("%s %.2f", string(raw.Labels{1}), raw.Scores{1});
    imshow(insertObjectAnnotation(I1, "rectangle", raw.Boxes{1}, lbl, ...
        Color="yellow", LineWidth=2));
    title(sprintf("第 1 張：%d 個框（GT 只有 %d 個）", ...
        size(raw.Boxes{1},1), size(gtBoxes{1},1)))
end
%%
%[text] # 3. 本章最重要的一節：類別對應值多少分？
%[text] `car` 當然算 vehicle。**`truck` 呢？`bus` 呢？**
%[text] 這不是模型能回答的問題——**是你要定義的**。
%[text] 而這個定義會改變分數。**掃描它。**
mappings = { ...
    "只把 car 當車",             "car"; ...
    "car + truck",              ["car" "truck"]; ...
    "car + truck + bus",        ["car" "truck" "bus"]; ...
    "再加 motorcycle",          ["car" "truck" "bus" "motorcycle"] };

mapTbl = ch19_classMapping(raw, gtBoxes, mappings, "vehicle");
disp(mapTbl)
%[text] 實測（IoU 0.5）：
%[text:table]
%[text] | 對應方式 | 框數 | precision | recall | AP |
%[text] | --- | --- | --- | --- | --- |
%[text] | 只把 `car` 當車 | 141 | 19.9% | 60.9% | **0.2610** |
%[text] | `car` + `truck` | 180 | 20.6% | 80.4% | 0.4678 |
%[text] | **`car` + `truck` + `bus`** | 190 | 20.5% | 84.8% | **0.4827** |
%[text] | 再加 `motorcycle` | 190 | 20.5% | 84.8% | 0.4827 |
%[text:table]
%[text] **AP 從 0.261 到 0.483，相對提升 85%——而模型完全沒有改變。**
%[text] 三件事要注意：
%[text] **① 這不是「調參數」，是「定義任務」。**
%[text] 你不能為了讓分數好看而事後挑一個對應方式——
%[text] 那等於**用測試集調超參數**（第 16 章練習 3 的老問題）。
%[text] 對應方式應該在**看到分數之前**依任務語意決定，然後就固定。
%[text] **② 加 `motorcycle` 完全沒有效果**（框數與分數一個都沒動），
%[text] 因為這批影像裡根本沒有東西被判成機車。
%[text] **對應清單要從實際偵測到的類別推導**（§2.1 的表），不要憑空想。
%[text] **③ recall 漲了 24 個百分點，precision 幾乎沒動**（19.9% → 20.5%）。
%[text] 加入 `truck`／`bus` 補進來的是**原本被漏掉的真車**，
%[text] 而不是新的誤判。這說明那些漏標的原因是
%[text] **類別名稱不合，不是模型看不到那些車**。
%[text] > **這個區分很重要。** 若你只看到「recall 60.9%」就開始
%[text] > 換更大的模型、加訓練資料，你會浪費大量時間——
%[text] > 真正的問題是一行類別對應。
%%
%[text] # 4. `evaluateObjectDetection` 與 AP 的意義
%[text] 固定用 §3 選出的對應方式，接下來的分析都基於它。
detResults = ch19_mapClasses(raw, ["car" "truck" "bus"], "vehicle");
blds = boxLabelDatastore(table(gtBoxes(:), VariableNames="vehicle"));
metrics = evaluateObjectDetection(detResults, blds, 0.5, Verbose=false);

fprintf("\nAP（IoU 0.5）= %.4f\n", metrics.ClassMetrics.APOverlapAvg(1));
fprintf("影像數 %d、類別數 %d\n", metrics.NumImages, metrics.NumClasses);

prec = metrics.ClassMetrics.Precision{1};
recl = metrics.ClassMetrics.Recall{1};
figure
plot(recl, prec, "-", LineWidth=2)
xlabel("recall"); ylabel("precision"); grid on
xlim([0 1]); ylim([0 1])
title(sprintf("PR 曲線（AP = %.4f）", metrics.ClassMetrics.APOverlapAvg(1)))
%[text] **AP 是這條 PR 曲線下的面積。**
%[text] 它把「所有可能的分數門檻」都納入，所以是一個
%[text] **與門檻無關**的摘要。這是優點也是陷阱：
%[text] - 優點：比較兩個模型時不必先選門檻
%[text] - **陷阱：你上線時只能選一個門檻，而 AP 沒告訴你該選哪個**
%[text] §6 會處理這件事。
%[text] > **`metrics` 物件的欄位名稱不直覺。**
%[text] > 常用的是 `metrics.ClassMetrics.APOverlapAvg`（純量）；
%[text] > `metrics.ClassMetrics.AP` 是 **cell**。
%[text] > 另外 `metrics.DatasetMetrics` 可以存取，
%[text] > 但**它不出現在 `properties(metrics)` 的清單裡**。
%%
%[text] # 5. IoU 門檻：平坦，然後懸崖
[iouTbl, allIoU] = ch19_iouSweep(detResults, gtBoxes, "vehicle");
disp(iouTbl)

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
plot(iouTbl.("IoU門檻"), iouTbl.AP, "o-", LineWidth=2, MarkerSize=8)
xlabel("IoU 門檻"); ylabel("AP"); grid on; ylim([0 0.6])
title("AP vs IoU 門檻")
nexttile
histogram(allIoU, 0:0.05:1)
xlabel("每個框對最近 GT 的 IoU"); ylabel("框數"); grid on
title("IoU 的分布（雙峰）")
%[text] 實測：
%[text:table]
%[text] | IoU 門檻 | AP | precision | recall |
%[text] | --- | --- | --- | --- |
%[text] | 0.30 | 0.4827 | 20.5% | 84.8% |
%[text] | 0.50 | 0.4827 | 20.5% | 84.8% |
%[text] | 0.60 | 0.4827 | 20.5% | 84.8% |
%[text] | 0.75 | 0.4740 | 20.0% | 82.6% |
%[text] | **0.90** | **0.0307** | **5.8%** | **23.9%** |
%[text:table]
%[text] **0.30 到 0.60 完全平坦，0.75 掉一點點，0.90 直接崩潰。**
%[text] 為什麼？看右邊那張直方圖，以及這兩個數字：
%[text:table]
%[text] | 統計量 | 值 |
%[text] | --- | --- |
%[text] | 所有框對最近 GT 的 IoU 中位數 | **0.010** |
%[text] | 命中框（IoU ≥ 0.5）的平均 IoU | **0.871** |
%[text:table]
%[text] **分布是雙峰的**：框要嘛幾乎完美（平均 0.871），
%[text] 要嘛根本不在目標上（那些是誤判）。**中間地帶幾乎是空的**，
%[text] 所以門檻在 0.3–0.6 之間移動不會改變任何一個配對。
%[text] > **這個雙峰結構是「分數對 IoU 門檻不敏感」的原因，
%[text] > 而它是這個模型 + 這批資料的性質，不是通則。**
%[text] > 框位置比較鬆的模型會得到一條平滑下降的曲線，
%[text] > 那時候門檻選 0.5 還是 0.75 差別就很大。
%[text] **所以報告 mAP 一定要寫清楚門檻。**
%[text] COCO 的慣例是 mAP@[0.5:0.05:0.95]（十個門檻的平均），
%[text] Pascal VOC 是 mAP@0.5。**兩者不能互相比較**，
%[text] 而論文裡常常只寫「mAP」。
%%
%[text] # 6. 分數門檻：AP 沒告訴你的事
scoreTbl = ch19_scoreSweep(detResults, gtBoxes, "vehicle");
disp(scoreTbl)

figure
plot(scoreTbl.("分數門檻"), scoreTbl.precision, "o-", LineWidth=2); hold on
plot(scoreTbl.("分數門檻"), scoreTbl.recall, "s--", LineWidth=2)
plot(scoreTbl.("分數門檻"), scoreTbl.F1, "^-", LineWidth=1.5)
hold off; grid on; legend(["precision" "recall" "F1"], Location="best")
xlabel("分數門檻"); ylabel("%"); title("分數門檻的取捨")
%[text] **AP 是整條曲線的面積，但你上線時只能站在曲線上的一個點。**
%[text] 怎麼選？**看下游**（這是第 17 章 §11 的同一個原則）：
%[text:table]
%[text] | 下游 | 該選 |
%[text] | --- | --- |
%[text] | 預標註給人修 | recall 高的**低門檻**（刪比畫便宜） |
%[text] | 自動化產線決策 | precision 高的**高門檻** |
%[text] | 沒有明確偏好 | F1 最高的點——**但那只是一個預設值** |
%[text:table]
%[text] > **「AP 0.48」和「上線後的 precision」是兩回事。**
%[text] > AP 描述模型的**潛力**，門檻決定你**實際取到**哪一段。
%%
%[text] # 7. 誤差拆解：precision 20% 到底錯在哪
%[text] 「八成的框是錯的」沒有告訴你要修什麼。**把它拆開。**
[errTbl, errInfo] = ch19_errorBreakdown(detResults, gtBoxes);
disp(errTbl)

figure
pie([errInfo.NumDup errInfo.NumLoc errInfo.NumBg], ...
    ["重複框" "定位不準" "背景誤判"]);
title("誤判的組成")
%[text] 不同的錯要用**完全不同**的方法修：
%[text:table]
%[text] | 誤差型態 | 怎麼修 |
%[text] | --- | --- |
%[text] | 背景誤判 | 提高分數門檻、加硬負樣本（第 16 章 §7） |
%[text] | 定位不準 | 調錨框／輸入尺寸、檢查目標尺寸分布 |
%[text] | 重複框 | 調 NMS 的 `OverlapThreshold` |
%[text] | 漏標 | 降低分數門檻、**檢查類別對應**（§3） |
%[text:table]
%[text] > **拿錯誤的藥治錯誤的病是偵測任務最常見的浪費。**
%[text] > 看到 precision 低就去調 NMS 的人很多，
%[text] > 但若誤差幾乎都是背景誤判，調 NMS 一點用都沒有。
%[text] R2026a **沒有**現成的誤差分析函式
%[text] （`detectionErrorAnalysis` 的 `exist` 回傳 0），所以這要自己寫。
%[text] `ch19_errorBreakdown` 用的是**依分數由高到低的貪婪配對**——
%[text] 順序很重要，否則「重複框」這個型態沒有意義。
%[text] 實測的誤差組成：
%[text:table]
%[text] | 型態 | 數量 | 佔誤判 |
%[text] | --- | --- | --- |
%[text] | 命中（本函式配對） | 46 | — |
%[text] | 重複框 | 23 | 16.0% |
%[text] | 定位不準 | 1 | 0.7% |
%[text] | **背景誤判** | **120** | **83.3%** |
%[text:table]
%[text] **83% 的誤判是背景誤判**，所以該做的是提高分數門檻或加硬負樣本，
%[text] **調 NMS 完全沒有用**（重複框只佔 16%）。
%%
%[text] # 7.1 兩個配對實作，兩個 recall——而且差了 7 個目標
%[text] **上面那張表和 §4 的數字對不起來，這件事必須講清楚。**
%[text:table]
%[text] | 來源 | 配到的 GT | recall |
%[text] | --- | --- | --- |
%[text] | `ch19_errorBreakdown` 的貪婪配對 | 46 / 46 | **100%** |
%[text] | `evaluateObjectDetection` | 39 / 46 | **84.78%** |
%[text:table]
%[text] 逐張比對後找到 4 張不一致的影像。其中一張的 GT 是
%[text] `[102 69 27 19]`，而它的偵測框是：
%[text:table]
%[text] | 框 | 分數 | IoU |
%[text] | --- | --- | --- |
%[text] | 1 | 0.573 | 0.024 |
%[text] | **2** | 0.519 | **0.859** |
%[text] | 3 | 0.319 | 0.016 |
%[text] | 4 | 0.289 | 0 |
%[text] | **5** | 0.261 | **0.951** |
%[text:table]
%[text] **有兩個框的 IoU 遠超過 0.5，但官方的
%[text] `ImageMetrics.APOverlapAvg` 對這張影像回報 0。**
%[text] 官方的配對規則沒有完整文件化，所以**本課程不猜它的內部邏輯**。
%[text] 能確定的是：**兩種都合理的配對實作，在同一批資料上
%[text] 會給出不同的 recall。**
%[text] 實務上要怎麼做：
%[text] 1. **同一份報告裡的數字全部用同一個工具算。**
%[text]    本章 §4–§6 一律用 `evaluateObjectDetection`；
%[text]    §7 的貪婪配對只用來看**誤判的組成比例**，
%[text]    它的 recall 不當結論用。
%[text] 2. **跨團隊比較分數前，先確認雙方用的是同一套評估程式碼。**
%[text] > **這正是本章的主題本身。**
%[text] > §3 說「類別對應」是你的決定，§5 說「IoU 門檻」是你的決定，
%[text] > §6 說「分數門檻」是你的決定——
%[text] > 這一節再加上第四個：**配對規則也是一個決定，
%[text] > 而且它連在同一個 MATLAB 裡都不只一種實作。**
%[text] 順帶一提，`metrics.ImageMetrics` 是逐張的指標表，
%[text] 對這種除錯很有用——但它**不出現在 `properties(metrics)` 裡**，
%[text] 文件也沒特別提。
%%
%[text] # 8. 為什麼 precision 這麼低？——一個誠實的檢討
%[text] 20.5% 的 precision 看起來很糟。**但先想清楚它在量什麼。**
%[text] 這批影像是 128×228 的**車輛特寫裁切**，而 YOLOX 是在
%[text] COCO 的**完整場景照片**上訓練的。兩件事因此發生：
%[text] **① 模型會去標註畫面裡的其他東西。**
%[text] `traffic light`、`stop sign`、`parking meter` 各出現了幾次——
%[text] 那些**可能真的在畫面裡**，只是我們的 ground truth 只標了車。
%[text] **被判成誤判的框，有一部分其實是對的**，
%[text] 只是不在我們的標註範圍內。
%[text] **② 一台車可能被切成好幾個框**（車頭、車身、整台車）。
%[text] > **所以 20.5% 不是「模型很爛」，
%[text] > 是「模型在回答一個和我們的標註不同的問題」。**
%[text] 這是第 3 節那件事的延伸：**評估量的是模型與標註的一致性，
%[text] 不是模型的絕對能力。** 標註只涵蓋一個類別時，
%[text] 一個通用偵測器必然會被扣分。
%[text] 要公平評估，有三條路：
%[text] 1. **只計分在 GT 類別範圍內的框**（本章的做法，仍不完美）
%[text] 2. **把標註補齊**（把畫面裡的其他物件也標起來）
%[text] 3. **微調模型**，讓它只輸出你要的類別（§9）
%%
%[text] # 9. 訓練自己的偵測器（程式碼完整，預設不執行）
%[text] > **本節的程式碼尚未在本機驗證過。**
%[text] > 本課程的開發機器是 NVIDIA T550（4.29 GB），跑不動偵測器訓練。
%[text] > 程式碼是照 R2026a 的 API 寫完整的，
%[text] > **實際執行要在記憶體更大的機器上驗證**——
%[text] > README 有一份「換機器後要驗證什麼」的清單。
% 組出偵測訓練要的資料管線：影像 + 框 + 標籤
allFiles = fullfile(vd, string(vehicleTbl.imageFilename));
imdsDet = imageDatastore(allFiles);
bldsDet = boxLabelDatastore(vehicleTbl(:, "vehicle"));
dsDet = combine(imdsDet, bldsDet);

sample = read(dsDet);
fprintf("\ncombine(imds, blds) 之後 read 得到 %d 格：\n", numel(sample));
fprintf("  影像 %s、框 %s、標籤 %s\n", ...
    mat2str(size(sample{1})), mat2str(size(sample{2})), class(sample{3}));

% 切分（第 17 章 §6 的群組感知切分在這裡同樣適用）
n = height(vehicleTbl);
rng(0); p = randperm(n); nTr = round(0.7*n);
dsTrain = subset(dsDet, p(1:nTr));
dsVal   = subset(dsDet, p(nTr+1:end));
fprintf("訓練 %d 張、驗證 %d 張\n", nTr, n-nTr);

[detTrain, trainInfo] = ch19_trainDetector(dsTrain, dsVal, "vehicle", ...
    DoTrain=false, ModelName="tiny-coco", MaxEpochs=10, MiniBatchSize=4);
clear detTrain
%[text] **偵測訓練與分類訓練的四個差異**
%[text] **① 資料格式不同。** 分類是 `imds`（影像 + 標籤）；
%[text] 偵測要 `combine(imds, blds)`——每次 `read` 回傳
%[text] **三格** `{影像, 框, 標籤}`，不是兩格。
%[text] **② 擴增要同時變換影像與框。**
%[text] 這是第 17 章 §5「標籤要跟著一起變」在偵測上的版本，而且更麻煩：
%[text] 翻轉影像時框的 x 座標要鏡射，縮放時框要跟著縮放。
%[text] 寫錯一樣**不會報錯**，只會讓模型學不起來。
%[text] `bboxresize`／`bboxwarp` 就是為此存在的。
%[text] **③ 批次大小要小得多。** 分類能用 32 的地方，偵測可能只能用 4——
%[text] 輸入解析度高（320–640）而且要保留多尺度特徵圖。
%[text] **④ 輸入尺寸要配合目標大小。**
%[text] `vehicles` 的車大約 20–40 像素寬；若輸入縮放到 320×320，
%[text] 那些車會變得更小。**目標小到幾個像素時任何偵測器都學不起來。**
%[text] 訓練前先量目標尺寸的分布——這是第 16 章練習 2 的教訓。
sizes = cellfun(@(b) mean(b(:,3)), vehicleTbl.vehicle);
fprintf("\nGT 框寬度：最小 %.0f、中位數 %.0f、最大 %.0f 像素\n", ...
    min(sizes), median(sizes), max(sizes));
%%
%[text] # 10. R2026a 注意事項
%[text] 1. **`evaluateObjectDetection` 不接受只有一個變數的 table**，
%[text]    但接受由同一個 table 做成的 `boxLabelDatastore`（第 17 章已遇過）。
%[text] 2. 度量欄位是 **`metrics.ClassMetrics.APOverlapAvg`**（純量）；
%[text]    `metrics.ClassMetrics.AP` 是 **cell**。
%[text]    `metrics.DatasetMetrics` 可存取但**不在 `properties()` 清單裡**。
%[text] 3. **沒有 `detectionErrorAnalysis`**（`exist` 回傳 0），誤差分解要自己寫。
%[text] 4. `yoloxObjectDetector("small-coco")` 可直接推論；
%[text]    要訓練自己的類別則用 `yoloxObjectDetector(model, classNames, InputSize=...)`
%[text]    再交給 `trainYOLOXObjectDetector`。
%[text] 5. 偵測的資料管線是 `combine(imds, blds)`，`read` 回傳**三格**。
%[text] 6. 每個載入的偵測器都佔顯示記憶體，用完要 `clear`
%[text]    （第 17 章 §10.1 的教訓）。
%%
%[text] # 11. 常見陷阱
%[text] 1. **沒有寫出類別對應方式就報 mAP** → §3 顯示它值 85% 的相對差異。
%[text] 2. **事後挑對應方式讓分數好看** → 等於用測試集調超參數。
%[text] 3. **對應清單憑空想** → `motorcycle` 加了完全沒效果；要從實測的類別分布推導。
%[text] 4. **沒寫 IoU 門檻就比較兩個 mAP** → COCO 與 VOC 的慣例不同，不可比。
%[text] 5. **以為 AP 高就能上線** → AP 是整條曲線，上線只能站一個點（§6）。
%[text] 6. **看到 precision 低就調 NMS** → 先拆解誤差型態（§7）。
%[text] 7. **把「模型與標註不一致」當成「模型很爛」** → §8。
%[text] 8. **偵測擴增只變換影像不變換框** → 不報錯，模型學不起來。
%[text] 9. **偵測沿用分類的批次大小** → OOM。
%[text] 10. **沒量目標尺寸就設輸入解析度** → 目標被縮到幾個像素。
%%
%[text] # 12. 本章小結
%[text:table]
%[text] | 主題 | 一句話 |
%[text] | --- | --- |
%[text] | **類別對應** | **AP 0.261 → 0.483，模型沒變** |
%[text] | recall vs precision 的來源 | 加 `truck`／`bus` 補的是漏標，不是新誤判 |
%[text] | IoU 門檻 | 這裡平坦到 0.6、0.9 崩潰——因為 IoU 分布**雙峰** |
%[text] | 分數門檻 | AP 不告訴你選哪個點；看下游 |
%[text] | 誤差拆解 | 不同的錯要用不同的藥，R2026a 沒有現成函式 |
%[text] | precision 20.5% | 是**模型與標註不一致**，不是模型爛 |
%[text] | 偵測訓練 | 資料三格、擴增要連框、批次要小、先量目標尺寸 |
%[text:table]
%[text] > **這一章要帶走的一句話：
%[text] > 報告偵測效能時，「類別對應 + IoU 門檻 + 分數門檻」
%[text] > 必須和 mAP 一起寫出來。只給一個 mAP 是沒有意義的。**
%%
%[text] # 13. 練習
%[text] 練習在 `exercise/Ch19_Exercise.m`。
%%
%[text] # 14. 延伸閱讀與下一章
%[text] - `doc yoloxObjectDetector` / `doc trainYOLOXObjectDetector`
%[text] - `doc evaluateObjectDetection` — 注意 `ClassMetrics` 的欄位名稱
%[text] - `doc bboxwarp` / `doc bboxresize` — 擴增時變換框
%[text] **第 20 章**把框換成遮罩：語意分割與實例分割。
%[text] 評估指標也跟著換（IoU／Dice／BFscore），
%[text] 而**它們會給出互相矛盾的排序**——第 17 章加分題已經量到一次。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
