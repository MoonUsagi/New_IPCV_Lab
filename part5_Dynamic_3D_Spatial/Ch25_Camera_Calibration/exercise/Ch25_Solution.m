%[text] # 第 25 章　練習解答
%[text] {"align":"left"}相機標定與多相機系統　｜　MATLAB R2026b
%[text] > **練習 4 推翻了主教材 §2 自己給的建議。**
%[text] > 「把誤差最大的影像拿掉重標」會讓重投影誤差單調變好、
%[text] > 而**去畸變效果崩潰**。推翻的過程完整留在下面。
assert(exist("ch25_calibrateSet", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

calRoot = fullfile(toolboxdir("vision"), "visiondata", "calibration");
monoFiles = dir(fullfile(calRoot, "mono", "*.jpg"));
monoNames = string(fullfile({monoFiles.folder}, {monoFiles.name}));
[monoPts, monoBoard] = detectCheckerboardPoints(monoNames);
monoWorld = generateCheckerboardPoints(monoBoard, 25);
monoImg   = imread(monoNames(1));
monoSize  = [size(monoImg,1) size(monoImg,2)];
nMono     = size(monoPts, 3);
fprintf("mono：%d 張可用，棋盤 %s，影像 %dx%d\n", ...
    nMono, mat2str(monoBoard), monoSize(2), monoSize(1));
%%
%[text] # 解答 1　標定影像到底覆蓋了多少視野
sets = ["mono" "gopro" "dslr" "slr"];
SetName  = sets';
HullPct  = zeros(4,1);
MaxR     = zeros(4,1);
DiagR    = zeros(4,1);
RadiusPct = zeros(4,1);

for i = 1:4
    f = dir(fullfile(calRoot, sets(i), "*.jpg"));
    names = string(fullfile({f.folder}, {f.name}));
    [c, mr, dr] = localCoverage(names);
    HullPct(i)   = c;
    MaxR(i)      = mr;
    DiagR(i)     = dr;
    RadiusPct(i) = mr / dr * 100;
end
disp(table(SetName, HullPct, MaxR, DiagR, RadiusPct, ...
    VariableNames=["資料集" "凸包覆蓋%" "角點最大半徑" "影像對角半徑" "半徑覆蓋%"]))

figure;
f = dir(fullfile(calRoot, "mono", "*.jpg"));
names = string(fullfile({f.folder}, {f.name}));
allPts = reshape(permute(monoPts, [1 3 2]), [], 2);
allPts = allPts(all(isfinite(allPts),2), :);
imshow(monoImg); hold on
plot(allPts(:,1), allPts(:,2), "g.", MarkerSize=6);
k = convhull(allPts(:,1), allPts(:,2));
plot(allPts(k,1), allPts(k,2), "r-", LineWidth=2);
title("mono：所有標定角點只佔畫面 7.6%")
%[text] ## 量到的結果
%[text:table]
%[text] | 資料集 | 凸包覆蓋 | 角點最大半徑 | 影像對角半徑 | **半徑覆蓋** |
%[text] | --- | --- | --- | --- | --- |
%[text] | **mono** | **7.6%** | 252.2 | 643.5 | **39.2%** |
%[text] | gopro | 35.9% | 734.9 | 1250.0 | 58.8% |
%[text] | dslr | **47.9%** | 640.9 | 976.0 | **65.7%** |
%[text] | slr | 44.3% | 1110.7 | 1692.9 | 65.6% |
%[text:table]
%[text] **`mono` 的標定角點只佔畫面 7.6%，半徑只到 39.2%。**
%[text] **第 4 小題：把這個和主教材 §4 的徑向分組表對起來。**
%[text:table]
%[text] | 半徑區間 | 2 階 vs 3 階的去畸變差異 | **有標定資料嗎** |
%[text] | --- | --- | --- |
%[text] | 0 – 161 | 0.025 px | ✅ 有 |
%[text] | 161 – 322 | 0.101 px | ⚠ 部分（資料只到 252） |
%[text] | 322 – 483 | **14.03 px** | ❌ **沒有** |
%[text] | 483 – 643 | **141.29 px** | ❌ **完全沒有** |
%[text:table]
%[text] > ## **差異開始爆炸的半徑（約 322），正好在標定資料的邊界（252）之外。**
%[text] > 這不是巧合，這就是原因。**模型在有資料的地方一致，
%[text] > 在沒有資料的地方各說各話。**
%[text] > 而重投影誤差**只在有資料的地方計算**，所以它對這件事完全無感。
%[text] **第 5 小題**：`gopro` 的覆蓋（58.8%）比 `mono`（39.2%）好得多，
%[text] `dslr` 最好（65.7%）。
%[text] **第 6 小題：可以貼在作業指導書上的話**
%[text] > **「標定影像的角點必須覆蓋到影像對角線半徑的 80% 以上，
%[text] > 特別是四個角落。覆蓋不到的區域，去畸變結果是外插出來的，
%[text] > 誤差可以達到數百像素，而重投影誤差不會顯示任何異常。」**
%%
%[text] # 解答 2　張數夠不夠，用參數穩定性判斷
FocalX = zeros(nMono,1);
PrincX = zeros(nMono,1);
K1     = zeros(nMono,1);
ErrLOO = zeros(nMono,1);
for i = 1:nMono
    keep = setdiff(1:nMono, i);
    p = estimateCameraParameters(monoPts(:,:,keep), monoWorld, ImageSize=monoSize);
    FocalX(i) = p.Intrinsics.FocalLength(1);
    PrincX(i) = p.Intrinsics.PrincipalPoint(1);
    K1(i)     = p.Intrinsics.RadialDistortion(1);
    ErrLOO(i) = p.MeanReprojectionError;
end

Param = ["焦距 fx" "主點 cx" "k1" "重投影誤差"]';
Mean  = [mean(FocalX); mean(PrincX); mean(K1); mean(ErrLOO)];
Std   = [std(FocalX);  std(PrincX);  std(K1);  std(ErrLOO)];
CV    = Std ./ abs(Mean) * 100;
disp(table(Param, Mean, Std, CV, VariableNames=["參數" "平均" "標準差" "變異係數%"]))
%[text] ## 量到的結果（留一法，10 組）
%[text:table]
%[text] | 參數 | 平均 | 標準差 | **變異係數** |
%[text] | --- | --- | --- | --- |
%[text] | 焦距 $f_x$ | 715.65 | 2.44 | **0.34%** |
%[text] | 主點 $c_x$ | 568.70 | 5.64 | 0.99% |
%[text] | **$k_1$** | −0.34720 | 0.01097 | **3.16%** |
%[text] | 重投影誤差 | 0.1849 | 0.0039 | 2.14% |
%[text:table]
%[text] **第 2 小題：$k_1$ 最不穩定**（3.16%），是焦距的 9 倍。
%[text] 這很合理：焦距由整體尺度決定，每張影像都在貢獻資訊；
%[text] **畸變係數主要由邊緣的角點決定**，而解答 1 量到
%[text] 邊緣的角點很少。
%[text] **第 4、5 小題：用隨機子集畫穩定性曲線。**
subsetSizes = 3:8;
StdFocal = zeros(numel(subsetSizes),1);
StdK1    = zeros(numel(subsetSizes),1);
nRepeat = 10;
if ipcvFast(), nRepeat = 4; end
for i = 1:numel(subsetSizes)
    fVals = zeros(nRepeat,1);
    kVals = zeros(nRepeat,1);
    for r = 1:nRepeat
        keep = randperm(nMono, subsetSizes(i));
        p = estimateCameraParameters(monoPts(:,:,keep), monoWorld, ImageSize=monoSize);
        fVals(r) = p.Intrinsics.FocalLength(1);
        kVals(r) = p.Intrinsics.RadialDistortion(1);
    end
    StdFocal(i) = std(fVals);
    StdK1(i)    = std(kVals);
end
disp(table(subsetSizes', StdFocal, StdK1, ...
    VariableNames=["子集大小" "焦距標準差" "k1標準差"]))

figure;
yyaxis left;  plot(subsetSizes, StdFocal, "o-", LineWidth=1.5); ylabel("焦距標準差（像素）")
yyaxis right; plot(subsetSizes, StdK1, "s-", LineWidth=1.5);    ylabel("k_1 標準差")
grid on; xlabel("使用的影像張數"); title("參數穩定性：曲線轉平了才算夠")
%[text] **第 5 小題：`mono` 這 10 張夠嗎？**
%[text] 焦距的標準差已經降到 3 像素以下（0.34%），對大多數應用夠了。
%[text] 但 **$k_1$ 的曲線還沒明顯轉平**——而解答 1 告訴我們為什麼：
%[text] **邊緣沒有資料。再多拍幾張同樣位置的影像也救不了，
%[text] 必須拍到邊角。**
%[text] **第 6 小題：為什麼這比看重投影誤差可靠**
%[text] 重投影誤差問的是「模型擬合**已有資料**的程度」。
%[text] 資料不夠時，擬合可以很好——**那就是過擬合的定義**。
%[text] 參數穩定性問的是「**換一批資料，答案會不會變**」，
%[text] 那才是「參數可不可信」。
%[text] > 這和第 18 章 §6.1 的「先量重跑變異再相信差距」
%[text] > 是完全同一個做法，只是那裡的變異來自 GPU 非決定性，
%[text] > 這裡來自資料取樣。
%%
%[text] # 解答 3　方格邊長給錯會怎樣
%[text] ## 我的預期
%[text] 「焦距會等比例錯，重投影誤差可能會變差。」**兩個都錯。**
squareSizes = [25 25.4];
Focal   = zeros(2,2);
Princ   = zeros(2,2);
K1s     = zeros(2,1);
Errs    = zeros(2,1);
TransZ  = zeros(2,1);
for i = 1:2
    wp = generateCheckerboardPoints(monoBoard, squareSizes(i));
    p  = estimateCameraParameters(monoPts, wp, ImageSize=monoSize);
    Focal(i,:) = p.Intrinsics.FocalLength;
    Princ(i,:) = p.Intrinsics.PrincipalPoint;
    K1s(i)     = p.Intrinsics.RadialDistortion(1);
    Errs(i)    = p.MeanReprojectionError;
    TransZ(i)  = p.PatternExtrinsics(1).Translation(3);
end
disp(table(squareSizes', Focal(:,1), Princ(:,1), K1s, Errs, TransZ, ...
    VariableNames=["方格mm" "焦距fx" "主點cx" "k1" "重投影誤差" "板1的Z(mm)"]))
fprintf("\n焦距差 %.10f｜主點差 %.10f｜k1 差 %.10f｜誤差差 %.10f\n", ...
    abs(diff(Focal(:,1))), abs(diff(Princ(:,1))), abs(diff(K1s)), abs(diff(Errs)));
fprintf("外參 Z 的比值 %.6f（25.4/25 = %.6f）\n", ...
    TransZ(2)/TransZ(1), 25.4/25);
%[text] ## 量到的結果
%[text:table]
%[text] | | SquareSize = 25 | SquareSize = 25.4 | 差 |
%[text] | --- | --- | --- | --- |
%[text] | 焦距 $f_x$ | 715.60 | 715.60 | **0** |
%[text] | 主點 $c_x$ | 568.27 | 568.27 | **0** |
%[text] | $k_1$ | −0.34889 | −0.34889 | **0** |
%[text] | **重投影誤差** | **0.1851** | **0.1851** | **0** |
%[text] | 板 1 的 $Z$ | 688.4 mm | **699.4 mm** | **×1.0160** |
%[text:table]
%[text] > ## **內參完全沒變，重投影誤差完全沒變。**
%[text] > **只有外參等比例縮放**（699.4 / 688.4 = 1.0160 = 25.4 / 25）。
%[text] **為什麼？** 內參是**像素之間的關係**，和世界的單位無關。
%[text] 方格邊長只是定義了「一個世界單位有多長」——
%[text] 換單位不會改變任何影像上的東西，只會讓所有世界座標等比例縮放。
%[text] **第 4 小題：重投影誤差完全沒有告訴你出錯了。**
%[text] 它算的是**像素上的**誤差，而像素上的一切都沒變。
%[text] **第 5 小題：量長度會偏 1.6%。** 一個 100 mm 的物體會量成 101.6 mm。
%[text] **第 6 小題：怎麼事後發現**
%[text:table]
%[text] | 方法 | 可行嗎 |
%[text] | --- | --- |
%[text] | 看內參 | ❌ 完全看不出來 |
%[text] | 看重投影誤差 | ❌ 完全看不出來 |
%[text] | 看外參的絕對值 | ⚠ 要你知道板子大概放多遠 |
%[text] | **量一個已知長度的物體** | ✅ **唯一可靠的辦法** |
%[text:table]
%[text] > **標定之後一定要量一個已知尺寸的東西。**
%[text] > 這是整個標定流程裡唯一能抓到單位錯誤的檢查，
%[text] > 而它也順便驗證了你的整個量測管線。
%%
%[text] # 解答 4　把最差的影像拿掉——**建議是錯的**
%[text] ## 主教材 §2 的建議
%[text] > 「把明顯偏高的那幾張拿掉重標，或者直接重拍那幾個角度。」
%[text] **前半句是錯的。** 量給你看。
keep = 1:nMono;
Remaining = [];
ReprojErr = [];
BowImp    = [];
Removed   = [];
while numel(keep) >= 4
    p = estimateCameraParameters(monoPts(:,:,keep), monoWorld, ImageSize=monoSize);
    imp = localBowImprovement(monoPts(:,:,keep(1)), monoBoard, p.Intrinsics);
    e   = squeeze(mean(vecnorm(p.ReprojectionErrors, 2, 2), 1));
    [~, worst] = max(e);

    Remaining(end+1,1) = numel(keep);   %#ok<AGROW>
    ReprojErr(end+1,1) = p.MeanReprojectionError; %#ok<AGROW>
    BowImp(end+1,1)    = imp;           %#ok<AGROW>
    Removed(end+1,1)   = keep(worst);   %#ok<AGROW>

    keep(worst) = [];
end
disp(table(Remaining, ReprojErr, BowImp, Removed, ...
    VariableNames=["剩下張數" "重投影誤差" "彎曲改善%" "接著拿掉第幾張"]))

figure;
yyaxis left;  plot(Remaining, ReprojErr, "o-", LineWidth=1.8); ylabel("平均重投影誤差（像素）")
yyaxis right; plot(Remaining, BowImp, "s-", LineWidth=1.8);    ylabel("彎曲改善（%）")
yline(0, "k:");
set(gca, "XDir", "reverse"); grid on
xlabel("剩下的影像張數"); title("兩個指標往相反方向走")
%[text] ## 量到的結果
%[text:table]
%[text] | 剩下張數 | 重投影誤差 | **彎曲改善** |
%[text] | --- | --- | --- |
%[text] | 10 | 0.1851 | **+17.2%** |
%[text] | 9 | 0.1815 | +17.4% |
%[text] | **8** | **0.1770** | **+17.4%** |
%[text] | **7** | **0.1715** | **−42.4%** ← **崩了** |
%[text] | 6 | 0.1657 | −41.8% |
%[text] | 5 | 0.1583 | −34.2% |
%[text] | 4 | **0.1486（最好）** | **−26.4%** |
%[text:table]
%[text] > ## **重投影誤差單調變好，去畸變效果在第 8→7 張時崩潰。**
%[text] > 拿到只剩 4 張時，重投影誤差是全程最低的 **0.1486**，
%[text] > 而去畸變**讓直線變得比原本更彎**（−26.4%）。
%[text] （R2026a 只偵測到 9 張，崩潰點在 7→6 張、+17.3% → −35.7%；**結論相同**。）
%[text] **為什麼會這樣**：拿掉「誤差最大」的影像，通常拿掉的是
%[text] **角度最斜、最靠邊、最難偵測**的那幾張——
%[text] 而那正是**唯一提供邊緣畸變資訊**的影像。
fprintf("\n被拿掉的順序：%s\n", mat2str(Removed'));
fprintf("覆蓋率變化：\n");
keep2 = 1:nMono;
for step = 1:4
    P = reshape(permute(monoPts(:,:,keep2), [1 3 2]), [], 2);
    P = P(all(isfinite(P),2), :);
    k = convhull(P(:,1), P(:,2));
    fprintf("  %d 張：凸包覆蓋 %.1f%%，最大半徑 %.1f\n", ...
        numel(keep2), polyarea(P(k,1),P(k,2))/prod(monoSize)*100, ...
        max(vecnorm(P - monoSize([2 1])/2, 2, 2)));
    p = estimateCameraParameters(monoPts(:,:,keep2), monoWorld, ImageSize=monoSize);
    e = squeeze(mean(vecnorm(p.ReprojectionErrors, 2, 2), 1));
    [~, w] = max(e);
    keep2(w) = [];
end
%[text] **第 6 小題：重寫 §2 的建議**
%[text:table]
%[text] | 原文 | 問題 |
%[text] | --- | --- |
%[text] | 「把明顯偏高的那幾張拿掉重標」 | **會拿掉最有資訊量的影像** |
%[text:table]
%[text] 修正版：
%[text] > **誤差偏高的影像先去看它為什麼偏高。**
%[text] > 如果是**對焦模糊、板子反光、動態模糊**——拿掉是對的。
%[text] > 如果是**角度斜、靠近畫面邊緣**——**千萬不要拿掉**，
%[text] > 那是唯一約束邊緣畸變的資料。
%[text] > **拿掉之前，先量覆蓋率；拿掉之後，再量一次彎曲改善。**
%[text] > 原文的後半句「直接重拍那幾個角度」是對的：
%[text] > **補資料永遠比刪資料安全。**
%%
%[text] # 解答 5　基線誤差怎麼傳到深度
[~, ~, rs] = ch25_stereoSystem();
stereoLeftFiles = dir(fullfile(calRoot, "stereo", "left", "*.png"));
leftNames = string(fullfile({stereoLeftFiles.folder}, {stereoLeftFiles.name}));
[sPts, sBoard] = detectCheckerboardPoints(leftNames);
sImg = imread(leftNames(1));
pLeft = estimateCameraParameters(sPts, generateCheckerboardPoints(sBoard,108), ...
    ImageSize=[size(sImg,1) size(sImg,2)]);

focalPx  = pLeft.Intrinsics.FocalLength(1);
baseline = rs.BaselineMulti;
if isnan(baseline)
    baseline = rs.BaselineStereo;       % R2026b 未安裝多相機標定工具時，改用立體標定的基線
end
dBaseline = rs.BaselineSpread;

fprintf("焦距 %.1f 像素，基線 %.2f mm，基線不確定 %.3f mm（%.3f%%）\n", ...
    focalPx, baseline, dBaseline, dBaseline/baseline*100);

Z = [500 1000 2000 5000]';                       % mm
disparity = focalPx * baseline ./ Z;             % 像素
errFromBaseline = Z * (dBaseline / baseline);    % Z 正比於 B
dDisp = 0.5;                                     % 像素
errFromDisparity = Z.^2 * dDisp / (focalPx * baseline);

disp(table(Z/1000, disparity, errFromBaseline, errFromDisparity, ...
    errFromDisparity./Z*100, ...
    VariableNames=["距離m" "視差px" "基線誤差mm" "視差誤差mm" "視差相對誤差%"]))

figure;
loglog(Z/1000, errFromBaseline, "o-", LineWidth=1.8, DisplayName="基線不確定（正比於 Z）"); hold on
loglog(Z/1000, errFromDisparity, "s-", LineWidth=1.8, DisplayName="視差誤差 0.5 px（正比於 Z²）");
grid on; legend(Location="northwest");
xlabel("距離（公尺）"); ylabel("深度誤差（mm）");
title("近處基線主導，遠處視差主導")
%[text] ## 量到的結果
%[text] 基線不確定 **0.150 mm / 119.72 mm = 0.125%**，
%[text] 所以**深度的相對誤差就是 0.125%**（$Z \propto B$，線性傳遞）。
%[text] （這組數字用到多相機標定的基線。R2026b 未安裝多相機標定工具時，
%[text] 程式改用立體標定的基線 119.87 mm、全距只比兩種方法 0.129 mm（0.107%），下表的數字會略小，**結論不變**。）
%[text] **第 4、5 小題：兩種誤差的距離相依性完全不同**
%[text] $$\delta Z_{\text{基線}} = Z \cdot \frac{\delta B}{B} \propto Z
%[text] \qquad
%[text] \delta Z_{\text{視差}} = \frac{Z^2}{f B}\,\delta d \propto Z^2$$
%[text] **基線誤差線性成長，視差誤差二次成長。**
%[text] 量到的實際數字：
%[text:table]
%[text] | 距離 | 基線造成 | 視差造成（0.5 px） | 比值 |
%[text] | --- | --- | --- | --- |
%[text] | 0.5 m | 0.63 mm | **1.01 mm** | 1.6× |
%[text] | 1 m | 1.25 mm | **4.05 mm** | 3.2× |
%[text] | 2 m | 2.50 mm | **16.22 mm** | 6.5× |
%[text] | 5 m | 6.26 mm | **101.36 mm** | **16.2×** |
%[text:table]
%[text] > **我原本預期「近處基線主導」——在這個系統上是錯的。**
%[text] > 視差誤差在 0.5 公尺就已經比基線誤差大 1.6 倍，
%[text] > 而且差距隨距離拉開（5 公尺時 16 倍）。
%[text] > 原因是這組標定把基線估得**太準了**（0.125%），
%[text] > 0.5 像素的視差誤差相對之下大得多。
%[text] > **基線要估到多差，才會在近處主導？**
%[text] > 解 $Z \cdot \delta B / B = Z^2 \delta d /(fB)$ 得
%[text] > $\delta B = Z \delta d / f$，在 0.5 m 處是 **0.24 mm**——
%[text] > 也就是基線誤差要比現在大 1.6 倍才會平手。
%[text] > **所以正確的說法是：這個系統在整個工作距離內都是視差主導。**
%[text] **第 6 小題：5 公尺處要 1% 精度（50 mm）**
fprintf("\n5 公尺處要 1%%（50 mm）精度：\n");
Ztarget = 5000; target = 50;
needDisp = Ztarget^2 * 0.5 / (focalPx * target);
needBase = Ztarget^2 * 0.5 / (focalPx * target);
fprintf("  維持 0.5 px 視差精度，需要基線 %.0f mm（目前 %.0f mm，要 %.1f 倍）\n", ...
    needBase, baseline, needBase/baseline);
needAcc = Ztarget^2 * 0.5 / (focalPx * baseline) / target * 0.5;
fprintf("  維持目前基線，需要視差精度 %.3f px（目前假設 0.5 px）\n", ...
    target * focalPx * baseline / Ztarget^2);
%[text] **加長基線遠比提高視差精度容易。**
%[text] 0.5 像素已經是很好的次像素精度了（第 26 章會看到實際的視差圖有多雜），
%[text] 要再好一個數量級非常困難；把兩台相機拉開十倍則只是機構問題。
%[text] > **但基線不能無限加長**：基線越大，兩台相機的視野重疊越少，
%[text] > 而且對應點的比對越難（視角差異大）。
%[text] > 這是第 26 章立體視覺的核心取捨。
%%
%[text] # 解答 6　標定你自己的相機
%[text] 沒有標準答案，但**有一份該交出來的紀錄**。
%[text] 只寫「重投影誤差 0.18 像素」是不夠的——本章證明了它
%[text] **看不到畸變模型是否可信（§4）、看不到張數夠不夠（§7）、
%[text] 看不到方格邊長給錯（練習 3）、看不到刪錯影像（練習 4）**。
%[text:table]
%[text] | 該記錄的數字 | 為什麼 | 出處 |
%[text] | --- | --- | --- |
%[text] | 平均重投影誤差 | 角點擬合品質 | §2 |
%[text] | **逐張重投影誤差** | 找出該重拍的角度 | §2 |
%[text] | **角點覆蓋率（凸包% 與半徑%）** | 邊角外插的風險 | 練習 1 |
%[text] | **參數的留一法標準差** | 張數夠不夠 | 練習 2 |
%[text] | **彎曲改善%** | 畸變到底修掉多少 | §5 |
%[text] | **一個已知長度的量測結果** | 唯一能抓單位錯誤的檢查 | 練習 3 |
%[text] | 偵測成功張數 / 提供張數 | `imagesUsed` | §2 |
%[text] | 偵測到的點數 == 預期點數 | 遮擋時的安靜失敗 | §9 |
%[text:table]
%%
%[text] # 加分題解答　會擋住錯誤的守門函式
report = validateCalibration(monoPts, monoBoard, monoWorld, monoSize, "mono");
disp(report)

fprintf("\n=== 三個資料集 ===\n");
for s = ["gopro" "slr"]
    f = dir(fullfile(calRoot, s, "*.jpg"));
    names = string(fullfile({f.folder}, {f.name}));
    [pts, bs] = detectCheckerboardPoints(names);
    img = imread(names(1));
    sz = [size(img,1) size(img,2)];
    wp = generateCheckerboardPoints(bs, 25);
    r = validateCalibration(pts, bs, wp, sz, s);
    fprintf("  %-6s 通過 %d/%d 項", s, nnz(r.Pass), height(r));
    failed = r.Check(~r.Pass);
    if ~isempty(failed)
        fprintf("，未通過：%s", strjoin(failed, "、"));
    end
    fprintf("\n");
end
%[text] ## 量到的結果
%[text:table]
%[text] | 資料集 | 通過 | 未通過的項目 |
%[text] | --- | --- | --- |
%[text] | **mono** | **4/6** | **凸包覆蓋率**、**半徑覆蓋率** |
%[text] | gopro | **5/6** | 半徑覆蓋率 |
%[text] | slr | 3/6 | 影像張數、半徑覆蓋率、主點偏移 |
%[text:table]
%[text] **`mono` 只通過 4/6**，凸包覆蓋率 7.6%、半徑覆蓋率 39.2%。
%[text] 而它的重投影誤差（0.1851）是四個資料集裡**最好**的。
%[text] （R2026a 只偵測到 9 張，「影像張數」那一項也不通過，是 3/6。）
%[text] > **這正是這個守門函式存在的理由：
%[text] > 最好看的那個數字，來自覆蓋率最差的那組資料。**
%[text] **第 4 小題：這個函式抓不到什麼**（誠實列出）
%[text:table]
%[text] | 抓不到 | 為什麼 |
%[text] | --- | --- |
%[text] | **方格邊長給錯** | 練習 3 證明內參與誤差完全不變 |
%[text] | 板子不平（紙沒貼硬板） | 會被吸收進畸變係數，誤差可能還變小 |
%[text] | 所有影像都從同一個角度拍 | 覆蓋率可能很好，但焦距與距離不可分 |
%[text] | 鏡頭在標定後被動過（變焦、對焦） | 標定當下的檢查看不到未來 |
%[text:table]
%[text] 前兩項**只能靠外部資訊**：量一個已知長度、用硬板子。
%[text] 第三項可以加一個「外參旋轉角度的分散度」檢查——留給讀者。
%[text] **第 5 小題：「主點離中心太遠」的門檻**
%[text] 本章量到 `mono` 的主點離中心 32 像素（影像寬 1072，約 3.0%）。
%[text] 常見的門檻是**影像寬度的 5%**。
%[text] **但它確實可能誤殺**：感光元件和鏡頭的裝配公差本來就存在，
%[text] 有些工業相機的主點偏移就是比較大。
%[text] > **所以這一項應該是「警告」而不是「失敗」**——
%[text] > 它要你去看一眼，不是要你重做。
%[text] > 守門函式的分級（fail / warn / info）比單純的 pass/fail 有用得多。

% ========================================================================
% 本解答用到的本地函式

function [hullPct, maxRadius, diagRadius] = localCoverage(fileNames)
%LOCALCOVERAGE 所有標定角點的凸包面積佔比，以及最大半徑。
[pts, ~] = detectCheckerboardPoints(fileNames);
img = imread(fileNames(1));
imageSize = [size(img,1) size(img,2)];

P = reshape(permute(pts, [1 3 2]), [], 2);
P = P(all(isfinite(P), 2), :);

k = convhull(P(:,1), P(:,2));
hullPct = polyarea(P(k,1), P(k,2)) / prod(imageSize) * 100;

center     = imageSize([2 1]) / 2;
maxRadius  = max(vecnorm(P - center, 2, 2));
diagRadius = norm(center);
end

% ------------------------------------------------------------------------
function improvement = localBowImprovement(imagePoints, boardSize, intrinsics)
%LOCALBOWIMPROVEMENT 一張影像上、所有「欄」的平均相對彎曲度改善（%）。
nRows = boardSize(1) - 1;
nCols = boardSize(2) - 1;
before = zeros(1, nCols);
after  = zeros(1, nCols);
for c = 1:nCols
    idx = (c-1)*nRows + (1:nRows);
    L = imagePoints(idx, :);
    before(c) = localBow(L);
    after(c)  = localBow(undistortPoints(L, intrinsics));
end
improvement = (1 - mean(after)/mean(before)) * 100;
end

% ------------------------------------------------------------------------
function b = localBow(points)
P = double(points);
Q = P - mean(P, 1);
[~, ~, V] = svd(Q, 0);
b = max(abs(Q * V(:,2))) / (max(Q * V(:,1)) - min(Q * V(:,1))) * 100;
end

% ------------------------------------------------------------------------
function report = validateCalibration(imagePoints, boardSize, worldPoints, imageSize, name)
%VALIDATECALIBRATION 標定結果的六項守門檢查。
%   回傳 table，每一列一項檢查：Check、Value、Threshold、Pass、Note。
%
%   **設計原則**：每一項都對應本章量到的一個具體失敗，
%   不是憑印象列的檢查清單。

params = estimateCameraParameters(imagePoints, worldPoints, ImageSize=imageSize);

Check     = strings(0,1);
Value     = strings(0,1);
Threshold = strings(0,1);
Pass      = false(0,1);
Note      = strings(0,1);

    function add(c, v, t, p, n)
        Check(end+1,1)     = c;  %#ok<AGROW>
        Value(end+1,1)     = v;  %#ok<AGROW>
        Threshold(end+1,1) = t;  %#ok<AGROW>
        Pass(end+1,1)      = p;  %#ok<AGROW>
        Note(end+1,1)      = n;  %#ok<AGROW>
    end

% ① 點數
expected = prod(boardSize - 1);
actual   = size(imagePoints, 1);
add("點數正確", string(actual), string(expected), actual == expected, ...
    "§9：遮擋時棋盤格會回傳 63 個點還「成功」");

% ② 影像數
nImg = size(imagePoints, 3);
add("影像張數", string(nImg), ">= 10", nImg >= 10, ...
    "§7：少於 10 張時參數還在漂");

% ③ 覆蓋率（凸包）
P = reshape(permute(imagePoints, [1 3 2]), [], 2);
P = P(all(isfinite(P), 2), :);
k = convhull(P(:,1), P(:,2));
hullPct = polyarea(P(k,1), P(k,2)) / prod(imageSize) * 100;
add("凸包覆蓋率", sprintf("%.1f%%", hullPct), ">= 30%", hullPct >= 30, ...
    "練習 1：mono 只有 7.6%，邊角完全靠外插");

% ④ 半徑覆蓋
radius    = max(vecnorm(P - imageSize([2 1])/2, 2, 2));
radiusPct = radius / norm(imageSize([2 1])/2) * 100;
add("半徑覆蓋率", sprintf("%.1f%%", radiusPct), ">= 70%", radiusPct >= 70, ...
    "§4：資料邊界之外的去畸變差異可達 225 px");

% ⑤ 離群影像
perImage = squeeze(mean(vecnorm(params.ReprojectionErrors, 2, 2), 1));
zScore   = (max(perImage) - median(perImage)) / max(std(perImage), eps);
add("無離群影像", sprintf("z = %.2f", zScore), "< 3", zScore < 3, ...
    "§2：平均值會把一張爛影像藏起來");

% ⑥ 主點位置（**警告級，不是失敗級**）
offset    = norm(params.Intrinsics.PrincipalPoint - imageSize([2 1])/2);
offsetPct = offset / imageSize(2) * 100;
add("主點偏移", sprintf("%.1f%% (%.0f px)", offsetPct, offset), "< 5%", ...
    offsetPct < 5, "警告級：工業相機本來就可能偏心");

report = table(Check, Value, Threshold, Pass, Note);
report.Properties.Description = name;
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
