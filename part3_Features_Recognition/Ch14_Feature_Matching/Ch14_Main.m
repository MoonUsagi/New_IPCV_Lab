%[text] # 第 14 章　特徵偵測、描述與比對
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出八種關鍵點偵測器的差異，並用**已知變換**量測它們的重複性
%[text] 2. 區分「**重複性**」與「**可比對性**」——這是本章最重要的觀念
%[text] 3. 為一組關鍵點選擇合適的描述子，並知道哪些組合不合法
%[text] 4. 用 `matchFeatures` + `estgeotform2d` 完成比對與外點剔除
%[text] 5. 說出 `estgeotform2d` 的方向慣例，避免把變換估反
%[text] 6. 使用 R2026a 新增的 `selectStrongest`／`selectUniform` 索引輸出
%[text] 7. 完成影像拼接與影像檢索，並評估它們的品質 \
%[text] ## 前置知識
%[text] 第 07 章（幾何變換與影像對位）、第 10 章（邊緣與角點的概念）。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="14");
rng(0);
%%
%[text] # 1. 這一章的位置
%[text] 前面的章節處理**一張**影像。這一章開始處理**兩張以上**，
%[text] 而核心問題只有一個：
%[text] **這兩張影像裡，哪些點是同一個東西？**
%[text] 答對了這個問題，下面這些任務就都通了：
%[text:table]
%[text] | 任務 | 做法 |
%[text] | --- | --- |
%[text] | 影像拼接（panorama） | 找對應點 → 估幾何變換 → 疊合 |
%[text] | 物件比對 | 在雜亂場景中找到目標的對應點 |
%[text] | 影像對位（第 07 章） | 特徵法比強度法更能處理大位移 |
%[text] | 影像檢索 | 把特徵量化成「視覺詞」再建索引 |
%[text] | 相機標定、SfM、SLAM（第 25–27 章） | 全部建立在對應點上 |
%[text:table]
%[text] 流程固定是四步：
%[text] **① 偵測**關鍵點 → **② 描述**每個點的鄰域 →
%[text] **③ 比對**描述子 → **④ 剔除**錯誤的配對。
%[text] 這一章的重點是：**每一步都有它自己的失敗方式，而且會互相掩蓋。**
%%
%[text] # 2. 八種關鍵點偵測器
I = im2gray(imread("cameraman.tif"));
detNames = ["SIFT" "SURF" "ORB" "KAZE" "BRISK" "Harris" "FAST" "MSER"];

fprintf("\n%-10s %10s %14s\n", "偵測器", "點數", "回傳型別");
for d = detNames
    pts = ch14_detect(d, I);
    fprintf("%-10s %10d %14s\n", d, pts.Count, class(pts));
end

figure
tiledlayout(2,4, TileSpacing="compact")
for d = detNames
    pts = ch14_detect(d, I);
    nexttile
    imshow(I); hold on
    if d == "MSER"
        % MSERRegions 不支援 selectStrongest（它是區域不是點），
        % 而且沒有「強度」可排序。直接畫前 80 個區域。
        plot(pts(1:min(80, pts.Count)), "showPixelList", true, "showEllipses", false);
    else
        plot(selectStrongest(pts, min(80, pts.Count)));
    end
    hold off
    title(sprintf("%s (%d)", d, pts.Count))
