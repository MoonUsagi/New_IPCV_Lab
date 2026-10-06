%[text] # 第 13 章　影像修復、合成與資料擴增
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：2 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 產生修復用的遮罩（程式、互動式 ROI、R2026a 的 `uipaint` 筆刷）
%[text] 2. 用**有正確答案**的方式評估三種修復方法，並說出為什麼單一指標會誤導
%[text] 3. 選擇 `imblend` 的混合模式，並說出 Poisson 混合的**代價**
%[text] 4. 用 R2025a 的 `insertObjectInImage` 產生**自動標註**的合成訓練資料
%[text] 5. 用 `objectInsertionDatastore` 把合成流程規模化
%[text] 6. 判斷重疊限制該設多少，並理解它與資料量的取捨 \
%[text] ## 前置知識
%[text] 第 06 章（形態學與遮罩）、第 12 章（品質指標與它們的盲點）。
%[text] 本章大量沿用第 12 章的教訓，建議先完成。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="13");
hasInsert = exist("insertObjectInImage", "file") > 0;
hasPaint  = exist("uipaint", "file") > 0;
fprintf("\ninsertObjectInImage（AVI Library）：%s\n", statusText(hasInsert));
fprintf("uipaint（R2026a）：%s\n", statusText(hasPaint));
rng(0);
%%
%[text] # 1. 這一章的位置
%[text] 前面十二章都在**分析**既有影像。這一章開始**製造**影像：
%[text] - **修復**：把不該存在的東西移掉（刮痕、日期戳記、雜物）
%[text] - **合成**：把兩張影像接在一起，而且要看不出接縫
%[text] - **資料生成**：用合成的方式產生**帶標註**的訓練資料
%[text] 第三項是這一章最有價值的部分，也是 Part IV 深度學習的前置作業。
%[text] 標註是深度學習專案最大的成本；能自動產生標註的合成資料，
%[text] 可以把一個「要標一萬張」的專案變成「標一百張前景物件」。
%[text] **但合成資料有它自己的陷阱**，第 8–10 節會用實測數字說明。
%%
%[text] # 2. 遮罩從哪裡來
%[text] 修復與合成都需要遮罩。三種來源，各有適用場合。
%[text] **① 程式產生**——可重現，適合批次處理與教學
I = imread("peppers.png");

maskBox = false(size(I,1), size(I,2));
maskBox(120:209, 200:289) = true;

% 用幾何條件產生：例如「亮度低於門檻且在某區域內」
gray = im2gray(I);
maskAuto = gray < 60 & bwareafilt(gray < 60, [200 Inf]);

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(I);        title("原圖")
nexttile; imshow(maskBox);  title("手動指定方塊")
nexttile; imshow(maskAuto); title("由亮度條件自動產生")
fprintf("\n方塊遮罩 %d 像素、自動遮罩 %d 像素\n", nnz(maskBox), nnz(maskAuto));
%[text] **② 互動式 ROI**——`drawfreehand`、`drawassisted`、`drawellipse`、
%[text] `drawpolygon`，畫完用 `createMask` 轉成遮罩：
%[text] ```matlab
%[text] figure; imshow(I);
%[text] roi  = drawfreehand;          % 用滑鼠畫，畫完按 Enter
%[text] mask = createMask(roi);
%[text] ```
%[text] `drawassisted` 會**沿著邊緣自動吸附**，畫不規則物件比 freehand 精確得多。
%[text] **③ R2026a：`uipaint` 筆刷**
%[text] R2026a 新增 `uipaint`，提供真正的**筆刷式**塗抹介面
%[text] （可調筆刷大小、加/減模式），比逐點畫多邊形快很多：
%[text] ```matlab
%[text] figure; imshow(I);
%[text] p    = uipaint;               % 塗抹要修復的區域
%[text] mask = createMask(p);
%[text] ```
%[text] > 三種方式產生的遮罩**沒有本質差別**，都是 logical 矩陣。
%[text] > 差別只在**取得成本**與**可重現性**。
%[text] > 教材與自動化流程用程式產生；一次性的修圖用筆刷。
%%
%[text] # 3. 三種修復方法，用**正確答案**評估
%[text] 修復的教學常見問題是「看起來不錯」——那不是評估。
%[text] 這裡用一個能得到正確答案的做法：
%[text] **從完好的影像上挖一個洞，修復它，再與原圖比較。**
%[text] 原圖就是 ground truth。
methods13 = ["inpaintExemplar" "inpaintCoherent" "regionfill"];

Je = inpaintExemplar(I, maskBox);
Jc = inpaintCoherent(I, maskBox);
Jr = I;
for c = 1:3
    Jr(:,:,c) = regionfill(I(:,:,c), maskBox);
end

figure
tiledlayout(2,2, TileSpacing="compact")
nexttile; imshow(I);  title("原圖（正確答案）")
nexttile; imshow(Je); title("inpaintExemplar")
nexttile; imshow(Jc); title("inpaintCoherent")
nexttile; imshow(Jr); title("regionfill")
%%
%[text] ## 3.1 第一個陷阱：不要用整張影像算指標
%[text] 洞只占影像的一小部分。把沒被修改的區域一起納入統計，
%[text] 會把誤差**稀釋掉**——這正是第 12 章練習 1 的同一個問題。
fprintf("\n洞的大小：%d / %d 像素 = %.2f%%" + "\n", ...
    nnz(maskBox), numel(maskBox), 100*nnz(maskBox)/numel(maskBox));

