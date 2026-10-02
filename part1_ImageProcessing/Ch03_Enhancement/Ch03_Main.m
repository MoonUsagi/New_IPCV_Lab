%[text] # 第 03 章　點運算、直方圖與影像增強
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：3 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 判讀直方圖，從中看出影像的曝光與對比問題
%[text] 2. 依問題選擇正確的增強手法，而不是每次都用同一招
%[text] 3. 說明全域等化與局部等化（CLAHE）的差別與各自的代價
%[text] 4. 正確增強彩色影像而不讓顏色偏掉
%[text] 5. 用量化指標判斷「增強」到底有沒有變好 \
%[text] ## 前置知識
%[text] 第 01 章（資料型別與色彩空間）、第 02 章（工作流與評估的觀念）。
%[text] ## 環境需求
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="03", Verbose=false);
disp("環境檢查通過。")
%%
%[text] # 1. 什麼是點運算
%[text] **點運算**是逐像素的運算：輸出像素只取決於同一位置的輸入像素，
%[text] 與鄰居無關。
%[text] $g(x,y)=T[f(x,y)]$
%[text] 因為每個像素都套用同一個函式 $T$，點運算可以化簡成一張**查表**——
%[text] 8 位元影像只要算 256 個值就好。這也是它速度極快的原因。
%[text:table]
%[text] | 類型 | 輸出取決於 | 例子 | 本課程章節 |
%[text] | --- | --- | --- | --- |
%[text] | **點運算** | 同位置的單一像素 | `imadjust` `histeq` gamma | 第 03 章（本章） |
%[text] | **鄰域運算** | 周圍一小塊區域 | `imfilter` `medfilt2` | 第 04 章 |
%[text] | **全域運算** | 整張影像 | `fft2` 頻域濾波 | 第 05 章 |
%[text:table]
%[text] 這個分類很實用：**遇到問題先問「這是點運算能解決的嗎」**。
%[text] 亮度、對比、曝光屬於點運算；雜訊、模糊不是。
I = imread("pout.tif");

figure
tiledlayout(1,2)
nexttile; imshow(I); title("pout.tif")
nexttile; imhist(I); title("直方圖")
%%
%[text] # 2. 讀懂直方圖
%[text] 直方圖是影像的「體檢報告」。學會看它，你就能在動手之前知道問題在哪。
%[text:table]
%[text] | 直方圖長相 | 代表 | 該做什麼 |
%[text] | --- | --- | --- |
%[text] | 集中在窄範圍 | 對比不足 | 對比拉伸 `imadjust` |
%[text] | 整體偏左 | 曝光不足（太暗） | 提高亮度或 gamma \< 1 |
%[text] | 整體偏右 | 過曝 | 降低亮度或 gamma \> 1 |
%[text] | 兩端有高峰 | 已經截斷，資訊已遺失 | **救不回來**，要重拍 |
%[text] | 雙峰分離 | 前景背景分得開 | 直接二值化（第 08 章） |
%[text:table]
%[text] `pout.tif` 的直方圖集中在中間，兩端都是空的——典型的**對比不足**。
%[text] 用數字確認：
Id = im2double(I);
fprintf("實際使用範圍：%.3f – %.3f\n", min(Id(:)), max(Id(:)));
fprintf("只用了可用動態範圍的 %.0f%%" + "\n", 100*(max(Id(:)) - min(Id(:))));
fprintf("標準差（對比的粗略指標）：%.1f\n", std(double(I(:))));
%[text] 只用了約 60% 的動態範圍——還有四成的位元被浪費掉。
%%
%[text] # 3. 對比拉伸
%[text] ## 3.1 imadjust 與 stretchlim
%[text] `imadjust` 把輸入的某個範圍線性映射到輸出的某個範圍。
%[text] 最常見的用法是搭配 `stretchlim`——它會自動找出要拉伸的範圍，
%[text] 預設**忽略最亮與最暗各 1% 的像素**，避免被少數極端值綁架。
lim = stretchlim(I);
J1  = imadjust(I, lim, []);
J2  = imadjust(I);            % 等價寫法，imadjust 內部就會呼叫 stretchlim

fprintf("stretchlim 找到的範圍：[%.3f %.3f]\n", lim(1), lim(2));
fprintf("兩種寫法結果是否相同：%d\n", isequal(J1, J2));

