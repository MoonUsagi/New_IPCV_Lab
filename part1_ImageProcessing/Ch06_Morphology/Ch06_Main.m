%[text] # 第 06 章　形態學影像處理
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 說明結構元素如何決定形態學運算的結果
%[text] 2. 用開／閉運算清理二值分割的結果
%[text] 3. 用 top-hat 校正不均勻背景——不必先做任何增強
%[text] 4. 用形態學重建做「標記式」處理，精準保留或移除特定物件
%[text] 5. 從骨架萃取線狀結構的拓樸資訊 \
%[text] ## 前置知識
%[text] 第 01 章（二值影像）、第 02 章（遮罩清理的動機）。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="06", Verbose=false);
disp("環境檢查通過。")
%%
%[text] # 1. 形態學在整個流程中的位置
%[text] 第 02 章我們用 `imopen`、`imfill`、`bwareaopen` 清理遮罩，
%[text] 當時把它們當黑盒子用。本章把這個盒子打開。
%[text] 形態學處理的是**形狀**，不是亮度。它的典型位置是：
%[text] `分割 → **形態學清理** → 量測`
%[text] 分割的輸出永遠不完美：有雜點、有破洞、物件黏在一起、邊緣毛糙。
%[text] 形態學是把「符合條件的像素」變成「可以量測的物件」的那一步。
%%
%[text] # 2. 結構元素：形態學的「核」
%[text] 第 04 章的卷積用**核**決定鄰域的加權方式；形態學用**結構元素**
%[text] （structuring element，SE）決定要看哪些鄰居。
%[text] 差別在於：卷積是加權求和（線性），形態學是取最大／最小值（非線性）。
shapes = ["disk" "square" "line" "diamond" "octagon"];
params = {5, 9, {15, 45}, 5, 6};

figure
tiledlayout(1, numel(shapes))
for k = 1:numel(shapes)
    if iscell(params{k})
        se = strel(shapes(k), params{k}{:});
    else
        se = strel(shapes(k), params{k});
    end
    nexttile
    imshow(se.Neighborhood, InitialMagnification="fit")
    title(shapes(k) + newline + mat2str(size(se.Neighborhood)))
end
%[text:table]
%[text] | SE 形狀 | 適合 |
%[text] | --- | --- |
%[text] | `disk` | 一般用途，不偏袒方向。**預設選擇** |
%[text] | `square` `rectangle` | 矩形物件、要保留直角 |
%[text] | `line` | **只處理特定方向**的結構（移除掃描線、找出直線） |
%[text] | `diamond` `octagon` | disk 的快速近似 |
%[text:table]
%%
%[text] # 3. 兩個基本運算
%[text] 所有形態學運算都由**侵蝕**與**膨脹**組合而成。
BW = imread("blobs.png");
se = strel("disk", 5);

% 形態學的慣例是「前景為白」。動手前先確認——判斷錯方向，
% 後面每一個運算的效果都會相反。
fprintf("blobs.png：前景（白）佔 %.1f%%，看起來是%s\n", 100*mean(BW,"all"), ...
    ternaryStr(mean(BW,"all") < 0.5, "物件（正確，不需 imcomplement）", ...
                                     "背景（需要 imcomplement）"));

eroded  = imerode(BW, se);
dilated = imdilate(BW, se);

figure
montage({BW, eroded, dilated}, Size=[1 3])
title("原圖 ｜ 侵蝕（變瘦）｜ 膨脹（變胖）")

fprintf("前景像素數：原圖 %d ｜ 侵蝕後 %d ｜ 膨脹後 %d\n", ...
    nnz(BW), nnz(eroded), nnz(dilated));
%[text:table]
%[text] | 運算 | 規則 | 效果 |
%[text] | --- | --- | --- |
%[text] | **侵蝕** `imerode` | SE 要**完全**放得進前景，中心才留下 | 物件變瘦、小物件消失、細連結斷開 |
%[text] | **膨脹** `imdilate` | SE 只要**碰到**前景，中心就變前景 | 物件變胖、破洞填補、鄰近物件相連 |
%[text:table]
%[text] **記法**：侵蝕是「嚴格」（要完全放進去），膨脹是「寬鬆」（碰到就算）。
%%
%[text] ## 3.1 結構元素大小的影響
radii = [2 5 10 20];
erodedSet = cell(1, numel(radii));
for k = 1:numel(radii)
    erodedSet{k} = imerode(BW, strel("disk", radii(k)));
