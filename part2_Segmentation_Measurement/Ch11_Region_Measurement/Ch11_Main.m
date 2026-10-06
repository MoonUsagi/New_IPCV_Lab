%[text] # 第 11 章　區域分析、物件量測與空間校正
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 用 `regionprops` 取得物件的幾何屬性，並說出每個屬性在量什麼
%[text] 2. 依屬性篩選物件，而不是靠面積硬切
%[text] 3. **把像素換算成實際尺寸**，並驗證你的校正是否正確
%[text] 4. 說明為什麼三種量測法會給出三個不同的答案
%[text] 5. 產出一份可交付的量測報告，含**有效樣本數與排除理由** \
%[text] ## 前置知識
%[text] 第 06 章（形態學清理）、第 08 章（分割）、第 10 章（次像素邊緣）。
%[text] ## 環境需求
%[text] 第 7 節的 caliper 量測需要
%[text] **Visual Inspection Toolbox**（選用；R2026a 以前是 Automated Visual Inspection Library 支援包）。
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="11", Verbose=false);
hasCaliper = exist("caliper", "file") == 2;
disp("環境檢查通過。")
%%
%[text] # 1. 這一章的位置
%[text] 前面三章把影像變成**遮罩**。本章把遮罩變成**數字**——
%[text] 而且是**有單位、可交付、可被質疑的**數字。
%[text] `分割（Ch.08–09）→ 形態學清理（Ch.06）→ **量測（本章）**→ 決策`
%[text] 這一步常被低估。它看起來只是呼叫 `regionprops`，
%[text] 但「量出一個數字」和「量出一個**可信**的數字」之間差距很大。
I = imread("coins.png");

rawMask   = imbinarize(I);
cleanMask = imclearborder(bwareaopen(imfill(rawMask, "holes"), 100));

figure
montage({I, rawMask, cleanMask}, Size=[1 3])
title("原圖 ｜ 直接二值化 ｜ 清理後（補洞、去雜點、移除碰邊）")

fprintf("直接二值化   %d 個連通區域\n", max(bwlabel(rawMask), [], "all"));
fprintf("清理後       %d 個（正確：10 枚硬幣）\n", max(bwlabel(cleanMask), [], "all"));
%%
%[text] # 2. regionprops：屬性家族
%[text] `regionprops` 一次可以算出十幾種屬性。重點不是記住它們，
%[text] 而是知道**每一個在量什麼**——因為它們會給出不同的答案。
stats = regionprops("table", cleanMask, ...
    "Area", "Centroid", "EquivDiameter", "MajorAxisLength", "MinorAxisLength", ...
    "Perimeter", "Circularity", "Eccentricity", "Solidity", "Extent", "Orientation");

disp(head(sortrows(stats, "Area", "descend"), 5))
%[text:table]
%[text] | 屬性 | 量什麼 | 什麼時候用 |
%[text] | --- | --- | --- |
%[text] | `Area` | 前景像素數 | 最穩健的尺寸指標 |
%[text] | `Centroid` | 質心 **\[x y\]** | 定位、追蹤 |
%[text] | `EquivDiameter` | **與該區域同面積的圓**的直徑 | 近圓形物件的「直徑」 |
%[text] | `MajorAxisLength` `MinorAxisLength` | **最佳擬合橢圓**的長短軸 | 細長物件、判斷方向性 |
%[text] | `Perimeter` | 邊界長度 | 與面積合用算圓形度 |
%[text] | `Circularity` | $4\\pi A/P^2$，圓 = 1 | 篩掉非圓物件 |
%[text] | `Eccentricity` | 橢圓離心率，圓 = 0 | 判斷細長程度 |
%[text] | `Solidity` | 面積 / 凸包面積 | 偵測凹陷、缺角、破損 |
%[text] | `Extent` | 面積 / 外接矩形面積 | 判斷是否填滿矩形 |
%[text] | `Orientation` | 長軸與水平的夾角（度） | 物件方向 |
%[text:table]
%[text] **注意** **`Centroid`** **是** **`[x y]`**，不是 `[列 行]`。
%[text] 這個慣例在 MATLAB 的影像工具箱裡並不統一——下一節會看到一個現成的坑。
%%
%[text] # 3. R2026a：直接取得邊界座標
%[text] 以前要拿物件的輪廓，得另外呼叫 `bwboundaries`。
%[text] R2026a 起 `regionprops` 可以直接給——用 `"BoundaryCoordinates"` 屬性。
boundaryStats = regionprops("table", cleanMask, "Area", "Centroid", "BoundaryCoordinates");

fprintf("BoundaryCoordinates 的類別：%s\n", class(boundaryStats.BoundaryCoordinates));
fprintf("第 1 個區域的邊界有 %d 個點\n\n", size(boundaryStats.BoundaryCoordinates{1}, 1));