figure
montage({I, J1})
title("原圖 　｜　對比拉伸後")

figure
tiledlayout(1,2)
nexttile; imhist(I);  title("原圖直方圖");   ylim([0 3000])
nexttile; imhist(J1); title("拉伸後直方圖"); ylim([0 3000])
%[text] 直方圖被「撐開」填滿整個範圍，但**形狀沒有改變**——
%[text] 這是線性拉伸的特徵：它不會改變像素之間的相對關係。
%%
%[text] ## 3.2 那個 1% 很重要
%[text] 如果影像裡有一個亮點（反光、壞點），不忽略極端值的話整個拉伸就白做了。
%[text] 示範一下：
Ispot = I;
Ispot(1:3, 1:3) = 255;      % 模擬一個過曝亮點

noClip   = imadjust(Ispot, [min(im2double(Ispot(:))) max(im2double(Ispot(:)))], []);
withClip = imadjust(Ispot, stretchlim(Ispot), []);

figure
montage({Ispot, noClip, withClip})
title("有亮點的原圖 ｜ 不忽略極端值（幾乎沒效果）｜ 忽略 1%（正常）")

fprintf("不忽略極端值後的標準差：%.1f\n", std(double(noClip(:))));
fprintf("忽略 1%% 後的標準差    ：%.1f\n", std(double(withClip(:))));
%[text] 一個 3×3 的亮點就足以讓整張影像的拉伸失效。
%[text] **實務上一律用 `stretchlim`**，不要自己抓 min/max。
%%
%[text] ## 3.3 Gamma 校正
%[text] `imadjust` 的第四個引數是 gamma，做的是非線性映射：
%[text] $g=f^{\gamma}$
%[text] 第 02 章我們吃過它的虧，這裡把方向記牢：
gammas = [0.4 0.7 1.0 1.5 2.5];
outs = cell(1, numel(gammas));
for k = 1:numel(gammas)
    outs{k} = imadjust(I, [], [], gammas(k));
end

figure
montage(outs, Size=[1 5])
title("gamma = 0.4 ｜ 0.7 ｜ 1.0 ｜ 1.5 ｜ 2.5")

for k = 1:numel(gammas)
    fprintf("gamma=%.1f  平均亮度 %.3f  %s\n", gammas(k), ...
        mean(im2double(outs{k}), "all"), ...
        ternaryStr(gammas(k) < 1, "<- 變亮", ternaryStr(gammas(k) > 1, "<- 變暗", "<- 不變")));
end
%[text] **記法**：gamma 小於 1 變亮、大於 1 變暗。和直覺相反，
%[text] 因為 0–1 之間的數字取較小的次方會變大（$0.5^{0.4}=0.76$）。
%[text] 畫出映射曲線就一目了然：
x = linspace(0, 1, 256);
figure
hold on
for g = gammas
    plot(x, x.^g, LineWidth=1.5)
end
plot(x, x, "k:", LineWidth=1)
hold off
legend("γ=0.4","γ=0.7","γ=1.0","γ=1.5","γ=2.5","y=x", Location="southeast")
xlabel("輸入"); ylabel("輸出"); title("Gamma 映射曲線"); grid on
axis square
%%
%[text] # 4. 直方圖等化
%[text] ## 4.1 全域等化 histeq
%[text] 對比拉伸只是線性地撐開範圍。**直方圖等化**更進一步：
%[text] 重新分配像素值，讓直方圖盡量**均勻**，也就是讓每個灰階都有差不多多的像素。
Jstretch = imadjust(I);
Jhisteq  = histeq(I);

figure
montage({I, Jstretch, Jhisteq})
title("原圖 ｜ 線性拉伸 ｜ 直方圖等化")

figure
tiledlayout(1,3)
nexttile; imhist(I);        title("原圖");   ylim([0 3000])
nexttile; imhist(Jstretch); title("線性拉伸"); ylim([0 3000])
nexttile; imhist(Jhisteq);  title("直方圖等化"); ylim([0 3000])
%[text] 等化後的直方圖被「攤平」了。注意它**改變了直方圖的形狀**，
%[text] 所以像素之間的相對關係變了——這正是它比線性拉伸強、也比較危險的原因。
%%
%[text] ## 4.2 全域等化的問題
%[text] `histeq` 用整張影像的統計量決定映射。當影像裡有**明暗差異很大的區域**時，
%[text] 全域的映射沒辦法同時照顧到所有區域。
moon = imread("moon.tif");