end
sgtitle("八種偵測器，各畫最多 80 個點／區域")
%[text] 點數差異很大（ORB 1332 個、SURF 180 個），但**點多不代表比較好**。
%[text] 回傳型別也不同，而這件事在第 4 節會變成關鍵：
%[text:table]
%[text] | 型別 | 偵測器 | 有沒有自己的尺度／方向 |
%[text] | --- | --- | --- |
%[text] | `SIFTPoints` | SIFT | 有尺度、有方向 |
%[text] | `SURFPoints` | SURF | 有尺度、有方向 |
%[text] | `ORBPoints` | ORB | 有尺度、有方向 |
%[text] | `KAZEPoints` | KAZE | 有尺度、有方向 |
%[text] | `BRISKPoints` | BRISK | 有尺度、有方向 |
%[text] | **`cornerPoints`** | **Harris、FAST** | **都沒有** |
%[text] | `MSERRegions` | MSER | 是區域不是點 |
%[text:table]
%[text] `Harris` 與 `FAST` 只回報「這裡有個角」，不回報它有多大、朝哪邊。
%%
%[text] # 3. 重複性：用已知變換量測
%[text] 「好的偵測器」的第一個要求是：
%[text] **同一個物理位置，在變換後的影像裡還要被偵測到。**
%[text] 這件事可以嚴格量測，做法是**自己造變換**，所以正確答案已知：
%[text] 1. 在原圖偵測關鍵點
%[text] 2. 用已知的 `tform` 把影像變換
%[text] 3. 在變換後的影像偵測關鍵點
%[text] 4. 把**原圖的點**用同一個 `tform` 投影過去
%[text] 5. 若投影位置附近（3 像素內）有偵測到的點，算一次「重複偵測」
%[text] **第 4 步是關鍵**：只有投影**落在畫面內**的點才納入分母，
%[text] 被轉出畫面的點不算失敗——否則旋轉越大分數自動越低，變成量錯東西。
repeatTbl = ch14_detectorRepeatability(I);
disp(repeatTbl)
%[text] 實測（`cameraman.tif`）：
%[text:table]
%[text] | 偵測器 | 旋轉 15° | 旋轉 45° | 縮放 0.7 | 縮放 1.5 | 旋轉30+縮放0.8 | 點數 |
%[text] | --- | --- | --- | --- | --- | --- | --- |
%[text] | SIFT | 74.5% | 85.6% | **49.8%** | 71.7% | 58.5% | 245 |
%[text] | SURF | 67.7% | 51.4% | 67.8% | **47.6%** | 52.2% | 180 |
%[text] | ORB | 87.6% | **41.1%** | 94.6% | 57.2% | 69.3% | 1332 |
%[text] | KAZE | 85.4% | 80.1% | 76.1% | 79.3% | 75.7% | 631 |
%[text] | **BRISK** | 85.8% | **88.3%** | **91.8%** | **83.6%** | **91.6%** | 428 |
%[text] | Harris | 81.2% | 75.3% | 67.9% | 82.0% | 74.1% | 184 |
%[text] | FAST | 83.9% | 88.5% | 85.7% | 76.0% | 87.5% | 237 |
%[text:table]
%[text] 兩個結果值得注意，而且都與「常識」相反：
%[text] **① SIFT 在縮放 0.7 只有 49.8%，是那一欄最差的。**
%[text] SIFT 的名字裡就有「尺度不變」（Scale-Invariant），怎麼會這樣？
%[text] 因為縮小影像會讓細尺度的特徵**物理上消失**——
%[text] 不是 SIFT 定位錯了，是那些特徵在低解析度下不存在了。
%[text] 尺度不變性保證的是「同一個特徵在不同尺度下能被認出」，
%[text] **不保證「特徵在任何尺度下都還在」**。
%[text] **② ORB 在旋轉 45° 掉到 41.1%**，而它有方向估計。
%[text] 45° 是最糟的角度：ORB 的 FAST 基礎偵測器用的是固定的像素環樣板，
%[text] 在 45° 時樣板與像素格點的對齊最差。
%[text] **③ `Harris` 與 `FAST` 明明沒有尺度或旋轉不變性，分數卻不低。**
%[text] 這不是矛盾——角點的**位置**在旋轉下本來就相當穩定。
%[text] > **但這裡有一個陷阱，下一節會揭穿它。**
%[text] > 重複性只量「位置有沒有被再次偵測到」，
%[text] > 完全沒有量「你能不能把它們**配對起來**」。
%%
%[text] # 4. 描述子：`extractFeatures` 給每種點什麼
fprintf("\n%-10s %8s %18s %14s %10s\n", ...
    "偵測器", "點數", "描述子型別", "維度", "有效點");
for d = ["SIFT" "SURF" "ORB" "KAZE" "BRISK" "Harris" "FAST"]
    pts = ch14_detect(d, I);
    [f, v] = extractFeatures(I, pts);
    if isa(f, "binaryFeatures")
        dimStr = sprintf("%d bytes", f.NumBits/8);
    else
        dimStr = mat2str(size(f));
    end
    fprintf("%-10s %8d %18s %14s %10d\n", ...
        d, pts.Count, class(f), dimStr, v.Count);
