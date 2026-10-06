%[text] # 第 25 章　相機標定與多相機系統
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出標定在估什麼，以及為什麼沒有標定就不能做量測
%[text] 2. **知道重投影誤差不能用來選畸變模型**，並會用第二個指標
%[text] 3. 判讀每張影像的誤差，找出該重拍的那幾張
%[text] 4. 做立體標定，並用**三個獨立方法交叉檢查**基線
%[text] 5. 說出 ChArUco 相對棋盤格的優勢，以及棋盤格**會安靜給出錯答案**的情況
%[text] 6. 把標定結果用在實際量測上，並知道誤差會傳到哪裡
%[text] ## 前置知識
%[text] 第 7 章（幾何變換）、第 11 章（區域量測）、第 14 章（特徵與對應）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox。本章全部使用 MATLAB 內建的標定影像集，
%[text] **不需要外部資料**。
%[text] > ## **本章的一句話**
%[text] > **重投影誤差是這一章最容易被誤信的數字。**
%[text] > §4 會量到兩個模型的重投影誤差只差 **0.0001 像素**，
%[text] > 但去畸變後的影像邊角差了 **225 像素**。
assert(exist("ch25_calibrateSet", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
%%
%[text] # 1. 這一章的位置：把像素變成公釐
%[text] 前面 24 章的輸出都是**像素**。可是產線要的是「這個孔徑是 3.02 公釐」。
%[text] 像素和公釐之間隔著一整組未知數：
%[text:table]
%[text] | 未知 | 是什麼 | 符號 |
%[text] | --- | --- | --- |
%[text] | **內參** | 焦距、主點、傾斜 | $f_x, f_y, c_x, c_y, s$ |
%[text] | **畸變** | 鏡頭讓直線變彎的程度 | $k_1, k_2, \ldots, p_1, p_2$ |
%[text] | **外參** | 相機相對於世界的位置與姿態 | $R, t$ |
%[text:table]
%[text] 標定就是**用一個已知尺寸的圖樣，把這些數字解出來**。
%[text] > **第 11 章的「每像素幾公釐」只在一個平面、一個距離上成立。**
%[text] > 物體離遠一點、偏離光軸一點，那個比例就變了。
%[text] > 標定給你的是一個**在整個視野內都成立**的模型。
%%
%[text] # 2. 第一次標定
[paramsMono, reportMono] = ch25_calibrateSet("mono");
fprintf("資料集 mono：%d 張影像，**偵測成功 %d 張**\n", ...
    reportMono.NumImages, reportMono.NumDetected);
fprintf("棋盤 %s（內角點 %d 個），方格 %d mm\n", ...
    mat2str(reportMono.BoardSize), ...
    prod(reportMono.BoardSize - 1), reportMono.SquareSize);
fprintf("影像尺寸 %dx%d\n", reportMono.ImageSize(2), reportMono.ImageSize(1));
fprintf("\n焦距 %s 像素\n", mat2str(round(reportMono.FocalLength, 2)));
fprintf("主點 %s 像素（影像中心是 %s）\n", ...
    mat2str(round(reportMono.PrincipalPoint, 2)), ...
    mat2str(reportMono.ImageSize([2 1])/2));
fprintf("徑向畸變 %s\n", mat2str(round(reportMono.RadialDistortion, 5)));
fprintf("**平均重投影誤差 %.4f 像素**\n", reportMono.MeanError);
%[text] **10 張全部偵測成功——但這是 R2026b 的結果。**
%[text] 同一組影像在 R2026a 只成功 9 張：`image06.jpg` 的棋盤格偵測失敗。
%[text] R2026b 改進了 `detectCheckerboardPoints`，第 6 張也偵測得到了。
%[text] > **`detectCheckerboardPoints` 失敗時不會報錯**，
%[text] > 只是在 `imagesUsed` 裡標 `false`。
%[text] > **不檢查這個回傳值，你會以為用了 10 張，其實可能只有 9 張。**
%[text] > 而且**換一個 MATLAB 版本，張數就可能不同**——多了一張影像，
%[text] > 後面所有的內參、畸變係數、誤差都跟著變（本章所有用 `mono` 算的數字，在 R2026a 與 R2026b 之間都動了一點）。
%[text] > 升級版本後重跑標定，**第一件事是比對張數**。
%[text] 主點 `[568.27 356.93]` 和影像中心 `[536 356]` 差了 **32 像素**。
%[text] 那不一定是錯的（感光元件確實可能沒對準光軸），
%[text] 但**偏差太大時值得懷疑標定影像的分布**。
fprintf("\n每張影像的平均誤差：\n");
disp(round(reportMono.PerImageError, 4))
fprintf("最差的是第 %d 張（%.4f 像素）\n", ...
    reportMono.WorstImage, max(reportMono.PerImageError));
%[text] > **逐張的誤差比平均值有用得多。** 平均值會把一張爛影像藏起來。
%[text] > 實務上的做法是：**把明顯偏高的那幾張拿掉重標，
%[text] > 或者直接重拍那幾個角度。**
%%
%[text] # 3. 畸變模型該用幾階？
%[text] 一個很自然的想法：多加幾個係數，誤差應該會降。量一次。
modelNames = ["2 階徑向" "2 階 + 切向" "3 階徑向" "3 階 + 切向"];
configs = [2 0; 2 1; 3 0; 3 1];
MeanErr = zeros(4,1);
BowImp  = zeros(4,1);
Coeffs  = strings(4,1);
for i = 1:4
    [~, r] = ch25_calibrateSet("mono", ...
        NumRadial = configs(i,1), Tangential = logical(configs(i,2)));
    MeanErr(i) = r.MeanError;
    BowImp(i)  = r.BowImprovement;
    Coeffs(i)  = mat2str(round(r.RadialDistortion, 5));
end
disp(table(modelNames', MeanErr, Coeffs, ...
    VariableNames=["模型" "重投影誤差" "徑向係數"]))
%[text:table]
%[text] | 模型 | 重投影誤差 | 徑向係數 |
%[text] | --- | --- | --- |
%[text] | 2 階徑向 | **0.1851** | `[-0.34889 0.15714]` |
%[text] | 2 階 + 切向 | 0.1817 | `[-0.4145 0.38374]` |
%[text] | 3 階徑向 | **0.1853** | `[-0.3292 -0.15676 1.23385]` |
%[text] | 3 階 + 切向 | **0.1816** | `[-0.42279 0.48847 -0.3949]` |
%[text:table]
%[text] **重投影誤差幾乎不動**（0.1816–0.1853，全距 2%）。
%[text] **但係數劇烈變動**：$k_2$ 從 `0.157` 變成 `−0.157` 再變成 `0.488`，
%[text] $k_3$ 可以是 `1.234` 也可以是 `−0.395`。
%[text] > **這是典型的「參數不可辨識」。**
%[text] > 幾個係數彼此可以互相抵消，所以有無限多組參數
%[text] > 都能把標定角點擬合得一樣好。**誤差看不出差別，
%[text] > 不代表模型一樣。**
%%
%[text] # 4. **重投影誤差不能用來選畸變模型**
%[text] 上一節的係數差那麼多，**去畸變的結果會一樣嗎？**
[p2, ~] = ch25_calibrateSet("mono", NumRadial=2);
[p3, ~] = ch25_calibrateSet("mono", NumRadial=3);
cmp = ch25_undistortCompare(p2.Intrinsics, p3.Intrinsics, reportMono.ImageSize);

fprintf("兩個模型的重投影誤差差 %.4f 像素\n", ...
    abs(p2.MeanReprojectionError - p3.MeanReprojectionError));
fprintf("但去畸變後：中位數差 %.2f 像素，**最大差 %.2f 像素**\n", ...
    cmp.MedianDiff, cmp.MaxDiff);
fprintf("中心附近 %.2f 像素｜邊角 %.2f 像素\n", cmp.CenterDiff, cmp.CornerDiff);
disp(cmp.RadialProfile)
%[text:table]
%[text] | 離中心的距離 | 去畸變差異中位數 | 最大 |
%[text] | --- | --- | --- |
%[text] | 0 – 161 px | **0.025** | 0.050 |
%[text] | 161 – 322 px | 0.101 | 1.211 |
%[text] | 322 – 483 px | **14.03** | 77.60 |
%[text] | 483 – 643 px | **141.29** | **225.26** |
%[text:table]
%[text] **差異隨半徑單調爆炸。** 中心幾乎沒差，邊角差 225 像素——
%[text] 而影像只有 1072 像素寬。
%[text] > ## **為什麼會這樣**
%[text] > 重投影誤差**只在標定角點的位置計算**。
%[text] > 棋盤格再怎麼擺，角點都不會落在影像的最邊角——
%[text] > **那裡沒有任何資料約束模型。**
%[text] > 高階項在有資料的地方被壓得服服貼貼，
%[text] > 在沒有資料的地方可以任意外插。
%[text] **實務上的三個結論：**
%[text] 1. **標定影像必須覆蓋整個視野，尤其是邊角。**
%[text]    這是所有標定教學都會說的一句話，上面那張表是它的量化理由。
%[text] 2. **不要為了降低重投影誤差而增加模型複雜度。**
%[text]    它幾乎一定會降一點點，而你不知道代價是什麼。
%[text] 3. **需要第二個指標。** 下一節。
figure;
tiledlayout(1,2, TileSpacing="compact");
imgMono = imread(fullfile(toolboxdir("vision"), "visiondata", ...
    "calibration", "mono", "image01.jpg"));
nexttile; imshow(undistortImage(imgMono, p2.Intrinsics)); title("2 階徑向")
nexttile; imshow(undistortImage(imgMono, p3.Intrinsics)); title("3 階徑向")
%%
%[text] # 5. 第二個指標：彎曲度
%[text] 我們需要一個量**在影像各處**都成立的東西。
%[text] 棋盤格上一整排角點在三維空間中是一條**直線**，
%[text] 針孔相機把直線投影成直線——所以**去畸變之後那排點應該是直的**。
%[text] $$\text{彎曲度} = \frac{\text{偏離最佳擬合直線的最大距離}}{\text{直線長度}} \times 100\%$$
%[text] **它是尺度不變的**，所以去畸變前後可以直接比。
fprintf("mono：去畸變前彎曲 %.3f%%，去畸變後 %.3f%%（改善 %.1f%%）\n", ...
    reportMono.BowBefore, reportMono.BowAfter, reportMono.BowImprovement);
%[text] > **這裡有一個我自己踩過的坑。**
%[text] > 第一版我用**絕對**距離（不除以線長）來比，得到
%[text] > 「去畸變讓線變得**更彎**」的結論。
%[text] > 原因是 `undistortPoints` 回傳的座標整體被放大了，
%[text] > 絕對偏差當然跟著變大。**必須用相對量。**
%[text] > 另一個坑：**`detectCheckerboardPoints` 的角點是逐「欄」排序的**，
%[text] > 不是逐「列」。索引搞反會得到一個看起來很大、
%[text] > 但完全沒有意義的彎曲度（我量到 10–13%，真值是 0.2–0.8%）。
%%
%[text] # 6. 四個資料集，兩個指標排序相反
sets = ["mono" "dslr" "gopro" "slr"];
SetName   = sets';
MeanError = zeros(4,1);
BowBefore = zeros(4,1);
BowAfter  = zeros(4,1);
BowImp    = zeros(4,1);
ImgSize   = strings(4,1);
for i = 1:4
    [~, r] = ch25_calibrateSet(sets(i));
    MeanError(i) = r.MeanError;
    BowBefore(i) = r.BowBefore;
    BowAfter(i)  = r.BowAfter;
    BowImp(i)    = r.BowImprovement;
    ImgSize(i)   = sprintf("%dx%d", r.ImageSize(2), r.ImageSize(1));
end
disp(table(SetName, ImgSize, MeanError, BowBefore, BowAfter, BowImp, ...
    VariableNames=["資料集" "尺寸" "重投影誤差" "去畸變前彎曲" "去畸變後" "改善%"]))
%[text:table]
%[text] | 資料集 | 重投影誤差 | 彎曲改善 |
%[text] | --- | --- | --- |
%[text] | **mono** | **0.1851（最好）** | 17.2% |
%[text] | dslr | 0.1905 | 68.0% |
%[text] | gopro | 0.5911 | **94.7%（最好）** |
%[text] | **slr** | **0.9035（最差）** | **−1.7%（最差）** |
%[text:table]
%[text] > ## **兩個指標把 mono 和 gopro 的排序換了過來**
%[text] > 依重投影誤差，`mono` 最好、`gopro` 是它的 3.2 倍。
%[text] > 依彎曲改善，`gopro` 最好（94.7%）、`mono` 只有 17.2%。
%[text] **兩個都沒有錯，它們量的是不同的東西：**
%[text:table]
%[text] | 指標 | 回答的問題 |
%[text] | --- | --- |
%[text] | 重投影誤差 | **模型把標定角點擬合得多好** |
%[text] | 彎曲改善 | **鏡頭本來有多少畸變，修掉了多少** |
%[text:table]
%[text] `mono` 的鏡頭本來就很平（彎曲 0.193%），沒什麼好修的；
%[text] `gopro` 是廣角鏡，彎曲 0.819%，修掉 94.7%。
%[text] `slr` 的彎曲只有 0.089%——**幾乎沒有畸變**，
%[text] 所以「去畸變」反而因為數值誤差讓它變差 1.7%。
%[text] 而它的重投影誤差最高（0.9035），那是**另一個問題**
%[text]（影像最大 2816×1880，角點定位的絕對像素誤差自然較大）。
%[text] > 這和第 20 章「IoU 與 BFscore 排序相反」、
%[text] > 第 21 章「零樣本贏不了特徵抽取」是同一個結構：
%[text] > **一個指標永遠不夠，而兩個指標常常給出相反的排名。**
figure;
yyaxis left;  bar(MeanError); ylabel("平均重投影誤差（像素）")
yyaxis right; plot(1:4, BowImp, "o-", LineWidth=2); ylabel("彎曲改善（%）")
xticks(1:4); xticklabels(sets); grid on
title("兩個指標，幾乎相反的排序")
%%
%[text] # 7. 拍幾張才夠？
%[text] 常見的建議是「10–20 張」。**用量的看看它在說什麼。**
counts = [3 4 5 6 7 9 10]';   % 超過偵測成功的張數時，ch25_calibrateSet 會用全部
FocalX = zeros(numel(counts),1);
PrincX = zeros(numel(counts),1);
K1     = zeros(numel(counts),1);
ErrN   = zeros(numel(counts),1);
for i = 1:numel(counts)
    [~, r] = ch25_calibrateSet("mono", UseImages=1:counts(i));
    FocalX(i) = r.FocalLength(1);
    PrincX(i) = r.PrincipalPoint(1);
    K1(i)     = r.RadialDistortion(1);
    ErrN(i)   = r.MeanError;
end
disp(table(counts, FocalX, PrincX, K1, ErrN, ...
    VariableNames=["張數" "焦距x" "主點x" "k1" "重投影誤差"]))
%[text:table]
%[text] | 張數 | 焦距x | 主點x | k1 | 重投影誤差 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 3 | **752.28** | **621.07** | −0.26543 | 0.1873 |
%[text] | 5 | 710.24 | 592.18 | −0.30201 | 0.1734 |
%[text] | 9 | 716.45 | 582.05 | −0.31821 | 0.1900 |
%[text] | 10 | **715.60** | **568.27** | **−0.34889** | 0.1851 |
%[text:table]
%[text] **焦距漂了 37 像素（5%）、主點漂了 53 像素、$k_1$ 變了 31%。**
%[text] **而重投影誤差全程在 0.173–0.190 之間，看不出任何趨勢。**
%[text] 連最後一步——從 9 張加到 10 張——主點都還移動了 **14 像素**。
%[text] > ## **重投影誤差也不能告訴你張數夠不夠**
%[text] > 這是它第二次失效。它量的是「模型擬合已有資料的程度」，
%[text] > 而**資料不夠的時候，擬合可以很好，只是參數不可靠**。
%[text] > 這就是過擬合的定義。
%[text] **可行的判斷方式**：**加一張影像，看參數變多少**。
%[text] 參數穩定下來了才算夠——這是練習 2 要做的事。
%[text] ## 拍攝的實務準則
%[text:table]
%[text] | 準則 | 為什麼 |
%[text] | --- | --- |
%[text] | **覆蓋整個視野，特別是四個角** | §4 量到邊角沒資料就外插到 225 px 的差 |
%[text] | **角度要變化**（±30° 左右的傾斜） | 正面拍的影像對焦距與距離**無法區分** |
%[text] | 佔畫面 1/3 以上 | 角點的定位精度隨尺寸提高 |
%[text] | 15–25 張 | 少於 10 張時參數還在漂 |
%[text] | **不要動相機，動板子** | 內參是相機的性質，不該混進相機的移動 |
%[text:table]
%%
%[text] # 8. 魚眼：另一個模型家族
[pFish, rFish] = ch25_calibrateSet("gopro", Fisheye=true);
[pPin,  rPin ] = ch25_calibrateSet("gopro", Fisheye=false);
fprintf("gopro（2000x1500 廣角）\n");
fprintf("  魚眼模型：重投影誤差 %.4f，彎曲改善 %.1f%%" + "\n", ...
    rFish.MeanError, rFish.BowImprovement);
fprintf("  針孔模型：重投影誤差 %.4f，彎曲改善 %.1f%%" + "\n", ...
    rPin.MeanError, rPin.BowImprovement);
cmpFish = ch25_undistortCompare(pFish.Intrinsics, pPin.Intrinsics, ...
    rFish.ImageSize, Fisheye=[true false]);
fprintf("  **兩個模型去畸變後差：中位數 %.1f px，最大 %.1f px**\n", ...
    cmpFish.MedianDiff, cmpFish.MaxDiff);
%[text:table]
%[text] | | 魚眼模型 | 針孔模型 |
%[text] | --- | --- | --- |
%[text] | 重投影誤差 | 0.5783 | 0.5911（**只差 2.2%**） |
%[text] | 彎曲改善 | 96.1% | 94.7%（**只差 1.5%**） |
%[text] | **去畸變後的位置** | — | **中位數差 113 px，最大 1281 px** |
%[text:table]
%[text] **兩個指標都說「差不多」，去畸變結果卻差半張影像寬。**
%[text] 這是 §4 的同一個現象，**跨到不同的模型家族**上。
%[text] > **`fisheyeIntrinsics` 沒有 `FocalLength`／`PrincipalPoint`／
%[text] > `RadialDistortion`。** 它用的是完全不同的參數化
%[text] >（Scaramuzza 多項式映射 + `DistortionCenter` + `StretchMatrix`）。
%[text] > 想寫「不管哪個模型都印出焦距」的程式碼會在這裡報
%[text] > 「Unrecognized method, property, or field 'FocalLength'」。
fprintf("\n魚眼的 MappingCoefficients %s\n", ...
    mat2str(round(rFish.MappingCoefficients, 4)));
fprintf("DistortionCenter %s（影像中心 %s）\n", ...
    mat2str(round(rFish.DistortionCenter, 2)), ...
    mat2str(rFish.ImageSize([2 1])/2));
%[text] **什麼時候該用魚眼模型？** 視場角超過約 **120°** 時，
%[text] 針孔模型的投影本身就不成立（$\tan\theta$ 在 90° 發散）。
%[text] `gopro` 這組還在針孔模型勉強撐得住的範圍內，
%[text] 所以兩者的**誤差**接近——**但外插行為完全不同。**
%%
%[text] # 9. 標定圖樣：ChArUco 的優勢，與棋盤格的安靜失敗
robust = ch25_patternRobustness();
disp(robust)
fprintf("預期點數：ChArUco %d，棋盤格 %d\n", ...
    robust.Properties.UserData.ExpectedCharuco, ...
    robust.Properties.UserData.ExpectedChecker);
%[text:table]
%[text] | 遮擋 | ChArUco（滿分 24） | 棋盤格（滿分 54） |
%[text] | --- | --- | --- |
%[text] | 0 – 30% | **24 ✅** | 54 ✅ |
%[text] | **40%** | **24 ✅** | **63 ❌** |
%[text] | **50%** | **24 ✅** | **15 ❌** |
%[text:table]
%[text] > ## **看 40% 那一列：棋盤格回傳了 63 個點——比滿分 54 還多。**
%[text] > 它把剩下的區域當成**另一個尺寸的棋盤**，偵測「成功」了。
%[text] > 除了一個關於「棋盤必須非對稱」的警告之外，**沒有任何錯誤**。
%[text] 拿那 63 個點去標定會怎樣？`estimateCameraParameters`
%[text] 會照常執行，給你一組看起來很正常的內參——**全錯。**
%[text] **所以標定流程一定要檢查偵測到的點數等於預期值。**
%[text] ## 為什麼 ChArUco 撐得住
%[text] 棋盤格的角點**沒有身分**：偵測器必須看到完整的矩形陣列，
%[text] 才能推斷每個角點對應世界座標的哪一格。
%[text] ChArUco 在每個白格裡放一個有**唯一 ID** 的 ArUco 標記，
%[text] 所以只要看得到一部分，就能算出那部分角點的世界座標。
%[text] > **`generateCharucoBoard` 與 `detectCharucoBoardPoints`
%[text] > 接受的字典清單不一樣。**
%[text] > 產生器吃 `DICT_4X4_50`，偵測器只吃
%[text] > `DICT_4X4_1000`／`DICT_5X5_1000`／`DICT_6X6_1000`／
%[text] > `DICT_7X7_1000`／`DICT_ARUCO_ORIGINAL`。
%[text] > 用產生器接受、偵測器不接受的字典，**會在偵測那一步才爆**。
%[text] R2026a 的 `patternWorldPoints` 支援五種圖樣：
fprintf("checkerboard         %s\n", mat2str(size(patternWorldPoints("checkerboard", [7 10], 25))));
fprintf("charuco-board        %s\n", mat2str(size(patternWorldPoints("charuco-board", [7 5], 100))));
fprintf("circle-grid-symmetric %s\n", mat2str(size(patternWorldPoints("circle-grid-symmetric", [4 11], 20))));
fprintf("aprilgrid            %s\n", mat2str(size(patternWorldPoints("aprilgrid", [6 6], 30, 0.3))));
%%
%[text] # 10. 立體與多相機：用三個方法算同一個數字
[~, ~, rs] = ch25_stereoSystem();
fprintf("stereo 資料集：%d/%d 對可用，棋盤 %s，影像 %dx%d\n", ...
    rs.NumPairsUsed, rs.NumPairs, mat2str(rs.BoardSize), ...
    rs.ImageSize(2), rs.ImageSize(1));
fprintf("\n%-28s %12s %12s\n", "方法", "基線 (mm)", "誤差 (px)");
fprintf("%-28s %12.2f %12.4f\n", "estimateCameraParameters", rs.BaselineStereo, rs.ErrorStereo);
fprintf("%-28s %12.2f %12.4f\n", "estimateStereoBaseline",   rs.BaselineOnly,   rs.ErrorBaselineOnly);
if rs.MultiAvailable
    fprintf("%-28s %12.2f %12.4f\n", "estimateMultiCameraParameters", rs.BaselineMulti, rs.ErrorMulti);
else
    fprintf("%-28s %12s %12s\n", "estimateMultiCameraParameters", "（未安裝）", "—");
    disp("（R2026b 起要先執行 installMultiSensorCalibrationTools 才能用多相機標定；下面的全距只比兩種方法）")
end
fprintf("\n**全距 %.3f mm（%.3f%%）**\n", rs.BaselineSpread, rs.BaselineSpreadPct);
fprintf("平移向量 %s mm\n", mat2str(round(rs.Translation, 2)));
%[text] **119.87 / 119.74 / 119.72 mm，全距 0.15 mm（0.13%）。**
%[text] （第三個數字需要多相機標定工具；R2026b 未安裝時只比前兩種方法，全距 0.13 mm、0.11%。）
%[text] > ## **為什麼要算三次**
%[text] > **因為基線沒有真值可比。** 你不知道那兩台相機實際上差幾公分。
%[text] > 三個獨立的估計法吻合到 0.13%，你對這個數字的信心
%[text] > 遠高於只跑一次。
%[text] > 這和第 22 章的留一法、第 24 章「和獨立偵測器比對」是同一個想法：
%[text] > **沒有真值時，用多個獨立方法互相檢查。**
%[text] ## 三個 API 的差別
%[text:table]
%[text] | 函式 | 內參 | 用途 |
%[text] | --- | --- | --- |
%[text] | `estimateCameraParameters(pts, wpts, ImageSize=...)` | **同時估** | 從零開始 |
%[text] | `estimateStereoBaseline(pts, wpts, intr1, intr2)` | **要先給** | 內參已知，只要外參 |
%[text] | `estimateMultiCameraParameters(pts, wpts, intrArray)` | **要先給** | 2 台以上 |
%[text:table]
%[text] > **R2026b 起，多相機標定工具不再內建**：`estimateMultiCameraParameters`、`detectPatternPoints`、
%[text] > `detectMultiPatternPoints` 與 Multi-Camera Calibrator app 都要先執行一次
%[text] > `installMultiSensorCalibrationTools`，否則報「This function requires the Multi-Sensor Calibration Tools」。
%[text] > **`estimateStereoBaseline` 的內參是第 3、4 個位置引數。**
%[text] > 寫成 `ImageSize=...` 會報
%[text] > 「The value of 'intrinsics1' is invalid ... its type was string」
%[text] > ——訊息指向 `intrinsics1`，但你根本沒傳那個引數。
fprintf("\n共視矩陣：\n"); disp(rs.CovisibilityMatrix)
fprintf("每台相機的重投影誤差 %s\n", mat2str(round(rs.ErrorPerCamera, 4)));
%[text] **共視矩陣**是 R2026a 多相機標定的核心：它記錄哪幾台相機
%[text] 同時看得到同一個圖樣。**非重疊視野**的相機系統就是靠它
%[text] 一段一段串起來的——A 和 B 有重疊、B 和 C 有重疊，
%[text] 即使 A 和 C 從來沒看過同一個板子，也能推出它們的相對位置。
%%
%[text] # 11. 用標定結果做量測
%[text] 標定完之後，`undistortImage` 讓直線變直，
%[text] 而 `pointsToWorld` 類的函式把像素換成世界座標。
imgCal = imread(fullfile(toolboxdir("vision"), "visiondata", ...
    "calibration", "gopro", "gopro01.jpg"));
undistorted = undistortFisheyeImage(imgCal, pFish.Intrinsics);
figure;
tiledlayout(1,2, TileSpacing="compact");
nexttile; imshow(imgCal);      title("原始（廣角，直線是彎的）")
nexttile; imshow(undistorted); title("魚眼去畸變後")
%[text] **量測誤差會傳到哪裡？** 三個來源：
%[text:table]
%[text] | 來源 | 大小 | 怎麼降 |
%[text] | --- | --- | --- |
%[text] | 角點定位 | 重投影誤差告訴你的（0.18–0.90 px） | 更好的對焦、更大的板子 |
%[text] | **畸變模型外插** | **§4 量到邊角可達 225 px** | **標定影像覆蓋邊角** |
%[text] | 深度未知 | 單相機無解 | 立體、或已知平面假設 |
%[text:table]
%[text] > **第二項通常被完全忽略**，而它可以比第一項大三個數量級。
%%
%[text] # 12. 本章沒有驗證的部分
%[text] 誠實交代：下面這些在 R2026a 有 API，但本機**沒有資料或硬體可驗證**。
%[text] ## Hand-Eye 標定（機械手臂 + 相機）
%[text] 課綱列的 `estimateHandEyeTransform` **在 R2026a 不存在**。
fprintf("estimateHandEyeTransform 存在？%s\n", ...
    string(exist("estimateHandEyeTransform") ~= 0));
%[text] 實際的做法是解 $AX = XB$ 這個經典問題：
%[text] ```matlab
%[text] % A：機械手臂末端在兩個姿態之間的相對運動（由控制器讀出）
%[text] % B：相機在同樣兩個姿態之間的相對運動（由標定板算出）
%[text] % X：相機相對於末端的固定變換 ← 要求的
%[text] ```
%[text] 需要**至少 3 組**姿態，而且旋轉軸不能共面。
%[text] MATLAB 沒有現成函式，但 Robotics System Toolbox 的
%[text] `se3` 與 `tform2axang` 可以組出來。
%[text] ## OpenCV 相機模型互通
%[text] OpenCV 的畸變係數順序是 `[k1 k2 p1 p2 k3]`，
%[text] **MATLAB 的 `RadialDistortion` 是 `[k1 k2 k3]`、
%[text] `TangentialDistortion` 是 `[p1 p2]`，兩者分開。**
%[text] 而且 **OpenCV 的像素座標從 0 開始，MATLAB 從 1 開始**——
%[text] 主點要 $\pm 1$。**這兩個差異都不會報錯，只會讓結果偏一點點。**
%[text] ## 非重疊視野的多相機
%[text] 本章只驗證了 2 台**完全重疊**的相機（`CovisibilityMatrix` 全 true）。
%[text] 非重疊的情況需要至少 3 台且兩兩之間有重疊鏈，本機沒有這種資料。
%%
%[text] # 13. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 處理 |
%[text] | --- | --- | --- |
%[text] | **用重投影誤差選畸變模型** | 誤差差 0.0001，邊角差 225 px | **加量彎曲度**，並覆蓋邊角 |
%[text] | **用重投影誤差判斷張數夠不夠** | 誤差平穩，參數還在漂 5% | **看參數的穩定性** |
%[text] | 不檢查 `imagesUsed` | 以為用了 10 張其實 9 張；**換版本後張數不同** | 檢查回傳值，升級後先比對張數 |
%[text] | **不檢查偵測到的點數** | 遮擋時棋盤格回傳 63 個點還「成功」 | **比對預期點數** |
%[text] | 方格邊長給錯 | 焦距與外參整組等比例錯，**無警告** | 量一次板子 |
%[text] | 角點索引當成逐列 | 彎曲度算出 10–13%（真值 0.2–0.8%） | **是逐欄排序** |
%[text] | 用絕對距離比去畸變前後 | 結論反向 | **用相對量** |
%[text] | `fisheyeIntrinsics` 當成 `cameraIntrinsics` | `FocalLength` 不存在 | 兩個模型家族的參數化不同 |
%[text] | `estimateStereoBaseline` 傳 `ImageSize=` | 報 `intrinsics1` 無效 | 內參是位置引數 3、4 |
%[text] | ChArUco 字典用產生器的清單 | 偵測那一步才爆 | 偵測器只吃 `*_1000` 與 `DICT_ARUCO_ORIGINAL` |
%[text] | OpenCV 畸變係數直接照抄 | 結果偏一點點，不報錯 | 順序不同、座標原點差 1 |
%[text:table]
%%
%[text] # 14. 練習
%[text] 練習在 `exercise/Ch25_Exercise.m`。
%%
%[text] # 15. 延伸閱讀
%[text] - **Camera Calibrator** / **Stereo Camera Calibrator**（APP 頁籤）
%[text] - `doc estimateCameraParameters` / `doc estimateFisheyeParameters`
%[text] - `doc estimateMultiCameraParameters` / `doc multiCameraParameters`
%[text] - `doc detectPatternPoints` / `doc patternWorldPoints`
%[text] - `doc generateCharucoBoard` / `doc detectCharucoBoardPoints`
%[text] - `doc showExtrinsics` / `doc showReprojectionErrors` / `doc plotCamera`
%[text] - 第 26 章：用標定好的立體相機做三維重建

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