fprintf("\n%-16s %14s %14s\n", "評估範圍", "PSNR", "SSIM");
fprintf("%-16s %14.3f %14.4f\n", "整張影像", ...
    psnr(Je, I), ssim(im2double(im2gray(Je)), im2double(im2gray(I))));
[psH, ssH] = ch13_holeMetrics(I, Je, maskBox);
fprintf("%-16s %14.3f %14.4f\n", "只看洞內", psH, ssH);
%[text] 實測（`inpaintExemplar`、洞占 **4.12%**）：
%[text:table]
%[text] | 評估範圍 | PSNR | SSIM |
%[text] | --- | --- | --- |
%[text] | 整張影像 | 26.832 dB | 0.9716 |
%[text] | **只看洞內** | **12.981 dB** | **0.3285** |
%[text:table]
%[text] 整張影像的 SSIM 0.9716 看起來「幾乎完美」，
%[text] 洞內的真實表現卻是 0.3285。
%[text] > **評估修復一定要限定在被修復的區域內。**
%[text] > 這與第 11 章「碰邊物件要排除」、第 12 章「局部破壞被平均稀釋」
%[text] > 是同一個原則：**統計範圍決定結論。**
%%
%[text] # 4. 三種方法的比較——以及為什麼要兩個指標
%[text] 先看 PSNR 與 SSIM 怎麼說。
[report, detail] = ch13_inpaintCompare(I, maskBox);
disp(report)
%[text] 實測結果（洞 90×90）：
%[text:table]
%[text] | 方法 | PSNR | SSIM | 秒數（機器相關） |
%[text] | --- | --- | --- | --- |
%[text] | `inpaintExemplar` | **12.981** | 0.3285 | ~0.20 |
%[text] | `inpaintCoherent` | 16.135 | **0.5593** | ~0.03 |
%[text] | **`regionfill`** | **16.503** | 0.5502 | ~0.05 |
%[text:table]
%[text] **最簡單的 `regionfill` 在 PSNR 上贏了兩個專門的修復演算法**，
%[text] 而且 `inpaintExemplar`（最複雜的那個）不但最差，還最慢。
%[text] 這個結論看起來很奇怪。**它是錯的**——但錯的不是數字，是指標。
%%
%[text] ## 4.1 加上紋理指標，排序完全改變
%[text] 第 12 章第 3 節證明過：**PSNR 偏好模糊。**
%[text] `regionfill` 解的是拉普拉斯方程，產生的是**平滑內插**——
%[text] 一塊糊掉的色斑。它的逐像素誤差小，但它**沒有紋理**。
%[text] 量化「有沒有紋理」：比較洞內的**平均梯度能量**與原圖同一塊的值。
fprintf("\n原圖洞內的梯度能量（正確答案）= %.5f\n\n", detail.ReferenceEnergy);
fprintf("%-18s %12s %12s %14s\n", "方法", "梯度能量", "能量比", "局部std比");
for k = 1:height(detail.Table)
    fprintf("%-18s %12.5f %12.3f %14.3f\n", ...
        detail.Table.Method(k), detail.Table.GradientEnergy(k), ...
        detail.Table.EnergyRatio(k), detail.Table.StdRatio(k));
end

figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
bar(categorical(detail.Table.Method), detail.Table.PSNR)
ylabel("洞內 PSNR (dB)"); title("PSNR：regionfill 最好"); grid on
nexttile
bar(categorical(detail.Table.Method), detail.Table.EnergyRatio)
yline(1, "--", "原圖的紋理量", LineWidth=1.5);
ylabel("梯度能量 / 原圖"); title("紋理量：regionfill 最差"); grid on
%[text] 實測（原圖洞內梯度能量 **0.21121**）：
%[text:table]
%[text] | 方法 | 梯度能量 | 能量比 | 局部 std 比 |
%[text] | --- | --- | --- | --- |
%[text] | `inpaintExemplar` | 0.28312 | **1.340** | 1.259 |
%[text] | **`inpaintCoherent`** | 0.16566 | **0.784** | 0.828 |
%[text] | `regionfill` | 0.06785 | **0.321** | 0.339 |
%[text:table]
%[text] **兩個指標的排序完全不同：**
%[text:table]
%[text] | | PSNR 最好 | 紋理最接近原圖 |
%[text] | --- | --- | --- |
%[text] | 第 1 名 | `regionfill` (16.503) | **`inpaintCoherent` (0.784)** |
%[text] | 第 2 名 | `inpaintCoherent` (16.135) | `inpaintExemplar` (1.340) |
%[text] | 第 3 名 | `inpaintExemplar` (12.981) | `regionfill` (0.321) |
%[text:table]
%[text] 三個方法各自的失效方式不一樣：
%[text] - **`regionfill` 紋理只有原圖的 32%**——它把洞填成一塊平滑色斑。
%[text]   逐像素誤差小（所以 PSNR 高），但**人眼一看就知道那裡被改過**。
%[text] - **`inpaintExemplar` 的紋理超出 34%**——它複製的補丁彼此接不齊，
%[text]   接縫本身產生了**假的**梯度。紋理「太多」也是錯的。
%[text] - **`inpaintCoherent` 是 0.784**，三者中最接近 1，
%[text]   而 PSNR 也只比第一名少 0.37 dB。
%[text] > **結論：`inpaintCoherent` 是這個案例上最好的選擇**——
%[text] > 但你只用 PSNR 是看不出來的，只用紋理指標也看不出來
%[text] > （那樣會選到 exemplar 或以為 regionfill 最差就好）。
%[text] > **必須同時看「像素對不對」與「紋理像不像」。**
%[text] 這是第 12 章「報告品質時永遠不要只報一個數字」在真實任務上的重演。
%%
%[text] # 5. 參數：預設值不一定是最好的
%[text] 兩個修復函式的參數行為差異很大，值得分開看。
fprintf("\n=== inpaintExemplar 的 PatchSize ===\n");
fprintf("%-12s %10s %10s %12s %10s\n", "PatchSize", "PSNR", "SSIM", "能量比", "秒數");
for psz = [5 9 15 21 31]
    t = tic; J = inpaintExemplar(I, maskBox, PatchSize=[psz psz]); tt = toc(t);
    [pp, ss] = ch13_holeMetrics(I, J, maskBox);
    er = ch13_gradEnergy(J, maskBox) / detail.ReferenceEnergy;
    fprintf("%-12d %10.3f %10.4f %12.3f %10.3f\n", psz, pp, ss, er, tt);
