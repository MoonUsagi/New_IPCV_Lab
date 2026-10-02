%[text] # 第 24 章　物件追蹤與運動估計
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出逐幀偵測與追蹤的差別，以及**追蹤到底多買到了什麼**
%[text] 2. 用 Kalman 濾波器穿過遮擋，並知道**運動模型比雜訊參數重要一個數量級**
%[text] 3. 說出 KLT 與 Kalman 各自在追什麼，以及它們各自怎麼死
%[text] 4. 說出四種傳統光流的適用前提，並知道它們**在同一對影格上可以差 75 倍**
%[text] 5. 實作多物件追蹤的三個步驟，並**用 ID 切換而不是位置誤差**來評估
%[text] 6. 說出 ReID 與 DeepSORT 真正解決的是哪一種失敗，**以及解決不了哪一種**
%[text] ## 前置知識
%[text] 第 23 章（逐幀管線、`singleball.mp4` 的遮擋）、
%[text] 第 11 章（區域量測）、第 14 章（特徵點）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox。
%[text] 第 6 節的 RAFT 深度光流需要 **Computer Vision Toolbox Model for
%[text] RAFT Optical Flow Estimation** 支援包——**沒安裝時會自動跳過，
%[text] 其餘內容不受影響**。
%[text] 第 11 節的 ReID 需要 Deep Learning Toolbox。
assert(exist("ch24_kalmanTrack", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 1. 這一章的起點：第 23 章留下的那個洞
%[text] 第 23 章用逐幀偵測追 `singleball.mp4` 的綠球，45 幀裡找到 23 幀。
%[text] 中間第 **27–33 幀**球滾到紙箱後面，逐幀偵測完全沒辦法。
det = ch23_ballSegmentVideo("singleball.mp4");
gaps = find(~det.Found)';
fprintf("逐幀偵測：%d/%d 幀找到球\n", nnz(det.Found), height(det));
fprintf("遮擋段：%s\n", mat2str(27:33));
%[text] **逐幀偵測沒有記憶。** 每一幀都是從零開始，
%[text] 它不知道上一幀球在哪、往哪走、走多快。
%[text:table]
%[text] | | 逐幀偵測 | **追蹤** |
%[text] | --- | --- | --- |
%[text] | 記得上一幀嗎 | 不 | **記得** |
%[text] | 沒看到時 | 只能回報 `NaN` | **可以繼續估計** |
%[text] | 多個物體 | 給你一堆位置 | **給你一堆有身分的軌跡** |
%[text] | 需要什麼 | 一個偵測器 | 偵測器 + **運動模型** + **關聯規則** |
%[text:table]
%[text] > **追蹤買到的東西只有一樣：跨幀的身分。**
%[text] > 其他都是為了維持這個身分而付出的代價。
%%
%[text] # 2. 追蹤的三個步驟
%[text] 不管是最簡單的單物件 Kalman，還是 DeepSORT，骨架都是三步：
%[text:table]
%[text] | 步驟 | 做什麼 | 需要 |
%[text] | --- | --- | --- |
%[text] | ① **預測** | 用運動模型把每條軌跡推進一步 | 運動模型 |
%[text] | ② **關聯** | 決定哪個偵測屬於哪條軌跡 | 成本函數 + 指派演算法 |
%[text] | ③ **更新** | 有配到的用量測修正；沒配到的靠預測撐 | 生死規則 |
%[text:table]
%[text] **單物件時第 ② 步是瑣碎的**（只有一個候選），所以第 3–4 節
%[text] 可以專心看第 ① 步。物體一多，**第 ② 步就變成整個問題的核心**
%[text] （第 8–10 節）。
%%
%[text] # 3. Kalman：把那 7 幀補起來
[estCV, infoCV] = ch24_kalmanTrack(det, MotionModel="ConstantVelocity");
fprintf("盲飛 %d 幀；重新出現在第 %d 幀時，預測誤差 %.2f 像素\n", ...
    infoCV.NumPredicted, infoCV.RejoinFrame, infoCV.RejoinError);
disp(estCV(25:36,:))
%[text] **每一幀都有位置了**，包括球看不見的那 7 幀。
%[text] `Source` 欄位誠實標明每一個值是怎麼來的：
%[text] `correct`（有量測）還是 `predict`（純粹靠模型盲飛）。
%[text] > **這個欄位一定要留著。** 下游看到一條連續的軌跡時，
%[text] > 必須能分辨哪些點是量到的、哪些是猜的。
%[text] > 把它們混在一起，等於把假設偽裝成資料。
figure;
tiledlayout(2,1, TileSpacing="compact");
nexttile
plot(det.Frame, det.X, "o", MarkerSize=7, DisplayName="逐幀偵測"); hold on
plot(estCV.Frame, estCV.X, "-", LineWidth=1.5, DisplayName="Kalman 估計");
isPred = estCV.Source == "predict";
plot(estCV.Frame(isPred), estCV.X(isPred), "rx", MarkerSize=9, ...
    LineWidth=1.5, DisplayName="盲飛（無量測）");
xline(27, "--"); xline(33, "--");
grid on; legend(Location="northwest");
xlabel("幀"); ylabel("X（像素）"); title("Kalman 補上遮擋段")
nexttile
plot(det.Frame, det.Y, "o", MarkerSize=7); hold on
plot(estCV.Frame, estCV.Y, "-", LineWidth=1.5);
plot(estCV.Frame(isPred), estCV.Y(isPred), "rx", MarkerSize=9, LineWidth=1.5);
xline(27, "--"); xline(33, "--");
grid on; xlabel("幀"); ylabel("Y（像素）")
%%
%[text] # 4. 運動模型的選擇，值 11 倍
%[text] 上面的 **31.65 像素**是什麼概念？球的直徑只有 17 像素——
%[text] **預測位置離真實位置差了快兩個球。**
%[text] 換一個運動模型再看：
[estCA, infoCA] = ch24_kalmanTrack(det, MotionModel="ConstantAcceleration");
fprintf("ConstantVelocity     重逢誤差 %.2f 像素\n", infoCV.RejoinError);
fprintf("ConstantAcceleration 重逢誤差 %.2f 像素（好 %.1f 倍）\n", ...
    infoCA.RejoinError, infoCV.RejoinError / infoCA.RejoinError);
%[text] ## 為什麼？因為球在減速
fprintf("遮擋前的每幀位移中位數：%.2f 像素\n", infoCV.MeanSpeedBefore);
fprintf("遮擋後的每幀位移中位數：%.2f 像素\n", infoCV.MeanSpeedAfter);
%[text] **球從 21.10 慢到 11.44 像素/幀。** 等速模型堅持它還在跑 21，
%[text] 盲飛 7 幀就多跑了 30 幾個像素。
%[text] > **而這件事在遮擋發生之前就看得出來。**
%[text] > 可見段的速度本來就不是常數——你只要**畫一下位移的差分**，
%[text] > 就知道等速假設不成立。**不需要等到失敗才發現。**
%[text] ## 對照：調雜訊參數值多少
%[text:table]
%[text] | 運動模型 | MotionNoise | 重逢誤差 |
%[text] | --- | --- | --- |
%[text] | ConstantVelocity | `[1 1]` | 39.86 px |
%[text] | ConstantVelocity | `[25 10]` | 31.65 px |
%[text] | ConstantVelocity | `[100 25]` | 31.88 px |
%[text] | ConstantVelocity | `[500 100]` | 32.10 px |
%[text] | **ConstantAcceleration** | `[1 1 1]` | **2.95 px** |
%[text] | ConstantAcceleration | `[25 10 1]` | 6.95 px |
%[text] | ConstantAcceleration | `[100 25 10]` | 7.45 px |
%[text:table]
%[text] **換模型：31.65 → 2.95，好 10.7 倍。**
%[text] **同一個模型裡調雜訊：最多 1.3 倍。**
%[text] > ## **先選對模型，再調參數。順序反過來會浪費很多時間。**
%[text] > 這和第 20 章「先處理類別不平衡，再調門檻」、
%[text] > 第 22 章「先確認良品乾淨，再調分離度」是同一個優先順序問題。
%[text] > **參數調校只能在正確的模型結構裡找最佳點，換不了結構。**
%[text] > **`ConstantAcceleration` 的向量長度是 3 不是 2。**
%[text] > 這是切換模型時最常見的錯誤：
try
    ch24_kalmanTrack(det, MotionModel="ConstantAcceleration", MotionNoise=[25 10]);
catch ME
    fprintf("%s\n  %s\n", ME.identifier, ME.message);
end
%%
%[text] # 5. KLT：追外觀的方法，以及它為什麼回不來
%[text] Kalman 追的是**運動**——它根本不看畫面，只吃質心座標。
%[text] KLT（Kanade–Lucas–Tomasi）正好相反：它追的是**外觀**，
%[text] 在畫面上找一組角點，逐幀把它們對應過去。
v = VideoReader("singleball.mp4");
k0 = 16;
frame0 = read(v, k0);
bbox = round([max(1, det.X(k0)-14) max(1, det.Y(k0)-14) 28 28]);
corners = detectMinEigenFeatures(rgb2gray(frame0), ROI=bbox);
fprintf("第 %d 幀，球的 ROI 內偵測到 %d 個角點\n", k0, corners.Count);

pointTracker = vision.PointTracker(MaxBidirectionalError=2, NumPyramidLevels=3);
initialize(pointTracker, corners.Location, frame0);

nValid = nan(1, height(det));
for k = (k0+1):height(det)
    [~, valid] = pointTracker(read(v, k));
    nValid(k) = nnz(valid);
end
release(pointTracker);

fprintf("追蹤中的點數：");
fprintf("%d ", nValid((k0+1):42));
fprintf("\n");
firstZero = find(nValid == 0, 1);
fprintf("第一次全部掉光：第 %d 幀（遮擋從第 27 幀才開始）\n", firstZero);
fprintf("之後有恢復嗎：%s\n", string(any(nValid(firstZero:end) > 0)));
%[text] ## 兩種方法，兩種死法
%[text:table]
%[text] | | Kalman | KLT |
%[text] | --- | --- | --- |
%[text] | 追什麼 | **運動**（只看座標） | **外觀**（只看畫面） |
%[text] | 遮擋時 | **繼續盲飛**，誤差累積 | **點全部失效** |
%[text] | 遮擋後 | **接得回來** | **永遠接不回來** |
%[text] | 需要偵測器嗎 | 要（提供量測） | **不要**（自己找點） |
%[text] | 會漂移嗎 | 不會（有量測就校正） | **會**（誤差逐幀累積） |
%[text:table]
%[text] **KLT 在第 26 幀就全滅了——比遮擋開始還早一幀。**
%[text] 因為球那時已經開始被紙箱邊緣切到，角點的鄰域變了。
%[text] > **`vision.PointTracker` 沒有「重新偵測」的概念。**
%[text] > 點掉了就是掉了。要讓 KLT 撐久一點，**呼叫端必須自己
%[text] > 監看有效點數，掉到某個門檻就重新 `detectMinEigenFeatures`
%[text] > 並 `setPoints`**。這是用 KLT 做長時間追蹤的必要工程，
%[text] > 官方範例（人臉追蹤）也是這樣寫的。
%[text] **這兩者是互補的，不是競爭的。** 真正的追蹤器兩個都要：
%[text] 運動模型負責短期外插，外觀負責確認身分——第 8–11 節會把它們合起來。
%%
%[text] # 6. 光流：同一對影格，四種答案差 75 倍
%[text] 光流給的是**每個像素**的速度場，不是物體的速度。
%[text] 它是很多追蹤方法的底層，但它本身有一個很容易踩的坑。
frameA = read(v, 20);
frameB = read(v, 21);
trueShift = det.X(21) - det.X(20);
fprintf("球在這兩幀之間實際移動了 %.2f 像素\n\n", trueShift);

ballMask = false(size(frameA,1), size(frameA,2));
cyy = round(det.Y(20));
cxx = round(det.X(20));
ballMask(max(1,cyy-20):min(end,cyy+20), max(1,cxx-30):min(end,cxx+30)) = true;

flowReport = ch24_flowCompare(frameA, frameB, Mask=ballMask);
disp(flowReport)
%[text] ## 量到的結果（只統計球附近的區域）
%[text:table]
%[text] | 方法 | 最大速度 | 95 百分位 | 耗時 | 相對真值（20.74） |
%[text] | --- | --- | --- | --- | --- |
%[text] | `opticalFlowHS` | 0.28 | 0.11 | 7.9 ms | **低估 74 倍** |
%[text] | `opticalFlowLKDoG` | 0.23 | 0 | 24.9 ms | **低估 90 倍** |
%[text] | `opticalFlowLK` | 5.76 | 0.04 | 5.1 ms | 低估 3.6 倍 |
%[text] | **`opticalFlowFarneback`** | **20.92** | **20.46** | 33.1 ms | **✅ 幾乎命中** |
%[text:table]
%[text] ## 為什麼差這麼多
%[text] Lucas–Kanade 與 Horn–Schunck 都從**亮度恆定**出發：
%[text] $$I(x, y, t) = I(x+u, y+v, t+1)$$
%[text] 然後把右邊做**一階泰勒展開**求解。那個線性化
%[text] **只在位移小於一個像素時成立**。
%[text] 球每幀跑 20.74 像素，**假設早就破了**。
%[text] Farnebäck 用**影像金字塔**：先在縮小 8 倍的影像上估位移
%[text]（那裡的位移只有 2.6 像素，線性化成立），再逐層細化回原尺寸。
%[text] 代價是慢 4–6 倍。
%[text] > ## **這一節最重要的一句話**
%[text] > **光流不會報錯。** 四個方法都乖乖回傳一張速度場，
%[text] > 型別對、尺寸對、看起來都很合理。
%[text] > 但其中三個錯了一到兩個數量級。
%[text] > **要驗證光流，你必須有一個已知答案的位移。**
%[text] 注意 `opticalFlowLK` 的**最大值** 5.76 看起來還好，
%[text] 但 95 百分位是 **0.04**——它只在極少數像素上估到東西。
%[text] **只看最大值會嚴重高估一個方法的表現。**
%[text] ## RAFT 深度光流
if any(flowReport.Method == "opticalFlowRAFT" & flowReport.Available)
    disp("RAFT 可用，數字見上表。")
else
    disp("RAFT 支援包未安裝，上表該列為 NaN。")
end
%[text] `opticalFlowRAFT`（R2024b 引入）用深度網路直接回歸光流，
%[text] **不做亮度恆定的線性化**，所以大位移不是問題。
%[text] 用法和傳統方法不同——**它一次吃兩張影格**：
%[text] ```matlab
%[text] of = opticalFlowRAFT;
%[text] flow = estimateFlow(of, frameA, frameB);   % 兩張，不是一張
%[text] ```
%[text] 傳統方法是 `estimateFlow(of, frame)`，靠物件內部記住上一幀；
%[text] **RAFT 是無狀態的**。這個差別在把兩者放進同一個迴圈時會出錯。
%[text] > 需要 **Computer Vision Toolbox Model for RAFT Optical Flow
%[text] > Estimation** 支援包。`ch24_flowCompare` 在沒安裝時
%[text] > 只會把該列標成 `Available = false`，不會中斷。
%%
%[text] # 7. 背景相減：從畫面裡找出「在動的東西」
%[text] 前面兩節的偵測都靠顏色。**固定相機**的場景有一個更通用的做法：
%[text] 學一個背景模型，凡是和背景不一樣的就是前景。
vAtrium = VideoReader("atrium.mp4");
nScan = 200;
fgDet = vision.ForegroundDetector(NumTrainingFrames=50, NumGaussians=3);
blobAn = vision.BlobAnalysis(MinimumBlobArea=300, ...
    CentroidOutputPort=true, BoundingBoxOutputPort=true, AreaOutputPort=true);

detCount = zeros(nScan,1);
for k = 1:nScan
    mask = fgDet(read(vAtrium, k));
    mask = imopen(mask, strel("rectangle",[3 3]));
    mask = imclose(mask, strel("rectangle",[15 15]));
    mask = imfill(mask, "holes");
    [~, cen, ~] = blobAn(mask);
    detCount(k) = size(cen,1);
end
post = detCount(51:end);
fprintf("atrium.mp4 訓練後 %d 幀：每幀偵測數中位數 %.1f、最多 %d、空幀 %d\n", ...
    numel(post), median(post), max(post), nnz(post==0));
%[text] 前 50 幀在**學背景**，那段的輸出不能用。
%[text] > **`vision.ForegroundDetector` 是有狀態的物件。**
%[text] > 第 23 章 §7.1 量到每幀重建它會慢 10 倍——
%[text] > 但真正的問題是**背景模型永遠停在「第一幀」**，
%[text] > 輸出完全是錯的，而且不會報錯。
%[text] 背景相減的三個典型失敗：
%[text:table]
%[text] | 失敗 | 原因 | 症狀 |
%[text] | --- | --- | --- |
%[text] | 物體停下來 | 停久了就被吸收進背景 | 物體**憑空消失** |
%[text] | 光線變化 | 整片畫面都和背景不一樣 | 前景**炸滿畫面** |
%[text] | 相機晃動 | 背景本身在動 | 邊緣**全是假前景** |
%[text:table]
%[text] **前兩個都沒有錯誤訊息**，只有一個突然變空或變滿的遮罩。
%%
%[text] # 8. 多物件：關聯才是難的那一步
%[text] 物體一多，「這一幀的第 3 個偵測是上一幀的哪一條軌跡」
%[text] 就變成一個**指派問題**。
%[text] MATLAB 提供 `assignDetectionsToTracks`（匈牙利演算法）：
%[text] ```matlab
%[text] cost = 每條軌跡的預測位置到每個偵測的距離;   % M x N
%[text] [assignments, unassignedTracks, unassignedDets] = ...
%[text]     assignDetectionsToTracks(cost, costOfNonAssignment);
%[text] ```
%[text] > **`costOfNonAssignment` 是這裡最重要的一個數字。**
%[text] > 它定義了「多遠算太遠」：
%[text] > 太小 → 稍微動快一點就配不上，**一直開新軌跡**；
%[text] > 太大 → 什麼都配得上，**亂認人**。
%[text] 真實影片沒有逐幀的身分真值，**所以 ID 切換量不出來**。
%[text] 本章用一個**合成場景**來量：
scene = ch24_crossingScene();
fprintf("合成場景：%d 幀，兩個物體最近距離 %.1f 像素（第 %d 幀），合併=%s\n", ...
    scene.NumFrames, scene.MinDistance, scene.CrossFrame, string(scene.Merged));

figure;
montage(scene.Frames([1 10 scene.CrossFrame 30 40]), Size=[1 5]);
title("合成交會場景：兩個物體反向而行")
%[text] > **合成資料的限制要講在前面**（和第 22 章一樣）：
%[text] > 這裡的物體是理想的圓、等速直線、不形變。
%[text] > 本節用它回答「**什麼條件下位置資訊不夠**」，
%[text] > **不是**用它宣稱任何追蹤器的效能。
[trk, trkInfo] = ch24_multiTracker(scene.Frames);
metrics = ch24_trackMetrics(trk, scene.Truth);
fprintf("\n平均每幀偵測到 %.2f 個物體（真值 2 個）\n", trkInfo.MeanDetections);
fprintf("產生 %d 條軌跡（真值 2 條）\n", metrics.NumTracks);
fprintf("ID 切換 %d 次｜覆蓋率 %.3f｜平均位置誤差 %.2f 像素\n", ...
    metrics.IDSwitches, metrics.Coverage, metrics.MeanError);
%%
%[text] # 9. ID 切換：追蹤真正的失敗指標
%[text] 追蹤有兩種完全不同的失敗，而**位置誤差只看得到其中一種**：
%[text:table]
%[text] | 失敗 | 位置誤差 | ID 切換 |
%[text] | --- | --- | --- |
%[text] | 位置估歪了 | **大** | 0 |
%[text] | 兩個物體交會後互換身分 | **≈ 0** | **2** |
%[text:table]
%[text] 第二種在位置誤差上**完全看不出來**——每條軌跡都緊貼著
%[text] 某個真實物體，只是貼錯了人。
%[text] > 如果你的下游要算「這個人在店裡待了多久」「這台車從哪個路口來」，
%[text] > **ID 切換是致命的，位置誤差反而無所謂。**
%[text] > 這和第 20 章「一個指標不夠」、第 22 章「分數看不出異常圖指錯地方」
%[text] > 是同一件事：**指標要對應你真正在意的失敗。**
%[text] 現在換一個情境：兩人**相向而來、停在一起、然後各自折返**。
sceneMeet = ch24_crossingScene(Scenario="meet", MissDistance=12);
trkMeet   = ch24_multiTracker(sceneMeet.Frames);
mMeet     = ch24_trackMetrics(trkMeet, sceneMeet.Truth);
fprintf("「穿越」情境：ID 切換 %d 次，%d 條軌跡\n", ...
    metrics.IDSwitches, metrics.NumTracks);
fprintf("「相遇折返」情境：ID 切換 %d 次，%d 條軌跡，位置誤差 %.2f 像素\n", ...
    mMeet.IDSwitches, mMeet.NumTracks, mMeet.MeanError);
%[text] **穿越 0 次，相遇折返 3 次——而位置誤差只有 1.85 像素。**
%[text] 一個看起來很準的追蹤器，身分已經錯了三次。
%[text] 為什麼「穿越」那麼容易？因為兩者**速度方向相反**，
%[text] Kalman 的預測本身就把它們分開了——
%[text] 即使影像上兩者重疊成一團，預測位置也一左一右。
%[text] **「相遇折返」打破的正是這個**：折返那一刻，
%[text] 等速模型預測他們**繼續前進**，方向剛好猜反。
%%
%[text] # 10. 決定性的變數：偵測端有沒有把它們分開
%[text] 現在做本章最重要的一個實驗。掃描兩條軌跡的間距：
missDistances = [0 8 12 16 20 24 30 40];
MissDist  = missDistances';
Merged    = false(numel(missDistances),1);
MeanDet   = zeros(numel(missDistances),1);
IDSw      = zeros(numel(missDistances),1);
NTracks   = zeros(numel(missDistances),1);

for i = 1:numel(missDistances)
    sc = ch24_crossingScene(MissDistance=missDistances(i));
    [rr, ii] = ch24_multiTracker(sc.Frames);
    mm = ch24_trackMetrics(rr, sc.Truth);
    Merged(i)  = sc.Merged;
    MeanDet(i) = ii.MeanDetections;
    IDSw(i)    = mm.IDSwitches;
    NTracks(i) = mm.NumTracks;
end
disp(table(MissDist, Merged, MeanDet, IDSw, NTracks, ...
    VariableNames=["間距" "區塊合併" "平均偵測數" "ID切換" "軌跡數"]))
%[text] 「穿越」情境下**全部都是 0 次 ID 切換**，
%[text] 連兩個物體完全重疊（間距 0）時也是——
%[text] 因為速度方向相反，運動模型自己就分得開。
%[text] 現在看「相遇折返」情境，並且把三個常見的「補救手段」逐一試過：
%[text:table]
%[text] | 手段 | 值域 | ID 切換 |
%[text] | --- | --- | --- |
%[text] | 外觀權重 `AppearanceWeight` | 0 → 0.9 | **3 → 4（更糟）** |
%[text] | 軌跡壽命 `MaxInvisible` | 2 → 15 | **全部都是 3** |
%[text] | 運動模型 | CV → CA | **3 → 4（更糟）** |
%[text] | **間距 12 → 30（偵測端分得開）** | — | **3 → 0** |
%[text:table]
appearW = [0 0.3 0.6 0.9];
IDSwByW = zeros(numel(appearW),1);
for i = 1:numel(appearW)
    sc = ch24_crossingScene(Scenario="meet", MissDistance=12, Identical=false);
    rr = ch24_multiTracker(sc.Frames, AppearanceWeight=appearW(i));
    IDSwByW(i) = ch24_trackMetrics(rr, sc.Truth).IDSwitches;
end
scWide = ch24_crossingScene(Scenario="meet", MissDistance=30);
mWide  = ch24_trackMetrics(ch24_multiTracker(scWide.Frames), scWide.Truth);

disp(table(appearW', IDSwByW, VariableNames=["外觀權重" "ID切換"]))
fprintf("間距拉到 30（兩者不再合併）：ID 切換 %d 次\n", mWide.IDSwitches);
%[text] > ## **關聯階段修不好偵測階段的錯**
%[text] > 兩個物體被偵測成一個區塊時，**你只有一個質心**。
%[text] > 後面不管用位置、速度還是外觀去算成本，
%[text] > 都是在一個**已經遺失的資訊**上做文章。
%[text] > 加外觀權重不但沒用，還因為單一區塊的直方圖混了兩個物體
%[text] > 而**把事情弄得更糟**（3 → 4）。
%[text] **實務上的意義**：追蹤效果不好時，
%[text] **先去看偵測遮罩，不要先調追蹤器的參數。**
%[text] 這和第 23 章「先量再改」、第 22 章「先看異常圖再調門檻」
%[text] 是同一種紀律——**往上游看**。
%%
%[text] # 11. ReID 與 DeepSORT：它們解決哪一種失敗
%[text] 上一節的結論看起來像是在否定 ReID，**其實不是**。
%[text] ReID 解決的是**另一種**失敗：
%[text:table]
%[text] | 失敗 | 外觀能救嗎 |
%[text] | --- | --- |
%[text] | 兩個物體被偵測成一個區塊 | **不能**（資訊在偵測端就沒了） |
%[text] | 軌跡斷掉、物體隔幾十幀後重新出現 | **能** ← **這才是 ReID 的戰場** |
%[text] | 兩個分開偵測到的物體，位置模稜兩可 | **能** |
%[text:table]
%[text] > **DeepSORT = SORT（Kalman + 匈牙利）+ 一個 ReID 嵌入。**
%[text] > 它的關鍵設計不是「把外觀加進成本」，
%[text] > 而是**保留已刪除軌跡的外觀特徵庫**，
%[text] > 讓一條新軌跡有機會被認回舊身分。
%[text] > 本章的 `ch24_multiTracker` **只做到前者**——
%[text] > 它把外觀混進成本矩陣，但**沒有實作特徵庫的重認**。
%[text] > 這是它和真正 DeepSORT 的主要差距，練習 6 會補上。
%[text] MATLAB 的 ReID 網路：
fprintf("reidentificationNetwork 存在：%s\n", string(exist("reidentificationNetwork") == 2));
fprintf("trainReidentificationNetwork 存在：%s\n", string(exist("trainReidentificationNetwork") == 2));
fprintf("evaluateReidentificationNetwork 存在：%s\n", string(exist("evaluateReidentificationNetwork") == 2));
%[text] **注意 API 的形狀**：
%[text] ```matlab
%[text] backbone = imagePretrainedNetwork("resnet18");          % dlnetwork
%[text] reID     = reidentificationNetwork(backbone, classNames);
%[text] feats    = extractReidentificationFeatures(reID, img);  % 預設 256 維
%[text] ```
%[text] > **`reidentificationNetwork` 的第一個引數必須是 `dlnetwork`，
%[text] > 不是字串。** 傳 `"resnet18"` 會報
%[text] > 「Invalid argument list. Function requires 1 more input(s).」——
%[text] > 那個訊息完全指不到真正的問題（它在抱怨缺少 `classNames`）。
%[text] > ## **R2026a 沒有預訓練的 ReID 權重**
%[text] > 你只能拿 ImageNet 的骨幹接一個新的分類頭，
%[text] > 然後用 `trainReidentificationNetwork` 在**你自己的身分資料**上訓練。
%[text] ## 未訓練的 ReID 嵌入有多沒用？量一次
reidNet = ch24_reidSketch("build");
probeNames = ["peppers.png" "football.jpg" "coins.png" ...
              "cameraman.tif" "onion.png" "tape.png"];
probeImgs = cell(1, numel(probeNames));
for i = 1:numel(probeNames)
    I = imread(probeNames(i));
    if size(I,3) == 1, I = repmat(I, 1, 1, 3); end
    probeImgs{i} = imresize(I, [128 64]);
end
reidFeats = ch24_reidSketch("extract", reidNet, probeImgs);
simMat = reidFeats * reidFeats';
offDiag = simMat(~eye(numel(probeNames)));
fprintf("六張**完全不相干**的內建影像，未訓練 ReID 的餘弦相似度：\n");
fprintf("  最小 %.4f｜中位數 %.4f｜最大 %.4f｜**全距 %.4f**\n", ...
    min(offDiag), median(offDiag), max(offDiag), max(offDiag)-min(offDiag));
%[text] **全部擠在 0.9962–0.9993，全距只有 0.0031。**
%[text] 椒、足球、硬幣、攝影師、洋蔥、膠帶——在這個嵌入空間裡**長得一模一樣**。
%[text] > **這和第 21 章 §5 量到的完全是同一個現象。**
%[text] > 那裡 CLIP 的相似度全距只有 0.0634、前二名差距中位數 0.0068；
%[text] > 這裡更極端。**嵌入的數值範圍窄，代表它沒有在區分你要的東西。**
%[text] > 未訓練的 ReID 頭量到的是「都是自然影像」這個共同點，
%[text] > **不是身分**。
%[text] 所以 `ch24_reidSketch("gallery", ...)` **一定要有相似度門檻**。
%[text] 沒有門檻時，任何新物體都會被硬塞給特徵庫裡最像的身分——
%[text] 而上面的數字告訴你，**「最像的」在未訓練時毫無意義**。
%[text] 本章**不執行 ReID 訓練**（開發機器跑不動）。
%[text] `code/ch24_reidSketch.m` 提供完整可讀的程式碼骨架，
%[text] 並在最前面標明它沒有被執行過：
ch24_reidSketch("train");
%%
%[text] # 12. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 處理 |
%[text] | --- | --- | --- |
%[text] | **先調雜訊再選模型** | 怎麼調都差 30 像素 | **先選模型**（值 10.7 倍），雜訊最多值 1.3 倍 |
%[text] | `ConstantAcceleration` 傳 2 元素向量 | 報「must be a 3-element vector」 | CV 要 2、CA 要 3 |
%[text] | 在 `correct` 之後量預測誤差 | 誤差看起來很小 | **在 `correct` 之前量** |
%[text] | 把預測值和量測值混在一起輸出 | 下游把猜的當成量的 | 保留 `Source` 欄位 |
%[text] | 用位置誤差評估追蹤 | 看起來很準，身分全錯 | **量 ID 切換** |
%[text] | 追蹤不好就調追蹤器 | 白調 | **先看偵測遮罩** |
%[text] | 每幀重建 `ForegroundDetector` | 慢 10 倍，**而且背景模型是錯的** | 提到迴圈外 |
%[text] | 用 LK/HS 估大位移 | 低估 74–90 倍，**不報錯** | 大位移用 Farnebäck 或 RAFT |
%[text] | 只看光流的最大值 | 高估方法的表現 | 看 95 百分位，並且**限定在物體區域** |
%[text] | 期待 KLT 自己恢復 | 點掉光後一路空著 | 監看有效點數，自己重新偵測 + `setPoints` |
%[text:table]
%%
%[text] # 13. 練習
%[text] 練習在 `exercise/Ch24_Exercise.m`。
%%
%[text] # 14. 延伸閱讀
%[text] - `doc configureKalmanFilter` / `doc vision.KalmanFilter`
%[text] - `doc assignDetectionsToTracks` — 匈牙利演算法
%[text] - `doc vision.PointTracker` / `doc detectMinEigenFeatures`
%[text] - `doc opticalFlowFarneback` / `doc opticalFlowRAFT`
%[text] - `doc vision.ForegroundDetector` / `doc vision.BlobAnalysis`
%[text] - `doc reidentificationNetwork` / `doc trainReidentificationNetwork`
%[text] - `doc trackerGNN` / `doc multiObjectTracker` — Sensor Fusion 的追蹤器
%[text] - 第 27 章：把追蹤和姿態估測接起來

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
