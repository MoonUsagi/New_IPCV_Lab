%[text] # 第 17 章　資料標註、資料集與 Datastore
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 組裝 `imageDatastore` / `pixelLabelDatastore` / `boxLabelDatastore` 的資料管線
%[text] 2. **說出為什麼「隨機切分」不保證避開資料洩漏**，並量測自己的切分
%[text] 3. 使用 `groundTruth` 物件與它的方法（包含標註搬家）
%[text] 4. 用 Grounding DINO 的**文字提示**自動標註，並**量化它的品質**
%[text] 5. **說出提示詞為什麼是一個超參數**，以及該用哪個指標挑它
%[text] 6. 串接 Grounding DINO 與 SAM，用一句英文產生像素級標註 \
%[text] ## 前置知識
%[text] 第 09 章（SAM）、第 16 章（偵測器評估與資料洩漏）。
%[text] 本章的 §6 是第 16 章練習 3 的延伸。
%[text] ## 環境需求
%[text] Computer Vision Toolbox、Deep Learning Toolbox，
%[text] 以及 **Computer Vision Toolbox Model for Grounding DINO Object Detection**
%[text] 與 **Image Processing Toolbox Model for Segment Anything Model** 兩個支援包。
%[text] 沒裝支援包時 §9–§12 會跳過並印出訊息。
assert(exist("ch17_dupGroups","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

addons = matlab.addons.installedAddons;
hasGDINO = any(contains(addons.Name, "Grounding DINO"));
hasSAM   = any(contains(addons.Name, "Segment Anything"));
fprintf("Grounding DINO 支援包：%s\n", string(hasGDINO));
fprintf("SAM 支援包：          %s\n", string(hasSAM));
%%
%[text] # 1. 這一章的位置：模型可以換，資料流程不能重來
%[text] 前面十六章都在處理**已經存在的影像**。
%[text] 從這一章開始進入深度學習，而深度學習的第一個問題不是選模型，
%[text] 是**資料從哪裡來、怎麼餵進去**。
%[text] 換模型很便宜：`resnet18` 改成 `resnet50` 是改一個字串。
%[text] 換資料流程很貴：標註錯了要重標，切分錯了之前所有的實驗數字全部作廢。
%[text] > **這一章的所有內容都是「一開始做對，後面省很多」的類型。**
%[text] 三個 datastore 的分工：
%[text:table]
%[text] | Datastore | 裝什麼 | 給誰用 |
%[text] | --- | --- | --- |
%[text] | `imageDatastore` | 影像檔 + 分類標籤 | 分類（第 18 章） |
%[text] | `boxLabelDatastore` | 邊界框 + 類別 | 偵測（第 19 章） |
%[text] | `pixelLabelDatastore` | 逐像素標籤圖 | 分割（第 20 章） |
%[text:table]
%[text] 它們都是**惰性**的：建立時不讀檔，`read` 才讀。
%[text] 這讓你可以用 8 GB 記憶體處理 80 GB 的資料集。
%%
%[text] # 2. Datastore 三兄弟
%[text] ## 2.1 `imageDatastore`：影像 + 分類標籤
digitDir = fullfile(matlabroot, "toolbox", "nnet", "nndemos", ...
    "nndatasets", "DigitDataset");
imds = imageDatastore(digitDir, IncludeSubfolders=true, ...
    LabelSource="foldernames");

fprintf("\nDigitDataset：%d 張影像、%d 類\n", ...
    numel(imds.Files), numel(categories(imds.Labels)));
fprintf("第一個檔案：%s\n", imds.Files{1});
%[text] `LabelSource="foldernames"` 是最常用的一招：
%[text] 把同一類的影像放進同名的資料夾，標籤就自動來了。
%[text] **沒加這個參數的話 `imds.Labels` 是空的**，
%[text] 而且 `countEachLabel` 會報錯——它不知道標籤在哪。
%%
%[text] ## 2.2 `pixelLabelDatastore`：逐像素標籤
triDir = fullfile(toolboxdir("vision"), "visiondata", "triangleImages");
imdsTri = imageDatastore(fullfile(triDir, "trainingImages"));

classNames = ["triangle" "background"];
labelIDs   = [255 0];
pxdsTri = pixelLabelDatastore(fullfile(triDir, "trainingLabels"), ...
    classNames, labelIDs);

fprintf("\ntriangleImages：影像 %d 張、標籤 %d 張\n", ...
    numel(imdsTri.Files), numel(pxdsTri.Files));

I1 = read(imdsTri);
L1 = read(pxdsTri);
% **注意這個不對稱**：read(imds) 直接給影像陣列，
% 但 read(pxds) 給的是一個 1x1 **cell**，要再剝一層。
fprintf("read(imds) -> %s；read(pxds) -> %s\n", class(I1), class(L1));
if iscell(L1)
    L1 = L1{1};
end
figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(I1); title("影像")
nexttile; imshow(uint8(L1 == "triangle")*255); title("標籤（triangle）")
nexttile; imshow(labeloverlay(I1, L1)); title("疊合")
%[text] **`labelIDs` 是把影像檔裡的灰階值對應到類別名稱。**
%[text] 這一步弄錯不會報錯，只會讓所有標籤變成同一類。
%[text] 檢查方法是 `countEachLabel(pxdsTri)`——若某一類是 0，就是對錯了。
%[text] > **一個我剛才才撞到的不對稱**：
%[text:table]
%[text] | 呼叫 | 回傳 |
%[text] | --- | --- |
%[text] | `read(imds)` | `uint8` 陣列（直接就是影像） |
%[text] | `read(pxds)` | **`1x1 cell`**（要 `L{1}` 剝一層） |
%[text] | `read(combine(imds,pxds))` | `1x2 cell`，而**第 2 格已經是 categorical** |
%[text:table]
%[text] > 也就是說 `combine` **幫你把那層 cell 剝掉了**。
%[text] > 所以單獨讀 pxds 要剝、從 combine 讀就不用剝。
%[text] > 寫錯會得到「Cell must be a cell array of character vectors」——
%[text] > 一個完全看不出問題在哪的訊息。
tblPx = countEachLabel(pxdsTri);
disp(tblPx)
%[text] ## 怎麼確定 `labelIDs` 沒對反
%[text] 「看起來沒報錯」不算證據。用**兩個獨立的線索交叉驗證**：
%[text] 1. 三角形應該是**少數類**（它只佔畫面一小塊）
%[text] 2. 被標成 triangle 的區域，在原始影像上應該**比較暗**（三角形是暗的）
dL = dir(fullfile(triDir, "trainingLabels", "*.png"));
dI = dir(fullfile(triDir, "trainingImages", "*.jpg"));
Lraw = imread(fullfile(dL(1).folder, dL(1).name));
Iraw = imread(fullfile(dI(1).folder, dI(1).name));
fprintf("\n標籤 PNG 的唯一值：%s\n", mat2str(unique(Lraw(:))'));
for u = unique(Lraw(:))'
    fprintf("  值 %3d 佔 %5.1f%%，該區域的影像平均亮度 %.1f\n", ...
        u, 100*mean(Lraw(:) == u), mean(Iraw(Lraw == u)));
end
fprintf("整張影像的平均亮度 %.1f\n", mean(Iraw(:)));
%[text] 實測：值 **255** 只佔 **2.9%%**，而且它覆蓋的區域平均亮度 **127**
%[text] （整張影像是 249.7）。**兩個線索都指向 255 = triangle**，
%[text] 所以 `labelIDs = [255 0]` 是對的。
%[text] > **而這裡有一個真實的陷阱，就在 MathWorks 自己出的資料裡。**
%[text] > 同一個資料夾下的 `triangleGroundTruth.mat`，它的
%[text] > `LabelDefinitions` 寫的是 **triangle → 0、background → 255**,
%[text] > 和上面量到的 PNG **完全相反**。
%[text] > 兩者並不矛盾——`groundTruth` 物件指的是**它自己的**
%[text] > `PixelLabelData` 檔案（來自影片來源），那批檔案用另一套編碼。
%[text] > **結論是：`labelIDs` 不能從別的地方複製過來，
%[text] > 一定要對著你手上那批檔案驗證。**
%%
%[text] ## 2.3 `boxLabelDatastore`：邊界框
v = load("vehicleTrainingData.mat");
fn = fieldnames(v);
vehicleTbl = v.(fn{1});
vroot = fullfile(toolboxdir("vision"), "visiondata");

fprintf("\nvehicleTrainingData：%d 列、變數 %s\n", ...
    height(vehicleTbl), strjoin(string(vehicleTbl.Properties.VariableNames), ", "));
disp(head(vehicleTbl, 3))

blds = boxLabelDatastore(vehicleTbl(:, "vehicle"));
fprintf("boxLabelDatastore 建立完成\n");
%[text] > **一個會卡住的地方**：`boxLabelDatastore` 只吃**框的欄位**，
%[text] > 不吃 `imageFilename`。影像路徑要另外做 `imageDatastore`，
%[text] > 再用 `combine` 接起來。
%[text] 而 `evaluateObjectDetection`（第 16 章用過）**不接受只有一個變數的 table**，
%[text] 會報「Not enough table variables. groundTruthData must contain at least
%[text] two variables」——但它**接受由同一個 table 做出來的 `boxLabelDatastore`**。
%[text] 同一份資料，包成 datastore 就通了。這不直覺，但記住就好。
%%
%[text] # 3. `countEachLabel`：先看清楚類別分布
[tblStats, statsInfo] = ch17_labelStats(imds);
disp(tblStats)
fprintf("不平衡比 = %.2f\n", statsInfo.ImbalanceRatio);
%[text] DigitDataset 每類剛好 1000 張——**這是教學資料集刻意做的，
%[text] 真實資料幾乎不會這樣。** 來看不平衡的情況會怎樣。
% 刻意做一個不平衡的子集：類別 0 留 1000 張，其他類別各留 50 張
lab = imds.Labels;
cats = categories(lab);
keep = [];
for k = 1:numel(cats)
    idx = find(lab == cats{k});
    n = 1000*(k == 1) + 50*(k ~= 1);
    keep = [keep; idx(1:min(n, numel(idx)))];
end
imdsImb = subset(imds, keep);

[tblImb, infoImb] = ch17_labelStats(imdsImb);
disp(tblImb)
%[text] 警告已經說明了問題：**一個永遠回答多數類的模型就有 69.0% 準確率。**
%[text] 它什麼都沒學到。
%[text] > **這是第 16 章那件事的第三次現身**：
%[text] > 選了一個對任務不敏感的指標，就會對一個沒用的模型很滿意。
%[text] > 第 16 章是 patch 準確率 vs 偵測器 precision，
%[text] > 這裡是整體準確率 vs 逐類別 recall。
%[text] 平衡取樣的做法（第 18 章會用到）：
imdsBal = splitEachLabel(imdsImb, infoImb.Suggested, "randomized");
fprintf("\n平衡取樣後：每類 %d 張、共 %d 張\n", ...
    infoImb.Suggested, numel(imdsBal.Files));
%[text] 注意 `splitEachLabel`、`countEachLabel`、`subset`、`shuffle`、`transform`
%[text] **都是 datastore 的方法，不是自由函式**。
%[text] `exist("splitEachLabel")` 回傳 **0**，但 `ds.splitEachLabel(...)` 可以用。
%[text] 在文件裡查不到「函式 splitEachLabel」時要往類別的方法列表找。
%%
%[text] # 4. `combine` 與 `transform`：惰性管線
%[text] `combine` 把多個 datastore 並排（每次 `read` 拿到一個 cell），
%[text] `transform` 在讀取時套用一個函式。**兩者都不會馬上讀檔。**
dsPair = combine(imdsTri, pxdsTri);
sample = read(dsPair);
fprintf("\ncombine 之後 read 得到 %s，尺寸 %s\n", ...
    class(sample), mat2str(size(sample)));
fprintf("  第 1 格：%s %s\n", class(sample{1}), mat2str(size(sample{1})));
fprintf("  第 2 格：%s %s\n", class(sample{2}), mat2str(size(sample{2})));

reset(dsPair);
[dsTrain, pipeInfo] = ch17_buildPipeline(imdsTri, pxdsTri, ...
    OutputSize=[64 64], Augment=true);
fprintf("\n管線：%s\n", pipeInfo.Pipeline);

out = read(dsTrain);
fprintf("輸出：影像 %s、標籤 %s\n", mat2str(size(out{1})), mat2str(size(out{2})));
%%
%[text] # 5. 擴增必須和標籤同步——最安靜的錯誤
%[text] **這一節是本章最容易犯、最難發現的錯。**
%[text] 錯誤的寫法看起來完全合理：
%[text] ```matlab
%[text] imdsAug = transform(imdsTri, @(I) fliplr(I));    % 影像翻轉
%[text] pxdsAug = transform(pxdsTri, @(L) fliplr(L));    % 標籤也翻轉
%[text] dsBad   = combine(imdsAug, pxdsAug);             % 看起來對？
%[text] ```
%[text] 這樣寫**每次都翻**，所以還算同步。但一旦加了隨機性：
%[text] ```matlab
%[text] imdsAug = transform(imdsTri, @(I) randFlip(I));  % 各自決定要不要翻
%[text] pxdsAug = transform(pxdsTri, @(L) randFlip(L));  % ← 兩邊的擲骰子不同步
%[text] ```
%[text] **影像翻了、標籤沒翻。** 而且：
%[text] - 不會報錯
%[text] - 訓練會跑完
%[text] - loss 會下降（模型會去學那些沒被破壞的樣本）
%[text] - 只有最終準確率莫名地差
%[text] 正確做法是**先 `combine` 再 `transform`**，
%[text] 讓同一個函式同時拿到影像與標籤，擲一次骰子、兩邊共用。
%[text] `ch17_buildPipeline` 的 `augmentPair` 就是這樣寫的。
%[text] 用一個具體的檢查驗證同步性：把三角形標籤的**質心**算出來，
%[text] 影像與標籤若同步，兩者的前景質心應該一致。
reset(dsTrain);
maxOff = 0;
for k = 1:12
    d = read(dsTrain);
    Ik = im2double(d{1});
    Lk = d{2} == "triangle";
    if ~any(Lk(:)), continue, end
    % 影像的暗前景（三角形是暗的）
    fg = Ik < graythresh(Ik);
    if ~any(fg(:)), continue, end
    sL = regionprops(Lk, "Centroid");
    sI = regionprops(fg, "Centroid");
    if isempty(sL) || isempty(sI), continue, end
    cL = sL(1).Centroid;
    % 取離標籤質心最近的影像連通區，避免抓到雜訊
    dists = vecnorm(reshape([sI.Centroid], 2, [])' - cL, 2, 2);
    [~, iBest] = min(dists);
    maxOff = max(maxOff, norm(sI(iBest).Centroid - cL));
end
fprintf("\n影像前景質心與標籤質心的最大偏差 = %.2f 像素\n", maxOff);
%[text] 偏差只有幾個像素（來自二值化門檻與縮放插值），**不是幾十個像素**——
%[text] 代表影像與標籤套用了同一個變換。
%[text] > **這個檢查值得寫進每個訓練腳本的開頭。**
%[text] > 它十行程式碼，能攔下一整週的無效訓練。
%%
%[text] # 6. 資料切分：先量重複，再選策略
%[text] 第 16 章練習 3 已經證明資料洩漏會高估效能 20 個百分點。
%[text] **這一節處理一個更隱蔽的版本：資料集裡本來就有重複的影像。**
%[text] 我原本的假設是：`vehicles` 是連續影格，
%[text] 所以隨機切分會洩漏、**照順序切會安全**。
%[text] 這是時序資料的標準建議。來量一下對不對。
vehicleFiles = fullfile(vroot, string(vehicleTbl.imageFilename)).';
[groupId, S, dupInfo] = ch17_dupGroups(vehicleFiles);

fprintf("\n%d 張影像 -> %d 個群組\n", numel(vehicleFiles), dupInfo.NumGroups);
fprintf("有近重複夥伴的影像：%d 張（%.0f%%）\n", ...
    dupInfo.NumWithPartner, 100*dupInfo.NumWithPartner/numel(vehicleFiles));
sz = dupInfo.GroupSizes;
for s = unique(sz)'
    fprintf("  大小 %d 的群組：%d 個\n", s, nnz(sz == s));
end
%%
%[text] ## 三種切分策略的實測
splitTbl = ch17_compareSplits(S, groupId, TrainFraction=0.7);
disp(splitTbl)
%[text] **結果和我的假設相反。**
%[text:table]
%[text] | 策略 | 訓練／測試 | 跨集合近重複 |
%[text] | --- | --- | --- |
%[text] | 隨機切分 | 207／88 | 27.3% |
%[text] | **區塊切分（照順序）** | 207／88 | **40.9%** ← 更糟 |
%[text] | **群組感知切分** | 208／87 | **0%** |
%[text:table]
%[text] 為什麼「照順序切」反而更糟？看最大的那個重複群組：
bigGroup = find(sz == max(sz), 1);
fprintf("\n最大群組的成員索引：%s\n", mat2str(find(groupId == bigGroup)'));
%[text] **重複的影像不相鄰。** 它們成對出現在資料集的兩個相距很遠的位置
%[text] （第 37/38 張與第 283/284 張）。
%[text] 「照順序切」的前提是重複只發生在相鄰樣本——
%[text] **這個前提在這個資料集上不成立，所以建議就是錯的。**
%[text] > **本節的結論不是「用某一種切法」。**
%[text] > 是：**重複情形要量，不能假設。**
%[text] > 量完之後，群組感知切分在**建構上**保證 0%——
%[text] > 它不靠隨機種子好運。
%[text] 順便注意群組感知切分的張數是 208／87，不是剛好的 207／88。
%[text] 因為切的單位是「群」不是「張」，群的大小不一，比例只能近似。
%[text] **這是正確的代價，不是 bug。**
%%
%[text] # 7. `groundTruth` 物件與它的方法
%[text] `groundTruth` 是 Image Labeler / Video Labeler 的輸出格式，
%[text] 也是餵給 `objectDetectorTrainingData` 與 `pixelLabelTrainingData` 的輸入。
gt = load(fullfile(triDir, "triangleGroundTruth.mat"));
gfn = fieldnames(gt);
gTruth = gt.(gfn{1});
fprintf("\ngroundTruth 物件：%s\n", class(gTruth));
disp(gTruth.LabelDefinitions)
%[text] **它的功能大多是「方法」而不是自由函式**：
fprintf("groundTruth 的方法：\n  %s\n", ...
    strjoin(string(setdiff(methods(gTruth), ...
        ["addlistener";"delete";"eq";"findobj";"findprop";"ge";"gt"; ...
         "isvalid";"le";"listener";"lt";"ne";"notify";"groundTruth"]))', ", "));
%[text] 最重要的是 **`changeFilePaths`**：
%[text] 標註檔裡存的是**絕對路徑**，所以資料夾一搬、換一台電腦，
%[text] 標註就全部指向不存在的檔案。
%[text] > **上面載入 `triangleGroundTruth.mat` 時，你應該看到了兩個警告。**
%[text] > 那不是本教材的問題——**是 MathWorks 自己出的檔案就有這個問題**：
%[text] > ```
%[text] > The data source points to a video file that cannot be found.
%[text] >   '/mathworks/devel/sbs/37/akamath.18afixes/matlab/toolbox/
%[text] >    vision/visiondata/triangleImages/triangleVideo.avi'
%[text] > ```
%[text] > 那是**他們建置機器上的絕對路徑**，被存進了 `.mat` 檔，
%[text] > 然後隨產品出貨到每一台使用者的電腦上。
%[text] > 影片其實就在你的 `visiondata\triangleImages\` 裡，
%[text] > 但標註檔認不出來。
%[text] **這就是 `changeFilePaths` 存在的理由，而且它出現在一個
%[text] 連 MathWorks 都沒避開的地方。** 你的專案不會比他們幸運。
%[text] ```matlab
%[text] % 舊路徑 -> 新路徑（注意這是方法，不是函式）
%[text] unresolved = changeFilePaths(gTruth, ["D:\舊位置" "E:\新位置"]);
%[text] ```
%[text] `exist("changeFilePaths")` 回傳 **0**——它只存在於 `groundTruth` 類別裡。
%[text] > **把標註檔連同它的資料一起版本控管，並在專案 README 裡
%[text] > 記下 `changeFilePaths` 這一招。** 這是交接時最常卡住的地方。
%%
%[text] # 8. 從 `groundTruth` 產生訓練資料
%[text] 兩個轉換函式把 `groundTruth` 變成 datastore：
%[text:table]
%[text] | 函式 | 產出 | 給誰 |
%[text] | --- | --- | --- |
%[text] | `objectDetectorTrainingData` | imds + blds | 第 19 章 |
%[text] | `pixelLabelTrainingData` | imds + pxds | 第 20 章 |
%[text:table]
%[text] 它們的重點是**把「一個標註容器」拆成「模型要的兩條資料流」**。
%[text] 用法（`triangleGroundTruth` 是像素標籤，所以用後者）：
%[text] ```matlab
%[text] [imdsOut, pxdsOut] = pixelLabelTrainingData(gTruth);
%[text] ```
%[text] 偵測的版本會寫出影像檔到指定資料夾，所以要給 `WriteLocation`：
%[text] ```matlab
%[text] [imdsD, bldsD] = objectDetectorTrainingData(gTruth, ...
%[text]     WriteLocation=tempdir, SamplingFactor=1);
%[text] ```
%[text] > **`SamplingFactor` 預設不是 1。** 對影片來源的 `groundTruth`，
%[text] > 它預設每隔幾個影格才取一張（因為相鄰影格幾乎相同——
%[text] > 這正是 §6 講的重複問題）。想要全部影格必須明確寫 `SamplingFactor=1`。
%%
%[text] # 9. 文字提示自動標註：Grounding DINO
%[text] **這是本章最重要的三節（§9–§11）的開始。**
%[text] 標註成本以前是電腦視覺專案的主要成本。R2026a 起，
%[text] 一句英文就能產生初步標註。
if ~hasGDINO
    disp("（沒有 Grounding DINO 支援包，略過 §9–§12。）")
else
    det = groundingDinoObjectDetector("swin-tiny", ...
        ClassNames="car", ClassDescriptions="car");
    Iv = imread(fullfile(vroot, vehicleTbl.imageFilename{1}));
    [bb, sc] = detect(det, Iv);

    gtBox = vehicleTbl.vehicle{1};
    ious = bboxOverlapRatio(bb, gtBox);
    [bestIoU, iBest] = max(ious);

    fprintf("\n第 1 張影像：偵測到 %d 個框（人工標註只有 1 個）\n", size(bb,1));
    fprintf("正確答案：          %s\n", mat2str(gtBox));
    fprintf("**分數最高**的框：  %s（分數 %.3f、IoU %.3f）\n", ...
        mat2str(round(bb(1,:))), sc(1), ious(1));
    fprintf("**IoU 最高**的框：  %s（分數 %.3f、IoU %.3f、排名第 %d）\n", ...
        mat2str(round(bb(iBest,:))), sc(iBest), bestIoU, iBest);

    figure
    labelsTxt = compose("%.2f", sc);
    % 注意：insertObjectAnnotation 的預設字型 Roboto-Regular **不含中日韓字元**
    % （第 15 章已遇過同一件事）。標註文字要用 ASCII，否則會發字型警告。
    labelsTxt(iBest) = labelsTxt(iBest) + " <-best IoU";
    imshow(insertObjectAnnotation(Iv, "rectangle", bb, labelsTxt, ...
        Color="yellow", LineWidth=2));
    title(sprintf("零樣本偵測：%d 個框，只有 1 個是對的", size(bb,1)))

    % **用完馬上釋放。** 腳本的工作區會一直持有 det 直到腳本結束，
    % 而每個偵測器佔約 1.7 GB 顯示記憶體——留著它會讓下一節的
    % 提示詞掃描慢好幾倍（見 §10.1）。
    clear det
end
%[text] ## 第一次就撞到的事：分數最高的框是錯的
%[text] 實測第 1 張影像（提示詞 `"car"`）：
%[text:table]
%[text] | | 框 | 分數 | IoU |
%[text] | --- | --- | --- | --- |
%[text] | 正確答案 | `[126 78 20 16]` | — | — |
%[text] | **分數最高**的框 | `[40 79 20 8]` | **0.664** | **0.000** |
%[text] | **IoU 最高**的框 | `[126 78 18 15]` | 0.558 | **0.844** |
%[text:table]
%[text] **分數最高的那個框完全不是車（IoU = 0），
%[text] 而真正的車排在第二名。**
%[text] （框的座標與分數會因 GPU 浮點累加順序而有 ±1 像素／±0.01 的差異，
%[text] 但「最高分的框是錯的、IoU 最高的排第 2」這個結構是穩定的。）
%[text] > **這是第 9 章那句話的重演：「信心分數高不代表是你要的」。**
%[text] > 當時是 SAM 的遮罩分數，這裡是 VLM 的偵測分數。
%[text] > **不要對 top-1 的框有任何信任。**
%[text] 所以自動標註的正確用法不是「取分數最高的框」，
%[text] 是「**把所有框都留下來給人篩**」——這也是 §11 會算的成本。
%[text] **API 還有兩個地方會讓人卡住，我兩個都撞到了。**
%[text] **① 提示詞不是傳給 `detect`，是建構偵測器時就要給。**
%[text] 直覺會寫 `detect(detector, I, "car")`——第三個位置引數是 **ROI**，
%[text] 不是文字。這樣寫會得到：
%[text] > `Expected ROI to be one of these types: double, single, uint8, ...`
%[text] > `Instead its type was string.`
%[text] **錯誤訊息完全沒提到文字提示**，看了只會以為自己的影像型別有問題。
%[text] **② `ClassNames` 是唯讀的。** 建構之後不能改，
%[text] 要換提示詞只能**重新建構一個偵測器**。
%[text] 正確寫法：
%[text] ```matlab
%[text] det = groundingDinoObjectDetector("swin-tiny", ...
%[text]     ClassNames="car", ...              % 寫進標註的類別名
%[text]     ClassDescriptions="a car on the road");   % 自然語言查詢
%[text] [bboxes, scores, labels] = detect(det, I);
%[text] ```
%[text] `ClassNames` 與 `ClassDescriptions` 的分工很重要：
%[text] **提示詞可以換，類別名要固定**，否則下游的訓練資料會有
%[text] 好幾個名稱指同一類。
%%
%[text] # 10. 提示詞是一個超參數
%[text] 上面用 `"car"` 拿到了不錯的結果。**換個字會怎樣？**
if ~hasGDINO
    disp("（略過提示詞掃描。）")
else
    % 均勻取樣，不要只拿開頭的連續影格（§6 講的重複問題）
    if ipcvFast()
        nSweep = 6;
        disp("（快速模式：只用 6 張影像掃描。完整執行用 20 張。）")
    else
        nSweep = 20;
    end
    idxSweep = round(linspace(1, height(vehicleTbl), nSweep));
    filesSweep = fullfile(vroot, string(vehicleTbl.imageFilename(idxSweep))).';
    gtSweep = vehicleTbl.vehicle(idxSweep);

    prompts = ["car", "vehicle", "a car on the road"];
    sweepTbl = ch17_promptSweep(filesSweep, prompts, gtSweep, ClassName="car");
    disp(sweepTbl)
end
%[text] 實測（20 張、swin-tiny、IoU 0.5）：
%[text:table]
%[text] | 提示詞 | 總框數 | precision | recall | AP | 秒/張 |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | `"car"` | 65 | 33.8% | **100.0%** | 0.873 | 1.82 |
%[text] | `"vehicle"` | 15 | **93.3%** | 63.6% | 0.597 | 1.83 |
%[text] | `"a car on the road"` | 38 | 55.3% | 95.5% | **0.908** | 1.85 |
%[text:table]
%[text] **同一個模型、同一批影像，只改英文用字，
%[text] precision 從 33.8% 到 93.3%、recall 從 63.6% 到 100.0%。**
%[text] 而且三個指標各有各的贏家：
%[text] - recall 最高 → `"car"`
%[text] - precision 最高 → `"vehicle"`
%[text] - AP 最高 → `"a car on the road"`
%[text] > **又一次「兩個指標給出相反排序」**
%[text] > （第 11、12、14、15、16 章都出現過）。
%[text] > 但這一章的旋鈕特別不直覺：**它是英文用字，不是數值參數。**
%[text] > 沒有梯度、沒有單調性、**沒辦法二分搜尋**。
%%
%[text] ## 10.1 掃描提示詞的效能陷阱：每個偵測器吃 1.7 GB 顯示記憶體
%[text] **這一節是我在寫上面那張表時被卡住兩次才找出來的。**
%[text] `ClassNames` 唯讀，所以換提示詞必須**重建偵測器**（§9）。
%[text] 而每個偵測器會佔掉約 **1.7 GB** 的顯示記憶體，**不會自己釋放**。
%[text] 在一張 4.29 GB 的卡（T550）上實測：
%[text:table]
%[text] | 第幾個偵測器 | 保留前一個 | 每個用完就 `clear` |
%[text] | --- | --- | --- |
%[text] | 1 | 1.90 秒 | 1.85 秒 |
%[text] | 2 | **11.64 秒** | 1.88 秒 |
%[text] | 3 | **39.87 秒** | 1.90 秒 |
%[text] | 4 | **54.50 秒** | **1.93 秒** |
%[text:table]
%[text] **28 倍的差距，而且沒有任何錯誤或警告。**
%[text] 顯示記憶體不足時它安靜地退化（換頁／回落到較慢的路徑），
%[text] 症狀看起來就只是「這台機器很慢」。
%[text] > **這是 GPU 程式最難診斷的一類問題：
%[text] > 沒有錯誤訊息，只有效能數字在說話。**
%[text] 解法很簡單，但必須主動做：
%[text] ```matlab
%[text] for k = 1:numel(prompts)
%[text]     det = groundingDinoObjectDetector("swin-tiny", ...
%[text]         ClassNames="car", ClassDescriptions=prompts(k));
%[text]     ... 用它 ...
%[text]     clear det          % ← 這一行就是全部的差別
%[text] end
%[text] ```
%[text] 注意**在腳本裡特別容易忘**：腳本的工作區會一直持有變數
%[text] 直到腳本結束，所以 §9 建的 `det` 會一路活到 §12。
%[text] 寫在函式裡的話離開函式就會釋放（`ch17_autoLabel` 就是這樣，
%[text] 而且它還是明確 `clear` 了一次，因為這件事太容易出錯）。
%[text] `ch17_groundedSAM` 也**先釋放 Grounding DINO 再載入 SAM**——
%[text] 兩個基礎模型同時留在 4 GB 的卡上，後者一定會退化。
if gpuDeviceCount > 0
    g = gpuDevice;
    fprintf("\n%s：可用 %.2f GB / 總 %.2f GB\n", ...
        g.Name, g.AvailableMemory/1e9, g.TotalMemory/1e9);
else
    disp("（沒有 GPU，本節的顯示記憶體問題不適用；CPU 推論會更慢但不會退化。）")
end
%%
%[text] 為什麼 `"vehicle"` 的 recall 這麼低？
%[text] 合理的猜測是它比較抽象——CLIP 式的文字編碼器對
%[text] 「上位詞」的對齊比較弱，而 `"car"` 是訓練資料裡最常見的說法。
%[text] **但這只是猜測。** 重點是你不能從語意直覺推出哪個提示詞好，
%[text] **只能量。**
%%
%[text] # 11. 選提示詞要看下游是人還是模型
%[text] 上表沒有唯一的贏家，所以要問：**這批標註要給誰用？**
%[text] `precision` 與 `recall` 是對稱的指標，
%[text] 但**人工修正的成本完全不對稱**：
%[text:table]
%[text] | 動作 | 成本 |
%[text] | --- | --- |
%[text] | 刪掉一個誤框 | 看一眼、按一次 Delete |
%[text] | 從頭畫一個漏標 | 要先**發現**它漏了，再對齊四個邊 |
%[text:table]
%[text] 「發現漏標」是最貴的一步：畫面上已經有框的時候，
%[text] 人的注意力會被既有的框吸走，**漏標很容易被整批跳過**。
%[text] 換算成實際工作量（20 張、GT 共 22 個目標）：
%[text:table]
%[text] | 提示詞 | 要刪的誤框 | 要畫的漏標 | 命中框平均 IoU |
%[text] | --- | --- | --- | --- |
%[text] | `"car"` | 43 | **0** | 0.838 |
%[text] | `"vehicle"` | 1 | **8** | 0.845 |
%[text] | `"a car on the road"` | 17 | 1 | 0.849 |
%[text:table]
%[text] **43 次點擊 vs 8 次「找出漏掉的車再畫框」**，前者幾乎一定更快，
%[text] 而且更不容易出錯。
%[text] 若真的想省總點擊數，`"a car on the road"` 是折衷：
%[text] 17 刪 + 1 畫。**但它還是有 1 個漏標**，
%[text] 而漏標是那種會一路流進訓練集、
%[text] 讓模型學到「這個位置的車不算車」的錯誤。
%[text] > **拿 VLM 做預標註時，要優化 recall，不是 precision。**
%[text] > 這和「上線的偵測器要 precision」剛好相反——
%[text] > 因為兩者的下游不同：一個下游是人，一個下游是產線決策。
%[text] 命中框的平均 IoU 是 **0.838**：框抓得到位置，
%[text] 但**還是要人微調邊界**。自動標註不是「不用人」，
%[text] 是把人的工作從「畫框」變成「改框」。
%%
%[text] # 12. Grounded SAM：文字 → 框 → 遮罩
%[text] Grounding DINO 只輸出矩形框；SAM 輸出精確遮罩但不懂文字。
%[text] **串起來就得到「用一句英文產生像素級標註」。**
if ~(hasGDINO && hasSAM)
    disp("（缺 Grounding DINO 或 SAM 支援包，略過本節。）")
elseif ipcvFast()
    disp("（快速模式：略過 Grounded SAM。完整執行約 20 秒。）")
else
    Ip = imread("visionteam.jpg");
    [masks, boxesP, scoresP, gsInfo] = ch17_groundedSAM(Ip, "a person", ...
        ClassName="person", Threshold=0.35, MaxObjects=6);

    fprintf("\n提示詞 ""a person""：%d 個框 -> %d 個遮罩\n", ...
        size(boxesP,1), size(masks,3));
    fprintf("偵測 %.2f 秒、嵌入 %.2f 秒、遮罩 %.2f 秒（%.2f 秒/遮罩）\n", ...
        gsInfo.SecDetect, gsInfo.SecEmbed, gsInfo.SecMasks, gsInfo.SecPerMask);

    overlay = Ip;
    colors = lines(size(masks,3));
    for k = 1:size(masks,3)
        overlay = labeloverlay(overlay, masks(:,:,k), ...
            Colormap=colors(k,:), Transparency=0.5);
    end
    figure
    tiledlayout(1,2, TileSpacing="compact")
    nexttile
    imshow(insertObjectAnnotation(Ip, "rectangle", boxesP, ...
        compose("%.2f", scoresP), Color="yellow", LineWidth=2));
    title("① Grounding DINO：文字 -> 框")
    nexttile
    imshow(overlay); title("② SAM：框 -> 遮罩")
end
%[text] 實測（`visionteam.jpg`、提示詞 `"a person"`）：
%[text] **6 個框 → 6 個遮罩。**
%[text:table]
%[text] | 步驟 | 秒數（兩次執行） |
%[text] | --- | --- |
%[text] | Grounding DINO 偵測 | 2.5 |
%[text] | SAM 影像嵌入（**含模型載入**） | 12.3–13.0 |
%[text] | 6 個遮罩 | 2.0–3.7（**0.33–0.61 秒/遮罩**） |
%[text:table]
%[text] （絕對秒數依機器而異，**比例才是重點**。）
%[text] 注意時間的分布：**重的編碼器只跑一次，輕的解碼器跑 K 次。**
%[text] 這是 SAM 架構刻意的設計，所以 `extractEmbeddings` 一定要
%[text] 提到迴圈外面——放進迴圈會讓 6 個遮罩從 3.7 秒變成 70 秒以上。
%[text] > **`segmentObjectsFromEmbeddings` 的 `BoundingBox` 一次只吃
%[text] > 一個 `1x4` 向量。** 傳整個 `Kx4` 矩陣會報錯，所以框要自己迴圈。
%%
%[text] # 13. COCO JSON 匯入
%[text] COCO 是物件偵測與分割最通用的標註交換格式。
%[text] R2025a 起可以直接匯入：
%[text] ```matlab
%[text] gTruth = groundTruthFromCOCO(pathToJSON, pathToImages);
%[text] ```
%[text] **函式名稱不是 `cocoToGroundTruth` 也不是 `importCOCO`**——
%[text] 這兩個常見的猜測都不存在（`exist` 回傳 0）。
fprintf("\ngroundTruthFromCOCO 存在：%s\n", string(exist("groundTruthFromCOCO") == 2));
fprintf("cocoToGroundTruth 存在：  %s\n", string(exist("cocoToGroundTruth") == 2));
%[text] 匯入之後就是一般的 `groundTruth` 物件，
%[text] 接 `objectDetectorTrainingData` 進入第 19 章的訓練流程。
%[text] > **匯入後第一件事是檢查路徑。** COCO 的 JSON 存的是相對檔名，
%[text] > `pathToImages` 給錯不會馬上報錯，要到訓練時才會發現讀不到檔。
%[text] > 用 `changeFilePaths`（§7）修正。
%%
%[text] # 14. R2026a 注意事項
%[text] 1. **`groundingDinoObjectDetector` 的提示詞放在 `ClassDescriptions`**，
%[text]    不是 `detect` 的位置引數。誤傳會得到一個講 ROI 型別的錯誤訊息。
%[text] 2. **`ClassNames` 唯讀**，換提示詞要重建偵測器。
%[text] 3. **第一次 `detect` 要額外約 10 秒**載入權重。要量穩定速度必須先暖機。
%[text] 4. `groundTruthFromCOCO` 是 R2025a 新增，簽章是
%[text]    `(pathToJSON, pathToImages)` 兩個位置引數。
%[text] 5. **`changeFilePaths` 是 `groundTruth` 的方法**，不是自由函式。
%[text] 6. `imsegsam` 預設模型已是 `"sam2-large"`；但**框提示的路徑
%[text]    走的是 `segmentAnythingModel` 類別**（`extractEmbeddings` +
%[text]    `segmentObjectsFromEmbeddings`），不是 `imsegsam`。
%[text] 7. **Image Labeler 現在支援 SAM 2 與 Grounding DINO 自動標註**，
%[text]    而且可以在 MATLAB Online 使用。互動操作請看
%[text]    `imageLabeler`（本章的程式碼路線是為了可重現與可批次）。
%%
%[text] # 15. 常見陷阱
%[text] 1. **`imageDatastore` 沒加 `LabelSource="foldernames"`** → `Labels` 是空的，
%[text]    `countEachLabel` 直接報錯。
%[text] 2. **`pixelLabelDatastore` 的 `labelIDs` 對錯** → 不報錯，
%[text]    所有像素變成同一類。檢查方法是 `countEachLabel`，看有沒有 0。
%[text] 3. **`boxLabelDatastore` 不吃 `imageFilename` 欄位**，只吃框的欄位。
%[text] 4. **`evaluateObjectDetection` 不接受只有一個變數的 table**，
%[text]    但接受由它做成的 `boxLabelDatastore`。
%[text] 5. **分別對影像與標籤做隨機擴增** → 兩邊不同步，
%[text]    **不報錯、loss 會下降、結果是垃圾**。先 `combine` 再 `transform`。
%[text] 6. **以為隨機切分就安全** → 本章 §6 量到 27% 的測試影像
%[text]    在訓練集裡有近重複。
%[text] 7. **以為照順序切更安全** → 這個資料集上反而是 41%，比隨機更糟。
%[text] 8. **`objectDetectorTrainingData` 的 `SamplingFactor` 預設不是 1**，
%[text]    影片來源會被抽樣。
%[text] 9. **只試一個提示詞就下結論** → §10 顯示 precision 可以差 2.8 倍。
%[text] 10. **拿 precision 挑預標註的提示詞** → 應該挑 recall（§11）。
%[text] 11. **`extractEmbeddings` 放進迴圈** → 每個框重跑一次重編碼器，
%[text]     6 個遮罩會從 3.7 秒變成 70 秒以上。
%[text] 12. **`splitEachLabel` / `countEachLabel` / `transform` 當成自由函式查**
%[text]     → `exist` 回傳 0，它們是 datastore 的方法。
%%
%[text] # 16. 本章小結
%[text:table]
%[text] | 主題 | 一句話 |
%[text] | --- | --- |
%[text] | Datastore 三兄弟 | 都是惰性的；分類／偵測／分割各一個 |
%[text] | `combine` + `transform` | 擴增要在 `combine` **之後**，否則標籤不同步 |
%[text] | 類別不平衡 | 不平衡時整體準確率會騙人（69% 卻什麼都沒學到） |
%[text] | **資料切分** | **重複要量不能假設**：隨機 27%、區塊 41%、群組感知 **0%** |
%[text] | `groundTruth` | 功能大多是方法；`changeFilePaths` 是交接的關鍵 |
%[text] | **提示詞** | **是超參數**，precision 33.8%→93.3%、recall 63.6%→100% |
%[text] | **挑提示詞的指標** | 下游是人 → 挑 **recall**；下游是模型 → 挑 AP |
%[text] | Grounded SAM | 一句英文產生遮罩；編碼器跑一次、解碼器跑 K 次 |
%[text:table]
%[text] 本章反覆出現的那條線索又出現了一次：
%[text] **一個指標永遠不夠，而且兩個指標常常給出相反的排序。**
%[text] 第 11 章是周長定義、第 12 章是 PSNR vs 紋理、
%[text] 第 14 章是重複性 vs 可配對性、第 15 章是 precision vs recall、
%[text] 第 16 章是 patch 準確率 vs 偵測器 precision，
%[text] 這一章是**同一個模型在不同英文用字下的 precision vs recall**。
%[text] > 差別在於：前面幾章的旋鈕都是數字，**這一章的旋鈕是一句話。**
%%
%[text] # 17. 練習
%[text] 練習在 `exercise/Ch17_Exercise.m`，六題加一題加分題。
%[text] 重點在**量測自己的資料**而不是套用建議。
%%
%[text] # 18. 延伸閱讀與下一章
%[text] - `doc imageLabeler` — 互動式標註，支援 SAM 2 與 Grounding DINO 自動標註
%[text] - `doc videoLabeler` — 時序標註與自動傳播
%[text] - `doc groundTruthFromCOCO` — COCO 匯入
%[text] - `doc datastore` — 所有 datastore 型別與它們的方法
%[text] **第 18 章**會用這一章建好的管線做第一個端到端深度學習任務：
%[text] 影像分類與遷移學習。§3 的平衡取樣、§4 的管線、§6 的群組感知切分
%[text] 都會直接用上。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