end

fprintf("\n=== inpaintExemplar 的 FillOrder ===\n");
for fo = ["gradient" "tensor"]
    J = inpaintExemplar(I, maskBox, FillOrder=fo);
    [pp, ss] = ch13_holeMetrics(I, J, maskBox);
    er = ch13_gradEnergy(J, maskBox) / detail.ReferenceEnergy;
    fprintf("  %-10s PSNR %.3f、SSIM %.4f、能量比 %.3f\n", fo, pp, ss, er);
end
%[text] **`PatchSize` 越小越好，而預設是 `[9 9]`：**
%[text:table]
%[text] | PatchSize | PSNR | SSIM | 能量比 |
%[text] | --- | --- | --- | --- |
%[text] | **5** | **14.598** | **0.4274** | 1.194 |
%[text] | 9（預設） | 12.981 | 0.3285 | 1.340 |
%[text] | 15 | 12.540 | 0.3424 | 1.324 |
%[text] | 21 | 12.277 | 0.2507 | 1.637 |
%[text] | 31 | 12.228 | 0.2378 | 1.503 |
%[text:table]
%[text] PSNR 從 5 到 31 單調下降，而且大補丁的紋理**超出得更多**
%[text] （能量比從 1.194 漲到 1.64）——補丁越大，接不齊的落差越明顯。
%[text] **`FillOrder` 的預設值是比較差的那一個：**
%[text:table]
%[text] | FillOrder | PSNR | SSIM | 能量比 |
%[text] | --- | --- | --- | --- |
%[text] | `"gradient"`（預設） | 12.981 | 0.3285 | 1.340 |
%[text] | **`"tensor"`** | **15.316** | **0.5079** | **0.843** |
%[text:table]
%[text] 換一個字串，PSNR 多 2.34 dB、SSIM 多 0.18、紋理比從 1.340 改善到 0.843。
%[text] > **預設值是為「大多數情況」選的，不是為你的情況選的。**
%[text] > 任何有 2–3 個離散選項的參數，都值得兩個都跑一次再決定。
%%
%[text] ## 5.1 對照：`inpaintCoherent` 的預設值幾乎是最佳的
fprintf("\n=== inpaintCoherent 的 SmoothingFactor x Radius ===\n");
fprintf("%-10s %-8s %10s %10s %10s\n", "Smooth", "Radius", "PSNR", "SSIM", "能量比");
best = -Inf; bestCfg = "";
for sf = [0.5 2 5]
    for rad = [3 5 10]
        J = inpaintCoherent(I, maskBox, SmoothingFactor=sf, Radius=rad);
        [pp, ss] = ch13_holeMetrics(I, J, maskBox);
        er = ch13_gradEnergy(J, maskBox) / detail.ReferenceEnergy;
        tag = "";
        if sf == 2 && rad == 5, tag = "  <- 預設"; end
        fprintf("%-10.1f %-8d %10.3f %10.4f %10.3f%s\n", sf, rad, pp, ss, er, tag);
        if pp > best, best = pp; bestCfg = sprintf("sf=%.1f rad=%d", sf, rad); end
    end
end
fprintf("\n最佳組合：%s（PSNR %.3f）\n", bestCfg, best);
%[text] 預設值 `SmoothingFactor=2, Radius=5` 在 9 種組合中拿到最高的 PSNR
%[text] **16.135**，第二名是 `sf=2, rad=3` 的 16.114——差距只有 0.02 dB。
%[text] > **這兩個函式的參數個性完全不同：**
%[text] > `inpaintCoherent` 的預設值可以直接用；
%[text] > `inpaintExemplar` 的兩個預設值**都不是**這個案例的最佳選擇。
%[text] > 沒有通則，只能實測。
%%
%[text] # 6. 影像混合：`imblend` 的八種模式
%[text] 把一個物件貼到另一張影像上，難的不是「貼」，是**接縫**。
P  = imread("peppers.png");
fgMask = false(size(P,1), size(P,2));
fgMask(60:200, 40:190) = true;

