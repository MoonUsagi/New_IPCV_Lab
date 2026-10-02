%[text] # 第 20 章　練習解答
%[text] 語意分割與實例分割
assert(exist("ch20_trivialBaseline","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

vd = fullfile(toolboxdir("vision"), "visiondata");
triDir = fullfile(vd, "triangleImages");
classNames = ["triangle" "background"];
labelIDs   = [255 0];

dI = dir(fullfile(triDir, "testImages", "*.jpg"));
dL = dir(fullfile(triDir, "testLabels", "*.png"));
L1 = imread(fullfile(dL(1).folder, dL(1).name));
gtMask = imresize(L1 == 255, 8, Method="nearest");
%%
%[text] # 解答 1：找出讓排序相反的錯誤型態
%[text] 主教材的五種錯誤排序一致。**關鍵是要刻意分離「面積」與「邊界」。**
%[text] 設計兩種對立的錯誤：
%[text] - **A：面積幾乎對，但邊界爛** → 正確區域 + 大量小碎點
%[text] - **B：面積差一半，但邊界完美** → 只留下半部，邊界原封不動
% 雜訊密度是關鍵：太低的話 BFscore 還沒掉到 B 以下，排序就不會翻。
% 實測 0.002 與 0.004 都不翻，**0.006 以上才翻**。這裡用 0.008。
maskA = gtMask;
noise = rand(size(gtMask)) < 0.008;      % 散布的小碎點
maskA = maskA | (noise & ~imdilate(gtMask, strel("disk",6)));

maskB = gtMask;
[r, ~] = find(gtMask);
maskB(min(r):round((min(r)+max(r))/2), :) = false;   % 砍掉上半

names2 = ["A 面積對、邊界爛（碎點）"; "B 面積差一半、邊界完美"];
masks2 = {maskA, maskB};
J2 = zeros(2,1); D2 = zeros(2,1); B2 = zeros(2,1);
fprintf("\n%-28s %10s %10s %10s\n", "錯誤型態", "Jaccard", "Dice", "BFscore");
for k = 1:2
    J2(k) = jaccard(masks2{k}, gtMask);
    D2(k) = dice(masks2{k}, gtMask);
    B2(k) = bfscore(masks2{k}, gtMask);
    fprintf("%-28s %10.4f %10.4f %10.4f\n", names2(k), J2(k), D2(k), B2(k));
end

flipped = (J2(1) > J2(2)) ~= (B2(1) > B2(2));
fprintf("\nJaccard 認為 %s 比較好\n", names2(1 + (J2(2) > J2(1))));
fprintf("BFscore 認為 %s 比較好\n", names2(1 + (B2(2) > B2(1))));
fprintf("**排序相反？%s**\n", string(flipped));

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(gtMask); title("正確答案")
nexttile; imshow(maskA); title(sprintf("A：J=%.3f B=%.3f", J2(1), B2(1)))
nexttile; imshow(maskB); title(sprintf("B：J=%.3f B=%.3f", J2(2), B2(2)))
%[text] ## 量到的結果——**排序真的翻轉了**
%[text:table]
%[text] | 錯誤型態 | Jaccard | Dice | BFscore |
%[text] | --- | --- | --- | --- |
%[text] | **A：面積對、邊界爛（碎點）** | **0.7203** | 0.8374 | 0.4122 |
%[text] | **B：面積差一半、邊界完好** | 0.3095 | 0.4727 | **0.5436** |
%[text:table]
%[text] **Jaccard 說 A 好（0.72 vs 0.31，差 2.3 倍）；
%[text] BFscore 說 B 好（0.54 vs 0.41）。完全相反。**
%[text] > **主教材 §5 沒找到的東西，在這裡找到了。**
%[text] > 差別在於主教材的五種錯誤都同時影響面積與邊界；
%[text] > 這一題**刻意把兩者分開**：碎點幾乎不動面積但毀掉邊界，
%[text] > 砍一半毀掉面積但保留邊界。
%[text] 順帶記錄一個調校過程：雜訊密度是關鍵。
%[text:table]
%[text] | 雜訊密度 | Jaccard | BFscore | 排序相反？ |
%[text] | --- | --- | --- | --- |
%[text] | 0.002 | 0.9087 | 0.7305 | ✗ |
%[text] | 0.004 | 0.8437 | 0.5951 | ✗ |
%[text] | **0.006** | 0.7832 | 0.4959 | **✓** |
%[text] | 0.008 | 0.7203 | 0.4122 | ✓ |
%[text:table]
%[text] **密度要夠大，BFscore 才會掉到 B 以下。**
%[text] 這也說明「指標會不會給出相反排序」**是一個程度問題**，
%[text] 不是有或沒有。
%[text] **第 4 小題：什麼樣的模型缺陷會產生這兩種錯誤？**
%[text:table]
%[text] | 錯誤型態 | 對應的真實缺陷 |
%[text] | --- | --- |
%[text] | **A：碎點** | 模型**沒有後處理**（沒有 `bwareaopen`／CRF），或門檻設太低。逐像素分類器很容易產生這種孤立的誤判 |
%[text] | **B：只對一半** | 模型**漏檢了一部分結構**——例如物體有兩種外觀，而訓練資料只涵蓋一種 |
%[text:table]
%[text] **第 5 小題：怎麼選指標？**
%[text] 這兩種錯誤**需要完全不同的補救**：
%[text] - A 的補救是**後處理**（移除小連通區），很便宜
%[text] - B 的補救是**補訓練資料**，很貴
%[text] 若你只看 BFscore，A 會看起來很糟而 B 看起來還好——
%[text] 你會去花大錢補資料，而真正的問題只要一行 `bwareaopen`。
%[text] 若你只看 Jaccard，結論剛好相反。
%[text] > **所以答案不是「選一個」，是「兩個都看，而且看它們不一致的地方」。**
%[text] > 兩個指標一致時，結論可靠；
%[text] > **不一致時，那個不一致本身告訴你錯誤的型態。**
%%
%[text] # 解答 2：古典門檻分割當基準
%[text] `triangleImages` 是暗三角形配亮背景，門檻法應該很有效。
pxdsGT = pixelLabelDatastore(fullfile(triDir,"testLabels"), classNames, labelIDs);

outDir = fullfile(tempdir, "ch20_thresh");
if isfolder(outDir), rmdir(outDir,"s"); end
mkdir(outDir);
for k = 1:numel(dI)
    I = imread(fullfile(dI(k).folder, dI(k).name));
    if size(I,3) > 1, I = im2gray(I); end
    bw = ~imbinarize(I);                 % 三角形是暗的，所以取反
    [~, nm] = fileparts(dL(k).name);
    imwrite(uint8(bw)*255, fullfile(outDir, nm + ".png"));
end
pxdsThresh = pixelLabelDatastore(outDir, classNames, labelIDs);
mThresh = evaluateSemanticSegmentation(pxdsThresh, pxdsGT, Verbose=false);

ws = warning("off", "ch20_trivialBaseline:misleadingMetrics");
mTriv = ch20_trivialBaseline(pxdsGT, classNames, labelIDs);
warning(ws);

fprintf("\n%-16s %16s %10s %18s\n", "方法", "GlobalAccuracy", "MeanIoU", "triangle 的 IoU");
fprintf("%-16s %16.4f %10.4f %18.4f\n", "全部猜背景", ...
    mTriv.DataSetMetrics.GlobalAccuracy, mTriv.DataSetMetrics.MeanIoU, ...
    mTriv.ClassMetrics.IoU(1));
fprintf("%-16s %16.4f %10.4f %18.4f\n", "門檻分割", ...
    mThresh.DataSetMetrics.GlobalAccuracy, mThresh.DataSetMetrics.MeanIoU, ...
    mThresh.ClassMetrics.IoU(1));
%[text] 量到的結果：
%[text:table]
%[text] | 方法 | GlobalAccuracy | MeanIoU | **triangle 的 IoU** |
%[text] | --- | --- | --- | --- |
%[text] | 全部猜背景 | 0.9538 | 0.4769 | **0.0000** |
%[text] | 門檻分割 | 0.9709 | 0.6930 | **0.4158** |
%[text:table]
%[text] **第 4 小題：哪個指標最能反映「第二個方法真的有用」？**
%[text] **`triangle` 的 IoU。** 它從 0 變成一個實際的數字，
%[text] 而 GlobalAccuracy 只從 0.95 動到 0.9x——
%[text] **一個把任務從「完全沒做」變成「大致做對」的改進，
%[text] 在 GlobalAccuracy 上只反映幾個百分點。**
%[text] **第 5 小題：這個任務需要深度學習嗎？——答案比我預期的微妙。**
%[text] 我原本預期門檻法會拿到 0.9 以上的 IoU（純色三角形配純色背景，
%[text] Otsu 的理想情況），然後結論會是「這個任務不需要深度學習」。
%[text] **實測是 0.4158——遠低於預期。**
%[text] 為什麼？因為影像有**雜訊與模糊的邊緣**
%[text] （`triangleImages` 的三角形邊緣是抗鋸齒的灰階過渡），
%[text] 而 Otsu 只能切一條水平線，切不出乾淨的輪廓。
%[text] 所以正確的結論是：
%[text:table]
%[text] | 方法 | triangle IoU | 評價 |
%[text] | --- | --- | --- |
%[text] | 全部猜背景 | 0.0000 | 完全沒做事 |
%[text] | 門檻分割 | 0.4158 | **有做事，但不夠好** |
%[text] | 深度學習 | ? | **本章沒訓練，等換機器驗證** |
%[text:table]
%[text] **門檻法把任務從「完全沒做」推到「做了一半」，
%[text] 所以深度學習在這裡確實有空間**——
%[text] 但要證明那個空間有多大，必須真的訓練一次。
%[text] > **這一題原本要說「教學資料集太簡單」，
%[text] > 結果量出來沒那麼簡單。** 預設立場又一次被數據修正。
%[text] 什麼樣的影像會讓門檻法失效？
%[text:table]
%[text] | 情況 | 為什麼門檻法會壞 |
%[text] | --- | --- |
%[text] | **照明不均** | 同一個灰階值在畫面不同位置代表不同的東西（第 2 章量過） |
%[text] | **前景與背景灰階重疊** | 直方圖沒有雙峰，沒有門檻能切開 |
%[text] | **需要語意才能分辨** | 「這塊灰色是路面還是屋頂」——**灰階值一樣** |
%[text:table]
%[text] **第三種才是深度學習真正不可取代的地方。**
%%
%[text] # 解答 3：BFscore 的容差參數
tols = [1 2 3 5 8];
variants = struct("name",{},"mask",{});
variants(end+1) = struct("name","膨脹 3px", "mask", imdilate(gtMask, strel("disk",3)));
variants(end+1) = struct("name","侵蝕 3px", "mask", imerode(gtMask, strel("disk",3)));
variants(end+1) = struct("name","平移 5px", "mask", imtranslate(gtMask,[5 5]));
variants(end+1) = struct("name","缺一角",   "mask", cutTop(gtMask, 0.3));

bfMat = zeros(numel(variants), numel(tols));
fprintf("\n%-12s", "錯誤型態");
fprintf("%10s", "容差=" + string(tols)); fprintf("\n");
for k = 1:numel(variants)
    fprintf("%-12s", variants(k).name);
    for t = 1:numel(tols)
        bfMat(k,t) = bfscore(variants(k).mask, gtMask, tols(t));
        fprintf("%10.4f", bfMat(k,t));
    end
    fprintf("\n");
end

figure
plot(tols, bfMat.', "o-", LineWidth=1.8)
legend(string({variants.name}), Location="southeast")
xlabel("容差（像素）"); ylabel("BFscore"); grid on
title("BFscore 對容差的敏感度")

sens = max(bfMat,[],2) - min(bfMat,[],2);
[~, iMost] = max(sens);
fprintf("\n對容差最敏感的是「%s」（變化 %.4f）\n", ...
    variants(iMost).name, sens(iMost));
%[text] 量到的結果：
%[text:table]
%[text] | 錯誤型態 | 容差 1 | 容差 2 | 容差 3 | 容差 5 | 容差 8 |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | 膨脹 3px | **0.0000** | **0.0000** | **1.0000** | 1.0000 | 1.0000 |
%[text] | 侵蝕 3px | **0.0000** | **0.0000** | **1.0000** | 1.0000 | 1.0000 |
%[text] | 平移 5px | 0.0219 | 0.0656 | 0.1858 | 0.2650 | 1.0000 |
%[text] | 缺一角 | 0.6545 | 0.6694 | 0.6815 | 0.7057 | 0.8478 |
%[text:table]
%[text] **第 4、5 小題**
%[text] **膨脹與侵蝕對容差最敏感，而且是階梯函數**：
%[text] 容差 2 時 BFscore 是 **0**，容差 3 時直接跳到 **1.0**。
%[text] 原因很乾淨：膨脹 3 像素讓**每一個**邊界點都剛好偏離 3 像素。
%[text] 容差 < 3 → 一個都不算對；容差 ≥ 3 → 全部算對。
%[text] **沒有中間狀態。**
%[text] 平移的曲線反而比較平緩（0.02 → 1.0），因為平移會讓
%[text] 邊界的**不同部位偏離不同的距離**（平行的邊偏得少、垂直的偏得多）。
%[text] 缺一角最不敏感（0.65 → 0.85）——它的大部分邊界是**完全正確**的，
%[text] 只有新切出來的那一條是錯的，而那一條無論容差多大都配不到。
%[text] > **一個指標的「敏感度」不只取決於誤差大小，
%[text] > 更取決於誤差的空間結構是否均勻。**
%[text] **容差該怎麼選？由任務的精度需求決定：**
%[text:table]
%[text] | 任務 | 合理的容差 |
%[text] | --- | --- |
%[text] | 切割路徑規劃 | 1–2 像素（換算成實際尺寸要夠小） |
%[text] | 面積量測 | 容差不重要，改用 IoU |
%[text] | 粗略定位 | 5–10 像素都可以 |
%[text:table]
%[text] > **和第 11 章的尺度校正、第 19 章的 IoU 門檻是同一類問題：
%[text] > 預設值不是中立的選擇，它只是一個預設值。**
%[text] 而且**容差的單位是像素**，所以它和影像解析度綁在一起——
%[text] 換一台相機就要重新換算（第 11 章的「校正指紋」原則）。
%%
%[text] # 解答 4：實例分割 → 語意分割的資訊損失
addons = matlab.addons.installedAddons;
hasSOLO = any(contains(addons.Name, "SOLOv2"));
if ~hasSOLO || ipcvFast()
    disp("（沒有 SOLOv2 支援包或處於快速模式，略過本題的推論部分。）")
else
    solo = solov2("resnet50-coco");
    Ip = imread("visionteam.jpg");
    [masks, labels, scores] = segmentObjects(solo, Ip);
    clear solo

    keep = string(labels) == "person";
    pMasks = masks(:,:,keep);
    fprintf("\nSOLOv2 找到 %d 個 person（總共 %d 個物件）\n", ...
        nnz(keep), numel(labels));

    % 合併成一張語意圖
    semantic = any(pMasks, 3);
    cc = bwconncomp(semantic);
    fprintf("實例分割：%d 個物件\n", size(pMasks,3));
    fprintf("合併成語意圖後，bwconncomp 數到：**%d 個連通分量**\n", cc.NumObjects);
    fprintf("**資訊損失：%d 個物件被黏在一起**\n", ...
        size(pMasks,3) - cc.NumObjects);

    figure
    tiledlayout(1,2, TileSpacing="compact")
    nexttile
    ov = Ip; cm = lines(size(pMasks,3));
    for k = 1:size(pMasks,3)
        ov = labeloverlay(ov, pMasks(:,:,k), Colormap=cm(k,:), Transparency=0.55);
    end
    imshow(ov); title(sprintf("實例分割：%d 個", size(pMasks,3)))
    nexttile
    imshow(labeloverlay(Ip, semantic, Transparency=0.55));
    title(sprintf("合併後的語意圖：數到 %d 個", cc.NumObjects))
end
%[text] 量到的結果：**6 個 person 實例 → 合併後 6 個連通分量，0 個被黏住。**
%[text] `visionteam.jpg` 裡的人彼此沒有接觸，所以這一次沒有資訊損失。
%[text] **但這是這張影像的性質，不是通則。**
%[text] 把同一段程式碼換到人群、貨架、細胞影像上，
%[text] 合併後的連通分量會遠少於實例數。
%[text] > **「這次沒發生」不等於「不會發生」**——
%[text] > 要說某個做法安全，必須說清楚它依賴什麼條件。
%[text] **第 4 小題：什麼情況下語意分割數得出正確的數量？**
%[text] **物件彼此不相鄰的時候。** 只要兩個同類物件在影像上接觸
%[text] （或被同一個遮罩連起來），連通分量就會把它們算成一個。
%[text] **第 5 小題：語意分割 + 分水嶺可以嗎？**
%[text] 可以，但代價是**你需要好的標記（marker）**。
%[text] 第 11 章已經處理過這件事：分水嶺的品質完全取決於標記的品質，
%[text] 而**產生好的標記本身就是一個難題**
%[text] （距離轉換的局部極大值對雜訊很敏感）。
%[text:table]
%[text] | 做法 | 優點 | 代價 |
%[text] | --- | --- | --- |
%[text] | 實例分割 | 直接給出每個物件 | 模型較複雜、較慢 |
%[text] | 語意分割 + 分水嶺 | 模型簡單 | **標記難產生**，形狀不規則時容易切錯 |
%[text:table]
%[text] > **要數數量、要追蹤個體，用實例分割。**
%[text] > 語意分割適合「這一區是什麼」而不是「這裡有幾個」。
%%
%[text] # 解答 5：語意分割的訓練設定（不執行）
imdsTrain = imageDatastore(fullfile(triDir, "trainingImages"));
pxdsTrain = pixelLabelDatastore(fullfile(triDir, "trainingLabels"), ...
    classNames, labelIDs);
imdsTest = imageDatastore(fullfile(triDir, "testImages"));
dsTrain = ch17_buildPipeline(imdsTrain, pxdsTrain, OutputSize=[64 64], Augment=true);
dsVal   = ch17_buildPipeline(imdsTest, pxdsGT, OutputSize=[64 64], Augment=false);

fprintf("\n--- unet（可用 64x64）---\n");
[~, infoU] = ch20_trainSemantic(dsTrain, dsVal, classNames, ...
    DoTrain=false, Architecture="unet", InputSize=[64 64 3]);

fprintf("\n--- deeplabv3plus（輸入下限 224x224，見主教材 §7.1）---\n");
dsTrain224 = ch17_buildPipeline(imdsTrain, pxdsTrain, OutputSize=[224 224], Augment=true);
dsVal224   = ch17_buildPipeline(imdsTest, pxdsGT, OutputSize=[224 224], Augment=false);
[~, infoD] = ch20_trainSemantic(dsTrain224, dsVal224, classNames, ...
    DoTrain=false, Architecture="deeplabv3plus", InputSize=[224 224 3]);
%%
%[text] ## 第 3 小題：類別權重的三種設法
fprintf("\n%-22s %-22s %s\n", "設法", "權重", "預期效果");
fprintf("%-22s %-22s %s\n", "auto（逆頻率）", ...
    mat2str(round(infoU.ClassWeights,3)), "前景權重大，模型會努力找三角形");
fprintf("%-22s %-22s %s\n", "全部 1", "[1 1]", ...
    "模型會傾向全部猜背景（主教材 §3 的那個基準）");
fprintf("%-22s %-22s %s\n", "前景再加重 5 倍", ...
    mat2str(round([infoU.ClassWeights(1)*5 infoU.ClassWeights(2)],3)), ...
    "過度預測前景");
%[text] **權重太大的預期症狀**：
%[text] 模型為了不漏掉前景，會把很多背景也標成前景——
%[text] **recall 上升、precision 下降**，
%[text] 而在分割上這表現為「遮罩比真實物件胖一圈」。
%[text] 用主教材 §5 的語言：那是**膨脹型**的錯誤，
%[text] 所以 Jaccard 與 BFscore 都會掉，但不會崩潰。
%[text] > **權重是一個要調的超參數，不是設了就對。**
%[text] > 它的作用是把 loss 從「像素數」重新加權成「你在乎的東西」，
%[text] > 而「你在乎多少」沒有客觀答案。
%%
%[text] ## 第 4 小題：確認影像與標籤同步
reset(dsTrain);
maxOff = 0;
for k = 1:10
    d = read(dsTrain);
    Ik = im2double(d{1});
    Lk = d{2} == "triangle";
    if ~any(Lk(:)), continue, end
    fg = Ik < graythresh(Ik);
    if ~any(fg(:)), continue, end
    sL = regionprops(Lk, "Centroid");
    sI = regionprops(fg, "Centroid");
    if isempty(sL) || isempty(sI), continue, end
    cL = sL(1).Centroid;
    cents = reshape([sI.Centroid], 2, []).';
    maxOff = max(maxOff, min(vecnorm(cents - cL, 2, 2)));
end
fprintf("\n影像前景與標籤質心的最大偏差 = %.2f 像素\n", maxOff);
if maxOff < 5
    fprintf("**影像與標籤同步。**\n");
else
    fprintf("**警告：可能不同步。**\n");
end
%[text] **第 5 小題：換機器後要驗證的清單**
%[text] 1. `unet` 能不能在 64×64 上訓練完並收斂
%[text] 2. `deeplabv3plus` 在 224×224 上的記憶體需求（放大 12 倍的像素量）
%[text] 3. **訓練後 `triangle` 的 IoU**——和練習 2 的門檻法比較
%[text]    （**若深度學習輸給門檻法，那是重要的結果，要記錄下來**）
%[text] 4. 類別權重 `auto` vs `[1 1]` 的實際差別
%[text]    （預期：`[1 1]` 會退化成全部猜背景）
%[text] 5. 兩種架構的訓練時間與最終 IoU
%[text] 6. 主教材 §5 的指標比較，換成**真實模型的輸出**再做一次
%%
%[text] # 解答 6：SAM 2 當類別無關的分割器
hasSAM = any(contains(addons.Name, "Segment Anything"));
if ~hasSAM || ipcvFast()
    disp("（沒有 SAM 支援包或處於快速模式，略過。）")
else
    I1 = imread(fullfile(dI(1).folder, dI(1).name));
    Ibig = repmat(imresize(I1, 8, Method="nearest"), 1, 1, 3);
    t = tic;
    segOut = imsegsam(Ibig);
    fprintf("\nimsegsam %.1f 秒\n", toc(t));

    % **imsegsam 回傳的不是遮罩陣列，是一個 bwconncomp 風格的 struct**
    % （欄位：Connectivity / ImageSize / NumObjects / PixelIdxList）。
    % 直接拿去 jaccard 會報「Instead its type was struct」。
    fprintf("回傳 class = %s，欄位 %s\n", class(segOut), ...
        strjoin(string(fieldnames(segOut))', ", "));
    nM = segOut.NumObjects;
    fprintf("SAM 一共產生 %d 個遮罩\n", nM);

    % 從 PixelIdxList 重建每一張遮罩
    masksSAM = false([segOut.ImageSize nM]);
    for k = 1:nM
        m = false(segOut.ImageSize);
        m(segOut.PixelIdxList{k}) = true;
        masksSAM(:,:,k) = m;
    end

    % --- 規則 A（會作弊）：挑與 GT 的 IoU 最大的 ---
    ious = zeros(nM,1);
    for k = 1:nM
        ious(k) = jaccard(masksSAM(:,:,k), gtMask);
    end
    [bestIoU, iBest] = max(ious);

    % --- 規則 B（不看 GT）：挑「最暗」的那個遮罩 ---
    G = im2double(im2gray(Ibig));
    meanInt = zeros(nM,1);
    for k = 1:nM
        m = masksSAM(:,:,k);
        if nnz(m) < 50 || nnz(m) > 0.5*numel(m)
            meanInt(k) = Inf;          % 太小或太大的直接排除
        else
            meanInt(k) = mean(G(m));
        end
    end
    [~, iDark] = min(meanInt);

    fprintf("\n%-26s %10s %10s %10s\n", "挑選規則", "Jaccard", "Dice", "BFscore");
    fprintf("%-26s %10.4f %10.4f %10.4f\n", "A 挑 IoU 最大（作弊）", ...
        bestIoU, dice(masksSAM(:,:,iBest), gtMask), ...
        bfscore(masksSAM(:,:,iBest), gtMask));
    fprintf("%-26s %10.4f %10.4f %10.4f\n", "B 挑最暗的（不看 GT）", ...
        jaccard(masksSAM(:,:,iDark), gtMask), ...
        dice(masksSAM(:,:,iDark), gtMask), ...
        bfscore(masksSAM(:,:,iDark), gtMask));
end
%[text] 量到的結果（SAM 2 產生 **41 個**遮罩，耗時約 90–170 秒）：
%[text:table]
%[text] | 挑選規則 | Jaccard | Dice | BFscore |
%[text] | --- | --- | --- | --- |
%[text] | A 挑 IoU 最大（**作弊**） | 0.0952 | 0.1739 | 0.2379 |
%[text] | B 挑最暗的（不看 GT） | 0.0476 | 0.0909 | 0.1801 |
%[text:table]
%[text] **兩個都很糟——連作弊的上限都只有 0.095。**
%[text] 這和第 17 章加分題一致（那裡 SAM 用**人工的框**當提示，
%[text] Jaccard 上限也只有 0.5169）。這裡是全自動分割，沒有提示，
%[text] 所以更差。
%[text] > **基礎模型在它的訓練分布之外會安靜地退化。**
%[text] > 放大 8 倍的合成三角形（階梯狀邊緣、無紋理、純色）
%[text] > 離 SAM 的訓練資料（自然照片）太遠。
%[text] > 這和第 12 章「預設 NIQE 在工業影像上把好壞排反」是同一件事。
%[text] 順帶一提，**`imsegsam` 在這張 256×256 的小圖上花了 90–170 秒**，
%[text] 而練習 2 的門檻法是毫秒等級且 IoU 有 0.4158。
%[text] **這個任務上，Otsu 完勝 SAM 2。**
%[text] **第 5 小題：「挑出正確的遮罩」算不算作弊？**
%[text] **用 GT 來挑，就是作弊。**
%[text] 規則 A 量到的是「**SAM 產生的所有遮罩裡，最好的那個有多好**」，
%[text] 那是一個**上限**，不是這條流程的效能。
%[text] 真實使用時沒有 GT 可以挑，所以必須有一個不看答案的規則——
%[text] 規則 B（挑最暗的）就是一個例子。**兩者的差距就是
%[text] 「挑選規則」這一步的成本。**
%[text] > **這和第 17 章加分題的誤差分解是同一個手法**：
%[text] > 把「上限」與「實際」分開量，差距就是中間那一步的貢獻。
%[text] 而這也是第 16 章練習 3、第 19 章練習 1 的同一個原則：
%[text] **任何用到測試集答案的步驟，都會讓評估失真。**
%%
%[text] # 加分題：不平衡程度 vs 指標可信度
%[text] 合成一系列不同前景比例的標籤，量「全部猜背景」的分數。
fgPct = [0.5 1 2 5 10 20 35 50];
gAcc = zeros(size(fgPct));
mIoU = zeros(size(fgPct));
wIoU = zeros(size(fgPct));

sz = [128 128];
for k = 1:numel(fgPct)
    nFg = round(fgPct(k)/100 * prod(sz));
    L = zeros(sz, "uint8");
    L(1:nFg) = 255;                       % 前景像素
    % 全部猜背景 => 混淆矩陣可直接算
    tp = 0;  fn = nFg;                    % 前景：全部漏掉
    tn = prod(sz) - nFg;  fp = 0;         % 背景：全對
    gAcc(k) = (tp + tn) / prod(sz);
    iouFg = tp / max(tp + fp + fn, 1);
    iouBg = tn / max(tn + fn + fp, 1);
    mIoU(k) = (iouFg + iouBg)/2;
    wIoU(k) = (nFg*iouFg + tn*iouBg) / prod(sz);
end

fprintf("\n%-10s %16s %10s %12s\n", "前景比例", "GlobalAccuracy", "MeanIoU", "WeightedIoU");
for k = 1:numel(fgPct)
    fprintf("%9.1f%% %16.4f %10.4f %12.4f\n", fgPct(k), gAcc(k), mIoU(k), wIoU(k));
end

figure
plot(fgPct, gAcc, "o-", LineWidth=1.8); hold on
plot(fgPct, mIoU, "s--", LineWidth=1.8)
plot(fgPct, wIoU, "^-", LineWidth=1.5); hold off
grid on; legend(["GlobalAccuracy" "MeanIoU" "WeightedIoU"], Location="east")
xlabel("前景比例 (%)"); ylabel("「全部猜背景」的分數")
title("越不平衡，指標越樂觀")
%[text] **第 4、5 小題**
%[text] **GlobalAccuracy 直接等於背景比例**，所以前景越少它越高——
%[text] 前景 0.5% 時它是 0.995。**它從來沒有意義，只是不平衡時特別明顯。**
%[text] **`MeanIoU` 也不安全。** 二分類時「全部猜背景」的
%[text] MeanIoU 是 $(0 + \text{背景比例})/2$：
%[text:table]
%[text] | 前景比例 | MeanIoU |
%[text] | --- | --- |
%[text] | 0.5% | **0.4975** |
%[text] | 5% | 0.4750 |
%[text] | 50% | 0.2500 |
%[text:table]
%[text] **前景 0.5% 時 MeanIoU 是 0.4975——看起來像「差不多一半」，
%[text] 實際上完全沒用。**
%[text] **類別數變多時會更糟**：C 個類別時，
%[text] 「全部猜多數類」的 MeanIoU 約是 $\text{多數類比例}/C$，
%[text] 分母變大會把它壓低，看起來像是指標變可靠了——
%[text] 但那只是因為**其他所有類別的 IoU 都是 0** 被平均掉。
%[text] > **唯一安全的做法是看逐類別的 IoU，
%[text] > 而且要看最差的那一類。** 任何平均都會藏東西。
%[text] 這是整章、也是整個課程反覆出現的那句話的最後一次現身：
%[text] **一個數字永遠不夠。**

% ========================================================================
function m = cutTop(gt, frac)
%CUTTOP 砍掉上方 frac 比例的列。
m = gt;
[r, ~] = find(gt);
if isempty(r), return, end
m(min(r):min(r)+round(frac*(max(r)-min(r))), :) = false;
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