firstBoundary = boundaryStats.BoundaryCoordinates{1};
disp("前 3 個邊界點：")
disp(firstBoundary(1:3, :))
%%
%[text] ## 3.1 一個必須知道的座標陷阱
%[text] `regionprops` 的 `BoundaryCoordinates` 與 `bwboundaries` 的座標順序
%[text] **正好相反**。
legacyBoundaries = bwboundaries(cleanMask);

fprintf("%-32s %s\n", "regionprops BoundaryCoordinates", mat2str(firstBoundary(1,:)));
fprintf("%-32s %s\n", "bwboundaries", mat2str(legacyBoundaries{1}(1,:)));
fprintf("\n兩者互為轉置。\n");
%[text:table]
%[text] | 來源 | 座標順序 | 畫圖時 |
%[text] | --- | --- | --- |
%[text] | **`regionprops(...,"BoundaryCoordinates")`** | **\[x y\]** | `plot(b(:,1), b(:,2))` |
%[text] | `bwboundaries` | **\[row col\]** | `plot(b(:,2), b(:,1))`（要交換） |
%[text:table]
%[text] **新屬性用的是繪圖友善的** **`[x y]`**，可以直接丟給 `plot`。
%[text] 這是進步，但如果你把舊程式的 `bwboundaries` 換成新屬性卻沒改索引，
%[text] 輪廓會整個轉置——而且**不會報錯**，只是畫出來的東西不對。
figure
tiledlayout(1,2)

nexttile
imshow(I), hold on
for k = 1:height(boundaryStats)
    b = boundaryStats.BoundaryCoordinates{k};
    plot(b(:,1), b(:,2), "g", LineWidth=1.5)    % [x y] 直接用
end
plot(boundaryStats.Centroid(:,1), boundaryStats.Centroid(:,2), "r+", MarkerSize=8, LineWidth=1.5)
hold off
title("正確：BoundaryCoordinates 用 (:,1),(:,2)")

nexttile
imshow(I), hold on
for k = 1:height(boundaryStats)
    b = boundaryStats.BoundaryCoordinates{k};
    plot(b(:,2), b(:,1), "r", LineWidth=1.5)    % 錯誤：多交換了一次
end
hold off
title("錯誤：又交換一次 -> 輪廓轉置")
%[text] 右邊那張就是「把舊程式的索引沿用到新屬性」的後果。
%[text] **這類錯誤最危險的地方在於它不會報錯**，只會給你一個看起來
%[text] 「好像哪裡不對但說不上來」的結果。
%%
%[text] # 4. 依屬性篩選，而不是靠面積硬切
%[text] 第 06 章用 `bwareaopen` 依面積篩選。但面積常常不是最好的判準。
%[text] `bwpropfilt` 可以依**任何** `regionprops` 屬性篩選。
%[text] 先製造一些「不該算進去」的干擾物：
rng(0);

%[text] **注意干擾物要放在不會碰到硬幣的地方。** `coins.png` 的硬幣佔滿了
%[text] 第 7–237 列，任何水平刮痕都會和硬幣相連、合併成一個區域——
%[text] 那樣就不是「多了一個干擾物」，而是「少了兩枚硬幣」，示範的意思全變了。
%[text] 所以先在下方加一塊空白畫布，把干擾物放在那裡。
messyMask = padarray(cleanMask, [70 0], false, "post");

messyMask(270:273, 60:200) = true;                              % 細長的刮痕
messyMask(285:310, 40:70)  = rand(26, 31) > 0.4;                % 不規則碎片

messyStatsCheck = regionprops("table", messyMask, "Area");
fprintf("原本 %d 枚硬幣，加入干擾後 %d 個區域（硬幣沒有被合併）\n", ...
    max(bwlabel(cleanMask), [], "all"), height(messyStatsCheck));

messyStats = regionprops("table", messyMask, ...
    "Area", "Circularity", "Eccentricity", "Solidity", "EquivDiameter");
messyStats = sortrows(messyStats, "Circularity");

fprintf("加入干擾後共 %d 個區域\n\n", height(messyStats));
disp(head(messyStats, 4))
%%
%[text] ## 4.1 哪個屬性分得開
%[text] 把「真硬幣」與「干擾物」在各屬性上的分布畫出來，看哪個分得最乾淨：
candidateProps = ["Area" "Circularity" "Eccentricity" "Solidity"];

figure
tiledlayout(2,2)
for p = candidateProps
    nexttile
    values = messyStats.(p);
    stem(values, "filled")
    xlabel("區域編號"); ylabel(p); title(p); grid on