end

figure
montage(erodedSet, Size=[1 4])
title("侵蝕 半徑 = 2 ｜ 5 ｜ 10 ｜ 20")

for k = 1:numel(radii)
    fprintf("半徑 %2d：剩餘前景 %5.1f%%，連通區域 %d 個\n", radii(k), ...
        100*nnz(erodedSet{k})/nnz(BW), max(bwlabel(erodedSet{k}), [], "all"));
end
%[text] SE 半徑超過物件的「半寬」時，物件就完全消失。
%[text] 這個性質本身就是一種**尺寸篩選**——第 8 節的粒徑分析就靠它。
%%
%[text] # 4. 開運算與閉運算
%[text] 把侵蝕與膨脹**串起來**，就得到實務上最常用的兩個運算。
%[text:table]
%[text] | 運算 | 定義 | 效果 | 保持 |
%[text] | --- | --- | --- | --- |
%[text] | **開** `imopen` | 先侵蝕再膨脹 | 移除小物件、斷開細連結、平滑外緣 | 物件大小**不變** |
%[text] | **閉** `imclose` | 先膨脹再侵蝕 | 填補小洞、連接鄰近物件、平滑內緣 | 物件大小**不變** |
%[text:table]
%[text] **關鍵性質**：開與閉都會保持物件的整體大小，
%[text] 因為第二步會把第一步的縮放抵銷掉。這是它們比單獨侵蝕／膨脹好用的原因。
noisyBW = BW;
rng(0);
noisyBW(rand(size(BW)) < 0.02) = true;      % 加入雜點
noisyBW(rand(size(BW)) < 0.02) = false;     % 挖出小洞

opened = imopen(noisyBW, strel("disk", 3));
closed = imclose(noisyBW, strel("disk", 3));
both   = imclose(imopen(noisyBW, strel("disk", 3)), strel("disk", 3));

figure
montage({noisyBW, opened, closed, both}, Size=[2 2])
title("有雜點與破洞 ｜ 開（去雜點）｜ 閉（補洞）｜ 先開後閉")

fprintf("前景像素數：原圖 %d ｜ 開 %d ｜ 閉 %d ｜ 先開後閉 %d\n", ...
    nnz(BW), nnz(opened), nnz(closed), nnz(both));
%[text] **順序很重要**：先開後閉會先去掉雜點再補洞；
%[text] 先閉後開則會先把雜點與物件連起來，之後就分不開了。
%[text] **一般用先開後閉**——先清乾淨再修補。
%%
%[text] # 5. Top-hat：不必增強就能校正背景
%[text] 這是本章**最實用**的一招。
%[text] **Top-hat = 原圖 − 開運算結果**。開運算會把比 SE 小的亮物件移除，
%[text] 留下的就是「背景」；原圖減掉背景，就只剩下那些小亮物件。
rice = imread("rice.png");
seRice = strel("disk", 15);

background = imopen(rice, seRice);
tophat     = imtophat(rice, seRice);        % 等同 rice - background

figure
montage({rice, background, tophat}, Size=[1 3])
title("原圖（左上亮右下暗）｜ 開運算＝估計的背景 ｜ Top-hat＝原圖−背景")

fprintf("手動計算與 imtophat 是否相同：%d\n", isequal(rice - background, tophat));

figure
tiledlayout(1,2)
nexttile; imhist(rice);   title("原圖直方圖（單峰）");   ylim([0 2500])
nexttile; imhist(tophat); title("Top-hat 後（雙峰分離）"); ylim([0 2500])
%%
%[text] ## 5.1 與第 03 章的方法比較
%[text] 第 03 章用 `imflatfield` 解決同樣的問題。哪個好？
countGrains = @(bw) max(bwlabel(bwareaopen(bw, 30)), [], "all");

methods = { ...
    "直接二值化",          imbinarize(rice); ...
    "自適應門檻",          imbinarize(rice, "adaptive", Sensitivity=0.45); ...
    "imflatfield（第 03 章）", imbinarize(imflatfield(rice, 30)); ...
    "top-hat（本章）",      imbinarize(tophat)};

fprintf("\n%-26s %s\n", "方法", "偵測到的米粒數");
for k = 1:size(methods,1)
    fprintf("%-26s %d\n", methods{k,1}, countGrains(methods{k,2}));
