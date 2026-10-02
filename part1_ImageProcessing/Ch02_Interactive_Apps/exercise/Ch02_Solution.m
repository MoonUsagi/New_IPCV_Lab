%[text] # 第 02 章　練習解答
assert(exist("ch02_findChips","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);
RGB = imread("coloredChips.png");
%%
%[text] # 解答 1：走完五步驟（綠色）
%[text] 綠色的色相不跨越 0／1 邊界，所以 `lo < hi`。查色相直方圖可以先估出範圍，
%[text] 再用 APP 微調。這裡用 `[0.36 0.48]`。
greenRange = [0.36 0.48];
[sGreen, mGreen] = ch02_findChips(RGB, HueRange=greenRange, MinCircularity=0.8);

figure
montage({RGB, mGreen})
title("原圖 　｜　綠色遮罩")
fprintf("綠色圓片：%d 個\n", height(sGreen));
%[text] ## 怎麼估出這個範圍
%[text] 不必純靠猜。先看高飽和度像素的色相分布，波峰就是各顏色所在：
HSV = rgb2hsv(RGB);
H = HSV(:,:,1); S = HSV(:,:,2);

figure
histogram(H(S > 0.45), 50)
xlabel("色相 H"); ylabel("像素數")
title("高飽和度像素的色相分布 — 每個波峰是一種顏色")
xline(greenRange, "g--", LineWidth=2)
%[text] **這個技巧很實用**：與其在 APP 裡盲目拖滑桿，先畫一張直方圖，
%[text] 你會立刻看出有幾個顏色群、各自在哪裡。APP 用來微調，不是用來探索。
%%
%[text] ## 綠色比紅色穩健嗎
dataDir = fullfile(tempdir, "ch02_sol_dataset");
if isfolder(dataDir), rmdir(dataDir, "s"); end
mkdir(dataDir);

variants = struct( ...
    "name", {"01_original" "02_rotated" "03_gamma06" "04_gamma15" "05_noisy" "06_blurred"}, ...
    "fcn",  {@(I) I, @(I) imrotate(I,15,"crop"), @(I) imadjust(I,[],[],0.6), ...
             @(I) imadjust(I,[],[],1.5), @(I) imnoise(I,"gaussian",0,0.002), ...
             @(I) imgaussfilt(I,2)});
for k = 1:numel(variants)
    imwrite(variants(k).fcn(RGB), fullfile(dataDir, variants(k).name + ".png"));
end

ds = imageDatastore(dataDir);
Tred   = ch02_batchCount(ds, HueRange=[0.95 0.04], MinCircularity=0.8);
Tgreen = ch02_batchCount(ds, HueRange=greenRange,  MinCircularity=0.8);

disp(table(Tred.Name, Tred.Count, Tgreen.Count, VariableNames=["Name" "紅色" "綠色"]))
%[text] **為什麼綠色通常比紅色穩健**：
%[text] 紅色的色相落在 0／1 的接縫上，任何讓色相輕微偏移的操作（gamma、白平衡、
%[text] 感測器色彩偏差）都可能把像素推到範圍外，或把橘色推進來。
%[text] 綠色位在色相軸的中段，兩側都有緩衝，同樣幅度的偏移比較不會跨出範圍。
%[text] 這是選擇「用哪個顏色當標記」時的實用知識——
%[text] 如果你能決定產線上要貼什麼顏色的標籤，**不要選紅色**。
%%
%[text] # 解答 2：加上 MaxArea 參數
%[text] 完整的修改版在 `exercise/ch02_findChips_withMaxArea.m`。
%[text] 核心只有兩處：`arguments` 區塊多一行宣告，篩選時改用 `bwareafilt`。
%[text] ```matlabCodeExample
%[text] options.MaxArea (1,1) double {mustBePositive} = Inf
%[text] ...
%[text] mask = bwareafilt(mask, [options.MinArea options.MaxArea]);
%[text] ```
[sAll, ~]  = ch02_findChips_withMaxArea(RGB);
[sCap, ~]  = ch02_findChips_withMaxArea(RGB, MaxArea=1700);

fprintf("不限上限：%d 個\n", height(sAll));
fprintf("MaxArea=1700：%d 個\n", height(sCap));
fprintf("各圓片面積：%s\n", mat2str(sort(sAll.Area)'));
%[text] 面積介於 1449–1809，設 1700 會濾掉最大的三個。
%[text] **實務提醒**：面積上限要依實際物件尺寸設定，而且**會隨鏡頭距離改變**。
%[text] 寫死像素數是脆弱的做法——正確的方式是先做空間校正，
%[text] 把門檻寫成實際尺寸（平方公釐），這是第 11 章的主題。
%%
%[text] # 解答 3：診斷雜訊
noisy = imnoise(RGB, "gaussian", 0, 0.002);
HSVn = rgb2hsv(noisy);
raw = ((HSVn(:,:,1) >= 0.95) | (HSVn(:,:,1) <= 0.04)) & ...
       HSVn(:,:,2) >= 0.45 & HSVn(:,:,3) >= 0.30;

stage    = {raw};
stage{2} = imopen(stage{1}, strel("disk",4));
stage{3} = imfill(stage{2}, "holes");
stage{4} = bwareaopen(stage{3}, 500);
stage{5} = bwpropfilt(stage{4}, "Circularity", [0.9 Inf]);

names = ["原始" "開運算" "補洞" "去雜點" "圓形度"];
for k = 1:5
    fprintf("%-8s 連通區域 %3d 個\n", names(k), max(bwlabel(stage{k}), [], "all"));
end

figure
montage(stage, Size=[1 5])
title("雜訊影像的清理各階段")
%[text] 看得出雜訊在**原始**階段製造了大量細碎區域，但開運算幾乎全部清掉了——
%[text] 所以問題不是「雜訊產生假物件」。
%[text] 真正的損失發生在最後一步。看看進入圓形度篩選前的各區域屬性：
props = regionprops("table", stage{4}, "Area", "Circularity");
props = sortrows(props, "Circularity");
disp(props)

rejected = props(props.Circularity < 0.9, :);
fprintf("\n被圓形度篩選濾掉 %d 個，其圓形度為 %s\n", ...
    height(rejected), mat2str(round(rejected.Circularity, 3)'));
%[text] **結論**：雜訊讓某個區域的邊緣變得不規則，圓形度掉到 0.9 以下，
%[text] 因此被最後一道篩選濾掉。
%[text] 這告訴我們：**每一道篩選都是雙面刃**。圓形度篩選幫我們擋掉了
%[text] 橘色誤判，但也讓方法對邊緣品質變得敏感。
%[text] 若要兼顧，可以先做輕微平滑再分割，或把圓形度門檻放寬並用其他屬性把關。
%%
%[text] # 解答 4：評分函式
%[text] 完整實作在 `code/ch02_scoreParams.m`。有了它就能自動掃參數：
[score, detail] = ch02_scoreParams(ds, 6);
fprintf("預設參數的正確率：%.0f%%" + "\n\n", 100*score);
disp(detail)
%%
%[text] ## 掃描參數看看有沒有更好的設定
%[text] 掃一遍 `MinCircularity`，看正確率怎麼變：
circVals = 0.70:0.05:0.95;
scores   = arrayfun(@(c) ch02_scoreParams(ds, 6, MinCircularity=c), circVals);

figure
plot(circVals, 100*scores, "-o", LineWidth=1.5)
xlabel("MinCircularity"); ylabel("正確率 (%)")
title("圓形度門檻對整體正確率的影響")
grid on

[best, idx] = max(scores);
fprintf("最佳 MinCircularity = %.2f，正確率 %.0f%%" + "\n", circVals(idx), 100*best);
%[text] **重要的觀察**：即使掃過所有門檻，正確率也上不去。
%[text] 這印證了主教材第 7.5 節的結論——**這不是參數的問題**，
%[text] 而是顏色門檻這個方法本身碰上了照明變化的邊界。
%[text] 換句話說：能靠掃參數解決的問題，掃參數就能看出來；
%[text] 掃了還是不行的，代表你需要換方法，而不是換參數。
%%
%[text] # 解答 5：該用哪個工具
%[text:table]
%[text] | 情境 | 建議 | 理由 |
%[text] | --- | --- | --- |
%[text] | 1. 500 張產線照片快速看過 | **Image Browser** | 專為瀏覽大量影像設計，能一次看縮圖、快速標記異常，並匯出成 datastore 接後續處理 |
%[text] | 2. X 光片分割骨骼 | **Image Segmenter** | 灰階影像，顏色資訊不存在，Color Thresholder 派不上用場。可用門檻、區域成長、主動輪廓，或 R2026a 的 SAM 工具 |
%[text] | 3. 找出能分開好壞品的屬性 | **Image Region Analyzer** | 它會一次算出所有區域屬性，讓你直接看哪個屬性的分布能分開兩群，省去逐一嘗試 |
%[text] | 4. 每天自動處理 10000 張 | **手寫 datastore 迴圈**（不是 APP） | 需要無人值守、可排程、可記錄、可接 CI。APP 需要人操作，不適合自動化 |
%[text:table]
%[text] 第 4 題是重點：**APP 是探索工具，不是生產工具**。
%[text] 這正是五步驟工作流第 ③ ④ 步存在的理由——把 APP 的探索成果
%[text] 轉成能無人值守執行的程式碼。
%%
%[text] # 加分題：平行化
%[text] 關鍵在於 `imageDatastore` 不能直接在 `parfor` 裡共用，要先 `partition`。
%[text] 這段需要 Parallel Computing Toolbox，而且**第一次執行要花約一分鐘**
%[text] 啟動平行池。預設關閉，想跑的話把下面改成 `true`。
runParallelDemo = false;

if runParallelDemo && ~isempty(ver("parallel"))
    nWorkers = 4;

    tSerial = tic;
    Tserial = ch02_batchCount(ds);
    tSerial = toc(tSerial);

    tPar = tic;
    parts = cell(nWorkers, 1);
    parfor w = 1:nWorkers
        subds   = partition(ds, nWorkers, w);
        parts{w} = ch02_batchCount(subds);
    end
    Tpar = vertcat(parts{:});
    tPar = toc(tPar);

    fprintf("循序：%.2f 秒（%d 張）\n", tSerial, height(Tserial));
    fprintf("平行：%.2f 秒（%d 張，%d workers）\n", tPar, height(Tpar), nWorkers);
    fprintf("加速比：%.2fx\n", tSerial/tPar);
    fprintf("\n注意：只有 6 張影像時，平行化幾乎一定更慢——\n");
    fprintf("啟動 worker 的成本遠大於處理 6 張小圖的時間。\n");
else
    disp("略過平行化示範（把 runParallelDemo 改成 true 可執行，需 Parallel Computing Toolbox）。")
end
%[text] **什麼時候平行化才划算**：單張處理時間 × 張數，要顯著大於
%[text] 啟動 worker 的固定成本（通常數秒到數十秒）。
%[text] 判斷方式很簡單——**實測**。不要假設平行一定比較快。

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