figure
montage({moon, histeq(moon), adapthisteq(moon)})
title("原圖 ｜ histeq（全域）｜ adapthisteq（局部 CLAHE）")
%[text] 全域等化常見的兩個副作用：**暗處雜訊被放大**、**平坦區域出現偽輪廓**。
%%
%[text] ## 4.3 CLAHE：局部等化
%[text] `adapthisteq` 實作 **CLAHE**（Contrast-Limited Adaptive Histogram
%[text] Equalization）。它做兩件事：
%[text] 1. **Adaptive**：把影像切成小塊，每塊各自等化，再內插接起來
%[text] 2. **Contrast-Limited**：限制每塊的對比增益上限，避免放大雜訊 \
%[text] 第 2 點是關鍵。純粹的局部等化會把平坦區域的雜訊放大到無法接受，
%[text] `ClipLimit` 就是用來壓制這件事的。
clips = [0.005 0.01 0.02 0.05 0.1];
outsC = cell(1, numel(clips));
for k = 1:numel(clips)
    outsC{k} = adapthisteq(moon, ClipLimit=clips(k));
end

figure
montage(outsC, Size=[1 5])
title("ClipLimit = 0.005 ｜ 0.01（預設）｜ 0.02 ｜ 0.05 ｜ 0.1")
%%
%[text] ## 4.3.1 一個會騙人的指標
%[text] 直覺是「ClipLimit 越大對比越強」。用標準差量量看：
fprintf("%-12s %12s %14s %10s\n", "ClipLimit", "全域標準差", "局部標準差", "熵");
fprintf("%-12s %12.1f %14.4f %10.4f\n", "原圖", std(double(moon(:))), ...
    mean(stdfilt(im2double(moon), ones(9)), "all"), entropy(moon));

for k = 1:numel(clips)
    J   = outsC{k};
    loc = stdfilt(im2double(J), ones(9));      % 9×9 鄰域內的標準差 = 局部對比
    fprintf("%-12.3f %12.1f %14.4f %10.4f\n", clips(k), ...
        std(double(J(:))), mean(loc(:)), entropy(J));
end
%[text] 兩個指標給出**相反的結論**：
%[text] - **全域標準差**隨 ClipLimit 增加而**下降**（72 → 56）
%[text] - **局部標準差**隨 ClipLimit 增加而**上升**（0.039 → 0.121） \
%[text] 哪一個是對的？**兩個都對，它們量的是不同的東西**。
%[text] CLAHE 的本質是在每個小區塊內重新分配亮度。這讓區塊**內部**的細節
%[text] 更清楚（局部對比上升），但同時把區塊**之間**的整體明暗差異拉平了
%[text] （全域對比下降）。月亮照片正是如此：月面細節變清楚了，
%[text] 但「月亮亮、背景暗」這個大尺度的反差被削弱。
%[text] **這一節的教訓比 CLAHE 本身更重要**：
%[text] 選錯指標就會得到錯誤的結論。要評估局部增強，就得用局部指標。
%[text] 用全域標準差去評估 CLAHE，你會得出「CLAHE 讓對比變差」這種荒謬結果。
%[text] 熵在這裡是比較誠實的指標——它從 5.51 一路升到 7.66，
%[text] 反映 CLAHE 確實讓灰階分布更豐富。
%[text] `ClipLimit` **沒有通用的最佳值**，要看影像的雜訊水準與你的用途。
%[text] 預設 0.01 偏保守；要看清暗處細節可以加到 0.02–0.05，
%[text] 但雜訊也會跟著放大。
%%
%[text] ## 4.4 三種手法怎麼選
%[text:table]
%[text] | 手法 | 適用 | 代價 |
%[text] | --- | --- | --- |
%[text] | `imadjust` 線性拉伸 | 對比不足但照明均勻 | 對局部暗處沒幫助 |
%[text] | `histeq` 全域等化 | 需要大幅提升對比、影像照明均勻 | 放大雜訊、可能出現偽輪廓 |
%[text] | `adapthisteq` CLAHE | **照明不均**、局部細節重要（醫療、衛星） | 較慢；參數要調；可能有區塊邊界痕跡 |
%[text:table]
%[text] **預設建議**：不確定時先試 `imadjust`，它最溫和也最好解釋。
%[text] 需要看清暗處細節才上 CLAHE。`histeq` 在實務上用得比教科書少得多。
%%
%[text] # 5. 直方圖匹配
%[text] `imhistmatch` 把影像 A 的直方圖調整成接近參考影像 B。
%[text] 這在**多張影像要一致**的場合非常有用——例如同一條產線不同時段拍的照片，
%[text] 或要拼接的多張衛星影像。
ref  = imread("pout.tif");
src  = imadjust(ref, [], [], 2.2);      % 模擬一張偏暗的同場景影像
matched = imhistmatch(src, ref);