end
%[text] 兩件必須記住的事：
%[text] **① SIFT 的描述子比關鍵點**多**。**
%[text:table]
%[text] | 影像 | 關鍵點 | 描述子 | 多出 |
%[text] | --- | --- | --- | --- |
%[text] | `cameraman.tif` | 245 | **311** | +26.9% |
%[text] | `peppers.png` | 320 | 374 | +16.9% |
%[text] | `circuit.tif` | 424 | 529 | +24.8% |
%[text:table]
%[text] SIFT 對主方向不明確的關鍵點會**指派多個方向**，每個方向產生一個描述子。
%[text] 所以 **`pts(i)` 不對應 `desc(i,:)`**。
%[text] 一定要用 `extractFeatures` 的**第二個輸出** `validPoints` 來對應：
%[text] ```matlab
%[text] [desc, vpts] = extractFeatures(I, pts);   % 用 vpts，不要用 pts
%[text] matched = vpts(pairs(:,1));
%[text] ```
%[text] **② 有些偵測器的點會被丟掉。**
%[text] `BRISK` 428 個點只剩 365 個有效、`Harris` 184 剩 166——
%[text] 太靠近邊界的點無法取出完整鄰域，會被 `extractFeatures` 移除。
%[text] 這也是必須用 `validPoints` 的另一個理由。
%%
%[text] # 5. 本章最重要的一節：重複性 ≠ 可比對性
%[text] 現在把完整的四步流程跑一次，看**配對**的結果。
matchTbl = ch14_matchAndVerify(I, simtform2d(0.8, 30, [0 0]));
disp(matchTbl)
%[text] 同一個變換（縮放 0.8 + 旋轉 30°），完整流程的結果：
%[text:table]
%[text] | 偵測器 | 第 3 節的重複性 | 配對數 | 內點數 | 內點率 | 秒數* |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | **SIFT** | 58.5% | **72** | **72** | **100.0%** | 0.048 |
%[text] | SURF | 52.2% | 23 | 13 | 56.5% | 0.011 |
%[text] | **ORB** | 69.3% | **159** | **143** | 89.9% | 0.017 |
%[text] | KAZE | 75.7% | 37 | 31 | 83.8% | 0.068 |
%[text] | **BRISK** | **91.6%** | **7** | 6 | 85.7% | 0.205 |
%[text] | Harris | 74.1% | 6 | 6 | 100.0% | 0.049 |
%[text] | FAST | 87.5% | 5 | 4 | 80.0% | 0.035 |
%[text:table]
%[text] *秒數是**暖機後**的值，而且與機器有關。
%[text] 第一次呼叫某個偵測器會慢很多（初始化成本）——
%[text] 第 10 章量 `imfindcirclesYOLO` 時也踩過同一個坑：
%[text] **量效能前一定要先暖機，否則量到的是載入時間。**
%[text] **把兩欄放在一起看，結論完全反轉：**
%[text] - **BRISK 的重複性最高（91.6%），配對數卻最少（7 個）。**
%[text] - **FAST 的重複性 87.5%，只配到 5 個。**
%[text] - **SIFT 的重複性只有 58.5%，卻配到 72 個而且 100% 都是內點。**
%[text] 為什麼？因為這是**兩個不同的能力**：
%[text:table]
%[text] | 能力 | 由誰負責 | 第 3 節量到的 |
%[text] | --- | --- | --- |
%[text] | **重複性**：同一位置能被再次偵測到 | **偵測器** | ✅ 這個 |
%[text] | **可比對性**：描述子能唯一地認出對應點 | **描述子** | ❌ 完全沒量 |
%[text:table]
%[text] BRISK 找得到同樣的位置，但它的二元描述子在這個變換下區辨力不足，
%[text] `matchFeatures` 無法唯一決定配對，於是大量候選被丟掉。
%[text] > **只量重複性會選到 BRISK 或 FAST，然後在真實任務上只拿到 5–7 個配對。**
%[text] > 這與第 12、13 章的教訓是同一件事：
%[text] > **一個指標永遠不夠，而且兩個指標常常給出相反的排序。**
%[text] **實務結論**
%[text] - 要**最可靠**的配對：`SIFT`（72 配對、100% 內點）
%[text] - 要**最多**配對且更快：`ORB`（143 內點，比 SIFT 快約 2.8 倍）
%[text] - **不要**只因為重複性高就選 `BRISK`／`FAST`
%[text] 注意 `BRISK` 在這個測試裡**又慢又配不到**（0.205 秒、7 組配對），
%[text] 是七個之中最差的組合——儘管它的重複性最高。
%%
%[text] # 6. 換描述子能不能救回 Harris？
%[text] 上一節 Harris 只配到 6 個。問題在描述子還是偵測器？
%[text] 做法很直接：**固定偵測器，只換描述子。**
ptsH = detectHarrisFeatures(I);
fprintf("\nHarris 點 %d 個。換不同描述子：\n\n", ptsH.Count);
fprintf("%-10s %14s %10s %10s %12s\n", ...
    "描述子", "維度", "配對數", "內點數", "內點率");

R = imref2d(size(I));
J = imwarp(I, simtform2d(0.8, 30, [0 0]), OutputView=R);
for m = ["Block" "SURF" "KAZE" "BRISK"]
    try
        p1 = detectHarrisFeatures(I);
        p2 = detectHarrisFeatures(J);
        [f1, v1] = extractFeatures(I, p1, Method=m);
        [f2, v2] = extractFeatures(J, p2, Method=m);
        if isa(f1, "binaryFeatures")
            dimStr = sprintf("%d bytes", f1.NumBits/8);
        else
            dimStr = mat2str(size(f1,2));
        end
        pairs = matchFeatures(f1, f2, Unique=true);
        if size(pairs,1) < 4
            fprintf("%-10s %14s %10d %10s %12s\n", m, dimStr, size(pairs,1), "不足", "--");
            continue
        end
        [~, inl] = estgeotform2d(v2(pairs(:,2)), v1(pairs(:,1)), ...
            "similarity", MaxNumTrials=2000);
        fprintf("%-10s %14s %10d %10d %11.1f%%" + "\n", ...
            m, dimStr, size(pairs,1), nnz(inl), 100*mean(inl));
    catch ME
        fprintf("%-10s %14s %10s  %s\n", m, "--", "FAIL", ME.message);
    end
