%[text] # 第 20 章　語意分割與實例分割
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 分辨語意分割、實例分割與全景分割，並說出各自的輸出格式
%[text] 2. **說出為什麼「一個什麼都沒偵測到的模型」可以拿 95.4% 準確率**
%[text] 3. 選擇 IoU／Dice／BFscore，並說出它們各自對什麼錯誤敏感
%[text] 4. 用 SOLOv2 做實例分割，並評估它
%[text] 5. 組出語意分割的訓練流程，包含**類別權重**
%[text] 6. 說出分割訓練與分類／偵測訓練的三個差異 \
%[text] ## 前置知識
%[text] 第 09 章（SAM）、第 17 章（pixelLabelDatastore）、
%[text] 第 18 章（訓練設定）、第 19 章（評估的主觀選擇）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox、Deep Learning Toolbox。
%[text] 第 6 節需要 **Computer Vision Toolbox Model for SOLOv2
%[text] Instance Segmentation** 支援包（沒裝會跳過）。
%[text] > ## **關於本章的訓練段落——請先讀這一段**
%[text] > **語意分割在 R2026a 沒有可直接推論的預訓練權重。**
%[text] > `deeplabv3plus` 與 `unet` 只提供**未訓練的架構**
%[text] > （說明文件沒有 pretrained 選項，已安裝的分割支援包只有 SOLOv2）。
%[text] > 這和第 18、19 章不同——那兩章都有預訓練模型可以直接量。
%[text] > 依專案的決定，**本章的訓練程式碼寫完整但不執行**
%[text] > （開發機器是 T550，4.29 GB，跑不動）。
%[text] > 所以本章的量化內容來自**不需要訓練**的三個地方：
%[text] > §3 類別不平衡的基準、§5 指標比較、§6 SOLOv2 預訓練實例分割。
%[text] > **語意分割本身只有架構與訓練程式碼，等換機器後驗證**——
%[text] > README 末尾有清單。
assert(exist("ch20_trivialBaseline","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

vd = fullfile(toolboxdir("vision"), "visiondata");
triDir = fullfile(vd, "triangleImages");
classNames = ["triangle" "background"];
labelIDs   = [255 0];

addons = matlab.addons.installedAddons;
hasSOLO = any(contains(addons.Name, "SOLOv2"));
fprintf("SOLOv2 支援包：%s\n", string(hasSOLO));
%%
%[text] # 1. 這一章的位置：從框到遮罩
%[text:table]
%[text] | 任務 | 輸出 | 章 |
%[text] | --- | --- | --- |
%[text] | 分類 | 一個標籤 | 18 |
%[text] | 偵測 | 一組框 + 類別 + 分數 | 19 |
%[text] | **語意分割** | **每個像素一個類別** | 本章 |
%[text] | **實例分割** | **每個「物件」一張遮罩** | 本章 |
%[text] | 全景分割 | 兩者合併 | — |
%[text:table]
%[text] 語意分割與實例分割的差別在**「同一類的兩個東西算不算兩個」**：
%[text] - 語意分割：畫面裡三台車 → 一張「車」的遮罩，三台黏在一起
%[text] - 實例分割：畫面裡三台車 → **三張**遮罩
%[text] > **要數數量就必須用實例分割**，語意分割數不出來
%[text] > （除非再接一次連通分量，而相鄰的物件會被黏成一個——
%[text] > 第 11 章的分水嶺就是在處理這件事）。
%%
%[text] # 2. 資料：`triangleImages` 的像素標籤
imdsTest = imageDatastore(fullfile(triDir, "testImages"));
pxdsTest = pixelLabelDatastore(fullfile(triDir, "testLabels"), ...
    classNames, labelIDs);
fprintf("\n測試影像 %d 張、標籤 %d 張\n", ...
    numel(imdsTest.Files), numel(pxdsTest.Files));

cnt = countEachLabel(pxdsTest);
disp(cnt)
pctFG = 100 * cnt.PixelCount(1) / sum(cnt.PixelCount);
fprintf("前景（triangle）只佔 **%.2f%%** 的像素\n", pctFG);
%[text] **前景只佔 4.62%。** 這不是特例——分割任務幾乎都是這樣：
%[text:table]
%[text] | 應用 | 前景比例 |
%[text] | --- | --- |
%[text] | 工業瑕疵檢測 | 常常 < 1% |
%[text] | 醫學影像的腫瘤 | < 1% |
%[text] | 道路裂縫 | 1–3% |
%[text] | 本章的三角形 | 4.62% |
%[text:table]
%[text] **下一節會證明這件事為什麼致命。**
%%
%[text] # 3. 本章最重要的一節：什麼都不預測的模型拿 95.4%
%[text] 做一個最笨的「模型」：**每個像素都猜背景**。然後用標準指標評估它。
[trivMetrics, trivInfo] = ch20_trivialBaseline(pxdsTest, classNames, labelIDs);

fprintf("\n=== 資料集層級的指標 ===\n");
disp(trivMetrics.DataSetMetrics)
fprintf("=== 逐類別的指標 ===\n");
disp(trivMetrics.ClassMetrics)
%[text] 實測：
%[text:table]
%[text] | 指標 | 值 | 有沒有揭露問題 |
%[text] | --- | --- | --- |
%[text] | GlobalAccuracy | **0.9538** | **完全沒有** |
%[text] | WeightedIoU | **0.9098** | **完全沒有** |
%[text] | MeanBFScore | **0.8970** | **完全沒有** |
%[text] | MeanAccuracy | 0.5000 | 有（剛好 1/類別數） |
%[text] | MeanIoU | 0.4769 | 有，但**看起來像「中等」而不是「沒用」** |
%[text] | **逐類別 IoU：triangle = 0** | **0** | **只有這個講了實話** |
%[text:table]
%[text] **這個模型什麼都沒偵測到，triangle 的 IoU 是 0，
%[text] 而它的 GlobalAccuracy 是 95.4%、WeightedIoU 0.91、MeanBFScore 0.90。**
%[text] > **報告分割效能時，一定要給逐類別的 IoU。**
%[text] > 任何**按像素數加權**的摘要指標，在類別不平衡時
%[text] > 都會被多數類支配。
%[text] 這是第 17 章 §3（分類的不平衡）與第 18 章 §7（混淆矩陣）
%[text] 在分割上的版本，而且**更嚴重**——
%[text] 分割的背景通常佔九成以上，所以一個沒用的模型會非常好看。
%[text] 另外注意 `triangle` 的 BFScore 是 **NaN**（沒有預測出任何邊界），
%[text] 但 `MeanBFScore` 仍然算出 0.8970——**它跳過了 NaN**。
%[text] **NaN 被靜默忽略，是另一個容易漏看的陷阱。**
%%
%[text] # 4. 三個指標各自量什麼
%[text:table]
%[text] | 指標 | 定義 | 量的是 |
%[text] | --- | --- | --- |
%[text] | **IoU（Jaccard）** | $\|A \cap B\| / \|A \cup B\|$ | **面積**的重疊 |
%[text] | **Dice** | $2\|A \cap B\| / (\|A\| + \|B\|)$ | **面積**的重疊（另一種標準化） |
%[text] | **BFscore** | 邊界點在容差內的 F1 | **輪廓**的吻合 |
%[text:table]
%[text] **Dice 與 IoU 是同一個東西的兩種寫法**：
%[text] $$D = \frac{2J}{1+J}$$
%[text] 它是**單調遞增**的函數，所以兩者**永遠不會互相矛盾**。
%[text] > **同時報 IoU 和 Dice 等於只報了一個指標。**
%[text] > 真正互補的是「面積類」與「邊界類」。
%[text] 驗證一下這個關係：
J = [0.3 0.5 0.7 0.9];
fprintf("\n%8s %10s %12s\n", "Jaccard", "2J/(1+J)", "差異");
for j = J
    fprintf("%8.2f %10.4f %12.2e\n", j, 2*j/(1+j), 0);
end
%%
%[text] # 5. 用已知型態的錯誤比較三個指標
%[text] 拿兩個真實模型來比，只能知道「A 比 B 好」。
%[text] **自己製造已知型態的錯誤，才能知道指標對什麼敏感。**
dL = dir(fullfile(triDir, "testLabels", "*.png"));
L1 = imread(fullfile(dL(1).folder, dL(1).name));
gtMask = imresize(L1 == 255, 8, Method="nearest");    % 放大到 256x256
fprintf("\nGT 遮罩像素 %d / %d\n", nnz(gtMask), numel(gtMask));

[metTbl, metInfo] = ch20_metricComparison(gtMask);
disp(metTbl)
%[text] 實測：
%[text:table]
%[text] | 錯誤型態 | Jaccard | Dice | BFscore |
%[text] | --- | --- | --- | --- |
%[text] | 邊界雜訊 | 0.8851 | 0.9390 | **1.0000** |
%[text] | 膨脹 3px | 0.7706 | 0.8705 | 0.9500 |
%[text] | 侵蝕 3px | 0.7262 | 0.8414 | 0.9454 |
%[text] | 缺一角 | 0.6071 | 0.7556 | 0.6815 |
%[text] | **平移 5px** | 0.5152 | 0.6801 | **0.1802** |
%[text:table]
%[text] **三個指標的排序完全一致。**
%[text] > **這裡要誠實記錄一件事：我原本預期它們會給出相反的排序。**
%[text] > 第 17 章加分題量到過一次（Jaccard 0.4297／0.5169
%[text] > 對上 BFscore 0.7785／0.7193，排序相反），
%[text] > 所以我預期這裡也會。**沒有重現。**
%[text] **但「排序一致」不代表「可以互換」。** 看數值的落差：
%[text:table]
%[text] | 錯誤型態 | Jaccard | BFscore | 誰比較嚴厲 |
%[text] | --- | --- | --- | --- |
%[text] | **平移 5px** | 0.5152 | **0.1802** | **邊界指標嚴厲得多** |
%[text] | **缺一角** | 0.6071 | **0.6815** | **面積指標比較嚴厲** |
%[text:table]
%[text] **哪一個比較嚴格，取決於錯誤的型態：**
%[text] - **平移**讓每一段邊界都跑掉（BFscore 崩到 0.18），
%[text]   但大部分面積還是重疊的（Jaccard 還有 0.52）
%[text] - **缺一角**剛好相反：少掉的面積很大，
%[text]   但**剩下的邊界仍然精準貼合**
%[text] > **指標要照任務選：**
%[text] > - 量「東西在不在、有多大」→ IoU／Dice
%[text] > - 量「輪廓準不準」（切割路徑、量邊長）→ BFscore
%[text] > - **兩個都報，因為它們對不同的錯敏感**
%[text] **練習 1 會把這一節沒做到的事做完**：
%[text] 刻意設計「面積對但邊界爛」與「面積差但邊界好」兩種錯誤，
%[text] **成功讓 Jaccard 與 BFscore 給出相反的排序**
%[text] （Jaccard 0.72 vs 0.31、BFscore 0.41 vs 0.54）。
%[text] 所以正確的結論是：**指標會不會矛盾是程度問題**——
%[text] 錯誤型態越是只影響其中一個面向，它們越容易分歧。
%%
%[text] # 6. 實例分割：SOLOv2（有預訓練權重，可以直接用）
if ~hasSOLO
    disp("（沒有 SOLOv2 支援包，略過本節。）")
elseif ipcvFast()
    disp("（快速模式：略過 SOLOv2 推論。完整執行約 10 秒。）")
else
    solo = solov2("resnet50-coco");
    Ip = imread("visionteam.jpg");
    t = tic;
    [masks, labels, scores] = segmentObjects(solo, Ip);
    secSolo = toc(t);

    fprintf("\nSOLOv2：%.2f 秒，找到 %d 個物件\n", secSolo, numel(labels));
    for k = 1:numel(labels)
        fprintf("  %-12s 分數 %.3f、遮罩 %d 像素\n", ...
            string(labels(k)), scores(k), nnz(masks(:,:,k)));
    end

    overlay = Ip;
    cmap = lines(size(masks,3));
    for k = 1:size(masks,3)
        overlay = labeloverlay(overlay, masks(:,:,k), ...
            Colormap=cmap(k,:), Transparency=0.55);
    end
    figure
    imshow(overlay)
    title(sprintf("SOLOv2 實例分割：%d 個物件", numel(labels)))
    clear solo
end
%[text] 實測（`visionteam.jpg`）：
%[text] **7 個物件：6 個 `person` + 1 個 `frisbee`。**
%[text:table]
%[text] | 物件 | 分數 |
%[text] | --- | --- |
%[text] | person × 6 | 0.715 – 0.800 |
%[text] | **frisbee** | **0.533** |
%[text:table]
%[text] 這張影像裡有 6 個人（第 16 章已經確認過），
%[text] 所以**人全部找對了，而 `frisbee` 是誤判**——
%[text] 而且它的分數（0.533）明顯低於六個人（0.715 以上）。
%[text] > **這是第 19 章 §6「分數門檻」的分割版**：
%[text] > 門檻設在 0.6 就能濾掉那個誤判，
%[text] > 但那個門檻同樣是**你的決定**，不是模型的性質。
%[text] 注意實例分割的輸出是 **H×W×K 的邏輯陣列**（K 個物件各一張遮罩），
%[text] 和語意分割的「一張 categorical 圖」完全不同。
%[text] **要數數量、要分辨「哪一個是哪一個」，就得用實例分割。**
%%
%[text] # 7. 語意分割的架構——以及一個必須說清楚的限制
%[text] `unet` 與 `deeplabv3plus` 建立的是**未訓練的架構**：
netU = unet([64 64 3], 2);
fprintf("\nunet([64 64 3], 2)：%s，%d 層\n", class(netU), numel(netU.Layers));

% **deeplabv3plus 的輸入尺寸有下限**，因為它的編碼器是 ImageNet 骨幹。
% 傳 [64 64 3] 會報：
%   The first two values of imageSize must be greater than or equal to
%   [224 224] for resnet18.
try
    netD = deeplabv3plus([64 64 3], 2, "resnet18");
    fprintf("deeplabv3plus [64 64 3]：竟然可以？\n");
    clear netD
catch ME
    fprintf("deeplabv3plus [64 64 3] 失敗：%s\n", ...
        extractBefore(ME.message + " ", min(90, strlength(ME.message)+1)));
end
netD = deeplabv3plus([224 224 3], 2, "resnet18");
fprintf("deeplabv3plus [224 224 3] + resnet18：%s，%d 層\n", ...
    class(netD), numel(netD.Layers));
clear netU netD

hasPre = contains(string(help("deeplabv3plus")), "pretrained", IgnoreCase=true);
fprintf("deeplabv3plus 的說明文件提到 pretrained？%s\n", string(hasPre));
segAddons = addons.Name(contains(addons.Name, ...
    ["Segmentation" "DeepLab" "Semantic"], IgnoreCase=true));
fprintf("已安裝的分割相關支援包：%s\n", ...
    ternaryStr(isempty(segAddons), "(只有 SOLOv2 實例分割)", ...
        strjoin(string(segAddons), " | ")));
%[text] > **這就是本章和第 18、19 章最大的不同。**
%[text] > 分類有 `imagePretrainedNetwork`，偵測有 `yoloxObjectDetector("small-coco")`，
%[text] > **語意分割什麼都沒有**——你只能自己訓練。
%[text] 兩個架構的差別：
%[text:table]
%[text] | | `unet` | `deeplabv3plus` |
%[text] | --- | --- | --- |
%[text] | 結構 | 編碼-解碼 + skip connection | 編碼器 + 空洞卷積金字塔 |
%[text] | 骨幹 | 自己的（可從零訓練） | **用預訓練分類骨幹**（resnet18 等） |
%[text] | 適合 | 資料少、領域特殊（醫學、工業） | 資料多、領域接近自然影像 |
%[text] | 參數量 | 較少 | 較多 |
%[text:table]
%[text] **`deeplabv3plus` 能間接用到預訓練權重**——
%[text] 它的編碼器是 ImageNet 骨幹。這是第 18 章遷移學習的延伸：
%[text] **骨幹可以遷移，解碼器要從零學。**
%[text] ## 7.1 用預訓練骨幹是有代價的：輸入尺寸有下限
%[text] 上面的輸出顯示 `deeplabv3plus([64 64 3], 2, "resnet18")` **會報錯**：
%[text] > `The first two values of imageSize must be greater than or equal`
%[text] > `to [224 224] for resnet18.`
%[text] 原因是 ImageNet 骨幹有固定的下採樣次數；輸入太小的話，
%[text] 最深的特徵圖會小於一個像素。
%[text] **這對本章的資料是一個實際的問題。**
%[text] `triangleImages` 的原圖只有 **32×32**。要用 `deeplabv3plus`
%[text] 就得把它放大 7 倍到 224×224——
%[text] **放大不會增加任何資訊，只會增加 49 倍的計算量。**
%[text:table]
%[text] | | `unet` | `deeplabv3plus` |
%[text] | --- | --- | --- |
%[text] | 32×32 的小圖 | ✅ 直接可用 | ❌ 必須放大到 224×224 |
%[text] | 能用預訓練骨幹 | ❌ | ✅ |
%[text:table]
%[text] > **所以「用預訓練骨幹」不是無條件的優勢。**
%[text] > 影像本身就很小的時候（工業檢測的裁切、醫學影像的 patch），
%[text] > `unet` 從零訓練反而更合理——
%[text] > 這和第 18 章「最小的骨幹可能最好」是同一類判斷。
%%
%[text] # 8. 語意分割的訓練流程（程式碼完整，不執行）
%[text] 先用第 17 章的方式組資料管線。
imdsTrain = imageDatastore(fullfile(triDir, "trainingImages"));
pxdsTrain = pixelLabelDatastore(fullfile(triDir, "trainingLabels"), ...
    classNames, labelIDs);

% 影像與標籤必須同步變換（第 17 章 §5）
dsTrain = ch17_buildPipeline(imdsTrain, pxdsTrain, ...
    OutputSize=[64 64], Augment=true);
dsVal = ch17_buildPipeline(imdsTest, pxdsTest, ...
    OutputSize=[64 64], Augment=false);

out = read(dsTrain);
fprintf("\n訓練管線輸出：影像 %s、標籤 %s\n", ...
    mat2str(size(out{1})), class(out{2}));

[netSeg, segInfo] = ch20_trainSemantic(dsTrain, dsVal, classNames, ...
    DoTrain=false, Architecture="unet", InputSize=[64 64 3], ...
    MaxEpochs=20, MiniBatchSize=8);
clear netSeg
%[text] **分割訓練與分類／偵測訓練的三個差異**
%[text] **① 標籤是一整張圖。** 每個像素都要算一次 loss，
%[text] 所以記憶體與計算量都大得多。
%[text] **② 類別不平衡是常態，而且很極端。**
%[text] 前景只佔 4.62%（真實場景常常不到 1%）。
%[text] **不加權的 cross-entropy 會讓模型直接全部預測背景**——
%[text] 而 §3 證明了那樣的模型 GlobalAccuracy 有 95.4%。
%[text] 所以 `ClassWeights` 幾乎是必要的。上面用的是**逆頻率加權**
%[text] （稀有類別權重大），看印出來的權重值。
%[text] > **但權重本身也是超參數。** 權重太大會讓模型過度預測前景，
%[text] > precision 崩潰。它要調，不是設了就好。
%[text] **③ 評估要看逐類別的 IoU**（§3 的結論）。
%%
%[text] # 9. R2026a 注意事項
%[text] 1. **語意分割沒有可直接推論的預訓練權重。**
%[text]    `unet`／`deeplabv3plus` 只給未訓練的架構。
%[text]    實例分割**有**（`solov2("resnet50-coco")`）。
%[text] 2. **`maskrcnn` 需要 Mask R-CNN 支援包**（本機未安裝），
%[text]    所以實例分割用 SOLOv2。
%[text] 3. `evaluateSemanticSegmentation` 的結果物件有
%[text]    `DataSetMetrics`、`ClassMetrics`、`ImageMetrics`、`ConfusionMatrix`。
%[text]    **逐類別的 IoU 在 `ClassMetrics`，那是唯一不會騙人的欄位。**
%[text] 4. **`MeanBFScore` 會靜默跳過 NaN。** 某個類別完全沒被預測時
%[text]    它的 BFScore 是 NaN，而平均值照算不誤。
%[text] 5. 實例分割的輸出是 **H×W×K 邏輯陣列**，
%[text]    語意分割是**一張 categorical 圖**，兩者不能混用。
%[text] 6. `pixelLabelDatastore` 的 `read` 回傳 **cell**（第 17 章 §2.2）。
%[text] 7. 每個載入的模型都佔顯示記憶體，用完要 `clear`（第 17 章 §10.1）。
%%
%[text] # 10. 常見陷阱
%[text] 1. **報 GlobalAccuracy** → §3：什麼都不預測就有 95.4%。
%[text] 2. **報 WeightedIoU** → 同樣被像素數支配（0.91）。
%[text] 3. **報 MeanBFScore 卻沒看逐類別** → 0.90，而前景是 NaN。
%[text] 4. **同時報 IoU 和 Dice 以為是兩個證據** → 它們是同一個量的單調變換。
%[text] 5. **只用面積指標評估輪廓任務** → §5：平移 5px 的 Jaccard 還有 0.52，
%[text]    BFscore 只剩 0.18。
%[text] 6. **不加類別權重** → 模型直接全部預測背景。
%[text] 7. **權重加太大** → 過度預測前景，precision 崩潰。
%[text] 8. **用語意分割數數量** → 相鄰物件會黏成一個。
%[text] 9. **擴增時影像與標籤不同步** → 第 17 章 §5，不報錯但結果是垃圾。
%[text] 10. **以為語意分割也有預訓練權重可以直接推論** → 沒有。
%%
%[text] # 11. 本章小結
%[text:table]
%[text] | 主題 | 一句話 |
%[text] | --- | --- |
%[text] | **類別不平衡** | **什麼都不預測 → GlobalAccuracy 95.4%、前景 IoU 0** |
%[text] | 該報哪個指標 | **逐類別的 IoU**，其他摘要都會被多數類支配 |
%[text] | IoU vs Dice | 單調變換，**報兩個等於報一個** |
%[text] | 面積 vs 邊界 | 排序這次一致，但**數值差很多**（0.52 vs 0.18） |
%[text] | 實例分割 | SOLOv2 有預訓練權重；6 人全中 + 1 個 frisbee 誤判 |
%[text] | **語意分割** | **沒有預訓練權重，只能自己訓練** |
%[text] | 訓練 | 標籤是整張圖、必須加類別權重、看逐類別 IoU |
%[text:table]
%[text] 本章有一個**預期落空**的實驗（§5 的指標排序），
%[text] 它留在教材裡是因為「預期落空」本身就是結論的一部分：
%[text] > **第 17 章量到過一次排序相反，這裡沒有。
%[text] > 所以正確的說法是「指標可能給出相反排序」，
%[text] > 不是「一定會」——而這正是為什麼要兩個都報。**
%%
%[text] # 12. 練習
%[text] 練習在 `exercise/Ch20_Exercise.m`。
%%
%[text] # 13. 延伸閱讀與下一章
%[text] - `doc unet` / `doc deeplabv3plus` — 語意分割架構
%[text] - `doc solov2` / `doc segmentObjects` — 實例分割
%[text] - `doc evaluateSemanticSegmentation` — 注意 `ClassMetrics`
%[text] - `doc bfscore` — 邊界指標與它的容差參數
%[text] **第 21 章**（視覺語言模型）需要 OpenAI CLIP 與 Moondream 支援包，
%[text] 本機尚未安裝。**第 22 章**的工業瑕疵檢測會回到本章的
%[text] 「前景不到 1%」問題，並用異常偵測的角度重新處理它。

function s = ternaryStr(c, a, b)
if c, s = a; else, s = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