figure
montage({ref, src, matched})
title("參考影像 ｜ 偏暗的來源 ｜ 匹配後")

fprintf("平均亮度  參考 %.3f ｜ 來源 %.3f ｜ 匹配後 %.3f\n", ...
    mean(im2double(ref),"all"), mean(im2double(src),"all"), mean(im2double(matched),"all"));
%[text] 這是第 02 章「照明變化」問題的一種**部分解**：
%[text] 如果你有一張基準影像，可以把後續影像都匹配過去，再做顏色分割。
%[text] 但它不是萬靈丹——場景內容變了，直方圖也會變，硬匹配反而會引入失真。
%%
%[text] # 6. 低光源增強
%[text] ## 6.1 傳統做法
lowlight = imread("lowlight_1.jpg");
lowlight = imresize(lowlight, 0.5);     % 縮小加快示範速度

figure
imshow(lowlight)
title(sprintf("低光源影像（平均亮度 %.3f）", mean(im2double(im2gray(lowlight)),"all")))

enhGamma = imadjust(lowlight, [], [], 0.45);
enhLocal = imlocalbrighten(lowlight);

figure
montage({lowlight, enhGamma, enhLocal})
title("原圖 ｜ gamma 0.45 ｜ imlocalbrighten")
%[text] `imlocalbrighten` 只提亮暗部，已經夠亮的區域幾乎不動——
%[text] 這比全域 gamma 好，因為全域 gamma 會把原本正常的區域一起拉到過曝。
%%
%[text] ## 6.2 為什麼低光源這麼難
%[text] 低光源不只是「暗」。感測器在低光下的**訊噪比**很差，
%[text] 提亮的同時一定會把雜訊一起放大。
darkRegion = im2double(im2gray(lowlight));
darkMask   = darkRegion < 0.15;

fprintf("暗部像素佔比：%.0f%%" + "\n", 100*mean(darkMask, "all"));
fprintf("暗部標準差（雜訊指標）：%.4f\n", std(darkRegion(darkMask)));
fprintf("亮部標準差            ：%.4f\n", std(darkRegion(~darkMask)));

enhLocalGray = im2double(im2gray(enhLocal));
fprintf("\n提亮後暗部標準差      ：%.4f  <- 雜訊被一起放大了\n", ...
    std(enhLocalGray(darkMask)));
%[text] 所以低光源增強**通常需要搭配去雜訊**（第 04 章），
%[text] 或改用專門訓練過的深度學習模型（見 6.3）。
%%
%[text] ## 6.3 深度學習的做法
%[text] MATLAB 有現成的低光源增強深度學習範例。它學的是「暗影像 → 亮影像」
%[text] 的映射，同時處理提亮與去雜訊，效果通常優於傳統方法。
%[text] 這個範例需要下載預訓練模型（約數百 MB），預設不執行。
%[text] 想跑的話把下面改成 `true`，或直接在命令列執行 `openExample` 那行。
runDeepLowLight = false;

if runDeepLowLight
    openExample("images/LowLightImageEnhancementExample")
else
    disp("略過深度學習低光增強示範。")
    disp("要執行：openExample(""images/LowLightImageEnhancementExample"")")