end
%[text] 實測：
%[text:table]
%[text] | 描述子 | 維度 | 配對數 | 內點數 | 內點率 |
%[text] | --- | --- | --- | --- | --- |
%[text] | **`Block`** | 121 | **1** | 不足 | — |
%[text] | **`SURF`** | 64 | **10** | 7 | 70.0% |
%[text] | `KAZE` | 64 | 4 | 4 | 100.0% |
%[text] | `BRISK` | 二元 | 1 | 不足 | — |
%[text:table]
%[text] **`Block` 只配到 1 組。** `Block` 描述子就是**原始的影像區塊**
%[text] （11×11 = 121 維的灰階值），它**完全沒有旋轉或尺度不變性**——
%[text] 影像一轉，區塊的內容就全變了。
%[text] 換成 `SURF` 描述子後配對數從 1 升到 10（10 倍），
%[text] 證明**問題確實在描述子，不在 Harris 偵測器**。
%[text] 但 10 個配對仍然遠少於 SIFT 的 72 個——
%[text] 因為 Harris 點沒有尺度資訊，`SURF` 描述子只能用固定的取樣半徑。
%[text] **有一個組合是不合法的：**
%[text] ```matlab
%[text] extractFeatures(I, detectHarrisFeatures(I), Method="ORB")
%[text] % 錯誤：To extract ORB feature vectors, use ORBPoints only.
%[text] ```
%[text] > **描述子需要偵測器提供尺度與方向。**
%[text] > 偵測器不給，描述子就只能猜一個固定值——這是 `cornerPoints`
%[text] > 配對能力先天不足的根源，換描述子只能部分補償。
%%
%[text] # 7. `matchFeatures` 的參數：誠實的版本
%[text] `MaxRatio` 是**比例測試**（ratio test）：
%[text] 最近鄰的距離必須小於次近鄰的 `MaxRatio` 倍，才接受這個配對。
%[text] 教科書都說它很重要。**實測它多數時候沒有差別。**
fprintf("\n=== 對照組：cameraman（非重複紋理），純平移 ===\n");
Jt = imwarp(I, simtform2d(1.0, 0, [25 15]), OutputView=R);
q1 = detectSIFTFeatures(I); q2 = detectSIFTFeatures(Jt);
[g1, w1] = extractFeatures(I, q1);
[g2, w2] = extractFeatures(Jt, q2);
fprintf("%-10s %10s %10s %12s\n", "MaxRatio", "配對數", "內點數", "內點率");
for mr = [0.3 0.5 0.7 0.9 1.0]
    pairs = matchFeatures(g1, g2, MaxRatio=mr, Unique=true);
    [~, inl] = estgeotform2d(w2(pairs(:,2)), w1(pairs(:,1)), ...
        "similarity", MaxNumTrials=3000);
    fprintf("%-10.1f %10d %10d %11.1f%%" + "\n", ...
        mr, size(pairs,1), nnz(inl), 100*mean(inl));
end
%%
%[text] ## 7.1 讓 `MaxRatio` 真的發揮作用
%[text] 比例測試處理的是**歧義**。要看到它的效果，就需要一張
%[text] **到處都長得一樣**的影像。
board = checkerboard(24, 8, 8) > 0.5;
Irep = im2uint8(im2double(board) * 0.8 + 0.1);
Irep = imnoise(Irep, "gaussian", 0, 0.0005);
Rr = imref2d(size(Irep));
Jrep = imwarp(Irep, simtform2d(1.0, 0, [25 15]), OutputView=Rr);

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile; imshow(Irep); title("棋盤格：每個角點都長得一樣")
nexttile; imshow(I);    title("cameraman：每個角點都不一樣")

r1 = detectSIFTFeatures(Irep); r2 = detectSIFTFeatures(Jrep);
[h1, u1] = extractFeatures(Irep, r1);
[h2, u2] = extractFeatures(Jrep, r2);
fprintf("\n=== 棋盤格（高度重複紋理），純平移 ===\n");
fprintf("%-10s %10s %10s %12s\n", "MaxRatio", "配對數", "內點數", "內點率");
for mr = [0.3 0.5 0.7 0.9 1.0]
    pairs = matchFeatures(h1, h2, MaxRatio=mr, Unique=true);
    [~, inl] = estgeotform2d(u2(pairs(:,2)), u1(pairs(:,1)), ...
        "similarity", MaxNumTrials=3000);
    fprintf("%-10.1f %10d %10d %11.1f%%" + "\n", ...
        mr, size(pairs,1), nnz(inl), 100*mean(inl));
