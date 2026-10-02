%[text] # 第 27 章　姿態估測與擴增實境
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：3 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 用 AprilTag／ArUco 取得 6-DoF 姿態，並在影像上做 AR 疊加
%[text] 2. **用重投影誤差檢查姿態**，並知道它抓得到什麼、抓不到什麼
%[text] 3. 說出 PnP 的最少點數需求，以及**四個點為什麼是最糟的情況**
%[text] 4. 分辨「座標框搞錯」與「數值誤差」這兩種完全不同的問題
%[text] 5. 用 HRNet 做人體關鍵點偵測
%[text] 6. 把姿態估測接到第 24 章的追蹤上
%[text] ## 前置知識
%[text] 第 25 章（內參、外參、重投影誤差）、第 26 章（三維座標框）、
%[text] 第 24 章（追蹤）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox。§8 的 HRNet 需要
%[text] **Computer Vision Toolbox Model for Object Keypoint Detection** 支援包。
assert(exist("ch27_tagPose", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 1. 這一章的位置：從「在哪裡」到「怎麼擺」
%[text:table]
%[text] | 章 | 回答的問題 | 自由度 |
%[text] | --- | --- | --- |
%[text] | 第 19 章 | 這是什麼、在畫面的哪裡 | 4（外框） |
%[text] | 第 24 章 | 它跨幀是同一個嗎 | 4 + 身分 |
%[text] | 第 26 章 | 它離我多遠 | 3（位置） |
%[text] | **第 27 章** | **它在空間中怎麼擺** | **6（位置 + 姿態）** |
%[text:table]
%[text] 6-DoF 姿態是機械手臂取放、AR 疊加、機器人導航的共同前提。
%[text] **而取得它最可靠的方法，是在場景裡放一個你完全知道其尺寸的東西。**
%%
%[text] # 2. AprilTag：偵測與姿態
dataDir = fullfile(toolboxdir("vision"), "visiondata");
tagImage = imread(fullfile(dataDir, "aprilTag36h11.jpg"));
fprintf("影像 %dx%d\n", size(tagImage,2), size(tagImage,1));

[poseTable, overlay] = ch27_tagPose(tagImage);
disp(poseTable)
%[text] 五個標記，距離 0.50 – 0.61 公尺。
%[text] `Translation` 是**標記原點在相機座標系中的位置**（公尺）。
figure;
imshow(imresize(overlay, 0.4));
title("AR 疊加：座標軸（RGB = XYZ）與立方體")
%[text] AR 疊加的原理很單純：
%[text] 1. 在**標記的座標系**裡定義你要畫的三維物體（立方體的八個角）
%[text] 2. 用 `world2img` 把它們投影到影像
%[text] 3. 用 `insertShape` 把邊連起來
%[text] **沒有任何「渲染」，只有投影。** 所以它畫不出遮擋、陰影、光照——
%[text] 真正的 AR 引擎在這之上還有很多層。
%%
%[text] # 3. 重投影誤差：唯一不需要真值的自我檢查
%[text] `readAprilTag` 回傳一個 `rigidtform3d`，看起來很權威。
%[text] **但姿態估計沒有真值可比**——你不知道那個標記實際在哪。
%[text] 唯一能自己算的檢查是：**把標記的四個角（世界座標已知）
%[text] 用估到的姿態投影回影像，和偵測到的角點比。**
fprintf("重投影誤差（像素）：\n");
disp(poseTable(:, ["Id" "ReprojError"]))
fprintf("中位數 %.2f 像素\n", median(poseTable.ReprojError));
%[text] **1.6 – 2.4 像素。** 這個數字告訴你「姿態和觀測一致」。
%[text] > **注意這裡的重投影誤差比第 25 章可信。**
%[text] > 標定時模型有十幾個自由度、角點有幾百個，
%[text] > 高階項可以在沒有資料的地方亂跑（第 25 章 §4）。
%[text] > **姿態只有 6 個自由度，而四個角提供 8 個約束——
%[text] > 沒有過度參數化的空間。**
%%
%[text] # 4. 但它抓不到 `TagSize` 給錯
%[text] `TagSize` 是你**用尺量出來告訴程式**的。量錯了會怎樣？
tagSizes = [0.02 0.04 0.08]';
MedianDistance = zeros(3,1);
MedianReproj   = zeros(3,1);
for i = 1:3
    r = ch27_tagPose(tagImage, TagSize=tagSizes(i));
    MedianDistance(i) = median(r.Distance);
    MedianReproj(i)   = median(r.ReprojError);
end
disp(table(tagSizes, MedianDistance, MedianDistance/MedianDistance(2), MedianReproj, ...
    VariableNames=["TagSize_m" "距離中位數_m" "相對比值" "重投影誤差_px"]))
%[text:table]
%[text] | TagSize | 距離 | 比值 | **重投影誤差** |
%[text] | --- | --- | --- | --- |
%[text] | 0.02 m | 0.288 m | 0.50 | **1.78 px** |
%[text] | 0.04 m | 0.577 m | 1.00 | **1.78 px** |
%[text] | 0.08 m | 1.154 m | 2.00 | **1.78 px** |
%[text:table]
%[text] > ## **距離完全等比例縮放，重投影誤差一個像素都沒變。**
%[text] **為什麼？** 因為 `TagSize` 只是**定義了世界的單位**。
%[text] 標記在影像上的樣子完全一樣，所以重投影誤差當然一樣。
%[text] > **這和第 25 章練習 3 的「方格邊長給錯」是完全同一件事**：
%[text] > 內參與重投影誤差完全不變，只有外參等比例縮放。
%[text] > **系統裡一定要有一個已知的長度，而且它必須從外面量進來——
%[text] > 沒有任何內部檢查能驗證它。**
%[text] 這是本課程第三次遇到同一個結構：
%[text:table]
%[text] | 章 | 那個「從外面量進來的長度」 |
%[text] | --- | --- |
%[text] | 第 25 章 | 棋盤格的方格邊長 |
%[text] | 第 26 章 | 立體相機的基線（單相機 SLAM 沒有，所以尺度未知） |
%[text] | **第 27 章** | **標記的實際邊長** |
%[text:table]
%%
%[text] # 5. 但它抓得到誤報
%[text] `readAprilTag` 的 `TagFamily` 預設是 `"all"`，搜尋全部九種家族。
allResult = ch27_tagPose(tagImage, TagFamily="all");
fprintf("指定 tag36h11：%d 個標記，重投影誤差中位數 %.2f px、最大 %.2f px\n", ...
    height(poseTable), median(poseTable.ReprojError), max(poseTable.ReprojError));
fprintf("不指定（""all""）：%d 個標記，重投影誤差中位數 %.2f px、**最大 %.2f px**\n", ...
    height(allResult), median(allResult.ReprojError), max(allResult.ReprojError));
%[text:table]
%[text] | | 標記數 | 重投影誤差中位數 | **最大** |
%[text] | --- | --- | --- | --- |
%[text] | 指定 `tag36h11` | **5** | 1.78 px | **2.36 px** |
%[text] | 不指定（`"all"`） | **15** | 2.36 px | **366.50 px** |
%[text:table]
%[text] **多出來的十個是 `tag16h5` 家族的誤報**，而
%[text] **重投影誤差把它們抓出來了**（366 px vs 2 px）。
%[text] > ## **重投影誤差抓得到誤報，抓不到尺寸錯誤。**
%[text] > 差別在於：誤報**和影像不一致**（角點對不上），
%[text] > 尺寸錯誤**和影像完全一致**（只是單位錯了）。
%[text] > **一個指標只能抓到它量得到的那種錯。**
%[text] 而且不指定家族**慢 3.2 倍**（0.40 秒 vs 0.13 秒）。
%[text] **指定家族不是最佳化，是正確性。**
%%
%[text] # 6. ArUco：另一套標記，以及一個必踩的坑
arucoImage = generateArucoMarker("DICT_4X4_1000", 7, 300);
fprintf("產生的 ArUco 標記 %dx%d\n", size(arucoImage,2), size(arucoImage,1));

paddings = [0 10 30 60]';
NumDetected = zeros(4,1);
for i = 1:4
    if paddings(i) == 0
        padded = arucoImage;
    else
        padded = padarray(arucoImage, [paddings(i) paddings(i)], 255, "both");
    end
    NumDetected(i) = numel(readArucoMarker(padded, "DICT_4X4_1000"));
end
disp(table(paddings, NumDetected, VariableNames=["白邊px" "偵測到"]))
%[text:table]
%[text] | 白邊 | 偵測到 |
%[text] | --- | --- |
%[text] | **0 px** | **0** ❌ |
%[text] | 10 px | 1 ✅ |
%[text] | 60 px | 1 ✅ |
%[text:table]
%[text] > ## **標記周圍沒有白邊就偵測不到。**
%[text] > 偵測器靠「黑色方框外面接白色」來找候選區域。
%[text] > 標記貼到邊界上就沒有那個對比，**偵測器直接看不到它**。
%[text] **實務上的意義**：印標記時**一定要留白邊**（通常一個模組寬度），
%[text] 而且**貼的時候不要貼在深色背景上**。
%[text] 這在產線上是一個很常見的失敗——標記貼在機台的黑色面板上，
%[text] 怎麼調參數都偵測不到。
%[text] > **`readArucoMarker` 給內參時會檢查影像尺寸**：
%[text] > 傳一張合成的標記影像配上真實相機的內參，會報
%[text] > 「Image size is not consistent with camera intrinsics」。
%[text] > 那是一個**好的**檢查——它擋住了「用 A 相機的內參去解 B 相機的影像」。
%%
%[text] # 7. PnP：姿態估計的底層
%[text] AprilTag 的姿態其實就是一次 PnP（Perspective-n-Point）：
%[text] **已知 n 個三維點與它們的影像投影，求相機的姿態。**
%[text] MATLAB 的介面是 `estworldpose(imagePoints, worldPoints, intrinsics)`。
%[text] ## 先講一個會讓你 debug 半天的坑
%[text] > **`estworldpose` 回傳的是「相機在世界座標中的姿態」，
%[text] > 而 `world2img` 吃的是「世界到相機的變換」——兩者互為反轉。**
%[text] 直接拿 `est.R` 和你設定的外參比，會得到：
%[text:table]
%[text] | | 殘差 |
%[text] | --- | --- |
%[text] | `est.R' * R_true` | **37.17 度** |
%[text] | **`est.R * R_true`** | **0.000000 度** |
%[text] | `invert(est)` 之後比 | **0.000000 度** |
%[text:table]
%[text] > ## **「殘差很大但幾乎不隨雜訊變動」是座標框搞錯的典型指紋。**
%[text] > 真正的數值問題會**隨雜訊放大**；框架問題是一個**常數偏移**。
%[text] > 我第一次量的時候在四個雜訊等級上都得到 37.0–37.2 度，
%[text] > 那個「太穩定」本身就是線索。
%%
%[text] # 8. PnP 的雜訊敏感度與點數需求
pnpNoise = ch27_pnpStudy(PointCounts=8, NumRepeats=20);
disp(pnpNoise)
%[text:table]
%[text] | 雜訊 σ | 旋轉誤差 | 平移誤差 |
%[text] | --- | --- | --- |
%[text] | 0 px | **0.0016°** | 0.007 mm |
%[text] | 1 px | 0.297° | 2.07 mm |
%[text] | 5 px | 1.477° | 9.55 mm |
%[text] | 10 px | 2.801° | 21.71 mm |
%[text:table]
%[text] **大致線性於雜訊**——沒有突然崩潰的門檻，這是好消息。
pnpPoints = ch27_pnpStudy(PointCounts=[4 5 6 8], NoiseSigmas=1, NumRepeats=30);
disp(pnpPoints)
%[text:table]
%[text] | 點數 | 旋轉誤差 | **成功率** |
%[text] | --- | --- | --- |
%[text] | **4** | **0.821°** | **70%** |
%[text] | 5 | 0.490° | 100% |
%[text] | **6** | **0.342°** | 100% |
%[text] | 8 | 0.301° | 100% |
%[text:table]
%[text] > ## **四個點是 PnP 的理論下限，而它同時是最不準、最容易失敗的。**
%[text] > 從 4 個加到 6 個，誤差**減半**、成功率從 70% 變 100%；
%[text] > 再加到 8 個幾乎沒有改善。
%[text] **這件事對 AprilTag 有直接的後果：一個標記只給你四個角。**
%[text] 所以單一標記的姿態精度有一個內建的天花板。
%[text:table]
%[text] | 改善的方法 | 為什麼有效 |
%[text] | --- | --- |
%[text] | **用多個標記**（已知相對位置） | 點數變多，而且分布更廣 |
%[text] | 用更大的標記 | 角點的像素定位誤差相對變小 |
%[text] | 用 ChArUco 板 | 一塊板子提供幾十個角點（第 25 章 §9） |
%[text] | 跨幀平滑（第 24 章的 Kalman） | 把時間上的多次觀測合起來 |
%[text:table]
%%
%[text] # 9. 人體姿態：HRNet 關鍵點
hasKeypoint = false;
try
    keypointDetector = hrnetObjectKeypointDetector;
    hasKeypoint = true;
    fprintf("hrnetObjectKeypointDetector 載入成功\n");
catch ME
    fprintf("⚠ 無法載入：%s\n", ME.identifier);
    disp("需要 Computer Vision Toolbox Model for Object Keypoint Detection 支援包。")
end

if hasKeypoint
    personImage = imread("visionteam1.jpg");
    peopleBoxes = detectPeopleACF(personImage);
    fprintf("偵測到 %d 個人\n", size(peopleBoxes,1));
    if ~isempty(peopleBoxes)
        t0 = tic;
        keypoints = detect(keypointDetector, personImage, peopleBoxes);
        fprintf("關鍵點偵測 %.2f 秒，輸出 %s\n", toc(t0), mat2str(size(keypoints)));
        figure;
        annotated = insertObjectKeypoints(personImage, keypoints, ...
            KeypointColor="yellow", KeypointSize=4);
        annotated = insertShape(annotated, "rectangle", peopleBoxes, ...
            Color="green", LineWidth=2);
        imshow(annotated); title("HRNet 人體關鍵點")
    end
end
%[text] **HRNet 是「自上而下」的做法**：先偵測人，再在每個框裡找關鍵點。
%[text:table]
%[text] | | 自上而下（HRNet） | 自下而上（OpenPose 類） |
%[text] | --- | --- | --- |
%[text] | 流程 | 偵測人 → 每人找關鍵點 | 找所有關鍵點 → 分組 |
%[text] | 人越多 | **越慢**（線性成長） | 幾乎不變 |
%[text] | 人重疊時 | 框會互相包含，**關鍵點會混** | 分組會出錯 |
%[text] | 精度 | 通常較高 | 通常較低 |
%[text:table]
%[text] > **自上而下的致命弱點：它完全依賴前一步的偵測。**
%[text] > 人沒被偵測到，關鍵點就一定沒有——
%[text] > 這和第 24 章 §10 的「關聯階段修不好偵測階段的錯」
%[text] > 是完全同一個結構。
%[text] R2026a 的 `detect` 新增了 **`Threshold`** 引數，
%[text] 可以**不重建物件**就調整關鍵點的信心門檻。
%%
%[text] # 10. 把姿態接到追蹤上
%[text] 姿態估計是**逐幀**的，所以它有第 23–24 章的全部問題：
%[text:table]
%[text] | 問題 | 第 27 章的版本 |
%[text] | --- | --- |
%[text] | 某一幀偵測不到 | 標記被遮住／反光／模糊 → **沒有姿態** |
%[text] | 逐幀獨立 | 姿態會**抖動**，即使物體沒動 |
%[text] | 沒有身分 | 多個標記時，哪個是哪個？（**AprilTag 有 id，這點它贏**） |
%[text:table]
%[text] > **AprilTag 相對於一般物件偵測的最大優勢：它自帶身分。**
%[text] > 第 24 章花了整整一章處理「跨幀的身分」，
%[text] > 而標記的 id 直接就是身分——**不需要關聯、不會 ID 切換。**
%[text] 剩下的兩個問題要用第 24 章的方法解：
%[text] ```matlab
%[text] % 對每一個 id 維持一個 Kalman 濾波器
%[text] kf = configureKalmanFilter("ConstantVelocity", pose0, ...);
%[text] % 有偵測到就 correct，沒偵測到就只 predict
%[text] if found, correct(kf, measuredPose); else, predict(kf); end
%[text] ```
%[text] > **但姿態不能直接丟進 Kalman。** 平移可以，
%[text] > **旋轉不行**——旋轉矩陣不在歐氏空間裡，
%[text] > 對兩個旋轉矩陣取平均得到的東西通常不是旋轉矩陣。
%[text] > 正確的做法是轉成**四元數**再做球面內插（`slerp`），
%[text] > 或用專門處理 SE(3) 的濾波器。
%[text] **這是本章最容易被忽略的一個陷阱**：把 6 個數字當成 6 個獨立的量去濾波。
%%
%[text] # 11. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 處理 |
%[text] | --- | --- | --- |
%[text] | `readAprilTag(I, intrinsics=...)` | 報「Expected tagFamily to match」 | **內參是位置引數** |
%[text] | 不指定 `TagFamily` | 誤報多 3 倍、慢 3.2 倍 | **一定要指定** |
%[text] | `TagSize` 量錯 | 距離等比例錯，**重投影誤差完全不變** | 只能從外部量測驗證 |
%[text] | ArUco 標記沒留白邊 | **完全偵測不到**，不報錯 | 留至少一個模組的白邊 |
%[text] | 拿 `est.R` 直接和外參比 | 殘差 37 度且**不隨雜訊變動** | `invert(est)`；**「太穩定」是框架錯的指紋** |
%[text] | 只用四個角做 PnP | 誤差加倍、30% 機率失敗 | 多標記、ChArUco、或跨幀平滑 |
%[text] | 把旋轉矩陣丟進 Kalman | 濾出來的不是旋轉矩陣 | 轉四元數，用 `slerp` |
%[text] | 自上而下的關鍵點偵測 | 人沒偵測到就完全沒有關鍵點 | 檢查上游的偵測率 |
%[text] | `world2img` 的角點順序 | 重投影誤差很大但無意義 | 順序要和偵測器的輸出一致 |
%[text:table]
%%
%[text] # 12. 練習
%[text] 練習在 `exercise/Ch27_Exercise.m`。
%%
%[text] # 13. 延伸閱讀
%[text] - `doc readAprilTag` / `doc readArucoMarker` / `doc generateArucoMarker`
%[text] - `doc estworldpose` / `doc world2img` / `doc img2world2d`
%[text] - `doc hrnetObjectKeypointDetector` / `doc posemaskrcnn`
%[text] - `doc plotCamera` / `doc insertObjectKeypoints`
%[text] - 第 25 章 §9：ChArUco 板可以提供幾十個角點
%[text] - 第 24 章 §3：跨幀的姿態平滑

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