end
%[text] **傳統 vs 深度學習的取捨**：
%[text:table]
%[text] | | 傳統（imadjust／imlocalbrighten） | 深度學習 |
%[text] | --- | --- | --- |
%[text] | 速度 | 毫秒級 | 需要 GPU，較慢 |
%[text] | 可解釋 | 完全可解釋，參數有物理意義 | 黑盒 |
%[text] | 去雜訊 | 不會，反而放大 | 會，一併處理 |
%[text] | 適用範圍 | 任何影像 | 訓練資料涵蓋的場景 |
%[text] | 失敗模式 | 可預測 | 可能產生不存在的細節（幻覺） |
%[text:table]
%[text] **量測用途要特別小心深度學習增強**——它可能「腦補」出原本不存在的
%[text] 細節。用來讓人看的可以，用來量測的要三思。
%%
%[text] # 7. 去霧與不均勻光場
%[text] ## 7.1 去霧
foggy = imresize(imread("foggysf1.jpg"), 0.25);
defogged = imreducehaze(foggy);

figure
montage({foggy, defogged})
title("有霧 ｜ imreducehaze")

fprintf("對比（標準差） 原圖 %.1f -> 去霧後 %.1f\n", ...
    std(double(im2gray(foggy)),0,"all"), std(double(im2gray(defogged)),0,"all"));
%%
%[text] ## 7.2 不均勻光場校正
%[text] 這是工業檢測**最常遇到**的問題：光源不可能完全均勻，
%[text] 影像會有一邊亮一邊暗。`imflatfield` 用大尺度的高斯模糊估計背景光場，
%[text] 再把它除掉。
rice = imread("rice.png");
flat = imflatfield(rice, 30);      % 第二個引數是高斯 sigma，要比物件大得多

figure
montage({rice, flat})
title("原圖（左上亮、右下暗）｜ imflatfield 校正後")

figure
tiledlayout(1,2)
nexttile; imhist(rice); title("原圖直方圖"); ylim([0 2500])
nexttile; imhist(flat); title("校正後直方圖"); ylim([0 2500])
%[text] 校正後直方圖出現清楚的**雙峰**——前景與背景分開了。
%[text] 這代表現在可以用單一全域門檻分割，不必再用自適應門檻。
bwBefore = imbinarize(rice);
bwAfter  = imbinarize(flat);

figure
montage({bwBefore, bwAfter})
title("直接二值化 ｜ 先校正光場再二值化")

fprintf("直接二值化    連通區域 %d 個\n", max(bwlabel(bwareaopen(bwBefore,30)),[],"all"));
fprintf("先校正再二值化 連通區域 %d 個（正確約 95 個米粒）\n", ...
    max(bwlabel(bwareaopen(bwAfter,30)),[],"all"));
%[text] **這是本章最實用的一招**。第 02 章我們發現照明變化會讓分割失效，
%[text] 這裡給了一個直接的解法：**分割之前先把光場校正掉**。
%[text] `sigma` 的選法：要**明顯大於**你要偵測的物件，才不會把物件也當成背景除掉。
%%
%[text] # 8. 彩色影像增強：一個常見的錯誤
%[text] ## 8.1 錯誤做法：逐通道等化
%[text] 直覺會想「對 R、G、B 各做一次 histeq 不就好了？」
%[text] 這是**錯的**，而且錯得很隱蔽。
RGB = imread("coloredChips.png");

wrong = RGB;
for c = 1:3
    wrong(:,:,c) = histeq(RGB(:,:,c));
end

figure
montage({RGB, wrong})
title("原圖 ｜ 逐通道 histeq（顏色偏掉了）")
%%
%[text] ## 8.2 正確做法：只增強亮度通道
%[text] 換到把亮度與顏色分開的色彩空間（L\*a\*b\* 或 HSV），
%[text] **只處理亮度通道**，顏色資訊完全不動。
lab      = rgb2lab(RGB);
lab(:,:,1) = adapthisteq(lab(:,:,1)/100) * 100;    % L 範圍是 0–100
correct  = lab2rgb(lab, OutputType="uint8");

figure
montage({RGB, wrong, correct})
title("原圖 ｜ 逐通道 histeq（錯）｜ 只調 L 通道（對）")
%%
%[text] ## 8.3 用數字證明
%[text] 「顏色偏掉」不能只靠眼睛說。量化它——比較高飽和度像素的色相偏移量：
hsv0 = rgb2hsv(RGB);
hsvW = rgb2hsv(wrong);
hsvC = rgb2hsv(correct);

sel = hsv0(:,:,2) > 0.45;                        % 只看顏色明確的像素

