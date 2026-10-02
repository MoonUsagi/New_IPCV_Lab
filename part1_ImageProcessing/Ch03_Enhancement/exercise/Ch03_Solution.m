%[text] # 第 03 章　練習解答
assert(exist("ch03_enhanceColor","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
%%
%[text] # 解答 1：先診斷，再開藥
imgs = ["pout.tif" "tire.tif" "moon.tif" "AT3_1m4_01.tif"];
diagnosis = ["對比不足，集中在中間"
             "偏暗且對比不足"
             "偏暗，且亮暗區域差異極大"
             "對比不足，細胞與背景灰階接近"];
treatment = ["imadjust 線性拉伸即可"
             "imadjust 加 gamma < 1"
             "adapthisteq（照明極不均，全域方法救不了）"
             "adapthisteq（要看清細胞邊界）"];

for k = 1:numel(imgs)
    I = imread(imgs(k));

    switch k
        case 1, J = imadjust(I);
        case 2, J = imadjust(I, stretchlim(I), [], 0.7);
        case 3, J = adapthisteq(I);
        case 4, J = adapthisteq(I, ClipLimit=0.02);
    end

    figure
    tiledlayout(1,3)
    nexttile; imshow(I); title(imgs(k))
    nexttile; imhist(I); title("直方圖")
    nexttile; imshow(J); title("處理後")

    fprintf("%-18s 使用範圍 %.2f–%.2f  標準差 %5.1f -> %5.1f\n", imgs(k), ...
        double(min(I(:)))/255, double(max(I(:)))/255, ...
        std(double(I(:))), std(double(J(:))));
    fprintf("   診斷：%s\n   處方：%s\n\n", diagnosis(k), treatment(k));
end
%[text] ## 哪一張救不回來
%[text] 檢查每張影像**貼在兩端**的像素比例。真正被截斷的影像，
%[text] 在 0 或 255 會有一根異常高的柱子。
for k = 1:numel(imgs)
    I = imread(imgs(k));
    atLow  = mean(I(:) <= 1);
    atHigh = mean(I(:) >= 254);
    fprintf("%-18s 貼底 %.2f%%  貼頂 %.2f%%" + "\n", imgs(k), 100*atLow, 100*atHigh);
end
%[text] 四張的兩端佔比都很低——**答案是沒有，它們都救得回來**。
%[text] 這四張都只是對比不足或偏暗，屬於「像素值擠在一起」，
%[text] 而不是「像素值被壓成同一個數字」。前者可以拉開，後者不行。
%[text] 如果你因為題目問了就硬指認一張，那就掉進陷阱了——
%[text] **診斷的結論要來自數據**。練習 2 會做出一張真正救不回來的來對照。
%%
%[text] # 解答 2：製造一張救不回來的影像
I = imread("pout.tif");

% 強力過曝：先大幅提亮再截斷
overexposed = imadjust(I, [0 0.55], [0 1]);

atHigh = mean(overexposed(:) >= 254);
fprintf("原圖   貼頂像素 %.2f%%" + "\n", 100*mean(I(:) >= 254));
fprintf("過曝後 貼頂像素 %.2f%%  <- 這些像素的原始值已經永久遺失\n", 100*atHigh);

figure
tiledlayout(2,2)
nexttile; imshow(I);           title("原圖")
nexttile; imhist(I);           title("原圖直方圖")
nexttile; imshow(overexposed); title("過曝後")
nexttile; imhist(overexposed); title("過曝直方圖 — 注意最右端的高柱")
%%
%[text] ## 試著救回來
rescue1 = imadjust(overexposed);
rescue2 = adapthisteq(overexposed);
rescue3 = imadjust(overexposed, [], [], 2.0);   % 壓暗

figure
montage({overexposed, rescue1, rescue2, rescue3}, Size=[1 4])
title("過曝 ｜ imadjust ｜ CLAHE ｜ gamma 2.0")

fprintf("\n%-12s %8s %10s %10s\n", "影像", "熵", "灰階數", "貼頂%%");
data = {"原圖", I; "過曝", overexposed; "imadjust", rescue1; ...
        "CLAHE", rescue2; "gamma2.0", rescue3};
for k = 1:size(data,1)
    X = data{k,2};
    fprintf("%-12s %8.4f %10d %9.2f\n", data{k,1}, entropy(X), ...
        numel(unique(X(:))), 100*mean(X(:) >= 254));
end
%[text] **為什麼救不回來**：看熵和灰階數。
%[text] 原圖有 121 個灰階、熵約 5.76；過曝後灰階數大幅減少，熵也掉下來。
%[text] 三種「救援」手法都**無法讓熵回到原圖的水準**——
%[text] 因為所有被壓到 255 的像素，原本的差異已經永久消失，
%[text] 它們現在是同一個數字，任何點運算都只會把同一個數字映射到另一個數字。
%[text] **點運算是一對一的查表。輸入相同，輸出必然相同。**
%[text] 這就是「過曝救不回來」的數學本質——不是技術不夠好，是資訊真的不在了。
%[text] 下次遇到這種影像，直接跟對方說：**請重拍，調低曝光**。
%%
%[text] # 解答 3：找出 imflatfield 的 sigma
rice = imread("rice.png");
sigmas = [5 10 20 30 50 80 120];
counts = zeros(size(sigmas));
results = cell(size(sigmas));

for k = 1:numel(sigmas)
    flat = imflatfield(rice, sigmas(k));
    bw   = bwareaopen(imbinarize(flat), 30);
    counts(k) = max(bwlabel(bw), [], "all");
    results{k} = flat;
end

figure
montage(results, Size=[1 numel(sigmas)])
title("sigma = " + strjoin(string(sigmas), " ｜ "))

figure
plot(sigmas, counts, "-o", LineWidth=1.5)
yline(95, "r--", LineWidth=2, Label="正確約 95 個")
xlabel("sigma"); ylabel("二值化後連通區域數")
title("imflatfield 的 sigma 對分割結果的影響")
grid on

disp(table(sigmas', counts', VariableNames=["sigma" "連通區域數"]))
%[text] **sigma 太小會怎樣**：高斯模糊的範圍比米粒還小，
%[text] 米粒本身就被當成「背景光場」估進去，除掉之後米粒也一起變淡，
%[text] 分割結果破碎、數量暴增或暴跌。
%[text] **sigma 太大會怎樣**：估出來的背景太平滑，跟不上實際的光場變化，
%[text] 校正效果打折，慢慢退回沒校正的狀態。
%[text] **選法**：sigma 要**明顯大於**單一物件的尺寸，但**小於**光場變化的尺度。
%[text] 米粒大約 10–20 像素寬，所以 sigma 取 30–50 是合理區間。
%[text] 不確定時就掃一遍畫這張圖——比憑感覺快得多。
%%
%[text] # 解答 4：安全的彩色增強函式
%[text] 完整實作在 `code/ch03_enhanceColor.m`。驗證三種方法：
RGB = imread("coloredChips.png");

fprintf("%-10s %-8s %12s %12s %12s\n", "色彩空間", "方法", "色相偏移(度)", "超出色域%%", "對比");
for cs = ["lab" "hsv"]
    for m = ["stretch" "histeq" "clahe"]
        w = warning("off", "ch03_enhanceColor:worstCombo");
        [~, d] = ch03_enhanceColor(RGB, m, ColorSpace=cs);
        warning(w);
        fprintf("%-10s %-8s %12.1f %12.2f %12.1f\n", ...
            cs, m, d.MeanHueShiftDegrees, 100*d.OutOfGamutFraction, d.ContrastAfter);
    end
end

% 對照組：錯誤的逐通道做法
wrong = RGB;
for c = 1:3
    wrong(:,:,c) = histeq(RGB(:,:,c));
end
h0 = rgb2hsv(RGB); hw = rgb2hsv(wrong);
sel = h0(:,:,2) > 0.45;
dw  = mod(hw(:,:,1) - h0(:,:,1) + 0.5, 1) - 0.5;
fprintf("%-10s %-8s %12.1f %12s %12.1f  <- 錯誤做法\n", "逐通道", "histeq", ...
    360*mean(abs(dw(sel))), "-", std(double(im2gray(wrong)),0,"all"));
%[text] **結論**：
%[text] - `hsv` 任何方法都是 0 度偏移——因為調 V 是同比例縮放，色相依定義不變
%[text] - `lab` + `stretch` 或 `clahe` 只有 2–4 度，可以接受
%[text] - **`lab` + `histeq` 是 12.2 度，比錯誤的逐通道做法還糟**，
%[text] 因為它把 13% 的通道值推出色域被裁切 \
%[text] 這題最重要的收穫是：**「用了正確的色彩空間」不等於「一定安全」**。
%[text] 要驗證，不要假設。這也是為什麼這支函式回傳診斷資訊——
%[text] 讓呼叫端能檢查，而不是盲目相信。
%%
%[text] # 解答 5：增強會不會讓分割變好？
rng(0);
dataDir = fullfile(tempdir, "ch03_sol_dataset");
if isfolder(dataDir), rmdir(dataDir, "s"); end
mkdir(dataDir);

chips = imread("coloredChips.png");
variants = struct( ...
    "name", {"01_original" "02_rotated" "03_gamma06" "04_gamma15" "05_noisy" "06_blurred"}, ...
    "fcn",  {@(I) I, @(I) imrotate(I,15,"crop"), @(I) imadjust(I,[],[],0.6), ...
             @(I) imadjust(I,[],[],1.5), @(I) imnoise(I,"gaussian",0,0.002), ...
             @(I) imgaussfilt(I,2)});
for k = 1:numel(variants)
    imwrite(variants(k).fcn(chips), fullfile(dataDir, variants(k).name + ".png"));
end

base = imageDatastore(dataDir);
preprocessors = { ...
    "不處理",      @(I) I; ...
    "imadjust",    @(I) imadjust(I, stretchlim(I), []); ...
    "imflatfield", @(I) imflatfield(I, 60); ...
    "Lab-CLAHE",   @(I) ch03_enhanceColor(I, "clahe"); ...
    "HSV-CLAHE",   @(I) ch03_enhanceColor(I, "clahe", ColorSpace="hsv")};

fprintf("\n%-14s %-22s %s\n", "前處理", "各張計數", "正確數");
for k = 1:size(preprocessors, 1)
    ds = transform(base, preprocessors{k,2});
    reset(ds);
    c = zeros(6,1);
    for j = 1:6
        c(j) = height(ch02_findChips(read(ds)));
    end
    fprintf("%-14s %-22s %d/6\n", preprocessors{k,1}, mat2str(c'), nnz(c == 6));
end
%[text] ## 結論：增強讓分割**變差**了
%[text] 不處理是 3/6，所有前處理都**沒有更好，多數更糟**。
%[text] 為什麼？回想第 02 章第 7.2 節的診斷：這批影像的失效原因是
%[text] **gamma 造成的色相偏移**，不是亮度不足。
%[text] 而本章學到的增強手法全部是**點運算**——它們調整的是亮度分布。
%[text] 亮度分布不是問題所在，所以修不好；更糟的是，
%[text] 這些手法本身又引入了新的色相偏移（`imadjust` 逐通道拉伸尤其嚴重，
%[text] 把 3/6 打成 1/6）。
%[text] **這一題的教訓**：
%[text] 1. 先診斷，再決定前處理。**不要「反正加個增強應該會比較好」**
%[text] 2. 前處理**不是免費的**，它會引入自己的失真
%[text] 3. 用點運算去修不是點運算造成的問題，通常只會讓事情更糟 \
%[text] 注意 `HSV-CLAHE` 沒有讓結果變差太多——因為它不引入色相偏移。
%[text] 但它也沒讓結果變好，因為它沒有解決真正的問題。
%[text] **真正的解法還是第 02 章說的：控制照明。**
%%
%[text] # 加分題：自己實作直方圖等化
I = imread("pout.tif");

% 步驟 1：算直方圖
counts = imhist(I);

% 步驟 2：累積分布函式，正規化到 0–1
cdf = cumsum(counts) / numel(I);

% 步驟 3：用 CDF 當查表。灰階 v 映射到 round(255 * cdf(v+1))
lut = uint8(round(255 * cdf));
myHisteq = lut(double(I) + 1);
myHisteq = reshape(myHisteq, size(I));

builtinResult = histeq(I, 256);

figure
montage({I, myHisteq, builtinResult})
title("原圖 ｜ 自己實作 ｜ histeq")

d = double(myHisteq) - double(builtinResult);
fprintf("與 histeq 的最大差異：%d 灰階\n", max(abs(d(:))));
fprintf("完全相同的像素比例  ：%.1f%%" + "\n", 100*mean(d(:) == 0));

figure
tiledlayout(1,2)
nexttile; plot(0:255, cdf, LineWidth=1.5); grid on
xlabel("輸入灰階"); ylabel("累積機率"); title("累積分布函式 CDF")
nexttile; plot(0:255, double(lut), LineWidth=1.5); grid on
xlabel("輸入灰階"); ylabel("輸出灰階"); title("由 CDF 導出的查表")
%[text] **這就是「點運算就是查表」的完整證明**：
%[text] 整個直方圖等化，最後濃縮成右邊那張 256 個元素的對照表。
%[text] 無論影像有幾百萬個像素，都只是查這張表。
%[text] 這也解釋了為什麼點運算這麼快——不管影像多大，
%[text] 真正的運算量永遠是 256 次。
%[text] 順帶一提：差異若不是零，多半來自 MATLAB 內部的捨入策略與 bin 數設定。
%[text] 概念上完全一致。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
