%[text] # 第 24 章　練習解答
%[text] {"align":"left"}物件追蹤與運動估計　｜　MATLAB R2026b
%[text] > **本章的練習 2 推翻了主教材 §4 的結論，練習 3 找到了一個
%[text] > 比「追丟」危險得多的失敗。** 兩個推翻都完整留在下面。
assert(exist("ch24_kalmanTrack", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

det = ch23_ballSegmentVideo("singleball.mp4");
vBall = VideoReader("singleball.mp4");
%%
%[text] # 解答 1　等速假設的事前診斷
seg1 = find(det.Found & det.Frame <= 26);
seg2 = find(det.Found & det.Frame >= 34);
d1 = diff(det.X(seg1));
d2 = diff(det.X(seg2));

fprintf("可見段 1（幀 13–26）每幀位移：\n  %s\n", mat2str(round(d1',2)));
fprintf("可見段 2（幀 34–42）每幀位移：\n  %s\n", mat2str(round(d2',2)));

[ok1, p1, slope1] = isConstantVelocity(d1);
[ok2, p2, slope2] = isConstantVelocity(d2);
fprintf("\n段 1：斜率 %.4f px/幀²，p = %.4f，等速假設成立？%s\n", slope1, p1, string(ok1));
fprintf("段 2：斜率 %.4f px/幀²，p = %.4f，等速假設成立？%s\n", slope2, p2, string(ok2));
fprintf("段 1 平均速度 %.2f、段 2 平均 %.2f，比值 %.2f\n", ...
    mean(d1), mean(d2), mean(d1)/mean(d2));

figure;
plot(det.Frame(seg1(2:end)), d1, "o-", LineWidth=1.5, DisplayName="段 1（13–26）"); hold on
plot(det.Frame(seg2(2:end)), d2, "s-", LineWidth=1.5, DisplayName="段 2（34–42）");
yline(mean(d1), "--", "段1平均"); yline(mean(d2), "--", "段2平均");
grid on; legend(Location="northeast");
xlabel("幀"); ylabel("每幀位移（像素）"); title("等速假設在遮擋之前就破了")
%[text] ## 量到的結果
%[text:table]
%[text] | 段 | 位移序列 | 線性斜率 | 平均 |
%[text] | --- | --- | --- | --- |
%[text] | 13–26 | 25.9 → 16.3 **單調下降** | **−0.80 px/幀²** | 21.38 |
%[text] | 34–42 | 11.8 → 6.0 起伏下降 | −0.32 px/幀² | 9.86 |
%[text:table]
%[text] **第 2、3 小題：等速假設從頭到尾都不成立。**
%[text] 段 1 的 13 個位移**幾乎單調遞減**，線性斜率 −0.80 px/幀²。
%[text] 那不是雜訊，是實實在在的減速。
%[text] **第 5 小題：只看第一段就足以否決等速模型。**
%[text] 而且事後看來這個建議是對的——主教材 §4 量到
%[text] `ConstantAcceleration` 在那段 7 幀盲飛上好 10.7 倍。
%[text] > **這是本章的第一個方法論重點：
%[text] > 模型假設可以在失敗之前就用手上的資料檢驗。**
%[text] > 你不需要等到遮擋發生、不需要真值、不需要調參數——
%[text] > 只要對已經量到的位置做一次差分。
%[text] > 這和第 23 章「先量再改」、第 22 章「先看分數分布」是同一種紀律。
%[text] **注意自由度**：段 2 只有 8 個位移值、7 個自由度，
%[text] 臨界 t 是 2.36 而不是 1.96。`isConstantVelocity` 用 `tinv` 現算，
%[text] 不用大樣本的直覺值——第 18 章練習 2 踩過這個坑。
%%
%[text] # 解答 2　盲飛多久之後，高階模型會反過來害你
%[text] ## 我的預期
%[text] 「`ConstantAcceleration` 一直比較好，差距可能隨盲飛拉長而擴大。」
%[text] **完全錯了。**
blindLengths = 1:6;
errCV = zeros(numel(blindLengths),1);
errCA = zeros(numel(blindLengths),1);

for i = 1:numel(blindLengths)
    L = blindLengths(i);
    d = det;
    blind = (21-L):20;                 % 在可見段內挖洞，第 21 幀重逢
    d.Found(blind) = false;
    d.X(blind) = NaN;
    d.Y(blind) = NaN;
    [~, iCV] = ch24_kalmanTrack(d, MotionModel="ConstantVelocity");
    [~, iCA] = ch24_kalmanTrack(d, MotionModel="ConstantAcceleration");
    errCV(i) = iCV.RejoinError;
    errCA(i) = iCA.RejoinError;
end
disp(table(blindLengths', errCV, errCA, errCV./errCA, ...
    VariableNames=["盲飛幀數" "CV誤差" "CA誤差" "CV/CA"]))

figure;
semilogy(blindLengths, errCV, "o-", LineWidth=1.5, DisplayName="ConstantVelocity"); hold on
semilogy(blindLengths, errCA, "s-", LineWidth=1.5, DisplayName="ConstantAcceleration");
grid on; legend(Location="northwest");
xlabel("盲飛幀數"); ylabel("重逢誤差（像素，對數軸）");
title("高階模型在長盲飛時會爆炸")
%[text] ## 量到的結果
%[text:table]
%[text] | 盲飛幀數 | CV 誤差 | CA 誤差 | 誰贏 |
%[text] | --- | --- | --- | --- |
%[text] | 1 | 5.08 | **3.72** | CA |
%[text] | 2 | 9.69 | **6.95** | CA |
%[text] | 3 | **13.07** | 25.42 | **CV** |
%[text] | 4 | **19.52** | 66.46 | CV |
%[text] | 5 | **36.08** | **255.32** | CV（**CA 爆炸**） |
%[text] | 6 | **69.85** | 106.08 | CV |
%[text:table]
%[text] **交叉點在第 2 到第 3 幀之間。** 之後 `ConstantAcceleration`
%[text] 不只輸，而是**輸到離譜**——盲飛 5 幀時誤差 255 像素，
%[text] 而整張影像只有 480 像素寬。
%[text] **第 4 小題：兩個模型的外插誤差怎麼長**
%[text] 等速模型的位置外插是 $x(t) = x_0 + v t$，
%[text] 速度估計的誤差 $\delta v$ 造成的位置誤差是 $\delta v \cdot t$——**線性成長**。
%[text] 等加速模型是 $x(t) = x_0 + v t + \tfrac{1}{2} a t^2$，
%[text] 加速度估計的誤差造成 $\tfrac{1}{2}\delta a \cdot t^2$——**二次成長**。
%[text] 而且**加速度比速度難估得多**：它是位置的二階差分，
%[text] 雜訊被放大兩次。
%[text] > **這是偏差—變異權衡的一個具體實例。**
%[text] > 高階模型偏差小（它描述得出減速），但變異大（參數難估）。
%[text] > **短外插時偏差主導，高階贏；長外插時變異主導，低階贏。**
%[text] **第 5 小題：修正主教材 §4 的說法。**
%[text:table]
%[text] | 原文 | 問題 |
%[text] | --- | --- |
%[text] | 「換模型好 10.7 倍」 | 沒有說在什麼盲飛長度、什麼資料量下 |
%[text:table]
%[text] 更準確的版本：
%[text] > **在有足夠的可見資料把加速度估準的前提下**（主教材那段盲飛
%[text] > 前面有 14 幀連續可見），**而且盲飛長度不過分**時，
%[text] > 等加速模型明顯較好（31.65 → 2.95）。
%[text] > **但加速度估得不準時，它的誤差以 $t^2$ 成長，
%[text] > 盲飛 5 幀就可能比等速模型差 7 倍。**
%[text] **第 6 小題：為什麼主教材那段 CA 反而贏？**
fprintf("主教材的盲飛（幀 27–33）前面有 %d 幀連續可見資料\n", numel(seg1));
fprintf("本題的盲飛（幀 15–20）前面只有 %d 幀\n", numel(find(det.Found & det.Frame < 15)));
%[text] **14 幀 vs 2 幀。** 加速度估計的品質完全不同。
%[text] > **同一個模型，在同一支影片上，可以是最好的也可以是最差的——
%[text] > 差別在於它拿到多少資料。** 報告一個模型比較好的時候，
%[text] > 必須連同「在什麼條件下」一起報告。
%%
%[text] # 解答 3　比「追丟」更危險的失敗
%[text] 先加上官方範例的重新偵測機制：
k0 = 16;
frame0 = read(vBall, k0);
bbox0 = round([max(1, det.X(k0)-14) max(1, det.Y(k0)-14) 28 28]);
corners0 = detectMinEigenFeatures(rgb2gray(frame0), ROI=bbox0);

nFrames = height(det);
Frame     = (k0+1:nFrames)';
NumValid  = zeros(numel(Frame),1);
Redetect  = false(numel(Frame),1);
KltX      = nan(numel(Frame),1);
KltY      = nan(numel(Frame),1);
TrueX     = det.X(Frame);
TrueY     = det.Y(Frame);

tracker = vision.PointTracker(MaxBidirectionalError=2, NumPyramidLevels=3);
initialize(tracker, corners0.Location, frame0);
for i = 1:numel(Frame)
    k = Frame(i);
    f = read(vBall, k);
    [loc, valid] = tracker(f);

    if nnz(valid) < 4 && det.Found(k)
        bb = round([max(1, det.X(k)-14) max(1, det.Y(k)-14) 28 28]);
        bb(3) = min(bb(3), size(f,2)-bb(1));
        bb(4) = min(bb(4), size(f,1)-bb(2));
        np = detectMinEigenFeatures(rgb2gray(f), ROI=bb);
        if np.Count > 0
            setPoints(tracker, np.Location);
            loc   = np.Location;
            valid = true(np.Count, 1);
            Redetect(i) = true;
        end
    end

    NumValid(i) = nnz(valid);
    if any(valid)
        c = mean(loc(valid,:), 1);
        KltX(i) = c(1);
        KltY(i) = c(2);
    end
end
release(tracker);

Error = vecnorm([KltX KltY] - [TrueX TrueY], 2, 2);
result3 = table(Frame, NumValid, Redetect, KltX, KltY, TrueX, Error);
fprintf("有有效點的幀數：%d / %d（沒有重新偵測時是 9 / 29）\n", ...
    nnz(NumValid > 0), numel(Frame));
disp(result3([8:12 18:22 26],:))
%[text] ## 量到的結果——**「修好了」是假象**
%[text] **第 2 小題**：有點的幀數從 **9/29 變成 29/29**。看起來完美。
%[text] **第 3–5 小題：檢查它追的是什麼。**
%[text:table]
%[text] | 幀 | 有效點 | KLT 質心 | 真實球位置 | 誤差 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 24 | 9 | (252.2, 251.0) | (251.2, 249.2) | 2.1 |
%[text] | 26 | 5（**重新偵測**） | (289.1, 247.3) | (285.7, 247.6) | 3.5 |
%[text] | 27 | **5** | **(289.4, 247.0)** | 遮擋 | — |
%[text] | 33 | **5** | **(289.4, 247.0)** | 遮擋 | — |
%[text] | 34 | **5** | **(289.4, 247.0)** | (399.1, 245.4) | **109.7** |
%[text] | 42 | **5** | **(289.4, 247.0)** | (478.0, 249.0) | **188.6** |
%[text:table]
%[text] > ## **它從第 27 幀之後就一動也不動了。**
%[text] > 重新偵測在第 26 幀抓到的 5 個點，是球即將消失時
%[text] > **ROI 裡的背景紋理**。球被遮住之後，那些點繼續
%[text] > 穩穩地追著背景——**位置完全正確，因為背景本來就不動。**
%[text] **而 `nValid` 一路回報 5。** 雙向誤差檢查（`MaxBidirectionalError=2`）
%[text] 也完全滿意——因為那些點**真的**被正確地追蹤著，
%[text] 只是它們追的不是球。
%[text] 球跑到 x = 478 時，KLT 還在 x = 289，**誤差 188.6 像素**，
%[text] 而追蹤器的每一個內部指標都顯示「一切正常」。
%[text] **第 6 小題：Kalman 和 KLT 在這件事上的關鍵差別**
%[text:table]
%[text] | | Kalman | KLT |
%[text] | --- | --- | --- |
%[text] | 沒有量測時 | 照樣輸出位置 | 照樣輸出位置 |
%[text] | **但它有沒有說？** | **有**：`Source = "predict"` | **沒有**：`nValid` 還是 5 |
%[text:table]
%[text] > **兩者都會在看不見物體時給你一個位置。
%[text] > 差別在於一個誠實標記了那是猜的，另一個沒有。**
%[text] > 這和第 22 章「PatchCore 被汙染時沒有任何警告」、
%[text] > 第 23 章「忘記縮 MinArea 得到 0 幀卻不報錯」是同一類問題：
%[text] > **沒有錯誤訊息的失敗最貴。**
%[text] **第 7 小題：該加什麼檢查**
%[text:table]
%[text] | 檢查 | 抓得到這次的失敗嗎 |
%[text] | --- | --- |
%[text] | 有效點數門檻 | ❌ 一直是 5 |
%[text] | 雙向誤差 | ❌ 背景點的雙向誤差很小 |
%[text] | **點群的位移量**（連續 N 幀幾乎不動） | ✅ **抓得到** |
%[text] | **和獨立偵測器的一致性** | ✅ **最可靠** |
%[text] | 點群的空間離散度突然改變 | ⚠ 部分有效 |
%[text:table]
%[text] > **最有效的檢查是「和一個獨立來源比對」。**
%[text] > 這正是追蹤要和偵測並用的理由——**單靠追蹤器自己的
%[text] > 內部指標，它永遠不會告訴你它跟丟了。**
%%
%[text] # 解答 4　在已知答案上驗證光流
imgFlow = repmat(imread("cameraman.tif"), 1, 1, 3);
inner = false(size(imgFlow,1), size(imgFlow,2));
inner(40:end-40, 40:end-40) = true;

gradMag = imgradient(rgb2gray(imgFlow));
maskHi  = inner & (gradMag > prctile(gradMag(inner), 90));
fprintf("高梯度遮罩：%d 像素（佔內部的 %.1f%%）\n", ...
    nnz(maskHi), nnz(maskHi)/nnz(inner)*100);

shifts  = [0.5 1 2 5 10 20]';
methods = ["opticalFlowLK" "opticalFlowHS" "opticalFlowFarneback" "opticalFlowLKDoG"];
estInner = zeros(numel(shifts), 4);
estHiGrad = zeros(numel(shifts), 4);

for i = 1:numel(shifts)
    shifted = imtranslate(imgFlow, [shifts(i) 0]);
    rInner = ch24_flowCompare(imgFlow, shifted, Mask=inner,  Quiet=true, Methods=methods);
    rHi    = ch24_flowCompare(imgFlow, shifted, Mask=maskHi, Quiet=true, Methods=methods);
    estInner(i,:)  = rInner.MedianSpeed';
    estHiGrad(i,:) = rHi.MedianSpeed';
end

fprintf("\n全部內部像素當遮罩（中位數速度）：\n");
disp(array2table(estInner, VariableNames=methods, RowNames="shift"+string(shifts)))
fprintf("只用高梯度像素（前 10%%）：\n");
disp(array2table(estHiGrad, VariableNames=methods, RowNames="shift"+string(shifts)))

figure;
plot(shifts, shifts, "k--", LineWidth=1.2, DisplayName="真值 y = x"); hold on
for m = 1:4
    plot(shifts, estHiGrad(:,m), "o-", LineWidth=1.4, DisplayName=methods(m));
end
grid on; legend(Location="northwest");
xlabel("真實位移（像素）"); ylabel("估計速度中位數（像素）");
title("只有 Farnebäck 在整個範圍內跟得上")
%[text] ## 量到的結果
%[text] **全部內部像素當遮罩：**
%[text:table]
%[text] | 真實位移 | LK | HS | Farnebäck | LKDoG |
%[text] | --- | --- | --- | --- | --- |
%[text] | 1.0 | **0.000** | 0.002 | 0.989 | **0.000** |
%[text] | 20.0 | **0.000** | 0.007 | 19.530 | **0.000** |
%[text:table]
%[text] **只用高梯度像素（前 10%）：**
%[text:table]
%[text] | 真實位移 | LK | HS | Farnebäck | LKDoG |
%[text] | --- | --- | --- | --- | --- |
%[text] | 0.5 | **0.598** | 0.126 | 0.508 | 0.000 |
%[text] | 1.0 | **0.920** | 0.239 | **1.000** | 0.000 |
%[text] | 2.0 | 0.906 | 0.155 | **2.000** | 0.000 |
%[text] | 5.0 | 0.457 | 0.078 | **5.000** | 0.000 |
%[text] | 10.0 | 0.262 | 0.050 | **10.000** | 0.000 |
%[text] | 20.0 | **0.005** | 0.033 | **20.000** | 0.000 |
%[text:table]
%[text] **第 3、4 小題：換一個遮罩，LK 從「完全失效」變成「在 1 像素附近很準」。**
fprintf("\nLK 的非零像素比例（內部區域）：\n");
for s = [1 5 20]
    shifted = imtranslate(imgFlow, [s 0]);
    of = opticalFlowLK;
    estimateFlow(of, rgb2gray(imgFlow));
    fl = estimateFlow(of, rgb2gray(shifted));
    M = fl.Magnitude(inner);
    fprintf("  位移 %4.1f：非零 %.1f%%，非零者中位數 %.3f\n", ...
        s, nnz(M > 1e-6)/numel(M)*100, median(M(M > 1e-6)));
end
%[text] **LK 只在約 33% 的像素上給出非零值**，其餘是 0。
%[text] 那不是「估成 0」，而是**孔徑問題**：
%[text] 平坦區域的結構張量奇異，解不出來，函式就回傳 0。
%[text] 拿全畫面取中位數，等於**用一大堆「沒有答案」把有答案的稀釋掉**。
%[text] > ## **這一題真正的教訓**
%[text] > **我第一次量的時候差點寫下「LK 在所有位移下都完全失效」。**
%[text] > 那個結論是**評估區域選錯**造成的，不是 LK 的性質。
%[text] > 這和第 13 章「評估區域跟著自變數變動 → 結論反向」
%[text] > 是完全一樣的錯誤。
%[text] > **量一個稀疏方法時，要在它有輸出的地方量。**
%[text] **第 5、6 小題：LK 的形狀**
%[text] LK 在 **1 像素附近最準**（0.920 / 1.0），然後**單調崩潰**：
%[text] 2 px → 0.906，5 px → 0.457，20 px → **0.005**。
%[text] 亮度恆定的一階泰勒展開
%[text] $$I_x u + I_y v + I_t = 0$$
%[text] 把 $I(x+u)$ 近似成 $I(x) + I_x u$。這個近似的誤差是 $O(u^2)$，
%[text] **只在 $u$ 小於影像結構的變化尺度時可用**——大約就是一個像素。
%[text] 位移一大，$I_t$ 對應到完全不同的結構，解出來的 $u$ 沒有意義。
%[text] **20 像素時 LK 給 0.005，等於在說「沒有東西在動」。**
%[text] Farnebäck 的金字塔把 20 像素的位移在最粗的一層變成 2.5 像素，
%[text] 線性化重新成立，再逐層細化回來——所以它在**每一個**位移上都命中。
%[text] **第 7 小題：這個測試對 LKDoG 公平嗎？不公平。**
%[text] `opticalFlowLKDoG` 用**時間方向的高斯導數**濾波，
%[text] 它預期的是一段**連續影格序列**，會累積好幾幀才給出穩定的估計。
%[text] 這裡只餵兩幀（而且是人工位移，沒有真實的時間連續性），
%[text] 它的時間濾波器根本沒有足夠的資料。
%[text] > **把一個方法放進它沒有被設計的場景，得到 0 分不是資訊。**
%[text] > 這和第 21 章「OpenAI 的樣板在手寫數字上最差」是同一件事：
%[text] > **要先問這個方法假設了什麼。**
%%
%[text] # 解答 5　`costOfNonAssignment` 的兩個懸崖
costs = [2 5 10 20 40 80 160 400]';
IDSw5    = zeros(numel(costs),1);
NTrack5  = zeros(numel(costs),1);
Cover5   = zeros(numel(costs),1);
Err5     = zeros(numel(costs),1);

for i = 1:numel(costs)
    sc = ch24_crossingScene(Scenario="meet", MissDistance=12);
    rr = ch24_multiTracker(sc.Frames, CostOfNonAssignment=costs(i));
    mm = ch24_trackMetrics(rr, sc.Truth);
    IDSw5(i)   = mm.IDSwitches;
    NTrack5(i) = mm.NumTracks;
    Cover5(i)  = mm.Coverage;
    Err5(i)    = mm.MeanError;
end
disp(table(costs, IDSw5, NTrack5, Cover5, Err5, ...
    VariableNames=["成本" "ID切換" "軌跡數" "覆蓋率" "誤差px"]))
%[text] ## 量到的結果
%[text:table]
%[text] | 成本 | ID 切換 | 軌跡數 | 覆蓋率 | 誤差 |
%[text] | --- | --- | --- | --- | --- |
%[text] | **2** | 0 | **1** | **0.138** | 9.08 |
%[text] | 5 | 3 | **5** | 0.900 | 2.14 |
%[text] | 10 | 3 | 3 | 0.875 | 1.85 |
%[text] | 20 – 400 | 3 | 3 | 0.875 | 1.85 |
%[text:table]
%[text] **第 2 小題：成本設成 2 時，ID 切換是 0——而那是個陷阱。**
%[text] 覆蓋率只有 **0.138**：追蹤器幾乎什麼都沒追到，
%[text] 只留下一條軌跡。**沒有軌跡就沒有 ID 可以切換。**
%[text] > **ID 切換是一個「越少越好」的指標，
%[text] > 但它可以用「什麼都不追」來作弊。**
%[text] > 這和第 20 章「全部猜背景」拿到高準確率、
%[text] > 第 22 章「分離度對樣本數敏感」是同一類問題：
%[text] > **單一指標都可以被退化解鑽漏洞，一定要配一個覆蓋率類的指標。**
%[text] **第 3 小題：從 20 之後飽和。** 因為場景裡兩個物體的最大間距
%[text] 遠小於 20 像素以上的成本門檻，**所有候選都在門檻內**，
%[text] 再放寬也不會改變匈牙利法挑出的最小成本解。
%[text] **第 4 小題：真實影片上的代理指標。**
vAtrium = VideoReader("atrium.mp4");
nAtrium = 200;
atriumFrames = cell(1, nAtrium);
for k = 1:nAtrium
    atriumFrames{k} = read(vAtrium, k);
end

costsReal = [5 20 50 100 200]';
NTrackR   = zeros(numel(costsReal),1);
MedLifeR  = zeros(numel(costsReal),1);
ShortR    = zeros(numel(costsReal),1);
for i = 1:numel(costsReal)
    [rr, ii] = ch24_multiTracker(atriumFrames, Detector="foreground", ...
        MinArea=300, CostOfNonAssignment=costsReal(i));
    ids  = unique(rr.TrackID);
    life = arrayfun(@(id) nnz(rr.TrackID == id), ids);
    NTrackR(i)  = ii.NumTracks;
    MedLifeR(i) = median(life);
    ShortR(i)   = nnz(life < 5);
end
disp(table(costsReal, NTrackR, MedLifeR, ShortR, ...
    VariableNames=["成本" "軌跡數" "壽命中位數" "短命軌跡數"]))
%[text:table]
%[text] | 成本 | 軌跡數 | 壽命中位數 | 短命（<5 幀） |
%[text] | --- | --- | --- | --- |
%[text] | 5 | **5** | **40** | 0 |
%[text] | 20 – 200 | 3 | **81** | 0 |
%[text:table]
%[text] **三個代理指標，以及它們各自會怎麼騙你：**
%[text:table]
%[text] | 代理指標 | 想抓什麼 | **什麼時候會誤導** |
%[text] | --- | --- | --- |
%[text] | **軌跡數 vs 目視物體數** | 過度切割 | 物體數本身要人工數；**真的有很多人時，多軌跡是對的** |
%[text] | **軌跡壽命中位數** | 片段化 | 物體本來就只在畫面裡待兩秒時，短壽命是正確的 |
%[text] | **短命軌跡比例** | 雜訊偵測 | **參數調到不產生新軌跡時，這個指標會變成 0 而看起來完美** |
%[text:table]
%[text] 第三個和「成本 = 2」的陷阱是同一回事：
%[text] **代理指標幾乎都可以用「少做事」來優化。**
%[text] 所以至少要配一個「有做事」的指標（覆蓋率、總軌跡長度）。
%[text] **第 6 小題：單位是像素。** 解析度加倍時所有距離都加倍，
%[text] **這個參數必須跟著加倍**，否則等效門檻縮小一半。
%[text] > 更穩健的做法是用**物體尺寸**來定義，
%[text] > 例如 `CostOfNonAssignment = 2 * 物體的等效直徑`，
%[text] > 這樣換解析度、換鏡頭都不必重調。
%%
%[text] # 解答 6　把 DeepSORT 缺的那一半補上
%[text] **第 1 小題：時機不同，這是關鍵。**
%[text:table]
%[text] | | 成本矩陣裡的外觀項 | **特徵庫重認** |
%[text] | --- | --- | --- |
%[text] | 什麼時候用 | **每一幀**，對**還活著**的軌跡 | **要開新軌跡時**，對**已刪除**的軌跡 |
%[text] | 解決什麼 | 同一幀內誰配誰 | **跨越長時間中斷的身分延續** |
%[text] | 主教材 §10 證明它對合併區塊 | **沒用** | 不適用（那不是它的問題） |
%[text:table]
%[text] 下面是特徵庫的核心邏輯（完整整合留給讀者）：
galleryFeats = zeros(0, 24, "single");
galleryIds   = zeros(0, 1);

sceneA = ch24_crossingScene(MissDistance=30);
[trkA, ~] = ch24_multiTracker(sceneA.Frames);
fprintf("示範：軌跡 %d 條\n", numel(unique(trkA.TrackID)));

% 用未訓練 ReID 的相似度分布說明門檻為什麼危險
reidNet = ch24_reidSketch("build");
probeNames = ["peppers.png" "football.jpg" "coins.png" "onion.png"];
probeImgs  = cell(1, numel(probeNames));
for i = 1:numel(probeNames)
    I = imread(probeNames(i));
    if size(I,3) == 1, I = repmat(I,1,1,3); end
    probeImgs{i} = imresize(I, [128 64]);
end
reidFeats = ch24_reidSketch("extract", reidNet, probeImgs);
simsOff = reidFeats * reidFeats';
simsOff = simsOff(~eye(numel(probeNames)));
fprintf("未訓練 ReID：四張不相干影像的相似度 %.4f – %.4f（全距 %.4f）\n", ...
    min(simsOff), max(simsOff), max(simsOff)-min(simsOff));
%[text] **第 5 小題：門檻在這裡為什麼特別危險。**
%[text] 未訓練的 ReID 把完全不相干的影像評在 **0.996–0.999**。
%[text:table]
%[text] | 門檻 | 後果 |
%[text] | --- | --- |
%[text] | 0.3 – 0.99 | **所有東西都配得上所有東西**——每個新物體都被認成舊身分 |
%[text] | 0.995 | 勉強能分，但**落在雜訊裡**，換一批資料就失效 |
%[text] | > 0.999 | 什麼都配不上，等於沒有特徵庫 |
%[text:table]
%[text] > **沒有可用門檻的區間。** 這不是門檻難調，
%[text] > 是**嵌入本身沒有攜帶身分資訊**。
%[text] > 第 21 章練習 3 量過同樣的事：CLIP 校準出來的門檻轉移不過去
%[text] >（0.875 → 0.500），因為相似度的尺度本身不穩定。
%[text] **先訓練 ReID，再談門檻。順序不能反。**
%[text] **第 6 小題：特徵庫要留多久？**
%[text:table]
%[text] | 策略 | 問題 |
%[text] | --- | --- |
%[text] | 永遠留著 | 記憶體無上限成長；**而且人會換衣服、換光線** |
%[text] | 固定時間窗（如 30 秒） | 簡單有效，是 DeepSORT 的做法 |
%[text] | 固定數量上限（LRU） | 適合物體流量穩定的場景 |
%[text:table]
%[text] 真正的 DeepSORT 對**每一條軌跡**保留最近 100 幀的特徵，
%[text] 比對時取**最小距離**而不是平均——因為外觀會隨時間漂移，
%[text] 平均會把舊的和新的混成一個都不像的東西。
%%
%[text] # 加分題解答　在真實影片上，你其實量不到 ID 切換
[trkReal, infoReal] = ch24_multiTracker(atriumFrames, ...
    Detector="foreground", MinArea=300);
idsReal  = unique(trkReal.TrackID);
lifeReal = arrayfun(@(id) nnz(trkReal.TrackID == id), idsReal);

fprintf("atrium.mp4 前 %d 幀：\n", nAtrium);
fprintf("  平均每幀偵測 %.2f 個物體\n", infoReal.MeanDetections);
fprintf("  產生 %d 條軌跡\n", numel(idsReal));
fprintf("  壽命：中位數 %d 幀、最長 %d 幀、最短 %d 幀\n", ...
    median(lifeReal), max(lifeReal), min(lifeReal));
fprintf("  活不到 5 幀的：%d 條（%.0f%%）\n", ...
    nnz(lifeReal < 5), nnz(lifeReal < 5)/numel(lifeReal)*100);

figure;
showFrames = [60 110 160];
tiledlayout(1, numel(showFrames), TileSpacing="compact");
for i = 1:numel(showFrames)
    k = showFrames(i);
    rows = trkReal(trkReal.Frame == k, :);
    img = atriumFrames{k};
    for r = 1:height(rows)
        img = insertShape(img, "filled-circle", [rows.X(r) rows.Y(r) 8], ...
            Color="yellow", Opacity=0.8);
        img = insertText(img, [rows.X(r)+10 rows.Y(r)-10], ...
            "ID " + string(rows.TrackID(r)), BoxColor="black", ...
            TextColor="white", FontSize=12);
    end
    nexttile; imshow(img); title("幀 " + k)
end
%[text] ## 量到的結果
%[text:table]
%[text] | 項目 | 值 |
%[text] | --- | --- |
%[text] | 平均每幀偵測 | 1.33 個 |
%[text] | 軌跡數 | **3** |
%[text] | 壽命中位數 | **81 幀** |
%[text] | 活不到 5 幀 | **0 條** |
%[text:table]
%[text] 看起來很健康。**但這些數字全都不能證明身分是對的。**
%[text] **第 3 小題：三個代理指標與它們的盲點**（解答 5 已列出兩個，補第三個）
%[text:table]
%[text] | 代理指標 | 盲點 |
%[text] | --- | --- |
%[text] | 軌跡數 vs 目視物體數 | 需要人工數；一次 ID 切換**不會改變軌跡總數** |
%[text] | 壽命中位數 | **兩條軌跡互換身分後，壽命完全不變** |
%[text] | 短命軌跡比例 | 可用「少開軌跡」作弊 |
%[text:table]
%[text] > **注意第二列。** 這正是主教材 §9 的重點：
%[text] > **ID 切換在所有「不看身分」的指標上都是隱形的。**
%[text] > 三個代理指標加起來，仍然抓不到本章最在意的那個失敗。
%[text] **第 5 小題：要真的量，需要什麼。**
%[text] 每一幀、每一個物體的**外框 + 身分編號**。
%[text] 200 幀 × 平均 1.33 個物體 ≈ **266 個標註**。
%[text] 用 Video Labeler 加上內插，熟手大約 **1–2 小時**；
%[text] 而 `atrium.mp4` 全片 600 幀就要三倍。
%[text] > 一支 10 分鐘、每幀 10 個人的產線影片是
%[text] > **18000 幀 × 10 = 18 萬個標註**。
%[text] > **這就是為什麼 MOT 的公開資料集只有那麼幾個。**
%[text] **第 6 小題：合成資料能外推什麼、不能外推什麼。**
%[text:table]
%[text] | 可以外推 | 不能外推 |
%[text] | --- | --- |
%[text] | **機制**：兩個物體被偵測成一個區塊時，關聯階段無解 | **數值**：ID 切換 3 次和 atrium 上會有幾次無關 |
%[text] | **優先順序**：先修偵測再調追蹤 | **參數**：合成場景的最佳 `CostOfNonAssignment` |
%[text] | **指標的性質**：ID 切換在位置誤差上隱形、可被退化解作弊 | **難度**：真實場景還有形變、光影、陰影被當成前景 |
%[text:table]
%[text] > **合成資料回答的是「為什麼」，不是「多少」。**
%[text] > 這和第 22 章用合成瑕疵示範 PatchCore 的流程、
%[text] > 但明說分數沒有參考價值，是同一個立場。

% ========================================================================
% 本解答用到的本地函式

function [isConst, pValue, slope] = isConstantVelocity(displacements, alpha)
%ISCONSTANTVELOCITY 用 t 檢定判斷每幀位移的線性趨勢是否顯著不為 0。
%
%   等速運動要求每幀位移是常數，也就是「位移對時間的迴歸斜率 = 0」。
%   **臨界值用 tinv 現算**：樣本很小的時候，大樣本的 1.96 完全不適用。
if nargin < 2
    alpha = 0.05;
end
n = numel(displacements);
if n < 3
    isConst = true; pValue = NaN; slope = NaN;
    return
end

t = (1:n)';
y = displacements(:);
X = [ones(n,1) t];
beta = X \ y;
slope = beta(2);

resid = y - X*beta;
df    = n - 2;
s2    = sum(resid.^2) / df;
covB  = s2 * inv(X'*X); %#ok<MINV>
se    = sqrt(covB(2,2));

tStat  = slope / se;
pValue = 2 * (1 - tcdf(abs(tStat), df));
isConst = pValue >= alpha;
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