% 色相是環狀的（0 與 1 相鄰），差值要繞回 [-0.5, 0.5]
hueDiff = @(a, b) mod(a - b + 0.5, 1) - 0.5;

dWrong   = hueDiff(hsvW(:,:,1), hsv0(:,:,1));
dCorrect = hueDiff(hsvC(:,:,1), hsv0(:,:,1));

fprintf("逐通道 histeq   平均色相偏移 %.4f（約 %.1f 度）\n", ...
    mean(abs(dWrong(sel))),   360*mean(abs(dWrong(sel))));
fprintf("只調 L 通道     平均色相偏移 %.4f（約 %.1f 度）\n", ...
    mean(abs(dCorrect(sel))), 360*mean(abs(dCorrect(sel))));

fprintf("\n對比（標準差）  原圖 %.1f ｜ 逐通道 %.1f ｜ 只調 L %.1f\n", ...
    std(double(im2gray(RGB)),0,"all"), ...
    std(double(im2gray(wrong)),0,"all"), ...
    std(double(im2gray(correct)),0,"all"));
%[text] 逐通道等化的色相偏移是 Lab 做法的**兩倍多**，而對比只多一點。
%[text] 用一點點對比換掉顏色的正確性，不划算。
%%
%[text] ## 8.4 但是 Lab 也不是零偏移
%[text] 上面 Lab 的做法仍有 4.2 度的偏移。既然我們只動 L 通道、完全沒碰 a 和 b，
%[text] 顏色為什麼還會變？
%[text] 答案是**色域裁切**。改完 L 之後，(L, a, b) 這個組合可能已經落在
%[text] sRGB 能表示的範圍之外，`lab2rgb` 會把超出的通道值裁回 [0, 1]——
%[text] 而裁切改變了通道比例，於是色相就變了。
%[text] 量一量到底有多少像素被裁：
labBase = rgb2lab(RGB);

for m = ["stretch" "histeq" "clahe"]
    L = labBase(:,:,1) / 100;
    switch m
        case "stretch", Lout = imadjust(L, stretchlim(L), []);
        case "histeq",  Lout = histeq(L);
        case "clahe",   Lout = adapthisteq(L, ClipLimit=0.01);
    end
    labTmp = labBase;
    labTmp(:,:,1) = Lout * 100;
    rgbUnclipped  = lab2rgb(labTmp);          % double 輸出，不裁切

    fprintf("lab + %-8s 超出 sRGB 色域的通道值 %5.2f%%" + "\n", ...
        m, 100 * mean(rgbUnclipped < 0 | rgbUnclipped > 1, "all"));
end
%[text] 越激進的方法推出去越多——`histeq` 有 13% 的通道值被裁切。
%[text] 這解釋了一個反直覺的實測結果：**`lab` + `histeq` 的色相偏移是 12.2 度，
%[text] 比「錯誤」的逐通道做法還糟**。
%%
%[text] ## 8.5 想要零偏移就用 HSV
%[text] HSV 的 V 定義是 $\max(R,G,B)$。調整 V 等於把三個通道**同比例縮放**，
%[text] 而色相只取決於比例，所以 H 在數學上完全不變。
hsvBase = rgb2hsv(RGB);
hsvNew  = hsvBase;
hsvNew(:,:,3) = adapthisteq(hsvBase(:,:,3));
hsvCheck = rgb2hsv(hsv2rgb(hsvNew));

fprintf("HSV 路線的色相最大變化：%.2e（純粹是浮點誤差）\n", ...
    max(abs(hsvCheck(:,:,1) - hsvNew(:,:,1)), [], "all"));
%[text] 本章的 `code/ch03_enhanceColor.m` 兩種空間都支援。怎麼選：
%[text:table]
%[text] | 色彩空間 | 色相偏移 | 視覺品質 | 什麼時候用 |
%[text] | --- | --- | --- | --- |
%[text] | `"lab"`（預設） | 約 2–4 度 | 較好，L 是感知均勻的亮度 | 給人看的影像 |
%[text] | `"hsv"` | 0 度 | 對比增強看起來較生硬 | 下游要做**顏色分割或色差量測** |
%[text:table]
%[text] **這一節請牢牢記住兩件事**：
%[text] 1. 對彩色影像逐通道做點運算幾乎都是錯的——第 02 章的 gamma 問題同源，
%[text] **通道之間的比例決定顏色，任何破壞比例的操作都會改變顏色**
%[text] 2. 「換到 Lab 只調 L」是好習慣，但**不等於零偏移**。
%[text] 真的需要保證顏色不動，用 HSV \
%%
%[text] # 9. R2026a：Poisson 影像混合
%[text] `imblend` 把兩張影像混合。R2025a 起支援 **Poisson 混合**，
%[text] 它不是直接疊上去，而是讓貼上的區域的**梯度**與來源一致、
%[text] **邊界**與目標一致，所以接縫幾乎看不出來。
target = imread("coloredChips.png");
source = imresize(imread("peppers.png"), [size(target,1) size(target,2)]);

