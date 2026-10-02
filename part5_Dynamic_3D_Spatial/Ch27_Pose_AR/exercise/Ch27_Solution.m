%[text] # 第 27 章　練習解答
%[text] {"align":"left"}姿態估測與擴增實境　｜　MATLAB R2026b
%[text] > **練習 1 推翻了主教材 §3 對重投影誤差的評價。**
%[text] > 它抓不到的東西比抓得到的多，而且**焦距錯 10% 時
%[text] > 重投影誤差反而變小**。
assert(exist("ch27_tagPose", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

dataDir = fullfile(toolboxdir("vision"), "visiondata");
S = load(fullfile(dataDir, "camIntrinsicsAprilTag.mat"));
intrinsics = S.intrinsics;
tagImage = imread(fullfile(dataDir, "aprilTag36h11.jpg"));
%%
%[text] # 解答 1　重投影誤差抓得到哪些錯
%[text] ## 我的預期
%[text] 「內參錯掉一定會讓重投影誤差爆增。」**錯了。**
% **注意**：在腳本裡定義的函式是 local function，**不共用腳本的工作區**。
% 寫成小幫手去 append 外層變數會報「Unrecognized function or variable」。
% 所以這裡用一個 cell 陣列把五種設定列出來，再一次跑完。
badFocal = cameraIntrinsics(intrinsics.FocalLength*0.9, ...
    intrinsics.PrincipalPoint, intrinsics.ImageSize);
badPrincipal = cameraIntrinsics(intrinsics.FocalLength, ...
    intrinsics.PrincipalPoint + [200 150], intrinsics.ImageSize);

results = { ...
    "① 正確設定",            ch27_tagPose(tagImage);
    "② TagSize 錯 2 倍",     ch27_tagPose(tagImage, TagSize=0.08);
    "③ 焦距錯 10%",          ch27_tagPose(tagImage, Intrinsics=badFocal);
    "④ 主點錯 200,150 px",   ch27_tagPose(tagImage, Intrinsics=badPrincipal);
    "⑤ family=all（有誤報）", ch27_tagPose(tagImage, TagFamily="all") };

nCase       = size(results,1);
Setting     = strings(nCase,1);
MedianError = zeros(nCase,1);
MaxError    = zeros(nCase,1);
NumTags     = zeros(nCase,1);
for c = 1:nCase
    r = results{c,2};
    Setting(c)     = results{c,1};
    MedianError(c) = median(r.ReprojError);
    MaxError(c)    = max(r.ReprojError);
    NumTags(c)     = height(r);
end

disp(table(Setting, NumTags, MedianError, MaxError, ...
    VariableNames=["設定" "標記數" "誤差中位數px" "誤差最大px"]))
%[text] ## 量到的結果
%[text:table]
%[text] | 設定 | 誤差中位數 | 誤差最大 | 抓到了嗎 |
%[text] | --- | --- | --- | --- |
%[text] | ① 正確 | 1.78 | 2.36 | — |
%[text] | ② `TagSize` 錯 2 倍 | **1.78** | 2.36 | ❌ **完全沒變** |
%[text] | ③ **焦距錯 10%** | **1.70** | — | ❌ **反而變小** |
%[text] | ④ **主點錯 200,150 px** | **1.87** | — | ❌ 幾乎沒變 |
%[text] | ⑤ `family="all"` | 2.36 | **366.50** | ✅ **抓到了** |
%[text:table]
%[text] **第 3 小題：焦距錯 10%，重投影誤差從 1.78 掉到 1.70——變小了。**
%[text] > ## **因為 PnP 會把內參的錯誤吸收進姿態。**
%[text] > 求解器的目標就是「找一個姿態讓投影對上觀測」。
%[text] > 焦距小 10%，它就把標記放遠 10%，投影出來**一模一樣**。
%[text] > **重投影誤差當然不會變大——它衡量的正是這件事。**
%[text] 主點錯 200 像素也一樣：姿態往旁邊偏一點就補回來了。
%[text] **第 4 小題：重投影誤差的判準**
%[text] > **它只抓得到「和影像觀測不一致」的錯，
%[text] > 抓不到任何「可以被姿態的六個自由度吸收掉」的錯。**
%[text] 誤報之所以抓得到，是因為那些角點**根本不是一個標記的角**，
%[text] 沒有任何姿態能讓它們對上——所以誤差衝到 366 像素。
%[text] **第 5 小題：改寫主教材 §3**
%[text:table]
%[text] | 原文 | 問題 |
%[text] | --- | --- |
%[text] | 「唯一不需要真值就能算的自我檢查」 | **語氣太強**，暗示它能驗證姿態正確 |
%[text:table]
%[text] 修正版：
%[text] > **重投影誤差驗證的是「姿態和影像觀測自洽」，
%[text] > 不是「姿態正確」。** 它抓得到偵測誤報與角點對應錯誤，
%[text] > **抓不到任何內參或尺寸的系統性錯誤**——
%[text] > 那些會被姿態完整吸收。
%[text] **第 6 小題：抓不到的錯要怎麼驗**
%[text:table]
%[text] | 錯誤 | 驗證方法 |
%[text] | --- | --- |
%[text] | `TagSize` 錯 | **用尺量標記，再量相機到標記的實際距離** |
%[text] | 焦距錯 | 第 25 章的標定流程（**而那也需要已知的方格邊長**） |
%[text] | 主點錯 | 同上；或用覆蓋整個視野的標定資料 |
%[text] | 誤報 | ✅ 重投影誤差就夠 |
%[text:table]
%[text] > **前三項全部指回「外部的已知長度」。**
%[text] > 這是第 25 章（方格邊長）、第 26 章（立體基線）、
%[text] > 第 27 章（標記邊長）連續三章的同一個結論：
%[text] > **系統裡一定要有一個從外面量進來的長度，
%[text] > 而且沒有任何內部檢查能驗證它。**
%%
%[text] # 解答 2　標記多遠就不能用了
tagHalf = 0.02;                                   % 4 公分的標記
tagCorners = [-tagHalf tagHalf 0; tagHalf tagHalf 0; ...
               tagHalf -tagHalf 0; -tagHalf -tagHalf 0];
distances = [0.3 0.6 1.2 2.4 5]';
SidePx   = zeros(numel(distances),1);
RotErr   = zeros(numel(distances),1);
TransErr = zeros(numel(distances),1);
nRepeat = 30;
if ipcvFast(), nRepeat = 10; end

for i = 1:numel(distances)
    T = rigidtform3d(eul2rotm(deg2rad([5 -8 3])), [0 0 distances(i)]);
    projected = world2img(tagCorners, T, intrinsics);
    SidePx(i) = norm(projected(1,:) - projected(2,:));
    rotE = []; transE = [];
    for r = 1:nRepeat
        noisy = projected + randn(4,2)*0.5;
        try
            est = estworldpose(noisy, tagCorners, intrinsics, MaxReprojectionError=3);
            back = invert(est);
            rotE(end+1)   = rad2deg(norm(rotm2eul(back.R * T.R'))); %#ok<AGROW>
            transE(end+1) = norm(back.Translation - T.Translation)*1000; %#ok<AGROW>
        catch
        end
    end
    RotErr(i)   = mean(rotE);
    TransErr(i) = mean(transE);
end
disp(table(distances, SidePx, RotErr, TransErr, ...
    VariableNames=["距離m" "標記邊長px" "旋轉誤差度" "平移誤差mm"]))

figure;
loglog(SidePx, RotErr, "o-", LineWidth=1.8); hold on
yline(2, "--r", "2 度精度需求");
grid on; set(gca, "XDir", "reverse");
xlabel("標記在影像上的邊長（像素）"); ylabel("旋轉誤差（度）");
title("精度由「標記佔幾個像素」決定")
%[text] ## 量到的結果
%[text:table]
%[text] | 距離 | 標記邊長 | 旋轉誤差 | 平移誤差 |
%[text] | --- | --- | --- | --- |
%[text] | 0.3 m | 358 px | **1.32°** | 0.51 mm |
%[text] | 0.6 m | 179 px | 2.82° | 2.20 mm |
%[text] | 1.2 m | 90 px | 8.09° | 6.94 mm |
%[text] | 2.4 m | 45 px | 13.21° | 23.92 mm |
%[text] | 5.0 m | **22 px** | **19.27°** | **158.25 mm** |
%[text:table]
%[text] **第 4、5 小題：邊長減半，旋轉誤差大約加倍到三倍。**
%[text] 要求 **2 度以內**的話，這個 4 公分的標記**只能用到約 0.45 公尺**
%[text]（邊長約 240 像素）。
%[text] **第 6 小題：工作距離加倍要把標記也加倍。**
%[text] 因為影像上的邊長 $\propto$ 標記實際尺寸 / 距離——
%[text] 兩者同時加倍，像素邊長不變，精度也不變。
%[text] > **決定精度的不是距離，是「標記佔了幾個像素」。**
%[text] > 這和第 23 章加分題「目標面積決定能縮幾倍」、
%[text] > 第 22 章「先量你的瑕疵佔幾個像素」是同一句話。
%%
%[text] # 解答 3　退化的點組態
%[text] ## 我的預期
%[text] 「八個共面的點應該比四個共面的點好不少。」**幾乎沒有。**
cubeWorld = [0 0 0; .1 0 0; .1 .1 0; 0 .1 0; ...
             0 0 .1; .1 0 .1; .1 .1 .1; 0 .1 .1];
planarWorld = [0 0 0; .1 0 0; .1 .1 0; 0 .1 0; ...
               .05 0 0; .1 .05 0; .05 .1 0; 0 .05 0];
tinyWorld = cubeWorld * 0.05;
poseTrue = rigidtform3d(eul2rotm(deg2rad([10 -15 5])), [0.1 -0.05 0.8]);

configs = { "① 立體 8 點",        cubeWorld,        1:8;
            "② 共面 4 點",        cubeWorld,        1:4;
            "③ 共面 8 點",        planarWorld,      1:8;
            "④ 立體 8 點縮 20 倍", tinyWorld,        1:8 };

ConfigName = strings(4,1);
RotError   = zeros(4,1);
Success    = zeros(4,1);
for c = 1:4
    W = configs{c,2}(configs{c,3}, :);
    projected = world2img(W, poseTrue, intrinsics);
    errs = [];
    for r = 1:nRepeat
        noisy = projected + randn(size(projected))*1;
        try
            est = estworldpose(noisy, W, intrinsics, MaxReprojectionError=3);
            back = invert(est);
            errs(end+1) = rad2deg(norm(rotm2eul(back.R * poseTrue.R'))); %#ok<AGROW>
        catch
        end
    end
    ConfigName(c) = configs{c,1};
    RotError(c)   = mean(errs);
    Success(c)    = numel(errs) / nRepeat * 100;
end
disp(table(ConfigName, RotError, Success, ...
    VariableNames=["組態" "旋轉誤差度" "成功率%"]))
%[text] ## 量到的結果
%[text:table]
%[text] | 組態 | 旋轉誤差 | 成功率 |
%[text] | --- | --- | --- |
%[text] | **① 立體 8 點** | **0.35°** | 100% |
%[text] | ② 共面 4 點 | 0.96° | **93%** |
%[text] | **③ 共面 8 點** | **0.96°** | 100% |
%[text] | **④ 立體 8 點縮 20 倍** | **5.80°** | 100% |
%[text:table]
%[text] （這是隨機實驗，跨執行會有變動；另一次執行量到
%[text] 0.29 / 0.78 / 0.86 / 6.10 度。**排序與數量級穩定，絕對值不穩定。**）
%[text] **第 4 小題：③ 比 ② 多了四個點，誤差完全沒有改善（0.96 vs 0.96）。**
%[text] > ## **點的「幾何」比點的「數量」重要得多。**
%[text] > 共面的點對相機的深度方向**幾乎沒有約束**——
%[text] > 平面可以往前移一點同時轉一點，投影出來幾乎一樣。
%[text] > 再加多少共面的點都不會改善那個方向。
%[text] 對照主教材 §8：**立體**的點從 4 加到 6 讓誤差減半。
%[text] **同樣是「加點」，共面時完全沒用、立體時有用。**
%[text] **第 5 小題：④ 縮小 20 倍是練習 2 的同一件事。**
%[text] 點在影像上佔的範圍變小，角點的像素誤差相對就變大。
%[text] 誤差從 0.35 變成 5.80 度（**17 倍**）。
%[text] **第 6 小題：讓 PnP 變準的三個條件，按重要性排序**
%[text:table]
%[text] | 排序 | 條件 | 證據 |
%[text] | --- | --- | --- |
%[text] | **1** | **點要佔滿影像**（不要縮在一角） | 縮 20 倍 → 誤差 17 倍 |
%[text] | **2** | **點不要共面** | 共面 8 點比立體 8 點差 2.7 倍 |
%[text] | 3 | 點數 4 → 6 | 誤差減半（**但只在立體時**） |
%[text:table]
%[text] > **AprilTag 同時踩到第 2 和第 3 個問題**：
%[text] > 它的四個角是**共面**的，而且只有四個。
%[text] > 這就是主教材 §8 說的「內建天花板」。
%[text] > 多標記（加分題）之所以有效，是因為它**同時**改善了三項。
%%
%[text] # 解答 4　AR 疊加對不對，怎麼驗
[poseTable, ~] = ch27_tagPose(tagImage);
fprintf("正確設定的重投影誤差中位數：%.2f px\n", median(poseTable.ReprojError));
%[text] **第 3 小題：離開平面的點驗不了。**
%[text] 標記只給你**平面上**四個角的觀測。立方體的上面四個角
%[text] 是你**用姿態外插出來的**——**沒有任何觀測可以對照**。
%[text] > ## **AR 疊加裡被驗證過的只有「貼在標記平面上的那一層」。**
%[text] > 立方體越高，外插得越遠，誤差被放大得越多——
%[text] > 而**你看不出來**，因為沒有東西可以比。
%[text] **第 4、5 小題：兩種錯誤看起來不一樣。**
%[text:table]
%[text] | 錯誤 | 立方體看起來 | 為什麼 |
%[text] | --- | --- | --- |
%[text] | **`TagSize` 錯 2 倍** | **完全一樣** | 尺度只改變單位，投影不變 |
%[text] | **焦距錯 10%** | **底面仍貼合，上面歪掉** | 姿態吸收了誤差，但**外插的方向錯了** |
%[text:table]
%[text] **第 6 小題：「看起來對」能保證什麼**
%[text:table]
%[text] | 能保證 | 不能保證 |
%[text] | --- | --- |
%[text] | 標記平面上的對應是對的 | **尺度對**（差 2 倍也一樣） |
%[text] | 偵測沒有誤報 | **內參對**（底面照樣貼合） |
%[text] | — | **離開平面的外插對** |
%[text:table]
%[text] > **AR 展示的說服力和它的驗證強度完全不成比例。**
%[text] > 一個貼得很漂亮的立方體，可能建立在錯 2 倍的尺度上。
%%
%[text] # 解答 5　旋轉不能直接平均
R0   = eul2rotm(deg2rad([0 0 0]));
R170 = eul2rotm(deg2rad([170 0 0]));

Ravg = (R0 + R170) / 2;
fprintf("逐元素平均的結果：\n");
fprintf("  R'*R 離單位矩陣的最大偏差：%.4f\n", max(abs(Ravg'*Ravg - eye(3)), [], "all"));
fprintf("  det(R) = %.4f（應該是 1）\n", det(Ravg));
fprintf("  **這不是一個旋轉矩陣。**\n");

q0   = quaternion(rotm2quat(R0));
q170 = quaternion(rotm2quat(R170));
qMid = slerp(q0, q170, 0.5);
Rslerp = quat2rotm(compact(qMid));
fprintf("\nslerp 的結果：\n");
fprintf("  R'*R 離單位矩陣的最大偏差：%.2e\n", max(abs(Rslerp'*Rslerp - eye(3)), [], "all"));
fprintf("  det(R) = %.6f\n", det(Rslerp));
fprintf("  對應的旋轉角 %.2f 度（正確答案是 85 度）\n", ...
    rad2deg(norm(rotm2eul(Rslerp))));

angleBetween = rad2deg(norm(rotm2eul(Rslerp' * localNormalize(Ravg))));
fprintf("\n兩種做法的「中間旋轉」差 %.2f 度\n", angleBetween);

fprintf("\n改成只差 10 度：\n");
R10 = eul2rotm(deg2rad([10 0 0]));
Ravg10 = (R0 + R10)/2;
q10 = quaternion(rotm2quat(R10));
Rslerp10 = quat2rotm(compact(slerp(q0, q10, 0.5)));
fprintf("  逐元素平均的 det = %.6f（170 度時是 %.4f）\n", det(Ravg10), det(Ravg));
fprintf("  兩種做法差 %.4f 度（170 度時是 %.2f 度）\n", ...
    rad2deg(norm(rotm2eul(Rslerp10' * localNormalize(Ravg10)))), angleBetween);
%[text] ## 量到的結果
%[text:table]
%[text] | | 逐元素平均 | **`slerp`** |
%[text] | --- | --- | --- |
%[text] | 角度差 170° 的 `det(R)` | **0.0076** | **1.000000** |
%[text] | 角度差 170° 的 `R'R` 偏差 | **0.9924** | **4.4e-16** |
%[text] | 角度差 10° 的 `det(R)` | 0.9924 | 1.000000 |
%[text:table]
%[text] **逐元素平均的結果完全不是旋轉矩陣**（170 度時 `det` = 0.0076）。
%[text] ## 但第 5 小題的答案和我預期的不一樣
%[text] 我預期「兩種做法的中間旋轉會差很多度」。**實測差 0.00 度。**
%[text] 原因是我在比較之前用 SVD 把平均後的矩陣**投影回最近的旋轉矩陣**
%[text]（`localNormalize`）。而**對「同一個旋轉軸上的兩個旋轉取中點」
%[text] 這個特例，投影回去之後剛好就等於 `slerp` 的答案。**
%[text] > ## **所以正確的說法要更精確：**
%[text] > **逐元素平均的結果不是旋轉矩陣**（這一點無條件成立），
%[text] > 但**如果你記得把它投影回 SO(3)**，在簡單的情況下
%[text] > 答案可能是對的。
%[text] > **問題是你多半不會記得**——因為
%[text] > `det = 0.9924`（10 度那個情況）看起來很像 1，
%[text] > 後續的運算也不會報錯。
%[text] **第 6 小題：角度差小的時候錯誤小到看不出來。**
%[text] `det` 從 170 度時的 0.0076 變成 10 度時的 0.9924。
%[text] > ## **而那正是它危險的地方。**
%[text] > 小角度時程式**看起來能跑**，數值也「差不多」。
%[text] > 等到某一幀物體轉快了、或追蹤跳了一次，
%[text] > 矩陣退化得很嚴重——**而且沒有任何警告**。
%[text] > 這和第 24 章「KLT 鎖在背景上卻回報 5 個有效點」
%[text] > 是同一類：**平常看起來正常的東西，在極端情況下安靜地崩潰。**
%[text] **一般情況下（旋轉軸不同、超過兩個旋轉）兩種做法會分歧**，
%[text] 而且平均的權重也不對——`slerp` 在球面上等速，
%[text] 逐元素平均在弦上等速。**用四元數是唯一不用擔心這些的做法。**
%[text] **正確的做法**：旋轉一律用四元數，內插用 `slerp`，
%[text] 濾波用專門處理 SO(3)／SE(3) 的方法。
%[text] 平移可以照常用 Kalman，**但要和旋轉分開處理**。
%%
%[text] # 解答 6　印一張標記，量你自己的場景
%[text] 這一題必須用實體標記與實體的尺，沒有辦法在教材裡執行。
%[text] **但第 5 小題（用尺量實際距離）是整章唯一能驗證絕對尺度的步驟**，
%[text] 而解答 1 證明了為什麼它不可省略：
%[text:table]
%[text] | 檢查 | 抓得到尺度錯誤嗎 |
%[text] | --- | --- |
%[text] | 重投影誤差 | ❌ |
%[text] | AR 疊加看起來對不對 | ❌ |
%[text] | 姿態的數值合不合理 | ⚠ 只有在你知道大概多遠時 |
%[text] | **用尺量** | ✅ **唯一可靠** |
%[text:table]
%[text] > **第 6 小題的答案**：它揭露的是
%[text] > **整條管線裡有一段完全沒有被檢查的環節**——
%[text] > 從「你告訴程式的 TagSize」到「程式算出的距離」之間，
%[text] > 沒有任何自動的驗證。第 25 章的方格邊長、
%[text] > 第 26 章的立體基線都有同樣的缺口。
%%
%[text] # 加分題解答　多標記聯合姿態
markerHalf = 0.02;
offsets = [0 0; 0.2 0; 0 0.2; 0.2 0.2];
singleCorners = [-markerHalf markerHalf 0; markerHalf markerHalf 0; ...
                  markerHalf -markerHalf 0; -markerHalf -markerHalf 0];

coplanarWorld = [];
for m = 1:4
    coplanarWorld = [coplanarWorld; singleCorners + [offsets(m,:) 0]]; %#ok<AGROW>
end
raisedWorld = coplanarWorld;
raisedWorld([9:16], 3) = 0.10;        % 後兩個標記抬高 10 公分

poseMulti = rigidtform3d(eul2rotm(deg2rad([8 -12 4])), [0.1 0.1 1.0]);

Strategy  = strings(0,1);
RotErrDeg = zeros(0,1);
for scenario = ["共面" "不共面"]
    if scenario == "共面"
        W = coplanarWorld;
    else
        W = raisedWorld;
    end
    projected = world2img(W, poseMulti, intrinsics);

    % ① 只用第一個標記
    errsSingle = [];
    errsJoint  = [];
    for r = 1:nRepeat
        noisy = projected + randn(size(projected))*0.5;
        try
            e1 = estworldpose(noisy(1:4,:), W(1:4,:), intrinsics, MaxReprojectionError=3);
            b1 = invert(e1);
            errsSingle(end+1) = rad2deg(norm(rotm2eul(b1.R * poseMulti.R'))); %#ok<AGROW>
        catch
        end
        try
            e3 = estworldpose(noisy, W, intrinsics, MaxReprojectionError=3);
            b3 = invert(e3);
            errsJoint(end+1) = rad2deg(norm(rotm2eul(b3.R * poseMulti.R'))); %#ok<AGROW>
        catch
        end
    end
    Strategy(end+1,1)  = scenario + "｜① 單標記 4 點";   %#ok<AGROW>
    RotErrDeg(end+1,1) = mean(errsSingle);               %#ok<AGROW>
    Strategy(end+1,1)  = scenario + "｜③ 16 點聯合";     %#ok<AGROW>
    RotErrDeg(end+1,1) = mean(errsJoint);                %#ok<AGROW>
end
disp(table(Strategy, RotErrDeg, VariableNames=["策略" "旋轉誤差度"]))
%[text] ## 量到的結果
%[text:table]
%[text] | 場景 | ① 單標記 4 點 | **③ 16 點聯合** | 改善 |
%[text] | --- | --- | --- | --- |
%[text] | 共面（四個標記在同一平面） | 7.34° | **0.372°** | **20 倍** |
%[text] | **不共面**（兩個抬高 10 cm） | 4.44° | **0.177°** | **25 倍** |
%[text:table]
%[text] **聯合求解勝過單標記 20–25 倍**，而且**不共面時又好一倍**——
%[text] 和解答 3 的結論完全一致：**幾何比數量重要。**
%[text] 注意單標記在「不共面」那一列也比較好（4.44 vs 7.34），
%[text] 但那只是因為抬高的標記離相機比較近、在影像上比較大——
%[text] **那是解答 2 的效應，不是幾何的效應。**
%[text] **第 4 小題：② 和 ③ 的差別**
%[text] 「各自解再平均」有兩個問題：
%[text] 1. **旋轉不能直接平均**（解答 5），必須用 `slerp` 或四元數平均
%[text] 2. **每個標記各自的解都很差**（4 個共面點），
%[text]    平均四個很差的估計不會變成一個好的估計——
%[text]    **它們的誤差是相關的**（同一個退化方向）
%[text] **③ 把 16 個點一起丟進去**才是對的：
%[text] 求解器看到的是一組**分布很廣**的點，退化方向被消掉了。
%[text] > **這和第 24 章「配對比較消掉切分變異」、
%[text] > 第 26 章「MSAC 找內點 + 最小平方精修」是同一個原則：
%[text] > 把資訊放進同一個估計問題裡，比分開估計再合併好。**
%[text] **第 6 小題：多標記聯合需要什麼**
%[text] > **你必須先知道四個標記彼此的相對位置與姿態。**
%[text] 那個資訊從哪裡來？
%[text:table]
%[text] | 來源 | 誤差 |
%[text] | --- | --- |
%[text] | **機構設計值**（標記貼在治具的已知位置） | 裝配公差 |
%[text] | **事先標定**（用一次多視角量測解出來） | 標定誤差 |
%[text] | ChArUco 板（廠商保證的版面） | 印刷與貼合誤差 |
%[text:table]
%[text] **那個誤差會直接加到最終姿態上**，而且
%[text] **重投影誤差抓得到它**——因為標記相對位置錯的話，
%[text] 沒有任何單一姿態能讓 16 個點同時對上。
%[text] > 所以多標記系統的重投影誤差**比單標記的更有診斷價值**。
%[text] > 這是解答 1 那個結論的一個例外，而理由是一樣的：
%[text] > **多餘的約束才能讓誤差顯現出來。**

% ========================================================================
% 本解答用到的本地函式

function R = localNormalize(M)
%LOCALNORMALIZE 把一個「接近旋轉矩陣」的矩陣投影回最近的旋轉矩陣。
%   用 SVD：M = U*S*V'，最近的旋轉矩陣是 U*V'。
%   **這正是逐元素平均之後必須做的修補**——
%   但修補改變不了「平均本身就不是正確的內插」這件事。
[U, ~, V] = svd(M);
R = U * V';
if det(R) < 0
    V(:,3) = -V(:,3);
    R = U * V';
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