bg = imread("saturn.png");
if size(bg,3) == 1, bg = repmat(bg, 1, 1, 3); end
bg = imresize(bg, [size(P,1) size(P,2)]);

figure
tiledlayout(1,3, TileSpacing="compact")
nexttile; imshow(P);      title("前景來源")
nexttile; imshow(fgMask); title("前景遮罩")
nexttile; imshow(bg);     title("背景（亮度與色調都不同）")
%%
%[text] ## 6.1 用數字量化接縫
%[text] 「看起來無縫」不是評估。接縫的定義很明確：
%[text] **遮罩邊界附近的梯度**。硬貼會在邊界產生一道階梯，梯度很大；
%[text] 好的混合會把它抹平。
[blendTbl, blendInfo] = ch13_compositeObject(P, bg, fgMask);
disp(blendTbl)
fprintf("\n參考值：純背景在接縫帶的梯度 = %.5f（理想下限）\n", blendInfo.BackgroundBaseline);
fprintf("        硬貼（完全不混合）      = %.5f（上限）\n", blendInfo.HardPasteSeam);
%[text] 實測（接縫帶 = 遮罩邊界 ±3 像素，共 2900 像素）：
%[text:table]
%[text] | Mode | 接縫梯度 | 內部保真 PSNR |
%[text] | --- | --- | --- |
%[text] | **Poisson** | **0.15196** | 19.542 |
%[text] | PoissonMixGradients | 0.16545 | 13.296 |
%[text] | Overlay | 0.26783 | 14.515 |
%[text] | Average | 0.28567 | 17.183 |
%[text] | Max | 0.28931 | 12.869 |
%[text] | Min | 0.32202 | 16.089 |
%[text] | Guided | 0.33727 | **Inf** |
%[text] | Alpha（預設） | 0.36932 | 21.630 |
%[text] | *（硬貼，不混合）* | *0.50240* | *Inf* |
%[text] | *（純背景基準線）* | *0.10531* | *—* |
%[text:table]
%[text] **Poisson 把接縫從 0.502 降到 0.152**，已經接近純背景的 0.105。
%%
%[text] # 7. Poisson 混合的代價
%[text] 上面的表格有第二欄，而它說的是**相反的故事**。
%[text] 「內部保真 PSNR」= 遮罩內縮 8 像素之後，混合結果與原始前景的差距。
%[text] 它回答的是：**貼進去的物件，還是原來那個物件嗎？**
figure
tiledlayout(1,2, TileSpacing="compact")
nexttile
scatter(blendTbl.SeamGradient, blendTbl.InteriorPSNR, 80, "filled")
text(blendTbl.SeamGradient, blendTbl.InteriorPSNR, "  " + blendTbl.Mode, FontSize=8)
xline(blendInfo.BackgroundBaseline, "--", "背景基準", LineWidth=1.2);
xlabel("接縫梯度（越小越好）"); ylabel("內部保真 PSNR（越大越好）")
title("兩個目標互相衝突"); grid on
nexttile
opac = [0.3 0.5 0.7 0.9 1.0];
sv = zeros(size(opac)); fv = zeros(size(opac));
fprintf("\n%-10s %14s %16s\n", "Opacity", "接縫梯度", "內部保真PSNR");
for k = 1:numel(opac)
    B = imblend(P, bg, fgMask, Mode="Alpha", ForegroundOpacity=opac(k));
    [sv(k), fv(k)] = ch13_seamAndFidelity(B, P, bg, fgMask);
    fprintf("%-10.1f %14.5f %16.3f\n", opac(k), sv(k), fv(k));
end
yyaxis left;  plot(opac, sv, "o-", LineWidth=1.6); ylabel("接縫梯度")
yyaxis right; plot(opac, fv, "s-", LineWidth=1.6); ylabel("內部保真 PSNR")
xlabel("ForegroundOpacity"); title("Alpha 模式：純粹的取捨旋鈕"); grid on
%[text] **Poisson 的接縫最好（0.152），但內部保真只有 19.5 dB。**
%[text] 而 `Guided` 的內部保真是 **Inf**（像素完全相同），接縫卻是 0.337。
%[text] 原因在演算法本身：**Poisson 混合只保留前景的梯度，不保留它的絕對值。**
%[text] 它解一個泊松方程，讓結果的梯度等於前景的梯度、邊界值等於背景的值。
%[text] 於是物件的**顏色會被背景拉走**——接縫消失了，但物件變色了。
%[text] > **這對合成訓練資料是一個真實的風險。**
%[text] > 如果你用 Poisson 混合產生訓練影像，物件的顏色會隨背景改變。
%[text] > 訓練出來的模型看到的「紅辣椒」其實是一堆被染色的辣椒——
%[text] > 而真實場景裡的辣椒不會這樣變色。
%[text] `Alpha` 模式的 `ForegroundOpacity` 把這個取捨變成一個旋鈕：
%[text:table]
%[text] | Opacity | 接縫梯度 | 內部保真 PSNR |
%[text] | --- | --- | --- |
%[text] | 0.3 | 0.20536 | 14.273 |
%[text] | 0.5 | 0.28567 | 17.182 |
%[text] | 0.7（預設） | 0.36932 | 21.630 |
%[text] | 0.9 | 0.45680 | 31.187 |
%[text] | 1.0 | 0.50240 | Inf |
%[text:table]
%[text] 完全單調：不透明度越高，物件越忠實、接縫越明顯。
%[text] 注意 `Opacity=0.5` 的接縫梯度 0.28567 與 `Mode="Average"` **完全相同**——
%[text] Average 就是 50% 的 alpha 混合。
%[text] **選擇建議**
%[text:table]
%[text] | 用途 | 建議模式 | 理由 |
%[text] | --- | --- | --- |
%[text] | 給人看的合成圖 | `Poisson` | 接縫最不明顯 |
%[text] | 訓練資料（要保留物件外觀） | `Guided` 或高 opacity 的 `Alpha` | 物件不變色 |
%[text] | 需要一個旋鈕調 | `Alpha` + `ForegroundOpacity` | 取捨連續可調 |
%[text:table]
%%
%[text] # 8. R2025a：自動標註的合成資料
%[text] 這是本章最實用的功能。`insertObjectInImage` 把前景物件貼進背景，
%[text] **並回傳它的邊界框與遮罩**——標註是免費的。
if ~hasInsert
    fprintf("\n未安裝 AVI Library，跳過第 8–10 節。\n");