blendMask = false(size(target,1), size(target,2));
blendMask(120:270, 180:340) = true;

% 注意語法：遮罩是**第三個位置引數**，不是名稱-值對
directPaste  = target;
directPaste(repmat(blendMask, [1 1 3])) = source(repmat(blendMask, [1 1 3]));

alphaBlend   = imblend(source, target, blendMask, Mode="Alpha");
poissonBlend = imblend(source, target, blendMask, Mode="Poisson");

figure
montage({directPaste, alphaBlend, poissonBlend})
title("直接貼上 ｜ Alpha 混合 ｜ Poisson 混合")
%[text] 直接貼上看得到明顯的方框邊界；Alpha 混合只是半透明疊加，邊界仍在；
%[text] **Poisson 混合把邊界完全融掉了**——因為它保留的是來源的梯度，
%[text] 而不是來源的絕對亮度，所以貼上的區域會自動適應目標的照明。
%[text] 量化一下邊界的突兀程度——沿著遮罩邊界取梯度強度：
edgeBand = imdilate(blendMask, strel("disk",2)) & ~imerode(blendMask, strel("disk",2));

for pair = {"直接貼上", directPaste; "Alpha", alphaBlend; "Poisson", poissonBlend}'
    g = imgradient(im2gray(pair{2}));
    fprintf("%-10s 邊界平均梯度 %.1f\n", pair{1}, mean(g(edgeBand)));
end
%[text] 可用的混合模式：`"Alpha"`（預設）、`"Poisson"`、`"PoissonMixGradients"`、
%[text] `"Guided"`、`"Min"`、`"Max"`、`"Average"`、`"Overlay"`。
%[text] 這個技巧在第 13 章（影像修復與合成資料生成）會正式用到——
%[text] 把缺陷樣本貼到良品影像上，製造訓練資料。
%%
%[text] # 10. 評估：增強到底有沒有變好
%[text] 「看起來比較清楚」不是可以交付的結論。本章示範三種量化角度。
%[text] 完整的影像品質評估是第 12 章的主題，這裡先建立習慣。
methods   = ["原圖" "線性拉伸" "histeq" "CLAHE"];
variants  = {I, imadjust(I), histeq(I), adapthisteq(I)};

metrics = table;
for k = 1:numel(methods)
    v  = im2double(variants{k});
    metrics = [metrics; table(methods(k), ...
        std(v(:)), ...                                   % 對比
        entropy(variants{k}), ...                        % 資訊量
        numel(unique(variants{k}(:))), ...               % 實際用到的灰階數
        VariableNames=["方法" "標準差" "熵" "灰階數"])]; %#ok<AGROW>