end
%[text] 實測對照：
%[text:table]
%[text] | MaxRatio | cameraman 配對／內點率 | **棋盤格** 配對／內點率 |
%[text] | --- | --- | --- |
%[text] | 0.3 | 226 / 99.6% | 671 / **99.6%** |
%[text] | 0.5 | 226 / 99.6% | 677 / 98.7% |
%[text] | 0.7 | 226 / 99.6% | 682 / 98.1% |
%[text] | 0.9 | 226 / 99.6% | 687 / 97.5% |
%[text] | 1.0 | 226 / 99.6% | 708 / **94.6%** |
%[text:table]
%[text] **在 cameraman 上，五個設定的結果完全相同**——
%[text] 226 個配對、99.6% 內點率，一個數字都沒變。
%[text] 在棋盤格上才看得出效果：`MaxRatio` 從 0.3 放到 1.0，
%[text] 配對數多了 37 個（+5.5%），但內點率從 99.6% 掉到 94.6%。
%[text] 換來的 37 組配對裡，**大部分是錯的**。
%[text] > **`MaxRatio` 是安全網，不是調校旋鈕。**
%[text] > 內容有歧義（重複紋理、週期結構、單色區域）時它會救你；
%[text] > 內容不歧義時調它完全沒用。
%[text] > 預設值 0.6 已經夠保守，**先不要動它**——
%[text] > 若配對太少，問題幾乎總是在偵測器或描述子的選擇，不在這個參數。
%[text] `Unique=true` 則是要求**一對一**配對（雙向最佳）。
%[text] 實測它讓配對數從 74 降到 72（cameraman、縮放旋轉），影響很小但方向明確：
%[text] **建議一直開著**，因為多對一的配對在估幾何變換時是純粹的雜訊。
%%
%[text] # 8. 復原變換：`estgeotform2d` 與一個方向陷阱
%[text] 有了配對就能估幾何變換。但**引數順序決定你估到哪個方向**。
pairs = matchFeatures(g1, g2, Unique=true);
Jw = imwarp(I, simtform2d(0.8, 30, [0 0]), OutputView=R);
s1 = detectSIFTFeatures(I); s2 = detectSIFTFeatures(Jw);
[d1, e1] = extractFeatures(I, s1);
[d2, e2] = extractFeatures(Jw, s2);
pp = matchFeatures(d1, d2, Unique=true);

[tfEst, inl] = estgeotform2d(e2(pp(:,2)), e1(pp(:,1)), "similarity");
A = tfEst.A;
sEst = hypot(A(1,1), A(1,2));
rEst = atan2d(A(2,1), A(1,1));

fprintf("\n我套用的變換：縮放 0.8、旋轉 +30 度（I -> Jw）\n");
fprintf("estgeotform2d(moving=Jw 的點, fixed=I 的點) 估的是 **Jw -> I**\n");
fprintf("所以預期得到縮放 1/0.8 = %.4f、旋轉 -30 度\n\n", 1/0.8);
fprintf("估計結果：縮放 %.4f、旋轉 %.2f 度\n", sEst, rEst);
fprintf("誤差：縮放 %.6f（%.3f%%）、旋轉 %.3f 度\n", ...
    abs(sEst - 1/0.8), 100*abs(sEst-1/0.8)/(1/0.8), abs(abs(rEst) - 30));
fprintf("內點 %d / %d\n", nnz(inl), numel(inl));
%[text] 實測：估計縮放 **1.2500**、旋轉 **−29.99°**，
%[text] 縮放誤差 **0.003%**、旋轉誤差 **0.015°**，內點 72 / 72。
%[text] **精確度非常高**——特徵法配上 MSAC 在有足夠內點時幾乎是精確解。
%[text] > **但注意那個負號與倒數。**
%[text] > `estgeotform2d(movingPoints, fixedPoints)` 估的是
%[text] > **把 moving 映射到 fixed** 的變換。
%[text] > 我把 `Jw` 的點當 moving、`I` 的點當 fixed，所以估到的是 `Jw → I`，
%[text] > 也就是我套用變換的**反變換**。
%[text] 這個陷阱很常見，症狀是「拼接出來的圖方向相反」或
%[text] 「校正後的影像變形更嚴重」。判斷方法：
%[text] **把估到的變換套回去，看能不能還原**——下一節的拼接就是這樣驗證的。
%[text] 第 07 章提過 `estimateGeometricTransform` 已被 `estgeotform2d` 取代。
%[text] 兩者的**引數順序相同**，但回傳的物件型別不同
%[text] （`affine2d` → `affinetform2d`），而且新版的 `A` 矩陣是
%[text] **行向量慣例的轉置**。舊程式直接改函式名會拿到轉置的矩陣。
%%
%[text] # 9. R2026a：`selectStrongest` 與 `selectUniform` 回傳索引
%[text] R2026a 讓這兩個函式可以**同時回傳被選中點的線性索引**。
%[text] 支援 SIFT、SURF、ORB、KAZE、BRISK 與 `cornerPoints`。
pts = detectSIFTFeatures(I);
[strongest, idxS] = selectStrongest(pts, 50);
[uniform,  idxU] = selectUniform(pts, 50, size(I));

fprintf("\n原始 %d 點\n", pts.Count);
fprintf("selectStrongest(pts, 50) -> %d 點，索引 %s\n", ...
    strongest.Count, mat2str(size(idxS)));
fprintf("selectUniform(pts, 50, size) -> %d 點，索引 %s\n", ...
    uniform.Count, mat2str(size(idxU)));