else
    srcObj  = imread("peppers.png");
    objMask = false(size(srcObj,1), size(srcObj,2));
    objMask(60:200, 40:190) = true;

    dest = imresize(imread("saturn.png"), [400 600]);
    if size(dest,3) == 1, dest = repmat(dest,1,1,3); end

    rng(0);
    [newImg, bbox, newMask] = insertObjectInImage(dest, srcObj, objMask);

    fprintf("\n回傳的邊界框 = %s\n", mat2str(bbox));
    fprintf("回傳的遮罩   = %d 像素\n", nnz(newMask));
    fprintf("**標註不用手標，函式直接給。**\n");

    figure
    imshow(insertObjectAnnotation(newImg, "rectangle", bbox, "pepper", ...
        LineWidth=3, Color="yellow"));
    title("合成影像 + 自動產生的標註")
end
%[text] 三個 `BlendMethod` 都可用（`"guidedfilter"` 預設、`"poisson"`、`"none"`），
%[text] 而且**邊界框完全相同**——混合方式只影響外觀，不影響幾何。
%[text] 實測三種方法都回傳 `bbox = [407.5 157.5 151 141]`、遮罩 21291 像素。
%[text] > 第 7 節的結論在這裡直接適用：
%[text] > 產生**訓練資料**時，`BlendMethod="poisson"` 會讓物件變色。
%[text] > 預設的 `"guidedfilter"` 是比較安全的選擇。
%%
%[text] ## 8.1 幾何擴增：一個物件變出很多個
%[text] `GeometricAugmentation` 接受一個**函式句柄**，
%[text] 每次插入時呼叫它取得一個隨機變換。
if hasInsert
    rng(0);
    [augImg, augBox, augMask] = insertObjectInImage(dest, srcObj, objMask, ...
        GeometricAugmentation=@() randomAffine2d(Scale=[0.4 0.8], Rotation=[-30 30]));

    fprintf("\n原始遮罩 %d 像素 -> 擴增後 %d 像素\n", nnz(objMask), nnz(augMask));
    fprintf("邊界框 %s（原始物件是 151x141）\n", mat2str(augBox));

    figure
    imshow(insertObjectAnnotation(augImg, "rectangle", augBox, "pepper", ...
        LineWidth=3, Color="cyan"));
    title("隨機縮放 + 旋轉後插入，邊界框自動跟著變")
end
%[text] 注意傳的是 `@() randomAffine2d(...)`——**一個沒有引數的函式句柄**，
%[text] 而不是 `randomAffine2d(...)` 的結果。
%[text] 差別很重要：傳結果的話每次插入都用**同一個**變換，
%[text] 傳句柄才會每次重新抽樣。
%[text] 實測：`Scale=[0.4 0.8]` 讓遮罩從 21291 縮到 4533 像素、
%[text] 邊界框從 151×141 變成 92×90。
%%
%[text] # 9. 規模化：`objectInsertionDatastore`
%[text] 一次插一個物件不夠。`objectInsertionDatastore` 直接產生
%[text] 可以餵給訓練的 datastore。
%[text] **它對輸入格式的要求很嚴格**，這是最容易卡住的地方。
if hasInsert
    tmpRoot = fullfile(tempdir, "ipcv_ch13_demo");
    if isfolder(tmpRoot), rmdir(tmpRoot, "s"); end
    bgDir  = fullfile(tmpRoot, "bg");  mkdir(bgDir);
    objDir = fullfile(tmpRoot, "obj"); mkdir(objDir);

    for k = 1:6
        B = imresize(imread("saturn.png"), [300 400]);
        if size(B,3) == 1, B = repmat(B,1,1,3); end
        imwrite(min(B + uint8(12*k), 255), fullfile(bgDir, sprintf("bg_%d.png", k)));
    end
    for k = 1:3
        imwrite(srcObj, fullfile(objDir, sprintf("o_%d.png", k)));
    end

    dsBg = imageDatastore(bgDir);

    % 物件端必須回傳 4 元素 cell：{影像, 邊界框, 標籤, 遮罩}
    objBox = ch13_maskToBox(objMask);
    dsObj  = transform(imageDatastore(objDir), ...
        @(X) { X, objBox, categorical("pepper"), objMask });

    fprintf("\n背景 %d 張、物件 %d 張\n", numel(dsBg.Files), 3);
    probe = read(dsObj); reset(dsObj);
    fprintf("物件 datastore 回傳 %d 元素的 cell：\n", numel(probe));
    for j = 1:numel(probe)
        fprintf("   {%d} %s %s\n", j, class(probe{j}), mat2str(size(probe{j})));
    end

    for fmt = ["ObjectDetection" "InstanceSegmentation"]
        reset(dsBg); reset(dsObj);
        rng(0);                       % 物件數是隨機的，固定種子才可重現
        dsSynth = objectInsertionDatastore(dsBg, dsObj, 5, ...
            NumObjectsToInsert=[1 3], OutputFormat=fmt, ...
            BlendMethod="guidedfilter");
        r = read(dsSynth);
        fprintf("\nOutputFormat=%s -> %d 元素\n", fmt, numel(r));
        for j = 1:numel(r)
            fprintf("   {%d} %s %s\n", j, class(r{j}), mat2str(size(r{j})));
        end
    end