end
%[text] 上面那張表用一個嚴格的判準檢查「硬幣的屬性範圍會不會與干擾物重疊」。
%[text] 結果只有 **`Circularity`** **完全分得開**：
%[text] - **`Circularity`** **可以**——刮痕又細又長，圓形度極低；硬幣接近 1
%[text] - `Area` **不行**——刮痕的面積和硬幣是同一個量級
%[text] - `Eccentricity` **不行**——碎片裡的小雜點離心率可以是任意值
%[text] - `Solidity` **不行**——單像素雜點的凸包就是它自己，凸實度剛好是 1.0 %\[text\] 注意 `Solidity` 這個結果**和直覺相反**。碎片本身凹凹凸凸、凸實度很低， \
%[text] 所以它看起來應該是個好判準——但碎片裡夾雜的**單像素雜點**
%[text] 把它的範圍撐開了。這正是下一節要處理的問題。
fprintf("%-14s %14s %14s\n", "屬性", "硬幣範圍", "是否能分開");
for p = candidateProps
    v = messyStats.(p);
    coinLike = messyStats.Circularity > 0.9;
    fprintf("%-14s %6.3f - %-7.3f %14s\n", p, ...
        min(v(coinLike)), max(v(coinLike)), ...
        ternaryStr(min(v(coinLike)) > max(v(~coinLike)) || ...
                   max(v(coinLike)) < min(v(~coinLike)), "可以", "不行"));
end
%%
%[text] ## 4.2 用 bwpropfilt 篩選
filtered = bwpropfilt(messyMask, "Circularity", [0.9 Inf]);

fprintf("\n篩選前 %d 個 -> 圓形度篩選後 %d 個（正確 10）\n", ...
    max(bwlabel(messyMask), [], "all"), max(bwlabel(filtered), [], "all"));
%[text] **多出來了。** 看一下混進來的是什麼：
leftovers = regionprops("table", filtered, "Area", "Circularity", "EquivDiameter");
disp(sortrows(leftovers, "Area"))
%[text] 混進來的是**只有兩三個像素**的雜點，而它的圓形度高達 0.97。
%[text] **極小的區域，形狀指標會退化。** 圓形度的定義是 $4\\pi A/P^2$——
%[text] 當區域只有兩三個像素時，面積與周長都是極小的整數，
%[text] 這個比值算出來的數字**沒有幾何意義**，卻可能剛好落在合理範圍內。
%[text] 同樣的問題也出現在 `Eccentricity` 與 `Solidity`——
%[text] 兩個像素的凸包就是它自己，凸實度必然是 1.0。
%[text] 這就是上一節 `Solidity` 「分不開」的真正原因。
%[text] **正確做法：形狀篩選之前先用面積擋掉退化的小區域。**
filteredProperly = bwpropfilt(bwareaopen(messyMask, 50), "Circularity", [0.9 Inf]);

fprintf("\n先用面積擋掉退化區域，再做圓形度篩選 -> %d 個\n", ...
    max(bwlabel(filteredProperly), [], "all"));

figure
montage({messyMask, filtered, filteredProperly}, Size=[1 3])
title("有干擾 ｜ 只做圓形度篩選（多 2 個）｜ 先擋面積再篩圓形度")
%[text] **這個順序很重要，而且方向可能和直覺相反**：
%[text] 第 4.1 節剛剛才說「面積分不開刮痕與硬幣」，所以不該用面積當**主要**判準。
%[text] 但面積仍然要用——用來**排除形狀指標無意義的退化區域**。
%[text] 兩件事不衝突：**面積不適合當分類器，但適合當有效性檢查。**
%[text] **`bwpropfilt`** **的兩種用法**：
%[text] - `bwpropfilt(BW, "Area", [lo hi])` — 保留屬性落在範圍內的
%[text] - `bwpropfilt(BW, "Area", n)` — 保留屬性**最大的 n 個** \
%[text] 第二種在「我知道應該有幾個物件」時很好用。
topThree = bwpropfilt(cleanMask, "Area", 3);
fprintf("保留面積最大的 3 個 -> %d 個區域\n", max(bwlabel(topThree), [], "all"));
%%
%[text] # 5. 空間校正：把像素變成公釐
%[text] 到目前為止所有數字的單位都是**像素**。
%[text] 但沒有人會問「這個零件幾像素」——他們問的是「幾公釐」。
%[text] **空間校正**就是建立 mm/pixel 的換算係數。做法是拍一個**已知尺寸的參考物**。
%[text] ## 5.1 先看資料告訴我們什麼
%[text] `coins.png` 裡的硬幣尺寸不是隨機的。把直徑排序看看：
coinStats = regionprops("table", cleanMask, "EquivDiameter", "Centroid", "Area");
coinStats = sortrows(coinStats, "EquivDiameter");