fprintf("\n前 5 個 strongest 的索引：%s\n", mat2str(idxS(1:5)'));
fprintf("驗證：pts(idxS) 與 strongest 的位置相同？%d\n", ...
    isequal(pts.Location(idxS,:), strongest.Location));
%%
%[text] ## 9.1 索引輸出解決什麼問題
%[text] 沒有索引時，要把「篩選後的點」對應回**別的陣列**
%[text] （例如已經算好的描述子、或每個點的自訂標籤）只能自己比對座標——
%[text] 慢、而且座標相同時會出錯。
[allDesc, allValid] = extractFeatures(I, pts);
customScore = rand(allValid.Count, 1);          % 假設每個點有一個自訂分數

[sel, idx] = selectStrongest(allValid, 30);
fprintf("\n有了索引，可以直接對應回描述子與自訂資料：\n");
fprintf("  篩選後 %d 點\n", sel.Count);
fprintf("  對應的描述子：allDesc(idx, :) -> %s\n", mat2str(size(allDesc(idx,:))));
fprintf("  對應的自訂分數：customScore(idx) -> %s\n", mat2str(size(customScore(idx))));
%[text] **注意這裡用的是 `allValid` 而不是 `pts`。**
%[text] 因為第 4 節說過 SIFT 的描述子比關鍵點多，
%[text] `allDesc` 的列數對應的是 `allValid`，不是 `pts`。
%[text] 弄錯就會索引到不對的描述子——而且**不會報錯**。
%[text] `selectStrongest` 與 `selectUniform` 的差別：
%[text] - **`selectStrongest`**：只看強度。可能全部集中在影像的一小塊
%[text] - **`selectUniform`**：兼顧**空間分布**，強迫點散開
%[text] 估幾何變換時 `selectUniform` 通常更好——
%[text] 集中在一角的點對變換的約束力很差（第 07 章的同一個道理）。
%%
%[text] # 10. 影像拼接
%[text] 把前面的步驟串起來，做一個最小但**可驗證**的拼接。
%[text] 為了能驗證，這裡從**一張完整影像**切出兩塊有重疊的區域——
%[text] 這樣原圖就是 ground truth。
Big   = im2gray(imread("peppers.png"));
left  = Big(:, 1:320);
right = Big(:, 200:512);

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile; imshow(left);  title("左圖（第 1–320 欄）")
nexttile; imshow(right); title("右圖（第 200–512 欄）")

[pano, stitchInfo] = ch14_stitchPair(left, right);
disp(stitchInfo)

figure
tiledlayout(2,1, TileSpacing="compact")
nexttile; imshow(pano); title("拼接結果")
nexttile; imshow(Big);  title("原圖（正確答案）")
%[text] 實測：
%[text:table]
%[text] | 項目 | 數值 |
%[text] | --- | --- |
%[text] | 配對數 | 89 |
%[text] | 內點數 | 89（**100%**） |
%[text] | 估計的 x 平移 | **198.94**（真實 199） |
%[text] | 平移誤差 | **0.06 像素** |
%[text] | 拼接結果 vs 原圖 PSNR | **41.227 dB** |
%[text:table]
%[text] 重疊區有 121 欄，89 個配對全部是內點，平移估到 **0.06 像素**。
%[text] > **重疊量是拼接成功的關鍵。** 重疊太少就沒有足夠的共同特徵。
%[text] > 實務上建議相鄰影像重疊 **30% 以上**；
%[text] > 本例的 121/320 = 38% 是舒適區。
%[text] 41.2 dB 而非無限大，是因為右圖經過 `imwarp` 重新取樣
%[text] （雙線性內插）而產生的微小差異，不是配對錯誤。
%%
%[text] # 11. HOG：方向梯度直方圖
%[text] HOG 不是關鍵點描述子，而是**整張影像（或整個視窗）的**描述子。
%[text] 它是第 16 章傳統物件偵測的基礎。
Ismall = imresize(I, [64 64]);
fprintf("\n%-12s %14s %12s\n", "CellSize", "特徵維度", "秒數");
for cs = [4 8 16 32]
    t = tic; hf = extractHOGFeatures(Ismall, CellSize=[cs cs]); el = toc(t);
    fprintf("%-12s %14d %12.4f\n", sprintf("[%d %d]", cs, cs), numel(hf), el);
end

[hogFeat, hogVis] = extractHOGFeatures(Ismall, CellSize=[8 8]);
figure
tiledlayout(1,2, TileSpacing="compact")
nexttile; imshow(Ismall); title("64x64 輸入")
nexttile; imshow(Ismall); hold on; plot(hogVis); hold off
title(sprintf("HOG 視覺化（CellSize [8 8]，%d 維）", numel(hogFeat)))
%[text] `CellSize` 對維度的影響是**平方**的（秒數與機器有關，僅供參考）：
%[text:table]
%[text] | CellSize | 特徵維度 |
%[text] | --- | --- |
%[text] | [4 4] | **8100** |
%[text] | [8 8] | 1764 |
%[text] | [16 16] | 324 |
%[text] | [32 32] | **36** |
%[text:table]
%[text] 從 [4 4] 到 [32 32]，維度差了 **225 倍**。
%[text] > **這是第 16 章訓練 SVM 時的第一個決定。**
%[text] > 維度太高會過擬合且訓練慢；太低會丟掉形狀細節。
%[text] > `[8 8]` 是行人偵測的經典設定，也是多數情況的合理起點。
%%
%[text] # 12. LBP：局部二元模式紋理描述
%[text] LBP 描述的是**紋理**，對均勻的亮度變化不敏感。
texNames = ["fabric.png" "rice.png" "circuit.tif" "hestain.png"];
lbpFeat = []; kept = strings(0);
for f = texNames
    A = imresize(im2gray(imread(f)), [128 128]);
    lbpFeat(end+1,:) = extractLBPFeatures(A);
    kept(end+1) = f;
end
fprintf("\nLBP 特徵維度 = %d（預設的 uniform LBP）\n", size(lbpFeat,2));

fprintf("\n兩兩距離（越小越像）：\n%-14s", "");
fprintf("%13s", kept); fprintf("\n");
for a = 1:numel(kept)
    fprintf("%-14s", kept(a));
    for b = 1:numel(kept)
        fprintf("%13.4f", norm(lbpFeat(a,:) - lbpFeat(b,:)));
    end
    fprintf("\n");
end
%%
%[text] ## 12.1 驗證 LBP 真的在描述紋理
%[text] 距離矩陣本身無法告訴你 LBP 好不好。要驗證，就得問：
%[text] **同一材質的兩個不同區塊，距離會不會比不同材質小？**
A = im2gray(imread("fabric.png"));
C = im2gray(imread("circuit.tif"));
b1 = extractLBPFeatures(imresize(A(1:100, 1:100), [128 128]));
b2 = extractLBPFeatures(imresize(A(end-99:end, end-99:end), [128 128]));
c1 = extractLBPFeatures(imresize(C(1:100, 1:100), [128 128]));

dSame  = norm(b1 - b2);
dDiff  = norm(b1 - c1);
fprintf("\nfabric 區塊1 vs fabric 區塊2（同材質）= %.4f\n", dSame);
fprintf("fabric 區塊1 vs circuit 區塊1（異材質）= %.4f\n", dDiff);
fprintf("比值 = %.2f 倍\n", dDiff/dSame);
assert(dDiff > dSame, "LBP 沒有把同材質判為更相似，請檢查。");
%[text] 實測：同材質 **0.1697**、異材質 **0.4534**，比值 **2.67 倍**。
%[text] **這個驗證才讓距離矩陣有意義。**
%[text] 若同材質的距離與異材質差不多，那整個特徵就沒有區辨力——
%[text] 而你從距離矩陣本身看不出這件事。
%[text] > 這是第 12 章「自己寫的量測要先驗證」的同一個動作：
%[text] > **先用已知答案確認工具有效，再用它去回答未知的問題。**
%%
%[text] # 13. 影像檢索：`indexImages` / `retrieveImages`
%[text] 把局部特徵量化成「視覺詞」（Bag of Features），就能建倒排索引，
%[text] 在大量影像中快速找相似的。
[precTbl, retrInfo] = ch14_retrievalPrecision();
disp(precTbl)
fprintf("\n%s\n", retrInfo.Note);
%[text] 資料庫：4 個來源影像 × 3 個變體（原圖、旋轉 10°、縮小再放大）= 12 張。
%[text] 用每一張當查詢，看前 3 名有幾張屬於同一個來源。
%[text:table]
%[text] | 判準 | 精確度 |
%[text] | --- | --- |
%[text] | 含查詢影像自己 | **100.0%**（36/36） |
%[text] | **排除自己** | **100.0%**（24/24） |
%[text:table]
%[text] > **「含自己」那一列是有問題的判準。** 查詢影像就在資料庫裡，
%[text] > 所以第 1 名必然是它自己——那一分是免費的，不代表檢索能力。
%[text] > 評估檢索一定要**排除查詢自身**，或用資料庫外的影像當查詢。
%[text] 這裡兩個數字都是 100%，所以結論不變。但**這是因為題目太簡單**：
%[text] 只有 4 個來源，而且視覺差異極大（辣椒 / 人像 / 電路板 / 布料）。
%[text] 真實檢索任務會有數千個類別與大量相似樣本。
%[text] **建索引時的訊息值得讀一次**：MATLAB 會印出
%[text] 它用 `detectSURFFeatures` 取點、保留最強的 80% 特徵、
%[text] 並建立視覺詞彙表。這些都可以調
%[text] （`bagOfFeatures` 的 `VocabularySize`、`StrongestFeatures`）。
%%
%[text] # 14. 常見陷阱
%[text] **① 假設 `pts(i)` 對應 `desc(i,:)`。**
%[text] SIFT 的描述子比關鍵點多 17–27%（多方向指派），
%[text] BRISK／Harris 則會丟掉邊界點。**一定要用 `validPoints`。**
%[text] **② 只用重複性選偵測器。**
%[text] BRISK 重複性 91.6% 但只配到 7 組；SIFT 重複性 58.5% 卻配到 72 組
%[text] 且 100% 內點（第 5 節）。
%[text] **③ 對 `cornerPoints` 用 `Block` 描述子。**
%[text] 它就是原始灰階區塊，**沒有旋轉不變性**，實測只配到 1 組（第 6 節）。
%[text] **④ 想對 Harris 點用 ORB 描述子。**
%[text] 直接報錯：`To extract ORB feature vectors, use ORBPoints only.`
%[text] **⑤ 花時間調 `MaxRatio`。**
%[text] 在非重複紋理上，0.3 到 1.0 五個設定的結果**完全相同**（第 7 節）。
%[text] 配對太少時要換偵測器或描述子，不是調這個。
%[text] **⑥ 弄反 `estgeotform2d` 的方向。**
%[text] `estgeotform2d(moving, fixed)` 估的是 moving → fixed。
%[text] 症狀是拼接方向相反或校正後變形更嚴重（第 8 節）。
%[text] **⑦ 把舊的 `estimateGeometricTransform` 直接改成 `estgeotform2d`。**
%[text] 回傳型別從 `affine2d` 變成 `affinetform2d`，
%[text] 而 `A` 矩陣是舊版 `T` 的**轉置**。
%[text] **⑧ 期待 SIFT 在任何縮放下都有高重複性。**
%[text] 縮放 0.7 只有 49.8%——細尺度特徵在低解析度下**物理上消失**了，
%[text] 尺度不變性救不了（第 3 節）。
%[text] **⑨ 評估檢索時把查詢影像自己算進去。**
%[text] 第 1 名必然是自己，那一分是免費的（第 13 節）。
%[text] **⑩ 重疊不足就想拼接。**
%[text] 建議相鄰影像重疊 30% 以上；本章的 38% 是舒適區（第 10 節）。
%%
%[text] # 15. 本章小結
%[text] **重複性與可比對性是兩件事**
%[text] 這是本章唯一必須記住的觀念。偵測器負責前者、描述子負責後者，
%[text] 而**只量一個會讓你選錯**——實測 BRISK 與 SIFT 的排序完全相反。
%[text] **`cornerPoints` 先天不足**
%[text] Harris 與 FAST 不提供尺度與方向，所以描述子只能用固定取樣。
%[text] 換描述子能從 1 組配對救到 10 組，但救不到 SIFT 的 72 組。
%[text] **實務選擇**
%[text] 要最可靠 → `SIFT`；要快又多 → `ORB`（快 5.3 倍、內點多一倍）。
%[text] **參數的優先順序**
%[text] 先選對偵測器與描述子，再考慮 `MaxRatio`。
%[text] 順序顛倒會浪費很多時間在一個多數時候沒有作用的參數上。
%[text] **能自己造正確答案就一定要造**
%[text] 本章的重複性、變換復原、拼接、LBP 區辨力，
%[text] 全部都用「自己套一個已知變換」或「同材質 vs 異材質」來驗證。
%[text] 這讓每個結論都有數字支撐，而不是「看起來對齊了」。
%[text] **R2026a 的新東西**
%[text] `selectStrongest` 與 `selectUniform` 可回傳線性索引，
%[text] 讓篩選後的點能安全地對應回描述子與自訂資料。
%%
%[text] # 16. 練習
%[text] 練習題在 `exercise/Ch14_Exercise.m`，解答在 `exercise/Ch14_Solution.m`。
%[text] 五題 + 一題加分題，建議 70 分鐘。
%%
%[text] # 17. 延伸閱讀與下一章
%[text] **本章函式**
%[text:table]
%[text] | 檔案 | 用途 |
%[text] | --- | --- |
%[text] | `code/ch14_detect.m` | 統一八種偵測器的呼叫介面 |
%[text] | `code/ch14_detectorRepeatability.m` | 用已知變換量測重複性 |
%[text] | `code/ch14_matchAndVerify.m` | 完整四步流程，**同時回報重複性與可比對性** |
%[text] | `code/ch14_stitchPair.m` | 拼接兩張影像並回報品質 |
%[text] | `code/ch14_retrievalPrecision.m` | 檢索精確度，**排除查詢自身** |
%[text:table]
%[text] **官方文件**
%[text] `doc detectSIFTFeatures`、`doc extractFeatures`、`doc matchFeatures`、
%[text] `doc estgeotform2d`、`doc extractHOGFeatures`、`doc extractLBPFeatures`、
%[text] `doc indexImages`、`doc bagOfFeatures`
%[text] **下一章**
%[text] 第 15 章　符碼、文字偵測與 OCR——從影像讀出**結構化資訊**
%[text] （條碼、QR、文字），包含繁體中文 OCR 與自訓練語言模型。

% ========================================================================
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