end
%[text] **格式要求**：物件 datastore 必須回傳
%[text] `{影像, 邊界框, 標籤, 遮罩}` 四元素 cell（實例分割格式）。
%[text] 直接傳 `imageDatastore` 會得到
%[text] `visualinspection:objectInsertionDatastore:sourceImageDataMustBeCellVector`。
%[text] 用 `transform` 包一層是最簡單的解法。
%[text] 輸出格式決定回傳幾個元素：
%[text:table]
%[text] | OutputFormat | 回傳內容 |
%[text] | --- | --- |
%[text] | `"ObjectDetection"` | `{影像, 框 N×4, 標籤 N×1}` |
%[text] | `"InstanceSegmentation"` | `{影像, 框 N×4, 標籤 N×1, 遮罩 H×W×N}` |
%[text:table]
%[text] `NumObjectsToInsert=[1 3]` 是一個**範圍**，所以每張影像的 N 會不同。
%[text] 上面的程式在兩個 `OutputFormat` 前都重設了 `rng(0)`，
%[text] 所以兩次讀到的物件數相同——**若不固定種子，這個數字每次都不一樣**，
%[text] 而那正是你要的（訓練資料本來就該有變化），
%[text] 只是寫教材時必須固定它才能對照數字。
%[text] > **固定種子只保證「同一個版本」可重現。**
%[text] > 同樣是 `rng(0)`，R2026a 這裡讀到 **2** 個物件，R2026b 讀到 **1** 個——
%[text] > 函式內部抽亂數的方式改了，種子就對不上。
%[text] > 要跨版本比對合成資料，**存下產生的資料本身**，不要只存種子。
%%
%[text] # 10. 重疊限制：資料量與標註品質的取捨
%[text] `ObjectsInSceneMaxOverlap` 限制物件之間的重疊。
%[text] 這個參數的影響比看起來大得多。
if hasInsert
    destSmall = imresize(imread("saturn.png"), [260 320]);
    if size(destSmall,3) == 1, destSmall = repmat(destSmall,1,1,3); end

    fprintf("\n擁擠場景（畫布 260x320，物件縮放 0.7–0.9）\n");
    fprintf("%-14s %10s %14s\n", "MaxOverlap", "插入個數", "最大實際IoU");
    for maxOv = [1 0.5 0.2 0]
        % 插入位置是隨機的。每個 MaxOverlap 都從同一個種子開始，
        % 差異才能歸因於限制本身，而不是不同的隨機序列。
        rng(0);
        [nIns, maxIoU] = ch13_fillScene(destSmall, srcObj, objMask, maxOv, 10);
        fprintf("%-14.1f %10d %14.4f\n", maxOv, nIns, maxIoU);
    end
end
%[text] 實測：
%[text:table]
%[text] | MaxOverlap | 插入個數 | 最大實際 IoU |
%[text] | --- | --- | --- |
%[text] | 1.0（預設） | **10** | **0.7794** |
%[text] | 0.5 | 2 | 0.0000 |
%[text] | 0.2 | 2 | 0.0000 |
%[text] | 0.0 | 2 | 0.0000 |
%[text:table]
%[text] **預設值 `1` 代表完全不限制重疊**，結果是十個物件疊在一起，
%[text] 最嚴重的一對重疊 **78%**。
%[text] 那種影像的標註是**有害的**：兩個框幾乎重合，
%[text] 訓練時模型無法學到「一個物件對應一個框」。
%[text] 但只要把限制收到 0.5，就只塞得進 **2 個**物件——**資料量掉了 5 倍**。
%[text] 而且 0.5、0.2、0 三個值的結果完全相同，說明在這個畫布尺寸下
%[text] 限制一旦生效就直接飽和。
%[text] > **這是合成資料的核心取捨：**
%[text] > **擠得越多，標註品質越差；標註越乾淨，資料量越少。**
%[text] > 沒有一個「正確」的值——要看你的真實場景有多擁擠。
%[text] > 若真實場景的物件本來就會互相遮擋，那就**應該**允許重疊；
%[text] > 若不會，允許重疊就是在製造真實世界不存在的樣本。
%[text] **合成資料最大的風險不是品質，是分布不匹配。**
%[text] 第 22 章（工業瑕疵檢測）會再回到這個問題。
%%
%[text] # 11. 資料擴增：`imageDataAugmenter` 與隨機變換
%[text] 合成新影像之外，另一條路是對既有影像做隨機變換。
aug = imageDataAugmenter( ...
    RandRotation=[-20 20], ...
    RandXReflection=true, ...
    RandScale=[0.8 1.2], ...
    RandXTranslation=[-10 10], ...
    RandYTranslation=[-10 10]);