diameters = coinStats.EquivDiameter;
fprintf("直徑（像素）：%s\n\n", mat2str(round(diameters', 2)));

% 找最大的間隙，把硬幣分成兩群
[maxGap, gapIdx] = max(diff(diameters));
smallGroup = diameters(1:gapIdx);
largeGroup = diameters(gapIdx+1:end);

fprintf("最大間隙在 %.2f 與 %.2f 之間（差 %.2f 像素）\n", ...
    diameters(gapIdx), diameters(gapIdx+1), maxGap);
fprintf("小的一群：%d 枚，平均直徑 %.2f 像素\n", numel(smallGroup), mean(smallGroup));
fprintf("大的一群：%d 枚，平均直徑 %.2f 像素\n", numel(largeGroup), mean(largeGroup));
fprintf("量到的尺寸比例：%.4f\n", mean(largeGroup)/mean(smallGroup));
%%
%[text] ## 5.2 用已知的實際尺寸校正
%[text] 這張圖是美國硬幣。查表可得：
%[text:table]
%[text] | 硬幣 | 實際直徑 |
%[text] | --- | --- |
%[text] | 10 分（dime） | 17\.91 mm |
%[text] | 5 分（nickel） | 21\.21 mm |
%[text:table]
dimeDiameterMM   = 17.91;
nickelDiameterMM = 21.21;

fprintf("實際的尺寸比例：%.4f\n", nickelDiameterMM / dimeDiameterMM);
fprintf("量到的尺寸比例：%.4f\n", mean(largeGroup)/mean(smallGroup));
fprintf("比例誤差：%.2f%%" + "\n\n", ...
    100*abs((mean(largeGroup)/mean(smallGroup)) / (nickelDiameterMM/dimeDiameterMM) - 1));
%[text] **比例誤差只有約 0.4%**。這是一個重要的**前置驗證**：
%[text] 它證明我們的分割在幾何上是忠實的——如果分割會系統性地高估或低估尺寸，
%[text] 兩群的比例就不會這麼準。
%[text] **先驗證比例，再做校正。** 比例是無單位的，
%[text] 它檢查的是「分割有沒有扭曲幾何」，與校正係數無關。
%%
%[text] ## 5.3 建立校正係數
%[text] 用大的那群（nickel）當參考：
mmPerPixel = nickelDiameterMM / mean(largeGroup);

fprintf("校正係數：%.6f mm/pixel\n", mmPerPixel);
fprintf("等效解析度：%.1f pixel/mm\n\n", 1/mmPerPixel);

% 用校正後的係數去**預測**另一群的尺寸，當作獨立驗證
predictedDime = mean(smallGroup) * mmPerPixel;

fprintf("預測 dime 直徑：%.3f mm\n", predictedDime);
fprintf("實際 dime 直徑：%.3f mm\n", dimeDiameterMM);
fprintf("誤差：%.3f mm（%.2f%%）\n", ...
    abs(predictedDime - dimeDiameterMM), ...
    100*abs(predictedDime/dimeDiameterMM - 1));
%[text] **這才是完整的校正流程**：
%[text] 1. 用參考物**建立**係數
%[text] 2. 用**另一個已知尺寸的物件驗證**它
%[text] 3. 報告驗證誤差 \
%[text] 只做第 1 步的校正是不可信的——你無法知道它對不對。
%[text] 這和第 07 章「控制點至少要 4 點才有殘差可看」是同一個道理：
%[text] **必須留一些已知答案不參與擬合，用來檢驗。**
%%
%[text] ## 5.4 產出有單位的量測結果
calibrated = coinStats;
calibrated.DiameterMM = calibrated.EquivDiameter * mmPerPixel;
calibrated.AreaMM2    = calibrated.Area * mmPerPixel^2;
calibrated.CoinType   = repmat("dime", height(calibrated), 1);
calibrated.CoinType(calibrated.EquivDiameter > mean([mean(smallGroup) mean(largeGroup)])) = "nickel";

disp(calibrated(:, ["CoinType" "EquivDiameter" "DiameterMM" "AreaMM2"]))

fprintf("\n%-10s %8s %14s %14s %12s\n", "類型", "枚數", "平均直徑(mm)", "標準差(mm)", "實際(mm)");
for t = ["dime" "nickel"]
    sel = calibrated.CoinType == t;
    actual = ternaryNum(t == "dime", dimeDiameterMM, nickelDiameterMM);
    fprintf("%-10s %8d %14.3f %14.3f %12.2f\n", t, nnz(sel), ...
        mean(calibrated.DiameterMM(sel)), std(calibrated.DiameterMM(sel)), actual);
end
%[text] **注意面積的換算是** **`mmPerPixel^2`**，不是 `mmPerPixel`。
%[text] 這是最常見的單位換算錯誤——長度是一次方，面積是二次方，體積是三次方。
%%
%[text] # 6. 三種量測法，三個答案
%[text] 同一枚硬幣，用不同屬性量會得到**不同的直徑**。這不是 bug。
targetCentroid = [188 110];
distances = vecnorm(coinStats.Centroid - targetCentroid, 2, 2);
[~, targetIdx] = min(distances);

detailed = regionprops("table", cleanMask, ...
    "EquivDiameter", "MajorAxisLength", "MinorAxisLength", "Perimeter", "Area", "Centroid");
distances = vecnorm(detailed.Centroid - targetCentroid, 2, 2);
[~, targetIdx] = min(distances);

fprintf("以最接近 (%d,%d) 的那枚硬幣為例：\n\n", targetCentroid);
fprintf("%-28s %12s %12s\n", "量測方式", "像素", "公釐");
fprintf("%-28s %12.3f %12.3f\n", "EquivDiameter（等面積圓）", ...
    detailed.EquivDiameter(targetIdx), detailed.EquivDiameter(targetIdx)*mmPerPixel);
fprintf("%-28s %12.3f %12.3f\n", "MajorAxisLength（擬合橢圓長軸）", ...
    detailed.MajorAxisLength(targetIdx), detailed.MajorAxisLength(targetIdx)*mmPerPixel);
fprintf("%-28s %12.3f %12.3f\n", "MinorAxisLength（擬合橢圓短軸）", ...
    detailed.MinorAxisLength(targetIdx), detailed.MinorAxisLength(targetIdx)*mmPerPixel);
fprintf("%-28s %12.3f %12.3f\n", "Perimeter/pi（由周長推算）", ...
    detailed.Perimeter(targetIdx)/pi, detailed.Perimeter(targetIdx)/pi*mmPerPixel);
%[text] 四種方式的差距可以到 **2–3 像素**。哪一個「對」？
%[text] **問題本身就問錯了。** 它們量的是不同的東西：
%[text:table]
%[text] | 方式 | 定義 | 對什麼敏感 |
%[text] | --- | --- | --- |
%[text] | `EquivDiameter` | 同面積圓的直徑 | **面積**——邊界的細微鋸齒會被平均掉，最穩定 |
%[text] | `MajorAxisLength` | 擬合橢圓的長軸 | 最遠的兩點——**離群的邊界點會拉長它** |
%[text] | `MinorAxisLength` | 擬合橢圓的短軸 | 同上，但方向相反 |
%[text] | `Perimeter/π` | 由周長反推 | **周長**——見下方說明 |
%[text:table]
%[text] ## 6.1 一個我原本猜錯的地方
%[text] 直覺會說：二值遮罩的邊界是階梯狀的，周長應該被**高估**，
%[text] 所以由周長反推的直徑會**偏大**。
%[text] 實測結果是 `Perimeter/π = 56.60`，比 `EquivDiameter = 57.47`
%[text] **還小** 1.5%。
%[text] 用一個已知形狀來量化這件事。把該硬幣單獨取出，
%[text] 拿 $\\pi d$（以 `EquivDiameter` 當 $d$）當參考值：
targetMask = bwselect(cleanMask, detailed.Centroid(targetIdx,1), detailed.Centroid(targetIdx,2));

theoreticalPerimeter = pi * detailed.EquivDiameter(targetIdx);
naivePixelCount      = nnz(bwperim(targetMask));
correctedPerimeter   = detailed.Perimeter(targetIdx);

fprintf("\n%-28s %10s %12s\n", "周長的估計方式", "數值", "相對偏差");
fprintf("%-28s %10.2f %11s\n", "理論值 pi x EquivDiameter", theoreticalPerimeter, "（參考）");
fprintf("%-28s %10.2f %11.1f%%" + "\n", "regionprops 的 Perimeter", correctedPerimeter, ...
    100*(correctedPerimeter/theoreticalPerimeter - 1));
fprintf("%-28s %10d %11.1f%%" + "\n", "單純數 nnz(bwperim)", naivePixelCount, ...
    100*(naivePixelCount/theoreticalPerimeter - 1));
%[text] **兩者都低估，但差距天壤之別**：`regionprops` 只差約 2%，
%[text] 單純數像素差了約 11%。
%[text] ## 為什麼數像素會低估
%[text] 直覺會說「階梯狀邊界比平滑邊界長，所以會**高估**」。這個直覺
%[text] 對「沿著階梯走的路徑長度」是對的，但**數像素個數不是在量路徑長度**。
%[text] 關鍵在對角線：邊界上一個斜向的步進，實際跨越了 $\\sqrt{2}\\approx1.41$
%[text] 的距離，但**只被算成 1 個像素**。圓形邊界有大量斜向步進，
%[text] 每一個都少算 0.41，累積起來就是約 11% 的低估。
%[text] `regionprops` 的 `Perimeter` 會依邊界的走向加權（直向算 1、
%[text] 斜向算 $\\sqrt{2}$，並對轉角做修正），所以準確得多。
%[text] **教訓**：不要憑「演算法應該有這個偏差」的推理下結論——
%[text] 我原本以為會高估，實測是低估，而且原因和我想的完全不同。
%[text] **要去確認這個實作到底做了什麼。**
%[text] **實務建議**：
%[text] - 近圓形物件量「直徑」→ **`EquivDiameter`**（最穩定，基於面積）
%[text] - 細長物件量長度 → `MajorAxisLength`
%[text] - 需要周長本身（例如算圓形度）→ 用 `regionprops` 的 `Perimeter`， \
%[text] **不要自己數** **`bwperim`** \\
%[text] 最重要的一點：**報告量測值時要說明你用哪一種定義**。
%[text] 否則別人拿同一張影像也量不出你的數字。
%%
%[text] # 7. 次像素量測：caliper
%[text] 第 10 章加分題手刻了次像素邊緣定位。
%[text] Visual Inspection Toolbox（R2025a 起；R2026a 以前是 AVI Library 支援包）提供了專業版的 `caliper`，
%[text] 它沿著一條掃描線找**邊緣對**，並用次像素精度回報距離。
if hasCaliper
    scanLine = [158 89; 218 131];      % [x1 y1; x2 y2]，斜向穿過一枚硬幣

    % Width 明確寫出來：R2026b 改了它的預設值（見 7.1）
    measurement = caliper(I, scanLine, GradientThreshold=0.04, Width=50);

    fprintf("caliper 量測結果：\n");
    fprintf("  邊緣對內距離（物件寬度）%.4f 像素 = %.4f mm\n", ...
        measurement.IntraEdgeDistance, measurement.IntraEdgeDistance * mmPerPixel);
    fprintf("  各邊緣距起點的距離      %s\n", mat2str(round(measurement.Distance, 3)));
    fprintf("  邊緣處的梯度值          %s\n", mat2str(round(measurement.GradientValue, 4)));

    figure
    tiledlayout(1,2)
    nexttile
    imshow(I), hold on
    plot(scanLine(:,1), scanLine(:,2), "r-", LineWidth=2)
    plot(scanLine(:,1), scanLine(:,2), "ro", MarkerSize=8, LineWidth=2)
    hold off
    title("掃描線位置")
    nexttile
    plot(measurement.ProfileData, LineWidth=1.2); grid on
    xlabel("沿掃描線的位置"); ylabel("平均梯度")
    title("梯度剖面（峰值就是邊緣）")
else
    disp("未安裝 Visual Inspection Toolbox，略過 caliper 示範。")
    disp("實測：IntraEdgeDistance = 56.4544 像素")
end
%%
%[text] ## 7.1 caliper 的兩個關鍵參數
if hasCaliper
    fprintf("%-12s %s\n", "Width", "量到的寬度（像素）");
    for w = [5 10 20 50]
        m = caliper(I, [158 89; 218 131], GradientThreshold=0.04, Width=w);
        fprintf("%-12d %s\n", w, mat2str(round(m.IntraEdgeDistance, 3)));
    end
    mDefault = caliper(I, [158 89; 218 131], GradientThreshold=0.04);   % 不指定 Width
    fprintf("%-12s %s　（%s）\n", "不指定", mat2str(round(mDefault.IntraEdgeDistance, 3)), ...
        string(version("-release")));
end
%[text] **`Width`** **是掃描帶的寬度**——caliper 會在垂直於掃描線的方向上
%[text] 取多條平行線，平均成一條剖面再找邊緣。
%[text] - 太窄（5）→ 剖面嘈雜，邊緣位置不穩，量到 48.1
%[text] - 太寬 → 若帶寬超過物件的曲率尺度，會把不同位置的邊緣混在一起
%[text] - 50 在這個案例上剛好 \
%[text] **`GradientThreshold`** **預設 0.1 對這張圖太高**，完全找不到邊緣。
%[text] 本例的最大正規化梯度只有約 0.38，實際邊緣處更低，所以要調到 0.04。
%[text] **判斷方式**：先畫出 `ProfileData`，看梯度的實際量級，再設門檻。
%[text] > **R2026b 改了** **`Width`** **的預設值，而且不會有任何警告。**
%[text] > R2026a 的預設是 **50 像素**；R2026b 改成**掃描線長度的 10%**。
%[text] > 本例的掃描線長 73.2 像素，所以 R2026b 的預設只有 7.3。
%[text] > 同一行 `caliper(I, scanLine, GradientThreshold=0.04)`，
%[text] > R2026a 量到 **56.454**，R2026b 量到 **48.094**——**差了 15%**。
%[text] > 更麻煩的是，**兩個版本的說明文字都寫「Default: 10 pixels」**，和兩個版本的實際行為都對不上。
%[text] > 教訓：**會影響量測結果的參數，一律明確寫出來**，不要依賴預設值，也不要只相信說明文字。
%[text] > 所以本章其他的 `caliper` 呼叫都明確指定 `Width=50`，在兩個版本上量到的值相同。
%%
%[text] ## 7.2 三種量測的最終比較
%[text] **一個寫中文教材會踩到的限制**：MATLAB 的**識別字必須是 ASCII**。
%[text] 中文可以放在**字串**裡（`title("標題")` 沒問題），
%[text] 但不能當變數名、欄位名或用點記法存取的 table 變數——
%[text] 寫 `T.公釐 = ...` 會得到 `Invalid text character` 而且\*\*錯誤訊息不會
%[text] 告訴你是中文的問題\*\*。
%[text] 所以 table 的變數名用 ASCII，要顯示中文表頭時另外設 `VariableNames`
%[text] 或在 `disp` 前改名。
if hasCaliper
    m = caliper(I, [158 89; 218 131], GradientThreshold=0.04, Width=50);

    methodNames = ["regionprops EquivDiameter"
                   "regionprops MajorAxisLength"
                   "caliper IntraEdgeDistance"];
    pixelValues = [detailed.EquivDiameter(targetIdx)
                   detailed.MajorAxisLength(targetIdx)
                   m.IntraEdgeDistance];

    comparison = table(methodNames, pixelValues, pixelValues * mmPerPixel, ...
        VariableNames=["Method" "Pixels" "Millimeters"]);

    % 要顯示中文表頭時，在最後一步改名——而不是用中文當識別字
    comparison.Properties.VariableNames = ["方法" "像素" "公釐"];
    disp(comparison)
end
%[text] `caliper` 量到的值**偏小**，這是合理的：
%[text] 它量的是**沿著那一條掃描線**的弦長，而掃描線不一定剛好穿過圓心。
%[text] 沒穿過圓心的弦，必然比直徑短。
%[text] **這不是 caliper 不準，是它回答的問題不一樣**：
%[text:table]
%[text] | 方法 | 回答的問題 |
%[text] | --- | --- |
%[text] | `regionprops` | 這**整個區域**的等效直徑是多少 |
%[text] | `caliper` | 沿著**我指定的這條線**，兩個邊緣相距多遠 |
%[text:table]
%[text] 產線上的固定治具量測（同一位置、同一方向）正是 caliper 的場景——
%[text] 它的優勢是**次像素精度**與**不需要完整分割**。
%%
%[text] # 8. 產出可交付的量測報告
%[text] 一份能交出去的報告，必須包含**被排除的樣本**。
%[text] 第 08 章練習 5 示範過：移除碰邊物件會讓平均面積上升 8.9%。
beforeClearBorder = bwareaopen(imfill(imbinarize(I), "holes"), 100);
afterClearBorder  = imclearborder(beforeClearBorder);

nBefore = max(bwlabel(beforeClearBorder), [], "all");
nAfter  = max(bwlabel(afterClearBorder),  [], "all");

statsBefore = regionprops("table", beforeClearBorder, "EquivDiameter");
statsAfter  = regionprops("table", afterClearBorder,  "EquivDiameter");

fprintf("%-22s %8s %16s\n", "樣本集", "數量", "平均直徑(mm)");
fprintf("%-22s %8d %16.3f\n", "全部（含碰邊）", nBefore, ...
    mean(statsBefore.EquivDiameter)*mmPerPixel);
fprintf("%-22s %8d %16.3f\n", "有效（排除碰邊）", nAfter, ...
    mean(statsAfter.EquivDiameter)*mmPerPixel);
fprintf("\n排除了 %d 個位於影像邊界的物件。\n", nBefore - nAfter);
%[text] `coins.png` 剛好沒有硬幣碰到邊界，所以兩者相同。
%[text] 但**流程必須永遠包含這一步與這個說明**——
%[text] 因為下一張影像可能就有。
%[text] ## 報告該寫什麼
%[text:table]
%[text] | 項目 | 為什麼必要 |
%[text] | --- | --- |
%[text] | **有效樣本數，以及排除了幾個、為什麼** | 讀者要能判斷統計是否有偏 |
%[text] | **量測定義**（用哪個屬性） | 否則無法重現 |
%[text] | **校正係數與它的驗證誤差** | 這是所有絕對數字的基礎 |
%[text] | 平均值**與離散程度** | 只給平均值等於隱藏一半的資訊 |
%[text] | 分割與清理的參數 | 換人接手時的唯一線索 |
%[text:table]
%[text] 本章的 `code/ch11_measureObjects.m` 把這些打包成一支函式。
report = ch11_measureObjects(cleanMask, MMPerPixel=mmPerPixel, ...
    CalibrationNote=sprintf("以 nickel 21.21 mm 校正，dime 驗證誤差 %.2f%%", ...
        100*abs(predictedDime/dimeDiameterMM - 1)));

disp(report.Summary)
fprintf("\n校正說明：%s\n", report.CalibrationNote);
%%
%[text] # 9. Image Region Analyzer APP
%[text] 前面用程式碼做屬性篩選。**Image Region Analyzer** 提供互動版：
%[text] 載入二值影像，它會列出所有區域的所有屬性，拖曳滑桿即時看篩選結果，
%[text] 滿意後匯出成函式——又是第 02 章的五步驟工作流。
interactive = false;    % 改成 true 以開啟 APP

if interactive
    imageRegionAnalyzer(messyMask)
end
%[text] 這個 APP 最有價值的時機是**還不知道該用哪個屬性篩選**時——
%[text] 它把所有屬性一次算給你，你可以直接看哪個分得開，
%[text] 不必像第 4.1 節那樣自己一個一個畫。
%%
%[text] # 10. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 把 `BoundaryCoordinates` 當 `[row col]` 用 | 輪廓轉置，**不會報錯** | 新屬性是 **\[x y\]**，直接 `plot(b(:,1),b(:,2))` |
%[text] | 面積換算用 `mmPerPixel` | 面積差了一個平方 | 長度一次方、**面積二次方**、體積三次方 |
%[text] | 只做校正不做驗證 | 不知道校正對不對 | 留一個已知尺寸的物件當驗證 |
%[text] | 自己數 `nnz(bwperim)` 當周長 | **低估約 11%**（斜向步進跨 √2 卻算 1） | 用 `regionprops` 的 `Perimeter`，它會依走向加權 |
%[text] | 對極小區域做形狀篩選 | 2 像素的雜點圓形度可達 0.97 而通過篩選 | **形狀篩選前先用面積擋掉退化區域** |
%[text] | 用中文當變數／table 欄位名 | `Invalid text character`，訊息不提中文 | 識別字必須 ASCII；中文只能放在字串裡 |
%[text] | 量測前沒 `imclearborder` | 碰邊物件的尺寸被低估，污染統計 | 量測前必做，並在報告中說明排除數量 |
%[text] | 報告只給平均值 | 隱藏了離散程度 | 一定要附標準差或全距 |
%[text] | 沒說明用哪個屬性量 | 別人無法重現你的數字 | 報告中明確寫出量測定義 |
%[text] | `caliper` 用預設 `GradientThreshold` | 完全找不到邊緣 | 先看 `ProfileData` 的梯度量級再設門檻 |
%[text] | `caliper` 依賴 `Width` 的預設值 | 升級到 R2026b 後同一行程式量到的寬度少 15%，**不會報錯** | 會影響結果的參數一律明確指定（本章用 `Width=50`） |
%[text] | 以為 `caliper` 與 `regionprops` 該一致 | 以為某一個算錯了 | 它們回答**不同的問題**（弦長 vs 等效直徑） |
%[text:table]
%%
%[text] # 11. 本章小結
%[text] - 每個 `regionprops` 屬性量的是**不同的東西**，選錯就得到不同的答案
%[text] - **R2026a 的** **`BoundaryCoordinates`** **用** **`[x y]`**，與 `bwboundaries` 相反
%[text] - 篩選物件時，**圓形度與凸實度常比面積有效**
%[text] - **校正必須配驗證**：用一個已知尺寸建立係數，用另一個驗證它。 \
%[text] 本章實測比例誤差 0.4%、預測誤差 0.4%
%[text] - **面積換算是** **`mmPerPixel^2`**
%[text] - `caliper` 與 `regionprops` 的差異不是誤差，是**問題不同**
%[text] - **會影響結果的參數要明確寫出**：`caliper` 的 `Width` 預設值在 R2026b 從 50 改成掃描線長的 10%，量到的值差 15%
%[text] - 報告要含**有效樣本數、排除理由、量測定義、校正誤差、離散程度** \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `regionprops` | 區域屬性 | **R2026a 新增** **`"BoundaryCoordinates"`****（\[x y\]）** |
%[text] | `bwlabel` `bwconncomp` `labelmatrix` | 連通元件標記 |  |
%[text] | `bwpropfilt` | 依任意屬性篩選 | 可給範圍或「最大 n 個」 |
%[text] | `bwareafilt` `bwareaopen` | 依面積篩選 |  |
%[text] | `bwboundaries` | 邊界追蹤 | 回傳 **\[row col\]** |
%[text] | `imclearborder` | 移除碰邊物件 | **量測前必做** |
%[text] | `caliper` `uicaliper` | 次像素邊緣對量測 | Visual Inspection Toolbox（R2026a 以前是 AVI Library）；**R2026b 改了 `Width` 預設值** |
%[text] | `imdistline` | 互動式距離量測 | 快速檢查用 |
%[text] | `imageRegionAnalyzer` | 互動式區域分析 APP | 探索該用哪個屬性 |
%[text:table]
%%
%[text] # 12. 練習
%[text] 開啟 `exercise/Ch11_Exercise.m`，完成五題。解答在 `Ch11_Solution.m`。
%%
%[text] # 13. 延伸閱讀與下一章
%[text] - [Measure Properties of Image Regions](https://www.mathworks.com/help/images/measuring-regions-in-grayscale-images.html)
%[text] - [Correct Nonuniform Illumination and Analyze Foreground Objects](https://www.mathworks.com/help/images/correcting-nonuniform-illumination.html)
%[text] - **下一章**：第 12 章　影像品質評估與相機／光學特性——本章假設影像是「對的」，下一章討論怎麼確認這件事 \

function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end

function v = ternaryNum(cond, a, b)
if cond, v = a; else, v = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