end
fprintf("%-26s %s\n", "（正確答案）", "約 95");

figure
montage(cellfun(@(x) bwareaopen(x,30), methods(:,2)', UniformOutput=false), Size=[2 2])
title("直接 ｜ 自適應 ｜ imflatfield ｜ top-hat")
%[text] **三種方法結果幾乎一樣**（都是 94，比直接二值化的 89 好）。那怎麼選？
%[text:table]
%[text] | 方法 | 優點 | 缺點 |
%[text] | --- | --- | --- |
%[text] | 自適應門檻 | 一行搞定 | 參數（Sensitivity）不直觀 |
%[text] | `imflatfield` | 校正後的**灰階影像**可再利用 | sigma 要調，且是全域高斯假設 |
%[text] | **top-hat** | 參數有**明確物理意義**（SE 大於物件即可） | 只對「亮物件在暗背景」有效 |
%[text:table]
%[text] **推薦 top-hat**，因為它的參數最好解釋：
%[text] 「結構元素要比米粒大」——這句話可以直接講給產線人員聽。
%%
%[text] ## 5.2 SE 大小怎麼選
radiiTest = [5 10 15 20 30 50];
fprintf("\n%-12s %s\n", "SE 半徑", "偵測數");
for r = radiiTest
    fprintf("%-12d %d\n", r, countGrains(imbinarize(imtophat(rice, strel("disk", r)))));
end
%[text] 半徑 5 時**多算了**（96）——SE 比米粒小，米粒自己也被當成背景的一部分
%[text] 減掉了，結果米粒破碎成多個小塊。
%[text] 半徑 10 以上就穩定在 94，**再大也不會更好**。
%[text] **選法**：SE 要**明顯大於**要偵測的物件，但不必精準——
%[text] 這個參數有很寬的安全區間，這正是 top-hat 好用的地方。
%[text] **Bottom-hat**（`imbothat`）是對偶的運算，用於「暗物件在亮背景」。
darkOnLight = imcomplement(rice);
figure
montage({darkOnLight, imbothat(darkOnLight, seRice)})
title("暗物件在亮背景 ｜ Bottom-hat")
%%
%[text] # 6. 形態學重建：標記式處理
%[text] 前面的運算都是「一視同仁」地處理整張影像。
%[text] **形態學重建**（`imreconstruct`）不一樣：你給它一組**標記**，
%[text] 它會從標記出發，在**遮罩**允許的範圍內「長」出完整的物件。
%[text] 這讓你能**精準地保留或移除特定物件，而完全不改變它們的形狀**。
grains = bwareaopen(imbinarize(tophat), 30);

% 標記：影像中央的一個小區域
marker = false(size(grains));
marker(100:160, 100:160) = true;
marker = marker & grains;

reconstructed = imreconstruct(marker, grains);

figure
montage({grains, marker, reconstructed}, Size=[1 3])
title("全部米粒 ｜ 標記（中央區域）｜ 重建結果（碰到標記的完整米粒）")

fprintf("全部 %d 個 → 與標記相交的 %d 個\n", ...
    max(bwlabel(grains),[],"all"), max(bwlabel(reconstructed),[],"all"));
%[text] 注意重建出來的米粒是**完整的**，不是被標記框切掉的那一塊。
%[text] 這就是重建的價值：**以「碰到就整個保留」的邏輯運作**。
%%
%[text] ## 6.1 兩個常用的重建應用
%[text] `imfill` 與 `imclearborder` 其實都是形態學重建的包裝。
withHoles = imfill(grains, "holes");
noBorder  = imclearborder(grains);

figure
montage({grains, withHoles, noBorder}, Size=[1 3])
title("原始 ｜ imfill 補洞 ｜ imclearborder 移除碰邊的")

fprintf("原始         %d 個\n", max(bwlabel(grains),[],"all"));
fprintf("移除碰邊後   %d 個（少了 %d 個不完整的米粒）\n", ...
    max(bwlabel(noBorder),[],"all"), ...
    max(bwlabel(grains),[],"all") - max(bwlabel(noBorder),[],"all"));
%[text] **`imclearborder` 在量測時幾乎是必要的**：碰到影像邊界的物件
%[text] 是被切掉的，量它的面積、周長、圓形度全都不對。
%[text] 第 11 章做量測時，這會是標準流程的一部分。
%[text] **R2023b 起** `imclearborder` 可以指定要清哪幾個邊界——
%[text] 例如產線上物件會從輸送帶左右進出，但上下邊界是完整的，
%[text] 這時只清左右兩邊即可，不必浪費上下邊界的資料。
%%
%[text] # 7. 骨架與細線分析
%[text] `bwmorph` 提供一系列基於形態學的二值運算，其中最有用的是**骨架化**。
worm = false(200, 200);
worm(100, 30:170) = true;
worm(60:140, 100) = true;
worm = imdilate(worm, strel("disk", 6));
worm = imrotate(worm, 20, "crop");

skeleton = bwskel(worm);
branchPts = bwmorph(skeleton, "branchpoints");
endPts    = bwmorph(skeleton, "endpoints");

figure
tiledlayout(1,2)
nexttile; imshow(worm); title("粗細不一的線狀物件")
nexttile
imshow(labeloverlay(uint8(worm)*255, skeleton, Colormap=[1 0 0]))
hold on
[r1,c1] = find(branchPts); plot(c1, r1, "go", MarkerSize=12, LineWidth=2)
[r2,c2] = find(endPts);    plot(c2, r2, "bs", MarkerSize=12, LineWidth=2)
hold off
title("骨架（紅）＋ 分支點（綠）＋ 端點（藍）")

fprintf("骨架長度   %d 像素\n", nnz(skeleton));
fprintf("分支點     %d 個\n", nnz(branchPts));
fprintf("端點       %d 個\n", nnz(endPts));
%[text] 骨架把「粗細不一的形狀」化簡成「單像素寬的拓樸結構」。
%[text] 從端點與分支點的數量，可以判斷物件的**拓樸類型**——
%[text] 4 個端點加上中央的分支，就是一個十字形。
%[text] **注意分支點是 2 個而不是 1 個**。粗的交叉處骨架化後，
%[text] 中央往往會產生相鄰的兩個（甚至更多）分支點，而不是理想的單一交點。
%[text] 這是骨架化的常見現象，實務上要先把鄰近的分支點**合併**再計數：
branchLabeled = bwlabel(imdilate(branchPts, strel("disk", 3)));
fprintf("合併鄰近分支點後：%d 個分支節點\n", max(branchLabeled, [], "all"));
%[text] **應用**：血管分析、電路板走線檢查、纖維長度量測、
%[text] 第 10 章的線蟲形態分類。
%[text] **注意**：`bwskel` 取代了舊的 `bwmorph(BW,"skel",Inf)`，
%[text] 結果較穩定，且支援 3D。
%%
%[text] # 8. 粒徑分析
%[text] 用「SE 越大、消失的物件越多」這個性質，可以量出物件的**尺寸分布**，
%[text] 完全不需要先分割出個別物件。
radiiScan = 1:2:31;
remaining = zeros(size(radiiScan));

for k = 1:numel(radiiScan)
    remaining(k) = nnz(imopen(grains, strel("disk", radiiScan(k))));
end

granulometry = -diff(remaining);      % 每增加一級消失的面積

figure
tiledlayout(1,2)
nexttile
plot(radiiScan, remaining/nnz(grains)*100, "-o", LineWidth=1.5)
xlabel("SE 半徑"); ylabel("剩餘面積 (%)"); title("開運算後的剩餘面積"); grid on
nexttile
bar(radiiScan(2:end), granulometry)
xlabel("SE 半徑"); ylabel("消失的面積"); title("粒徑分布"); grid on

[~, peakIdx] = max(granulometry);
fprintf("尺寸分布的峰值在 SE 半徑 ≈ %d，對應米粒寬度約 %d 像素\n", ...
    radiiScan(peakIdx+1), 2*radiiScan(peakIdx+1));
%[text] 峰值的位置就是最常見的物件尺寸。
%[text] **這個方法的價值**：物件黏在一起也沒關係——
%[text] 它量的是形狀的尺度特性，不需要先把物件一個個分開。
%[text] 在顆粒、粉末、細胞等「數不清但要知道尺寸分布」的場合非常實用。
%%
%[text] # 9. 灰階形態學
%[text] 形態學不限於二值影像。對灰階影像，侵蝕是取鄰域**最小值**，
%[text] 膨脹是取**最大值**。前面的 top-hat 就是灰階形態學。
I = imread("cameraman.tif");
se9 = strel("disk", 5);

figure
montage({I, imerode(I,se9), imdilate(I,se9), imopen(I,se9), imclose(I,se9), ...
         imsubtract(imdilate(I,se9), imerode(I,se9))}, Size=[2 3])
title("原圖 ｜ 侵蝕(變暗) ｜ 膨脹(變亮) ｜ 開 ｜ 閉 ｜ 形態學梯度")
%[text] 最後一張是**形態學梯度**（膨脹 − 侵蝕），它突顯了所有邊界——
%[text] 這是另一種邊緣偵測，對雜訊比微分法穩健。第 10 章會做正式比較。
%%
%[text] # 10. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 前景是黑的 | 所有運算的效果都相反 | 形態學慣例是**前景為白**，必要時先 `imcomplement` |
%[text] | 只用侵蝕去雜點 | 物件也跟著縮小了 | 用**開運算**，它會把大小補回來 |
%[text] | 先閉後開 | 雜點先跟物件黏起來就分不開了 | 一般**先開後閉** |
%[text] | top-hat 的 SE 比物件小 | 物件被當成背景減掉，結果破碎 | SE 要**明顯大於**物件 |
%[text] | 量測前沒做 `imclearborder` | 碰邊物件的面積、周長全錯 | 量測前一律移除碰邊物件 |
%[text] | 用 `bwmorph(BW,"skel",Inf)` | 結果不穩定 | 改用 `bwskel` |
%[text] | 對灰階影像用 `bwareaopen` | 報錯 | `bwareaopen` 只吃二值影像 |
%[text] | SE 用 `square` 做一般清理 | 結果有方向性偏差、出現方角 | 預設用 `disk` |
%[text:table]
%%
%[text] # 11. 本章小結
%[text] - 形態學處理**形狀**，位置在「分割之後、量測之前」
%[text] - 侵蝕嚴格（要完全放進去）、膨脹寬鬆（碰到就算）
%[text] - **開／閉會保持物件大小**，這是它們比單獨侵蝕／膨脹好用的原因
%[text] - **top-hat 是本章最實用的一招**：參數有明確物理意義（SE 大於物件），
%[text] 且有很寬的安全區間
%[text] - 形態學重建讓你「碰到就整個保留」，精準且不改變形狀
%[text] - 粒徑分析能在**不分割**的情況下量出尺寸分布
%[text] - **動手前先確認前景是白是黑**。判斷錯方向，後面每一個運算的效果
%[text] 都會完全相反，而且結果「看起來」還很合理 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `strel` | 建立結構元素 | 預設用 `disk` |
%[text] | `imerode` `imdilate` | 侵蝕／膨脹 | 兩個基本運算 |
%[text] | `imopen` `imclose` | 開／閉 | 保持物件大小；一般先開後閉 |
%[text] | `imtophat` `imbothat` | 頂帽／底帽 | **背景校正首選** |
%[text] | `imreconstruct` | 形態學重建 | 標記式處理 |
%[text] | `imfill` | 補洞 | `"holes"` 選項 |
%[text] | `imclearborder` | 移除碰邊物件 | **量測前必做**；R2023b 可指定邊界 |
%[text] | `bwareaopen` `bwareafilt` | 依面積篩選 | `bwareafilt` 可設上下界 |
%[text] | `bwskel` | 骨架化 | 取代 `bwmorph(...,"skel",Inf)` |
%[text] | `bwmorph` | 其他二值運算 | `branchpoints` `endpoints` `thin` `spur` |
%[text] | `bwdist` | 距離轉換 | 分水嶺的前置（第 08 章） |
%[text] | `imhmax` `imimposemin` | 抑制淺極值／強制最小值 | 分水嶺過度分割的解藥 |
%[text:table]
%%
%[text] # 12. 練習
%[text] 開啟 `exercise/Ch06_Exercise.m`，完成五題。解答在 `Ch06_Solution.m`。
%%
%[text] # 13. 延伸閱讀與下一章
%[text] - [Morphological Operations](https://www.mathworks.com/help/images/morphological-filtering.html)
%[text] - [Types of Morphological Operations](https://www.mathworks.com/help/images/morphological-dilation-and-erosion.html)
%[text] - **下一章**：第 07 章　幾何轉換與影像配準——前六章都在處理「像素的值」，下一章開始處理「像素的位置」 \

function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