fprintf("\nimageDataAugmenter 可設定的項目：\n");
fprintf("  %s\n", strjoin(string(properties(aug)), "、"));

rng(0);
fprintf("\nrandomAffine2d 每次呼叫都重新抽樣：\n");
for k = 1:3
    tf = randomAffine2d(Rotation=[-30 30], Scale=[0.8 1.2]);
    fprintf("  第 %d 次：A(1,1)=%.4f、A(1,2)=%.4f\n", k, tf.A(1,1), tf.A(1,2));
end

rng(0);
fprintf("\nrandomWindow2d 從 384x512 隨機取 128x128：\n");
for k = 1:3
    w = randomWindow2d([384 512], [128 128]);
    fprintf("  第 %d 次：rows %s、cols %s\n", k, ...
        mat2str(w.YLimits), mat2str(w.XLimits));
end

figure
tiledlayout(2,4, TileSpacing="compact")
rng(0);
small = imresize(I, 0.5);
for k = 1:8
    tf = randomAffine2d(Rotation=[-25 25], Scale=[0.8 1.15], XReflection=true);
    R  = imref2d(size(small, [1 2]));
    nexttile; imshow(imwarp(small, tf, OutputView=R));
end
sgtitle("randomAffine2d 的八次抽樣")
%[text] 三個工具的分工：
%[text:table]
%[text] | 工具 | 用途 |
%[text] | --- | --- |
%[text] | `imageDataAugmenter` | 給 `trainnet` 用的擴增設定物件，訓練時自動套用 |
%[text] | `randomAffine2d` | 抽一個隨機仿射變換，自己配 `imwarp` 用 |
%[text] | `randomWindow2d` | 抽一個隨機裁切視窗，配 `imcrop` 用 |
%[text:table]
%[text] **擴增與合成的差別很重要：**
%[text] - **擴增**改變既有影像的幾何／色彩，**標註要跟著變**（框要一起旋轉）
%[text] - **合成**產生新影像，**標註是計算出來的**（不會有轉換誤差）
%[text] 這就是 `insertObjectInImage` 的價值：它把幾何擴增放在**插入之前**，
%[text] 所以回傳的框已經是擴增後的正確位置。
%[text] 自己做的話很容易忘記同步更新標註——這是資料集出錯最常見的原因之一。
%%
%[text] # 12. 已移除：`vision.AlphaBlender`
%[text] 舊教材與網路上大量範例用 `vision.AlphaBlender` 做混合。
%[text] 它的淘汰過程正好示範了 MATLAB 移除功能的標準節奏：
%[text:table]
%[text] | 版本 | 呼叫 `vision.AlphaBlender` 的結果 |
%[text] | --- | --- |
%[text] | R2026a 以前 | 可以用，**只發警告**（`vision:obsolete:obsoleteFunctionality`） |
%[text] | **R2026b** | **直接報錯**（`vision:obsolete:removeFunctionality`） |
%[text:table]
try
    ab = vision.AlphaBlender; %#ok<NASGU>
    fprintf("\n這個版本還能建構 vision.AlphaBlender（R2026a 以前的行為）\n");
catch ME
    fprintf("\n建構 vision.AlphaBlender 的錯誤：\n");
    fprintf("  id  = %s\n", ME.identifier);
    fprintf("  msg = %s\n", ME.message);
end

fprintf("\n第 00 章的 findLegacyAPI 能掃出這類呼叫：\n");
if exist("findLegacyAPI", "file") == 2
    fprintf("  findLegacyAPI 可用。對本章目錄執行：\n");
    fprintf("  findLegacyAPI(fullfile(ipcvRoot, ""part2_Segmentation_Measurement""))\n");