end
disp(metrics)
%%
%[text] ## 10.1 讀懂這三個指標
%[text:table]
%[text] | 指標 | 意義 | 越高越好嗎 |
%[text] | --- | --- | --- |
%[text] | 標準差 | 對比強度 | 不一定。過高代表被過度拉伸、細節被壓掉 |
%[text] | 熵 | 資訊量 | 點運算**不會增加資訊**，熵最多持平 |
%[text] | 實際灰階數 | 動態範圍利用率 | 等化後反而會**減少**，因為多個灰階被合併 |
%[text:table]
%[text] 注意 `histeq` 的灰階數比原圖**少**。這是等化的本質：
%[text] 它把原本相鄰的灰階合併或拉開，合併的部分就永久失去區別能力。
%[text] **這是本章最重要的觀念**：
%[text] 增強**不會創造資訊**，只會重新分配你已經有的資訊。
%[text] 它讓某些東西更容易看見，代價是另一些東西變得更難看見。
%[text] 所以「增強得好不好」永遠要問：**為了什麼用途？**
fprintf("原圖熵      ：%.4f\n", entropy(I));
fprintf("histeq 後熵 ：%.4f  <- 沒有增加\n", entropy(histeq(I)));
fprintf("原圖灰階數  ：%d\n", numel(unique(I(:))));
fprintf("histeq 灰階數：%d  <- 反而變少\n", numel(unique(reshape(histeq(I),[],1))));
%%
%[text] # 11. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 對彩色影像逐通道做點運算 | 顏色偏掉，而且很難察覺 | 換到 Lab／HSV，只處理亮度通道 |
%[text] | 自己抓 min/max 做拉伸 | 一個亮點就讓拉伸失效 | 用 `stretchlim` 忽略極端值 |
%[text] | 以為 gamma 越大越亮 | 方向弄反 | gamma \< 1 變亮、\> 1 變暗 |
%[text] | 把 `histeq` 當萬用增強 | 雜訊被放大、出現偽輪廓 | 先試 `imadjust`；照明不均才用 CLAHE |
%[text] | `imflatfield` 的 sigma 設太小 | 物件也被當成背景除掉 | sigma 要明顯大於物件尺寸 |
%[text] | 以為增強能救回過曝 | 兩端截斷的資訊永遠回不來 | 重拍。直方圖兩端有高峰就是證據 |
%[text] | 用深度學習增強後拿去量測 | 模型可能「腦補」細節 | 量測用途優先用可解釋的傳統方法 |
%[text] | 只憑肉眼判斷「變好了」 | 無法交付、無法重現 | 量化：標準差、熵、或第 12 章的正式指標 |
%[text] | 用全域指標評估局部增強 | 得出「CLAHE 讓對比變差」的荒謬結論 | 局部增強要用局部指標（如 `stdfilt`） |
%[text:table]
%%
%[text] # 12. 本章小結
%[text] - 點運算是逐像素查表，快、可解釋，但只能處理亮度與對比類的問題
%[text] - 直方圖是影像的體檢報告，先看它再決定用什麼手法
%[text] - `imadjust`（溫和）→ `adapthisteq`（照明不均）→ `histeq`（很少用）
%[text] - **彩色影像只增強亮度通道**，永遠不要逐通道做
%[text] - `imflatfield` 校正光場，是第 02 章照明問題最直接的解法
%[text] - 增強不創造資訊，只重新分配。所以一定要問「為了什麼用途」
%[text] - **評估要選對指標**。用全域標準差評估 CLAHE 會得到相反的結論 \
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 備註 |
%[text] | --- | --- | --- |
%[text] | `imhist` | 顯示直方圖 | 診斷的第一步 |
%[text] | `imadjust` | 對比拉伸與 gamma | 最常用、最溫和 |
%[text] | `stretchlim` | 自動找拉伸範圍 | 預設忽略兩端各 1% |
%[text] | `histeq` | 全域直方圖等化 | 會放大雜訊，慎用 |
%[text] | `adapthisteq` | CLAHE 局部等化 | 照明不均時的首選，調 `ClipLimit` |
%[text] | `imhistmatch` | 直方圖匹配到參考影像 | 多影像一致化 |
%[text] | `imlocalbrighten` | 只提亮暗部 | 低光源 |
%[text] | `imreducehaze` | 去霧 | |
%[text] | `imflatfield` | 不均勻光場校正 | sigma 要大於物件 |
%[text] | `imcomplement` | 取補色／反相 | |
%[text] | `imblend` | 影像混合，含 Poisson | R2025a 新增混合模式 |
%[text] | `entropy` | 資訊量 | 評估增強效果 |
%[text:table]
%%
%[text] # 13. 練習
%[text] 開啟 `exercise/Ch03_Exercise.m`，完成五題。解答在 `Ch03_Solution.m`。
%%
%[text] # 14. 延伸閱讀與下一章
%[text] - [Contrast Adjustment](https://www.mathworks.com/help/images/contrast-adjustment.html)
%[text] - [Adaptive Histogram Equalization](https://www.mathworks.com/help/images/ref/adapthisteq.html)
%[text] - **下一章**：第 04 章　空間域濾波與雜訊處理——點運算解決不了的問題（雜訊、模糊），要靠鄰域運算 \

function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
