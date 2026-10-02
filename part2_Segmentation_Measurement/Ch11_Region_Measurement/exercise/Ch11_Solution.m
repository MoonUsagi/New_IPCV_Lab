%[text] # 第 11 章　練習解答
%[text] 區域分析、物件量測與空間校正
assert(exist("ch11_measureObjects","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
hasCaliper = exist("caliper","file") == 2;
rng(0);
%%
%[text] # 解答 1：選出能分開的屬性
%[text] 先建立影像，並用**位置**指定每個物件的真實類別——
%[text] 有了真實標籤才能客觀檢驗分類規則，而不是看圖說故事。
canvas = false(400, 500);
[gx, gy] = meshgrid(1:500, 1:400);

canvas((gx-70).^2  + (gy-70).^2  < 35^2) = true;    % 圓
canvas((gx-180).^2 + (gy-70).^2  < 28^2) = true;    % 較小的圓
canvas(50:70,   280:420) = true;                     % 細長矩形
canvas(150:250, 60:90)   = true;                     % L 形（垂直段）
canvas(220:250, 60:180)  = true;                     % L 形（水平段）
canvas(300:400, 250:350) = rand(101,101) > 0.75;     % 雜點群

stats = regionprops("table", canvas, ...
    "Area", "Centroid", "Circularity", "Eccentricity", "Solidity", "Extent");

% 依質心位置指定真實類別
cx = stats.Centroid(:,1);
cy = stats.Centroid(:,2);
truth = strings(height(stats), 1);
truth(:) = "雜點";
truth(cx < 250 & cy < 120)                = "圓";
truth(cx > 250 & cy < 120)                = "細長矩形";
truth(cx < 250 & cy > 120 & cy < 290)     = "L 形";

fprintf("物件總數 %d：", height(stats));
classes = ["圓" "細長矩形" "L 形" "雜點"];
for c = classes
    fprintf(" %s %d 個", c, nnz(truth == c));
end
fprintf("\n");
%%
%[text] ## 看每個屬性的範圍，判斷哪些會重疊
props = ["Area" "Circularity" "Eccentricity" "Solidity" "Extent"];

fprintf("\n%-10s %12s %12s %12s %12s %12s\n", "類別", props);
for c = classes
    sel = truth == c;
    fprintf("%-10s", c);
    for p = props
        v = stats.(p)(sel);
        fprintf(" %5.2f–%5.2f", min(v), max(v));
    end
    fprintf("   (n=%d)\n", nnz(sel));
end
%[text] **關鍵觀察**：`Circularity` 無法單獨使用——
%[text] 幾個像素大的雜點的圓形度可以接近 1（第 10 章已經踩過這個坑）。
%[text] 所以**必須先用 `Area` 把雜點濾掉**，屬性才有意義。
%%
%[text] ## 二維散佈圖：Solidity vs Eccentricity
%[text] 濾掉雜點之後，剩下三類需要兩個屬性才分得開。
minArea = 200;                      % 遠小於三類真實物件，遠大於雜點
isBig   = stats.Area >= minArea;

figure
markers = ["o" "s" "^" "."];
hold on
for k = 1:numel(classes)
    sel = truth == classes(k) & isBig;
    if any(sel)
        plot(stats.Solidity(sel), stats.Eccentricity(sel), markers(k), ...
            MarkerSize=9, LineWidth=1.5, DisplayName=classes(k));
    end
end
hold off
xlabel("Solidity（凹陷程度）"); ylabel("Eccentricity（細長程度）")
title(sprintf("面積 >= %d 的物件：兩個屬性就分得開", minArea))
legend(Location="best"); grid on; xlim([0 1.05]); ylim([-0.05 1.05])
%%
%[text] ## 分類規則與驗證
%[text] 規則的**順序**很重要：面積在最前面，因為它排除的是「屬性本身不可信」
%[text] 的物件，而不是「屬性值不符合」的物件。這兩件事不一樣。
predicted = classifyShape(stats, minArea);

confusion = zeros(numel(classes), numel(classes));
for i = 1:numel(classes)
    for j = 1:numel(classes)
        confusion(i,j) = nnz(truth == classes(i) & predicted == classes(j));
    end
end

fprintf("\n混淆矩陣（列=真實，欄=預測）\n");
fprintf("%-10s", "");
fprintf("%10s", classes); fprintf("\n");
for i = 1:numel(classes)
    fprintf("%-10s", classes(i));
    fprintf("%10d", confusion(i,:));
    fprintf("\n");
end

accuracy = sum(diag(confusion)) / height(stats);
fprintf("\n正確率 %.1f%%（%d / %d）\n", ...
    100*accuracy, sum(diag(confusion)), height(stats));
assert(accuracy == 1, "分類規則還有物件判錯，請檢查門檻。");
%%
%[text] # 解答 2：空間校正的誤差來源
%[text] 主教材的 0.37% 誤差是哪裡來的？把**系統誤差**與**隨機誤差**拆開看。
I = imread("coins.png");
cleanMask = imclearborder(bwareaopen(imfill(imbinarize(I),"holes"), 100));

coinStats = regionprops("table", cleanMask, "EquivDiameter", "Centroid");
d = coinStats.EquivDiameter;

% 用最大間隙分成兩群
dSorted = sort(d);
[~, gapIdx] = max(diff(dSorted));
cutoff = mean(dSorted(gapIdx:gapIdx+1));

isNickel = d >  cutoff;             % 大的：nickel 21.21 mm
isDime   = d <= cutoff;             % 小的：dime  17.91 mm

nickelTrueMM = 21.21;
dimeTrueMM   = 17.91;

fprintf("\n分群門檻 %.2f px：nickel %d 枚、dime %d 枚\n", ...
    cutoff, nnz(isNickel), nnz(isDime));
%%
%[text] ## 第 1 步：兩群各自的量測散布
%[text] 先建立校正係數（六枚 nickel 的平均），才能把像素散布換算成 mm。
mmPerPixel = nickelTrueMM / mean(d(isNickel));

fprintf("\n校正係數 %.6f mm/pixel\n\n", mmPerPixel);
fprintf("%-8s %6s %10s %10s %12s %12s\n", ...
    "群", "枚數", "平均(px)", "標準差(px)", "標準差(mm)", "變異係數");
for grp = ["nickel" "dime"]
    if grp == "nickel", sel = isNickel; else, sel = isDime; end
    v = d(sel);
    fprintf("%-8s %6d %10.3f %10.3f %12.3f %11.2f%%" + "\n", grp, numel(v), ...
        mean(v), std(v), std(v)*mmPerPixel, 100*std(v)/mean(v));
end
%%
%[text] ## 第 2 步：量測散布 vs 校正的驗證誤差
%[text] 這是整題的核心比較。
predictedDimeMM = mean(d(isDime)) * mmPerPixel;
validationErrMM  = abs(predictedDimeMM - dimeTrueMM);
validationErrPct = 100 * validationErrMM / dimeTrueMM;

nickelScatterMM = std(d(isNickel)) * mmPerPixel;

fprintf("\n校正的驗證誤差      %.3f mm (%.2f%%)   <- 系統誤差\n", ...
    validationErrMM, validationErrPct);
fprintf("單枚 nickel 的散布  %.3f mm            <- 隨機誤差\n", nickelScatterMM);
fprintf("隨機 / 系統 = %.1f 倍\n", nickelScatterMM / validationErrMM);
%[text] **結論（第 2 小題）**：隨機誤差明顯大於系統誤差。
%[text] 這代表**校正已經不是瓶頸了**——
%[text] 再換一個更準的參考物也不會讓量測變準，因為誤差主要來自
%[text] 每一次分割在邊界上的隨機差異。
%[text] 要改善就得提高影像解析度或改善分割，而不是重新校正。
%%
%[text] ## 第 3 步：若只用一枚 nickel 校正
%[text] 對六種選擇**各算一次**，看最糟情況有多糟。
nickelSizes = d(isNickel);
singleErrPct = zeros(numel(nickelSizes), 1);

fprintf("\n%-6s %12s %14s %14s %10s\n", ...
    "用第幾枚", "直徑(px)", "mm/pixel", "預測dime(mm)", "誤差");
for k = 1:numel(nickelSizes)
    mmppK = nickelTrueMM / nickelSizes(k);
    predK = mean(d(isDime)) * mmppK;
    singleErrPct(k) = 100 * abs(predK/dimeTrueMM - 1);
    fprintf("%-6d %12.3f %14.6f %14.3f %9.2f%%" + "\n", ...
        k, nickelSizes(k), mmppK, predK, singleErrPct(k));
end

fprintf("\n單枚校正：誤差 %.2f%% – %.2f%%（平均 %.2f%%）\n", ...
    min(singleErrPct), max(singleErrPct), mean(singleErrPct));
fprintf("六枚平均：誤差 %.2f%%" + "\n", validationErrPct);
fprintf("最糟的單枚選擇比平均差 %.1f 倍\n", max(singleErrPct)/validationErrPct);
%[text] **結論（第 4 小題）**：**一定要用多個參考物平均。**
%[text] 單枚校正的誤差取決於你剛好挑到哪一枚——而你事先無從得知。
%[text] 最糟的選擇會產生數倍的誤差，而平均把它壓回隨機散布的量級。
%[text] 注意這裡的驗證集**固定是四枚 dime**。若改用「剩下的全部物件」
%[text] 當驗證集（`NumReferences=1` 的預設行為），算出的數字會大得多——
%[text] 但那反映的是驗證集裡混了 nickel，不是校正誤差。
%%
%[text] # 解答 3：空間校正函式
%[text] 完成的函式在本章的 `code/ch11_calibrateScale.m`。
%[text] 這裡驗證它的三個設計要求：正確的係數、散布警告、驗證集純度檢查。
[mmpp, cal] = ch11_calibrateScale(cleanMask, nickelTrueMM, ...
    ValidateSizeMM=dimeTrueMM);

fprintf("\n自動挑選 %d 個參考物\n", cal.NumReferences);
fprintf("係數     %.6f mm/pixel（手算 %.6f，差 %.2g）\n", ...
    mmpp, mmPerPixel, abs(mmpp - mmPerPixel));
fprintf("散布     %.2f%%" + "\n", 100*cal.RelativeScatter);
fprintf("驗證誤差 %.2f%%（手算 %.2f%%）\n", cal.ValidationError, validationErrPct);
fprintf("指紋     %s\n", cal.Fingerprint);
disp(cal.Note)
%%
%[text] ## 三個警告都該在該響的時候響
%[text] 一支量測函式的價值有一半在**它拒絕安靜地給出壞答案**。
fprintf("\n--- 測試 1：只給一個參考物 ---\n");
lastwarn("");
ch11_calibrateScale(cleanMask, nickelTrueMM, NumReferences=1);
[~, id1] = lastwarn;
fprintf("觸發：%s\n", id1);
assert(id1 == "ch11_calibrateScale:singleReference");

fprintf("\n--- 測試 2：驗證集混了兩種硬幣 ---\n");
lastwarn("");
ch11_calibrateScale(cleanMask, nickelTrueMM, NumReferences=1, ...
    ValidateSizeMM=dimeTrueMM);
[~, id2] = lastwarn;
fprintf("觸發：%s\n", id2);
assert(id2 == "ch11_calibrateScale:mixedValidationSet");

fprintf("\n--- 測試 3：把兩種硬幣都當成參考物（散布過大）---\n");
lastwarn("");
ch11_calibrateScale(cleanMask, nickelTrueMM, NumReferences=10);
[~, id3] = lastwarn;
fprintf("觸發：%s\n", id3);
assert(id3 == "ch11_calibrateScale:highScatter");
%%
%[text] # 解答 4：caliper 的掃描線該放哪裡
%[text] 掃描線沒穿過圓心時，量到的是**弦長**而不是直徑：
%[text] $$\text{弦長} = 2\sqrt{r^2 - d^2}$$
%[text] 其中 $d$ 是掃描線到圓心的垂直距離。
%[text] 這題有兩個陷阱，兩個都得先解決才量得出這條曲線。
if ~hasCaliper
    fprintf("未安裝 Automated Visual Inspection Library，跳過解答 4。\n");
else
    % 陷阱一：掃描線是一條**水平線段**。同一列上若有別的硬幣，
    % 量到的邊緣對可能橫跨兩個物件——而且不會有任何警告。
    [target, r0] = pickIsolatedCoin(cleanMask);
    fprintf("選用質心 (%.1f, %.1f)、半徑 %.2f px 的硬幣（水平方向淨空）\n", ...
        target(1), target(2), r0);

    offsets = 0:3:24;
    theory  = 2*sqrt(r0^2 - offsets.^2);

    % 陷阱二（見下一節）：Width 同時控制「抗雜訊」與「空間解析度」，
    % 兩者互相衝突。所以這裡**同時**量一個窄的與一個寬的。
    widths   = [7 21];
    measured = nan(numel(widths), numel(offsets));

    for wi = 1:numel(widths)
        for k = 1:numel(offsets)
            y = target(2) + offsets(k);
            linePos = [target(1)-r0-20, y; target(1)+r0+20, y];
            md = caliper(I, linePos, Width=widths(wi), ...
                GradientThreshold=0.04, Sigma=1.5);
            measured(wi,k) = strongestPair(md);
        end
    end

    figure
    plot(offsets, theory, "k-", LineWidth=2, DisplayName="理論弦長 2\surd(r^2-d^2)")
    hold on
    plot(offsets, measured(1,:), "o-", MarkerSize=8, LineWidth=1.5, ...
        DisplayName=sprintf("caliper Width=%d", widths(1)))
    plot(offsets, measured(2,:), "s--", MarkerSize=8, LineWidth=1.5, ...
        DisplayName=sprintf("caliper Width=%d", widths(2)))
    hold off
    xlabel("掃描線偏離圓心的距離 d（px）"); ylabel("量到的距離（px）")
    title("掃描線位置決定量到的是直徑還是弦長")
    legend(Location="southwest"); grid on

    fprintf("\n%-8s %10s %10s %9s %10s %9s\n", ...
        "偏離d", "理論弦長", "W=7", "偏差", "W=21", "偏差");
    for k = 1:numel(offsets)
        fprintf("%-8d %10.2f %10.2f %+9.2f %10.2f %+9.2f\n", offsets(k), ...
            theory(k), measured(1,k), measured(1,k)-theory(k), ...
            measured(2,k), measured(2,k)-theory(k));
    end
end
%%
%[text] ## 第 5 小題：實測與理論吻合嗎？
%[text] 分三件事看，因為上面的表格裡混了三種性質完全不同的偏差。
if hasCaliper
    valid7 = ~isnan(measured(1,:));
    bias7  = measured(1,:) - theory;

    % 把「帶子還完整落在硬幣內」與「帶子已經探出硬幣」分開統計。
    % 混在一起算會得到一個沒有意義的平均偏差。
    inside = valid7 & (offsets + widths(1)/2) <= 0.6*r0;

    fprintf("\n(1) 窄掃描線 W=7：有效 %d / %d 點\n", nnz(valid7), numel(offsets));
    fprintf("    帶子完整在硬幣內（d <= %d）：偏差 %+.2f – %+.2f px，", ...
        max(offsets(inside)), min(bias7(inside)), max(bias7(inside)));
    fprintf("平均 %+.2f px、標準差 %.2f px\n", ...
        mean(bias7(inside)), std(bias7(inside)));
    fprintf("    帶子探出硬幣（d > %d）：偏差擴大到 %+.2f px\n", ...
        max(offsets(inside)), max(bias7(valid7)));

    fprintf("\n(2) 寬掃描線 W=21：d=0 偏差只有 %+.2f px，", ...
        measured(2,1)-theory(1));
    fprintf("但 d=15 已經偏 %+.2f px\n", measured(2,6)-theory(6));

    fprintf("\n(3) 失敗點：W=7 有 %d 個、W=21 有 %d 個偏移量量不到邊緣\n", ...
        nnz(isnan(measured(1,:))), nnz(isnan(measured(2,:))));
end
%[text] **(1) 一個固定的正偏移，約 +1.2 px——但只在一段範圍內固定。**
%[text] 這個偏移**不是誤差，是兩種量測定義的差**：
%[text] `EquivDiameter`（理論曲線的 $r$ 來源）算的是**二值遮罩**的面積，
%[text] 而 Otsu 門檻會把邊界上的灰階過渡像素判給背景，遮罩因此系統性偏小。
%[text] caliper 直接在**灰階**上找次像素邊緣，量到的是比較外側的位置。
%[text] 在帶子完整落在硬幣內的範圍裡，兩者的差幾乎不隨 $d$ 變化
%[text] （標準差不到 0.1 px）——這正是系統誤差的指紋：
%[text] **扣掉它之後殘差就很小了。**
%[text] 主教材第 6 節那四種直徑定義差 2–3 像素，是同一件事的另一個面貌。
%[text] 但 $d$ 再大（$d=21$）偏差就跳到 +2.5 px。那不再是定義差，
%[text] 而是下面第 (3) 點的前兆：帶子已經有一部分不在硬幣上了。
%[text] **所以「先確認偏差在哪個範圍內是常數」比「算一個平均偏差」重要得多**——
%[text] 把兩種機制混在一起算一個總平均，得到的數字兩邊都不準。
%[text] **(2) 寬掃描線 W=21 整條曲線被壓平。**
%[text] `Width` 是掃描線在垂直方向的平均寬度。W=21 代表每次量測都平均了
%[text] $d-10$ 到 $d+10$ 這一整條帶子，而帶子裡每一列的弦長都不一樣——
%[text] **你要量的效應被自己的參數平均掉了。**
%[text] 於是它在 $d=15$ 還回報接近直徑的數字，看起來「很穩定」，其實是錯的。
%[text] 這是量測參數最危險的一類錯誤：**它讓錯誤的結果看起來更可信。**
%[text] 更危險的是 $d=0$ 那一點：W=21 的偏差幾乎是零，**比 W=7 還漂亮**。
%[text] 那是巧合——寬帶子的平均效應把值往下拉約 1 px，
%[text] 剛好抵掉了第 (1) 點那個往上 +1.2 px 的定義差。
%[text] **兩個獨立的誤差在單一條件下互相抵消。**
%[text] 只在 $d=0$ 驗證的人會選 W=21，然後在別的條件下錯得一塌糊塗。
%[text] 這就是為什麼驗證要**掃一個範圍**，而不是只測一個點。
%[text] **(3) 偏移大時直接失敗（NaN）。**
%[text] $d$ 接近半徑時，寬度為 W 的帶子有一部分已經落在硬幣外面，
%[text] 灰階剖面被背景稀釋，梯度過不了門檻。W 越大越早失敗。
%[text] **綜合結論**：在帶子完整落在硬幣內、且 `Width` 夠窄時，
%[text] 實測與理論吻合——扣掉量測定義差之後殘差不到 0.1 px。
%[text] 但 `Width` 同時決定抗雜訊能力與空間解析度，**兩者無法兼得**：
%[text] 太窄會被雜訊主宰（W=3 時第一組邊緣對是 39.89 px，硬幣其實是 59.21），
%[text] 太寬會把要量的效應平均掉。
%[text] **實務意義**：量到的數字隨掃描線位置**單調下降**，而且沒有任何
%[text] 徵兆告訴你量錯了——caliper 會很有信心地回報一個偏小的值。
%[text] 這就是產線量測必須用**固定治具**的原因：
%[text] 掃描線的位置必須可重複，否則每次量到的都是不同的弦。
%%
%[text] # 解答 5：rice.png 的量測報告
%[text] 這題的核心在第 2 小題：**這張影像沒有參考物，所以沒有絕對尺寸。**
%[text] 誠實的做法是只報像素單位，並在報告中明確寫出這個限制。
rice = imread("rice.png");
riceBg   = imopen(rice, strel("disk", 15));       % 第 06 章的背景校正
riceFlat = rice - riceBg;
riceMask = bwareaopen(imbinarize(riceFlat), 20);

report = ch11_measureObjects(riceMask, ClearBorder=true, MinArea=20);

fprintf("\n有效樣本 %d 顆，排除 %d 顆\n", height(report.Objects), report.ExcludedCount);
fprintf("排除理由：%s\n", report.ExcludedReason);
fprintf("量測定義：%s\n", report.MeasurementDef);
fprintf("校正狀態：%s\n\n", report.CalibrationNote);
disp(report.Summary)
%[text] 注意 `ch11_measureObjects` 在**沒有** `MMPerPixel` 時不會產生任何
%[text] mm 欄位。這不是功能缺失，是刻意的：函式不該讓你不小心報出
%[text] 沒有根據的絕對尺寸。
%%
%[text] ## 為什麼不能「假設一個換算係數」
%[text] 若硬要假設，錯誤會被**放大**：面積是長度的平方。
dPx = report.Objects.EquivDiameter;

fprintf("假設不同的 mm/pixel，同一批米粒會得到完全不同的結論：\n\n");
fprintf("%-14s %14s %14s\n", "假設mm/pixel", "平均長度(mm)", "平均面積(mm^2)");
for guess = [0.05 0.10 0.20]
    fprintf("%-14.2f %14.3f %14.3f\n", guess, ...
        mean(dPx)*guess, mean(report.Objects.Area)*guess^2);
end
fprintf("\n係數差 4 倍 -> 長度差 4 倍、面積差 %d 倍。\n", 16);
fprintf("沒有參考物時，唯一誠實的報告是像素單位加上相對比較。\n");
%%
%[text] ## 尺寸分布直方圖
meanD = mean(dPx);
stdD  = std(dPx);

figure
histogram(dPx, 20, FaceColor=[0.35 0.55 0.75])
xline(meanD, "-", sprintf("平均 %.2f px", meanD), LineWidth=2, Color=[0.85 0.33 0.10]);
xline(meanD - stdD, "--", "-1\sigma", LineWidth=1.5);
xline(meanD + stdD, "--", "+1\sigma", LineWidth=1.5);
xlabel("等效直徑（像素）"); ylabel("顆數")
title(sprintf("rice.png 米粒尺寸分布（n=%d，未校正）", numel(dPx)))
grid on

withinOneSigma = 100 * nnz(abs(dPx - meanD) <= stdD) / numel(dPx);
fprintf("\n落在 ±1 sigma 內：%.1f%%（常態分布的期望值約 68%%）\n", withinOneSigma);
fprintf("最大值 %.2f px 是平均的 %.2f 倍、距平均 %.1f 個標準差\n", ...
    max(dPx), max(dPx)/meanD, (max(dPx)-meanD)/stdD);
fprintf("偏度 %.2f（常態分布為 0）\n", skewness(dPx));
%[text] **不要跳過這個 87% 不看。**
%[text] 它比 68% 高，代表分布**比常態更集中**，但同時有幾個明顯的離群值
%[text] （見上面的最大值與正偏度）。這通常是**兩顆米粒黏在一起**
%[text] 被當成一顆量測——第 08 章的分水嶺分割就是為了處理這件事。
%[text] 所以這裡的標準差 1.46 px **混了兩件事**：米粒真實的大小差異，
%[text] 以及少數幾個沾黏造成的量測錯誤。
%[text] 誠實的報告要嘛先分開沾黏，要嘛說明這個限制——
%[text] 直接把 1.46 px 當成「米粒尺寸變異」是不對的。
%%
%[text] ## 報告結論
%[text] 以下這段文字才是要交給客戶的東西。
conclusion = sprintf( ...
    "rice.png 米粒尺寸報告：有效樣本 %d 顆，" + ...
    "已排除碰觸影像邊界者 %d 顆（尺寸被切斷、數值不可信）。" + ...
    "等效直徑平均 %.2f 像素、標準差 %.2f 像素（變異係數 %.1f%%）。" + ...
    "**本影像不含已知尺寸的參考物，因此無法換算為實際單位**；" + ...
    "上述數字僅供同一張影像內的相對比較。" + ...
    "另註：尺寸分布含少數離群值，可能來自沾黏米粒被計為單顆。" + ...
    "若需絕對尺寸，請在拍攝時一併放入已知尺寸的標準件。", ...
    numel(dPx), report.ExcludedCount, meanD, stdD, 100*stdD/meanD);

fprintf("\n%s\n", conclusion);
fprintf("\n（%d 字）\n", strlength(conclusion));
%%
%[text] # 加分題：量測不確定度
%[text] 對同一批硬幣用不同前處理各量一次，比較兩種不確定度：
%[text] - **方法不確定度**：換一套前處理，答案變多少
%[text] - **樣本變異**：同一次量測裡，同種硬幣彼此差多少
%[text] 但在比較之前，有一個關卡必須先過。
variants = struct( ...
    "name", {"基準（Otsu + 填洞）", "門檻 x0.95", "門檻 x1.05", ...
             "加開運算 disk 2", "門檻 x1.15"}, ...
    "make", {@(x) imfill(imbinarize(x), "holes"), ...
             @(x) imfill(imbinarize(x, graythresh(x)*0.95), "holes"), ...
             @(x) imfill(imbinarize(x, graythresh(x)*1.05), "holes"), ...
             @(x) imopen(imfill(imbinarize(x), "holes"), strel("disk", 2)), ...
             @(x) imfill(imbinarize(x, graythresh(x)*1.15), "holes")});

nv = numel(variants);
counts = zeros(nv,1);
allStd = nan(nv,1);
nickelMean = nan(nv,1);
nickelStd  = nan(nv,1);

for k = 1:nv
    m  = imclearborder(bwareaopen(variants(k).make(I), 100));
    st = regionprops("table", m, "EquivDiameter");
    dAll = sort(st.EquivDiameter, "descend");
    counts(k) = numel(dAll);
    allStd(k) = std(dAll);
    if counts(k) >= 6
        nickelMean(k) = mean(dAll(1:6));     % 只取最大的六枚：nickel
        nickelStd(k)  = std(dAll(1:6));
    end
end
%%
%[text] ## 關卡：物件數不一致的變體不能納入比較
%[text] 若兩套流程連「有幾個物件」都不同意，它們的平均值指的就是
%[text] **不同的物件集合**，相減得到的數字沒有意義。
baselineCount = counts(1);
usable = counts == baselineCount;

fprintf("\n%-22s %8s %12s %10s\n", "前處理", "物件數", "全體標準差", "是否採用");
for k = 1:nv
    if usable(k), verdict = "採用"; else, verdict = "剔除"; end
    fprintf("%-22s %8d %12.3f %10s\n", ...
        variants(k).name, counts(k), allStd(k), verdict);
end

fprintf("\n基準找到 %d 個物件；「門檻 x1.15」找到 %d 個——它把硬幣切碎了。\n", ...
    baselineCount, counts(end));
fprintf("注意它的全體標準差 %.1f px，是基準 %.1f px 的 %.1f 倍。\n", ...
    allStd(end), allStd(1), allStd(end)/allStd(1));
fprintf("若把它納入比較，那個膨脹的標準差反映的是**分割破了**，\n");
fprintf("不是硬幣大小不一。所以它必須在比較之前就被剔除。\n");
%%
%[text] ## 只比較同一種硬幣
%[text] 十枚硬幣含 nickel 與 dime 兩種尺寸，直接算全體標準差會得到約 4.8 px——
%[text] 那主要是**兩種面額的差異**，不是量測散布。
%[text] 要談不確定度，必須把比較限制在**同一種**硬幣上。
fprintf("\n%-22s %14s %14s\n", "前處理", "nickel平均", "nickel標準差");
for k = 1:nv
    if usable(k)
        fprintf("%-22s %14.3f %14.3f\n", ...
            variants(k).name, nickelMean(k), nickelStd(k));
    end
end

methodUncertainty = std(nickelMean(usable));    % 各變體「平均值」之間的散布
sampleVariation   = mean(nickelStd(usable));    % 單次量測**內**的散布

fprintf("\n方法不確定度（各變體平均值的標準差）  %.3f px\n", methodUncertainty);
fprintf("樣本變異（單次量測的平均標準差）      %.3f px\n", sampleVariation);
fprintf("平均值全距 %.3f px（%.3f – %.3f）\n", ...
    max(nickelMean(usable))-min(nickelMean(usable)), ...
    min(nickelMean(usable)), max(nickelMean(usable)));
fprintf("樣本變異 / 方法不確定度 = %.1f 倍\n", sampleVariation/methodUncertainty);
%%
%[text] ## 視覺化：誤差棒 vs 點的高低差
idx = find(usable);
figure
errorbar(1:numel(idx), nickelMean(idx), nickelStd(idx), "o", ...
    MarkerSize=9, LineWidth=1.5, CapSize=12)
hold on
yline(mean(nickelMean(idx)), "--", "各變體的總平均", LineWidth=1.2);
hold off
xlim([0.5 numel(idx)+0.5]); xticks(1:numel(idx))
xticklabels(["基準" "x0.95" "x1.05" "開運算"])
ylabel("nickel 等效直徑（px）")
title("誤差棒 = 樣本變異；點的高低差 = 方法不確定度")
grid on
%[text] 誤差棒明顯比點的高低差大——這就是本例的答案。
%%
%[text] ## 第 4 小題：哪個大？報告該報哪一個？
if sampleVariation > methodUncertainty
    fprintf("\n本例：樣本變異大 %.1f 倍。\n", sampleVariation/methodUncertainty);
    fprintf("報樣本標準差是正當的——換一套**合理的**前處理不會改變結論。\n");
else
    fprintf("\n本例：方法不確定度大 %.1f 倍。\n", methodUncertainty/sampleVariation);
    fprintf("報告的標準差反映的是流程不穩定，不是物件差異。\n");
end
%[text] **判準**：先比大小，再決定報告怎麼寫。
%[text] · **樣本變異 > 方法不確定度**（本例）：
%[text]   報告的標準差可以解讀為「物件真的大小不一」，因為換一套合理的
%[text]   前處理不會顯著改變結論。這時報樣本標準差是正當的。
%[text] · **方法不確定度 > 樣本變異**：
%[text]   你報的「標準差」其實反映的是**流程不穩定**，不是物件的差異。
%[text]   把它當成物件變異來解讀是嚴重的誤導——
%[text]   必須先把流程固定下來，或在報告中兩個數字都給。
%[text] 另外注意「加開運算 disk 2」與基準的 nickel 平均幾乎完全相同。
%[text] 這不是巧合：disk 2 的開運算移除的是細小突起，
%[text] 而硬幣邊界本來就平滑，所以直徑幾乎沒變。
%[text] **一個不改變答案的步驟，也就不需要留在流程裡**——
%[text] 它只會讓後來的人以為它很關鍵，不敢動。
%[text] 這也是為什麼 `ch11_measureObjects` 一定要記錄 `MeasurementDef`
%[text] 與 `CalibrationNote`：**沒有寫明流程，別人根本無法判斷
%[text] 你報的標準差屬於上面哪一種。**

% ========================================================================
function labels = classifyShape(stats, minArea)
%CLASSIFYSHAPE 用面積、Solidity、Eccentricity 三個屬性分四類。
%
%   規則的順序有意義：面積在最前面，因為它排除的是「屬性不可信」的物件。
%   幾個像素大的雜點的 Circularity 可以接近 1，先濾面積才能用形狀屬性。

labels = strings(height(stats), 1);

isSmall = stats.Area < minArea;
labels(isSmall) = "雜點";

big = ~isSmall;

% L 形有明顯的凹陷：凸包比自己大很多
isConcave = big & stats.Solidity < 0.9;
labels(isConcave) = "L 形";

% 剩下的凸物件用細長程度分：矩形離心率接近 1，圓接近 0
rest = big & ~isConcave;
labels(rest & stats.Eccentricity >= 0.9) = "細長矩形";
labels(rest & stats.Eccentricity <  0.9) = "圓";
end

% ========================================================================
function dist = strongestPair(md)
%STRONGESTPAIR 從 caliper 回報的多組邊緣對中挑出梯度最強的那一組。
%
%   caliper 會回報**所有**通過門檻的邊緣對，順序是沿掃描線由近到遠，
%   **不是**依可信度排序。直接取 IntraEdgeDistance(1) 會拿到雜訊邊緣對：
%   實測在 Width=3 時第一組是 39.89 px，而硬幣實際直徑是 59.21 px。
%
%   這裡用「邊緣對兩端的梯度強度之和」挑選。這個準則**不需要事先知道
%   答案**，所以不是拿理論值去挑一個好看的結果。
%
%   GradientValue 的排列方式：n 組邊緣對對應 2n 個值，
%   第 j 組用的是第 2j-1 與第 2j 個。

d = md.IntraEdgeDistance(:)';
if isempty(d)
    dist = NaN;                 % 梯度全都過不了門檻
    return
end

g = abs(md.GradientValue(:));
strength = zeros(1, numel(d));
for j = 1:numel(d)
    strength(j) = g(2*j-1) + g(2*j);
end

[~, best] = max(strength);
dist = d(best);
end

% ========================================================================
function [centroid, radius] = pickIsolatedCoin(mask)
%PICKISOLATEDCOIN 挑一枚水平方向淨空的硬幣，讓掃描線不會撞到鄰居。
%
%   caliper 的掃描線是一條水平線段。若同一列上還有別的硬幣，
%   量到的邊緣對可能來自不同物件——這種錯誤不會有任何警告。

L = bwlabel(mask);
s = regionprops("table", L, "Centroid", "EquivDiameter");

bestClearance = -inf;
centroid = s.Centroid(1,:);
radius   = s.EquivDiameter(1)/2;

for k = 1:height(s)
    c = s.Centroid(k,:);
    r = s.EquivDiameter(k)/2;

    rows = max(1, round(c(2)-0.8*r)) : min(size(L,1), round(c(2)+0.8*r));
    cols = max(1, round(c(1)-r-25))  : min(size(L,2), round(c(1)+r+25));

    band   = L(rows, cols);
    others = unique(band(band > 0 & band ~= k));

    if isempty(others)
        % 淨空的候選裡取半徑最大的：半徑越大，弦長曲線的動態範圍越大
        if r > bestClearance
            bestClearance = r;
            centroid = c;
            radius   = r;
        end
    end
end

if ~isfinite(bestClearance)
    warning("Ch11_Solution:noIsolatedCoin", ...
        "找不到水平方向完全淨空的硬幣，改用第一枚。量到的邊緣可能來自鄰居。");
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