end
%[text] 錯誤訊息明確指向替代方案：**改用 `imblend`**。
%[text] > **警告期就是修改期。** R2026a 的那一行警告，到 R2026b 就變成一個讓整份程式停下來的錯誤。
%[text] > 沒有在警告期處理的程式碼，升級當天才會發現。
%[text] > 這與第 10 章「更新 API 會讓寫死的門檻失效」是同一件事的另一面：
%[text] > `findLegacyAPI` 能找出**哪裡**用了舊 API，
%[text] > 但換掉之後結果會不會變，**只有重跑驗證才知道**。
%[text] > `vision.AlphaBlender` 的預設不透明度與 `imblend` 的
%[text] > `ForegroundOpacity=0.7` 不一定相同——換的時候要一起檢查。
%%
%[text] # 13. 常見陷阱
%[text] **① 用整張影像的指標評估修復。**
%[text] 洞占 4.12% 時，整張 SSIM 是 0.9716、洞內只有 0.3285（第 3.1 節）。
%[text] **② 只用 PSNR 挑修復方法。**
%[text] PSNR 會選 `regionfill`，而它的紋理只有原圖的 32%——一塊糊掉的色斑。
%[text] 必須同時看紋理指標（第 4.1 節）。
%[text] **③ 以為紋理越多越好。**
%[text] `inpaintExemplar` 的紋理**超出 34%**，那是補丁接縫產生的假梯度。
%[text] 目標是**接近 1**，不是越大越好。
%[text] **④ 直接用 `inpaintExemplar` 的預設值。**
%[text] `PatchSize=[9 9]` 不如 `[5 5]`；`FillOrder="gradient"` 不如 `"tensor"`
%[text] （PSNR 差 2.3 dB）。反過來 `inpaintCoherent` 的預設值幾乎是最佳（第 5 節）。
%[text] **⑤ 產生訓練資料時用 Poisson 混合。**
%[text] Poisson 只保留梯度不保留絕對值，**物件會被背景染色**
%[text] （內部保真只有 19.5 dB，而 `Guided` 是 Inf）。第 7 節。
%[text] **⑥ 把 `randomAffine2d(...)` 的結果傳給 `GeometricAugmentation`。**
%[text] 要傳**函式句柄** `@() randomAffine2d(...)`，否則每次插入都用同一個變換。
%[text] **⑦ 第一次呼叫就傳空的 `ObjectsInSceneMasks`。**
%[text] 會報 `Value must not be empty`。第一次插入時**省略**這個參數，
%[text] 之後才傳累積的遮罩堆疊（第 10 節的 `ch13_fillScene` 就是這樣寫的）。
%[text] **⑧ 用 `imageDatastore` 直接餵 `objectInsertionDatastore`。**
%[text] 它要求 `{影像, 框, 標籤, 遮罩}` 四元素 cell，用 `transform` 包一層。
%[text] **⑨ 留著 `ObjectsInSceneMaxOverlap` 的預設值 `1`。**
%[text] 那代表**完全不限制**，實測最大 IoU 達 0.7794——標註幾乎無法使用。
%[text] 但收緊之後資料量會掉 5 倍，要自己權衡（第 10 節）。
%[text] **⑩ 繼續用 `vision.AlphaBlender`。** R2026b 已移除，呼叫就報錯；改用 `imblend`。
%%
%[text] # 14. 本章小結
%[text] **修復的評估必須有正確答案**
%[text] 從完好影像挖洞再修，原圖就是 ground truth。
%[text] 「看起來不錯」不是評估方法。
%[text] **一個指標永遠不夠**
%[text] PSNR 選 `regionfill`（紋理只有 32%），紋理指標選 `exemplar`（超出 34%）。
%[text] 兩個一起看才會選到 `inpaintCoherent`。
%[text] 這是第 12 章教訓在真實任務上的重演。
%[text] **混合的兩個目標互相衝突**
%[text] Poisson 接縫最好（0.152）但物件變色（19.5 dB）；
%[text] Guided 物件完全不變（Inf）但接縫明顯（0.338）。
%[text] 選哪個取決於**這張圖要給人看還是給模型學**。
%[text] **合成資料的標註是免費的，分布不是**
%[text] `insertObjectInImage` 直接回傳框與遮罩，省掉標註成本。
%[text] 但重疊限制、混合方式、擴增範圍都在**塑造你的資料分布**——
%[text] 而分布不匹配是合成資料最大的風險，不是畫質。
%[text] **R2026a / R2025a 的新東西**
%[text] `uipaint` 筆刷遮罩（R2026a）、`imblend` 的 Poisson 模式、
%[text] `insertObjectInImage` 與 `objectInsertionDatastore`（R2025a）。
%[text] 同時 `vision.AlphaBlender` 已在 R2026b 移除。
%%
%[text] # 15. 練習
%[text] 練習題在 `exercise/Ch13_Exercise.m`，解答在 `exercise/Ch13_Solution.m`。
%[text] 五題 + 一題加分題，建議 50 分鐘。
%%
%[text] # 16. 延伸閱讀與下一章
%[text] **本章函式**
%[text:table]
%[text] | 檔案 | 用途 |
%[text] | --- | --- |
%[text] | `code/ch13_inpaintCompare.m` | 三方法對照，**同時回報像素與紋理指標** |
%[text] | `code/ch13_compositeObject.m` | 混合模式對照，量化接縫與內部保真 |
%[text] | `code/ch13_makeSyntheticSet.m` | 產生合成標註資料集，並回報分布特性 |
%[text] | `code/ch13_holeMetrics.m` | 只在遮罩範圍內算 PSNR/SSIM |
%[text] | `code/ch13_gradEnergy.m` | 遮罩內的平均梯度能量（紋理指標） |
%[text] | `code/ch13_seamAndFidelity.m` | 接縫梯度與內部保真 |
%[text] | `code/ch13_fillScene.m` | 反覆插入物件直到放不下，處理首次呼叫的 API 陷阱 |
%[text] | `code/ch13_maskToBox.m` | 遮罩轉邊界框 |
%[text:table]
%[text] **官方文件**
%[text] `doc inpaintExemplar`、`doc inpaintCoherent`、`doc imblend`、
%[text] `doc insertObjectInImage`、`doc objectInsertionDatastore`、
%[text] `doc uipaint`、`doc imageDataAugmenter`
%[text] **下一章**
%[text] 第 14 章　特徵偵測、描述與比對——從「製造影像」回到「理解影像」，
%[text] 用關鍵點把兩張影像對應起來（影像拼接、物件比對、影像檢索）。

% ========================================================================
function s = statusText(flag)
if flag, s = "可用"; else, s = "未安裝（相關小節會跳過）"; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
