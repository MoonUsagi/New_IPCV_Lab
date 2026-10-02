%[text] # 第 23 章　練習解答
%[text] {"align":"left"}影像擷取與串流處理　｜　MATLAB R2026b
%[text] > **本章有三題的結果和我原本的預期相反**，
%[text] > 推翻的過程都留在解答裡：
%[text] > 練習 2（預先配置沒有效益）、練習 3（留在 GPU 上沒有比較好）、
%[text] > 加分題（降解析度贏過丟幀）。
assert(exist("ch23_ballSegmentFrame", "file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

v0 = VideoReader("singleball.mp4");
nBall = v0.NumFrames;
ballFrames = cell(1, nBall);
for k = 1:nBall
    ballFrames{k} = read(v0, k);
end
baseline = ch23_ballSegmentVideo("singleball.mp4");
nBaseline = nnz(baseline.Found);
fprintf("基準：%d 幀中偵測到球 %d 幀\n", nBall, nBaseline);
%%
%[text] # 解答 1　兩個參數的交互作用
thresholds = [5 10 15 20 25 30 40];
minAreas   = [20 40 80 150 250];
found = zeros(numel(thresholds), numel(minAreas));

for i = 1:numel(thresholds)
    for j = 1:numel(minAreas)
        tr = ch23_ballSegmentVideo("singleball.mp4", ...
            Threshold = thresholds(i), MinArea = minAreas(j));
        found(i,j) = nnz(tr.Found);
    end
end

disp(array2table(found, ...
    VariableNames = "MinArea" + string(minAreas), ...
    RowNames      = "Th" + string(thresholds)))

figure;
imagesc(found); colorbar; colormap(parula)
xticks(1:numel(minAreas));   xticklabels(string(minAreas));
yticks(1:numel(thresholds)); yticklabels(string(thresholds));
xlabel("MinArea"); ylabel("Threshold");
title("偵測到球的幀數（基準 23）")
for i = 1:numel(thresholds)
    for j = 1:numel(minAreas)
        text(j, i, string(found(i,j)), HorizontalAlignment="center", ...
            Color=[1 1 1]*(found(i,j) > 12));
    end
end
%[text] ## 量到的結果
%[text:table]
%[text] | Th＼MinArea | 20 | 40 | 80 | 150 | 250 |
%[text] | --- | --- | --- | --- | --- | --- |
%[text] | **5** | 23 | 23 | 23 | 22 | **17** |
%[text] | **10** | 23 | 23 | 23 | 21 | 13 |
%[text] | **15** | 23 | 23 | 22 | 20 | **1** |
%[text] | **20** | 23 | 23 | 22 | 18 | 0 |
%[text] | **25** | 23 | 23 | 21 | 14 | 0 |
%[text] | **30** | 23 | 22 | 18 | 4 | 0 |
%[text] | **40** | 18 | 15 | 7 | 0 | 0 |
%[text:table]
%[text] **第 3 小題：為什麼 `Threshold` 單獨變化時幾乎不影響幀數？**
%[text] 因為球和背景的顏色差距很大——綠球的 `G - max(R,B)` 遠大於 40，
%[text] 所以門檻從 5 調到 30，**球還是被抓到**。
%[text] 但它會改變**抓到多大**：
th = [3 5 8 10 15 20];
medianArea = zeros(size(th));
for i = 1:numel(th)
    a = nan(nBall,1);
    for k = 1:nBall
        r = ch23_ballSegmentFrame(ballFrames{k}, Threshold=th(i));
        if r.Found, a(k) = r.Area; end
    end
    medianArea(i) = median(a, "omitnan");
end
disp(table(th', medianArea', VariableNames=["Threshold" "最大區塊面積中位數"]))
%[text] 門檻從 3 調到 20，面積從 **323 掉到 189**（少了 41%）——
%[text] 門檻越嚴，只有越綠的核心像素留下來。
%[text] **第 4 小題：這兩個參數獨立嗎？不獨立。**
%[text] 看 `MinArea = 250` 那一欄：
%[text:table]
%[text] | Threshold | 5 | 10 | 15 | 20 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 偵測幀數 | **17** | 13 | **1** | 0 |
%[text:table]
%[text] **門檻越低反而抓得越多**——因為低門檻讓區塊變大，
%[text] 大到足以通過 `MinArea = 250` 的關卡。
%[text] > **一次只調一個參數會得到錯誤的結論。**
%[text] > 如果你先固定 `Threshold = 15`（在 `MinArea = 40` 時它表現完美），
%[text] > 再去調 `MinArea`，你會在 250 的地方看到「1 幀」，
%[text] > 結論是「`MinArea` 不能超過 150」。
%[text] > 但其實只要把門檻降到 5，`MinArea = 250` 還能抓到 17 幀。
%[text] > **這和第 12 章的光學參數、第 16 章的 Cascade 參數是同一類問題。**
%[text] **第 5 小題：`MinArea` 調到多少會丟掉第 42 幀？**
for ma = [40 60 80 100 150]
    tr = ch23_ballSegmentVideo("singleball.mp4", MinArea=ma);
    f = find(tr.Found);
    fprintf("MinArea=%3d：%2d 幀，最後一幀 = %d\n", ma, numel(f), f(end));
end
%[text] **介於 60 和 80 之間**——第 42 幀的球只有 70 像素。
%[text] **這算不算問題？看你要什麼。**
%[text:table]
%[text] | 用途 | 丟掉最後一幀 |
%[text] | --- | --- |
%[text] | 算平均速度 | 沒差 |
%[text] | 判斷球有沒有離開畫面 | **有差**，你會早一幀判定 |
%[text] | 算落點 | **有差**，而且是最重要的那一幀 |
%[text:table]
%[text] > **「最後幾幀最容易丟」不是巧合。** 物體遠離、光線變化、
%[text] > 部分出畫面——訊號在邊界一定最弱。
%[text] > **而這通常也是你最在意的那幾幀。**
%%
%[text] # 解答 2　先量雜訊，再相信加速
%[text] ## 我的預期
%[text] 「提到迴圈外」值 3–4 倍（第 7.1 節量過），
%[text] 「預先配置」值 1.2–1.3 倍。**第二項被推翻了。**
vTraffic = VideoReader("visiontraffic.avi");
nProfile = 150;
profFrames = cell(1, nProfile);
for k = 1:nProfile
    profFrames{k} = read(vTraffic, k);
end

variantName = ["① 都不做" "② 只提到迴圈外" "③ 只預先配置" "④ 兩者都做"];
config      = [false false; true false; false true; true true];

runVariant(profFrames, true, true);          % 熱身

nRepeat = 5;
if ipcvFast(), nRepeat = 2; end
elapsed = zeros(4, nRepeat);
for rep = 1:nRepeat
    for c = 1:4
        elapsed(c,rep) = runVariant(profFrames, config(c,1), config(c,2));
    end
end

med   = median(elapsed, 2);
lo    = min(elapsed, [], 2);
hi    = max(elapsed, [], 2);
noise = (hi - lo) ./ med * 100;

disp(table(variantName', med, lo, hi, noise, med(1)./med, ...
    VariableNames = ["做法" "中位數(s)" "最小" "最大" "全距%" "相對加速"]))

fprintf("\n同一設定重跑 %d 次，全距最大達到中位數的 %.1f%%" + "\n", ...
    nRepeat, max(noise));
%[text] ## 量到的結果
%[text:table]
%[text] | 做法 | 中位數 | 全距 | 相對加速 |
%[text] | --- | --- | --- | --- |
%[text] | ① 都不做 | 0.867 s | 48.9% | 1.00 |
%[text] | ② 只提到迴圈外 | 0.561 s | 33.5% | **1.54** |
%[text] | ③ 只預先配置 | 0.773 s | 61.7% | **1.12** |
%[text] | ④ 兩者都做 | 0.474 s | 23.4% | **1.83** |
%[text:table]
%[text] **第 3 小題：雜訊有多大？同一設定重跑 5 次，全距達 24–62%。**
%[text] **第 4 小題：哪些加速是真的？**
%[text:table]
%[text] | 手段 | 加速 | 雜訊 | 判斷 |
%[text] | --- | --- | --- | --- |
%[text] | 提到迴圈外 | 1.54 倍（+54%） | 33–49% | **勉強可信**，而且和第 7.1 節的獨立量測一致 |
%[text] | 預先配置 | 1.12 倍（+12%） | **25–62%** | **完全落在雜訊裡——測不出效果** |
%[text:table]
%[text] > **「預先配置」在這個迴圈裡是一個沒有效果的建議。**
%[text] > 四次獨立量測（主教材 §7.2 兩次、本題兩次）分別是
%[text] > **1.27、0.92、1.12、0.80 倍**——
%[text] > 橫跨「快 27%」到「慢 20%」，**兩次快、兩次慢**。
%[text] > 那不是一個被雜訊掩蓋的小效果，**那是沒有效果**。
%[text] 注意「提到迴圈外」的 1.54 倍也**只比雜訊大一點**。
%[text] 之所以敢相信它，是因為**有第二個獨立證據**：
%[text] 第 7.1 節的分段計時直接量到形態學那一段從 3.3 掉到 0.84 毫秒——
%[text] 那是同一個現象的另一種量法。
%[text] > **單一的端到端計時很難證明任何事。**
%[text] > 要嘛提高重複次數，要嘛**直接量你以為變快的那一段**。
%[text] **第 5 小題：只能做一件事就做「提到迴圈外」。**
%[text] 它效益大，而且第 7.1 節指出**有狀態的物件每幀重建還會讓答案錯**——
%[text] 那是比慢更嚴重的問題。
%[text] 預先配置仍然要寫，但理由是正確性（幀號對齊），不是速度。
%%
%[text] # 解答 3　GPU 的交叉點
hasGPU = false;
try
    gd = gpuDevice;
    hasGPU = true;
    fprintf("GPU：%s\n", gd.Name);
catch
    disp("沒有可用的 GPU，本題只列出既有量測值。")
end

if hasGPU && ~ipcvFast()
    frame1 = read(VideoReader("visiontraffic.avi"), 1);
    scales = [0.5 1 2 3 4 6];
    Pixels = zeros(numel(scales),1);
    CPUms  = zeros(numel(scales),1);
    GPUms  = zeros(numel(scales),1);
    for i = 1:numel(scales)
        I = imresize(frame1, scales(i));
        Pixels(i) = size(I,1) * size(I,2) / 1e6;
        CPUms(i)  = timeit(@() imgaussfilt(rgb2gray(I), 4)) * 1000;
        GPUms(i)  = gputimeit(@() gather(imgaussfilt(rgb2gray(gpuArray(I)), 4))) * 1000;
    end
    Speedup = CPUms ./ GPUms;
    disp(table(Pixels, CPUms, GPUms, Speedup))

    figure;
    semilogx(Pixels, Speedup, "o-", LineWidth=1.5); hold on
    yline(1, "--r", "CPU = GPU");
    grid on; xlabel("百萬像素"); ylabel("GPU 加速比");
    title("GPU 什麼時候才划算")
end
%[text] ## 量到的結果
%[text:table]
%[text] | 尺寸 | 百萬像素 | CPU | GPU | 加速 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 320×180 | 0.06 | 0.90 ms | 1.54 ms | **0.59** |
%[text] | 640×360 | 0.23 | 1.67 ms | 2.12 ms | **0.79** |
%[text] | 1280×720 | 0.92 | 6.32 ms | 4.68 ms | 1.35 |
%[text] | 1920×1080 | 2.07 | 13.15 ms | 9.24 ms | 1.42 |
%[text] | 2560×1440 | 3.69 | 23.99 ms | 15.14 ms | 1.58 |
%[text] | 3840×2160 | 8.29 | 51.08 ms | 32.18 ms | **1.59** |
%[text:table]
%[text] **第 1 小題：為什麼 GPU 要用 `gputimeit`？**
%[text] 因為 GPU 的呼叫是**非同步**的——`imgaussfilt(gpuArray(...))`
%[text] 會立刻回傳，實際運算還在排隊。`timeit` 量到的是「送出指令」的時間，
%[text] 不是「算完」的時間。`gputimeit` 會等 GPU 真正做完。
%[text] **第 2 小題：交叉點在 0.23 到 0.92 百萬像素之間**，
%[text] 大約 **0.5 MPix**（約 800×600）。
%[text] **第 3 小題：加速比不會一直上升。**
%[text] 從 0.92 MPix 的 1.35 倍到 8.29 MPix 的 1.59 倍，
%[text] **成長了 9 倍的像素只換來 18% 的加速改善——它飽和在 1.6 倍左右。**
%[text] 原因是搬運量和計算量**同步成長**：影像大一倍，
%[text] 要搬的資料也多一倍。高斯濾波的「計算/資料」比值是固定的，
%[text] 所以加速比會收斂到一個和這個比值有關的常數。
%[text] **第 4 小題：把多步驟留在 GPU 上——結果和第 8 節的說法不一致。**
if hasGPU && ~ipcvFast()
    I2 = imresize(frame1, 2);                 % 1280x720
    tCPUchain = timeit(@() imgaussfilt(imadjust(rgb2gray(I2)), 4)) * 1000;
    tGPUchain = gputimeit(@() gather(gpuChain(gpuArray(I2)))) * 1000;
    fprintf("三步驟 1280x720：CPU %.2f ms｜GPU（一次搬過去）%.2f ms｜加速 %.2f 倍\n", ...
        tCPUchain, tGPUchain, tCPUchain/tGPUchain);
    fprintf("對照：同尺寸只做一次 imgaussfilt 的加速是 %.2f 倍\n", Speedup(3));
end
%[text] 量到的是：
%[text:table]
%[text] | 工作（1280×720） | CPU | GPU | 加速 |
%[text] | --- | --- | --- | --- |
%[text] | 只做 `imgaussfilt` | 6.32 ms | 4.68 ms | **1.35** |
%[text] | `rgb2gray`→`imadjust`→`imgaussfilt`（一次搬過去） | 8.55 ms | 7.66 ms | **1.12** |
%[text:table]
%[text] > ## **這推翻了第 8 節的條件 ②**
%[text] > 第 8 節寫「資料能留在 GPU 上連續做好幾步」是划算的條件之一，
%[text] > 語氣像是「多做幾步會更划算」。**實測是反的**：
%[text] > 串三步的加速（1.12）比只做一步（1.35）**還差**。
%[text] > 原因是**每個函式的 GPU 實作品質不一樣**。
%[text] > `imgaussfilt` 在 GPU 上很有效率，但 `imadjust` 要算直方圖
%[text] >（需要 reduction，GPU 的弱項），它把整串的加速拖下來。
%[text] **第 5 小題：改寫後的條件。**
%[text:table]
%[text] | 原本的說法 | 改成 |
%[text] | --- | --- |
%[text] | 運算量夠大 | ✅ 維持。交叉點約 **0.5 MPix** |
%[text] | 資料能留在 GPU 上連續做好幾步 | ⚠ **「不用來回搬」是必要條件，但多串幾步不會更好。** 每多一步都要問那一步的 GPU 實作好不好 |
%[text] | 函式真的有 GPU 實作 | ✅ 維持，而且要加一句：**「有實作」不等於「實作得快」** |
%[text:table]
%[text] 追加一條第 8 節沒提的：
%[text] > **④ 加速比有上限。** 這台機器上，單一影像運算的天花板約 **1.6 倍**。
%[text] > 需要 10 倍以上的加速時，GPU 上的逐點濾波不是答案——
%[text] > 該換演算法，或換成深度學習那種計算/資料比極高的工作。
%%
%[text] # 解答 4　顯示要多頻繁才夠
if ipcvFast()
    disp("（快速模式：略過顯示計時，見下方既有量測值）")
else
    nDisp = 100;
    dispFrames = profFrames(1:nDisp);
    player = vision.VideoPlayer(Name="ch23 exercise 4");
    for k = 1:5, player(dispFrames{k}); end          % 熱身

    steps  = [1 2 5 10 0];
    label  = ["每 1 幀" "每 2 幀" "每 5 幀" "每 10 幀" "完全不顯示"];
    msPer  = zeros(numel(steps),1);
    se5    = strel("disk", 5);
    for i = 1:numel(steps)
        s = steps(i);
        t0 = tic;
        for k = 1:nDisp
            bw = imopen(imbinarize(rgb2gray(dispFrames{k})), se5);
            st = regionprops(bw, "Centroid"); %#ok<NASGU>
            if s > 0 && mod(k, s) == 0
                player(dispFrames{k});
            end
        end
        msPer(i) = toc(t0) / nDisp * 1000;
    end
    release(player);

    disp(table(label', msPer, 1000./msPer, ...
        VariableNames=["顯示間隔" "毫秒/幀" "fps"]))

    figure;
    plot([1 2 5 10], msPer(1:4), "o-", LineWidth=1.5); hold on
    yline(msPer(5), "--r", "完全不顯示");
    grid on; xlabel("每幾幀顯示一次"); ylabel("毫秒/幀");
    title("顯示成本隨間隔下降")
end
%[text] ## 量到的結果
%[text:table]
%[text] | 顯示間隔 | 毫秒/幀 | fps | 顯示的淨成本 |
%[text] | --- | --- | --- | --- |
%[text:table]
%[text] 兩次執行（毫秒/幀）：
%[text:table]
%[text] | 顯示間隔 | 第一次 | 第二次 | 顯示的淨成本 |
%[text] | --- | --- | --- | --- |
%[text] | 每 1 幀 | 7.7 | 3.96 | **+1.4 ~ +3.4 ms** |
%[text] | 每 2 幀 | 4.9 | 3.16 | +0.6 ms |
%[text] | 每 5 幀 | 4.5 | 2.54 | +0.2 ms 或 **−0.05** |
%[text] | 每 10 幀 | 4.0 | 2.66 | **−0.3 ~ +0.07** |
%[text] | 完全不顯示 | 4.3 | 2.59 | — |
%[text:table]
%[text] **第 3 小題：每 2 幀就砍掉 8 成以上的顯示成本。**
%[text] **第 4 小題：從每 5 幀開始就分不出來了。**
%[text] 兩次執行裡都出現了**比「完全不顯示」還快**的間隔
%[text]（第一次是每 10 幀，第二次是每 5 幀）——
%[text] 這在物理上不可能，**所以那是雜訊**。
%[text] 用練習 2 的尺標（全距可達中位數的 25–62%）來看，
%[text] 最後三列的數字**完全無法區分**。
%[text] > **這個「不可能的結果」本身就是證據。**
%[text] > 當你量到一個違反物理的差距時，不要去解釋它——
%[text] > 那是在告訴你雜訊比你想量的效果還大。
%[text] **第 5 小題：監看價值和顯示頻率不成正比。**
%[text] 30 fps 的來源每 5 幀顯示一次就是 6 fps，
%[text] **肉眼完全看得出畫面在動、東西在哪、有沒有明顯出錯**。
%[text] 從 6 fps 加到 30 fps，你多得到的資訊很少，
%[text] 卻要付 5 倍的顯示成本。
%[text] > **實務建議：開發時每 1 幀，跑批次時每 5–10 幀或完全關掉。**
%[text] > 而且**顯示的是給人看的，不是給程式看的**——
%[text] > 真正要記錄的東西應該寫進 log 或 table，不是畫在螢幕上。
%%
%[text] # 解答 5　量你自己的相機
nCapture = 60;
if ipcvFast(), nCapture = 15; end
[camFrames, camInfo] = ch23_captureFrames(nCapture, Warmup=0);
lat = camInfo.Latency * 1000;

fprintf("來源：%s（%s）解析度 %s\n", ...
    camInfo.Source, camInfo.Device, camInfo.Resolution);
fprintf("第一張 %.1f ms，是後面中位數（%.1f ms）的 %.1f 倍\n", ...
    camInfo.FirstMs, camInfo.MedianMs, camInfo.WarmupRatio);

steady = lat(11:end);
fprintf("\n丟掉前 10 張之後：\n");
fprintf("  中位數      %6.1f ms（%.1f fps）\n", median(steady), 1000/median(steady));
fprintf("  95 百分位   %6.1f ms（%.1f fps）\n", prctile(steady,95), 1000/prctile(steady,95));
fprintf("  最大值      %6.1f ms（%.1f fps）\n", max(steady), 1000/max(steady));

figure;
plot(lat, "o-", LineWidth=1.2); hold on
yline(median(steady), "--", "穩態中位數");
yline(prctile(steady,95), "--r", "95 百分位");
grid on; xlabel("第幾張"); ylabel("取像延遲（毫秒）");
title("取像延遲：第一張永遠是離群值")
%[text] ## 量到的結果（本機，Integrated Camera）
%[text] **第 2 小題：第一張是後面的 5 – 59 倍。**
%[text] 跨多次執行，第一張量到 **229、452、503、1015 毫秒**，
%[text] 而穩態在 **17 – 100 毫秒**之間。
%[text] **比值本身沒有規律**，因為分子和分母都在飄。
%[text] 唯一穩定的事實是：**第一張永遠是離群值，一律丟掉。**
%[text] **第 3 小題：驗收要用 95 百分位或最大值，不是中位數。**
%[text:table]
%[text] | 統計量 | 意義 | 該用在哪 |
%[text] | --- | --- | --- |
%[text] | 中位數 | 典型情況 | 估算吞吐量 |
%[text] | **95 百分位** | 二十次裡最慢的那一次 | **驗收規格** |
%[text] | 最大值 | 觀測到的最差 | 安全邊界／緩衝區大小 |
%[text:table]
%[text] > 「每一幀都要在 33 毫秒內」是一個**對每一幀**的要求，
%[text] > 所以要看分布的尾巴。用中位數驗收，等於默許 50% 的幀違規。
%[text] **第 4 小題：解析度和延遲不成正比。**
%[text:table]
%[text] | 解析度 | 像素比 | 量到的延遲 |
%[text] | --- | --- | --- |
%[text] | 320×240 | 1.0× | 99.9 ms |
%[text] | 640×480 | 4.0× | 32.1 – 96.4 ms |
%[text] | 1280×720 | 12.0× | 97.5 ms |
%[text] | 1920×1080 | 27.0× | **17.3 – 97.1 ms** |
%[text:table]
%[text] **像素多 27 倍，延遲沒有變。** 有幾次執行裡
%[text] 1920×1080 甚至是最快的（17.3 毫秒 = 57.8 fps）。
%[text] 因為 USB 相機的瓶頸**通常不是像素量**，而是
%[text] 曝光時間、USB 頻寬協商、以及驅動程式選了哪一種像素格式
%[text] （MJPEG 壓縮傳輸 vs YUY2 未壓縮，兩者的頻寬需求差很多）。
%[text] **第 5 小題：重跑三次的中位數差多少？**
%[text] 本機同一個解析度跨執行量到 **17.3、32.1、96.4、97.1 毫秒**——
%[text] **最快和最慢差 5.6 倍。**
%[text] > ## **這一題真正的結論**
%[text] > **你不能量一次就寫進規格。**
%[text] > 要在不同時段、不同照明、系統有其他負載時各量一次，
%[text] > 取**所有量測的最差 95 百分位**。
%[text] **第 6 小題：驗收規格的那一行應該長這樣：**
%[text] > 「本系統在**室內日光燈照明、解析度 1280×720、
%[text] > 固定曝光 −6、無其他 USB 裝置佔用頻寬**的條件下，
%[text] > 連續擷取 1000 張，取像延遲 95 百分位為 **98** 毫秒
%[text] > （對應 10.2 fps），第一張除外。」
%[text] 重點在**條件寫得比數字還長**。只寫「30 fps」的規格無法驗收，
%[text] 因為雙方對條件的假設不同。
%%
%[text] # 解答 6　換成你自己的影片
%[text] 這一題沒有標準答案，但**有一個可以檢查的標準**：
%[text] 你應該**只改了一支函式**。
%[text] 下面故意做一件**錯的**事：把綠球偵測器原封不動套到車流影片上，
%[text] 看驅動那一層會怎麼反應。
tr6 = ch23_ballSegmentVideo("viptraffic.avi", Threshold=30, MinArea=60);
fprintf("viptraffic.avi：%d 幀中「偵測到」%d 幀\n", ...
    height(tr6), nnz(tr6.Found));
%[text] **結果是 120 幀中 0 幀。** 車流影片裡沒有綠球，
%[text] 所以綠球偵測器一個都找不到——**這正是正確答案。**
%[text] 重點在於它的**失敗方式**：
%[text] - 沒有崩潰、沒有例外、沒有警告
%[text] - 回傳的 table 仍然有完整的 **120 列**
%[text] - `Found` 全部是 `false`，`X`／`Y` 全部是 `NaN`
%[text] > **「全部 `Found = false`」是一個你看得見、而且好診斷的失敗。**
%[text] > 對照加分題第 5 小題（忘記縮 `MinArea`）——**症狀一模一樣**。
%[text] > 所以看到滿江紅的 `NaN` 時，要問的不是「演算法爛不爛」，
%[text] > 而是「**這支單幀函式的前提，在這份資料上成立嗎**」。
%[text] 換成你自己的影片時，**第一件事就是看 `Found` 的比例**。
%[text] 這就是介面設計的價值：**換資料不會讓程式壞掉，只會讓答案變差**，
%[text] 而答案變差是看得見的。
if ~ipcvFast()
    [rep6, tot6] = ch23_pipelineProfile("viptraffic.avi", NumFrames=100);
    disp(rep6)
    fprintf("viptraffic（160x120）：%.2f 毫秒/幀，%.1f fps，來源 %.1f fps，即時 = %d\n", ...
        tot6.MsPerFrame, tot6.FPS, tot6.FrameRate, tot6.RealTime);
end
%[text] **注意 `viptraffic.avi` 只有 160×120。** 同一個管線在上面
%[text] 會快很多，但**瓶頸的排序可能不同**——
%[text] 影像越小，固定成本（函式呼叫、記憶體配置）佔比越高。
%[text] **第 5 小題的四個問題，示範答法：**
%[text:table]
%[text] | 問題 | 這個例子的答案 |
%[text] | --- | --- |
%[text] | 多少比例 `Found = false`？ | 要看實際輸出。**先問「那些幀發生了什麼事」，再決定是 bug 還是事實** |
%[text] | 跟得上幀率嗎？ | 160×120 綽綽有餘；但真正的問題是**來源換成 1080p 相機之後呢** |
%[text] | 瓶頸優化 2 倍，整體快多少？ | 瓶頸佔 43% 的話，整體只快 **1.27 倍**（Amdahl） |
%[text] | 丟幀還是降解析度？ | 看加分題——**在這個資料上降解析度贏**，但要重新量 |
%[text:table]
%%
%[text] # 加分題解答　丟幀 vs 降解析度
%[text] ## 我的預期
%[text] **丟幀的傷害比較小。** 理由是第 19 章練習 5、第 20 章 §7.1
%[text] 都量到降解析度會吃掉小物體，而丟幀至少保住了每個樣本的精度。
%[text] **這個預期被推翻了。**
skipS   = [1 2 3 5];
SkipN   = zeros(numel(skipS),1);
SkipRMS = zeros(numel(skipS),1);
SkipSec = zeros(numel(skipS),1);

for i = 1:numel(skipS)
    S   = skipS(i);
    idx = 1:S:nBall;
    X   = nan(nBall,1);
    Y   = nan(nBall,1);
    t0 = tic;
    for k = idx
        r = ch23_ballSegmentFrame(ballFrames{k});
        if r.Found
            X(k) = r.Centroid(1);
            Y(k) = r.Centroid(2);
        end
    end
    SkipSec(i) = toc(t0);
    SkipN(i)   = nnz(~isnan(X));

    good = find(~isnan(X));
    if numel(good) >= 2
        Xi = interp1(good, X(good), (1:nBall)', "linear", NaN);
        Yi = interp1(good, Y(good), (1:nBall)', "linear", NaN);
    else
        Xi = X; Yi = Y;
    end
    cmp = ~isnan(baseline.X) & ~isnan(Xi);
    SkipRMS(i) = sqrt(mean((baseline.X(cmp)-Xi(cmp)).^2 + ...
                           (baseline.Y(cmp)-Yi(cmp)).^2));
end
disp(table(skipS', SkipN, SkipRMS, SkipSec, ...
    VariableNames=["每S幀" "偵測到" "RMS(px)" "秒"]))

downD    = [1 2 3 4];
DownN    = zeros(numel(downD),1);
DownRMS  = zeros(numel(downD),1);
DownSec  = zeros(numel(downD),1);
DownSize = strings(numel(downD),1);

for i = 1:numel(downD)
    D = downD(i);
    X = nan(nBall,1);
    Y = nan(nBall,1);
    t0 = tic;
    for k = 1:nBall
        I = imresize(ballFrames{k}, 1/D);
        % **MinArea 要跟著 D^2 縮。** 忘了縮的後果見下面。
        r = ch23_ballSegmentFrame(I, MinArea = max(4, round(40/D^2)));
        if r.Found
            X(k) = r.Centroid(1) * D;       % 座標要乘回去
            Y(k) = r.Centroid(2) * D;
        end
    end
    DownSec(i) = toc(t0);
    DownN(i)   = nnz(~isnan(X));
    cmp = ~isnan(baseline.X) & ~isnan(X);
    DownRMS(i) = sqrt(mean((baseline.X(cmp)-X(cmp)).^2 + ...
                           (baseline.Y(cmp)-Y(cmp)).^2));
    s = size(imresize(ballFrames{1}, 1/D));
    DownSize(i) = sprintf("%dx%d", s(2), s(1));
end
disp(table(downD', DownSize, DownN, DownRMS, DownSec, ...
    VariableNames=["1/D" "尺寸" "偵測到" "RMS(px)" "秒"]))

figure;
plot(SkipSec, SkipRMS, "o-", LineWidth=1.5, DisplayName="策略A：丟幀"); hold on
plot(DownSec, DownRMS, "s-", LineWidth=1.5, DisplayName="策略B：降解析度");
grid on; legend(Location="northeast");
xlabel("耗時（秒）"); ylabel("質心 RMS 誤差（像素）");
title("相同耗時下，哪一個誤差小")
%[text] ## 量到的結果
%[text] **策略 A（丟幀，全解析度）**
%[text:table]
%[text] | 每 S 幀 | 偵測到 | RMS 誤差 |
%[text] | --- | --- | --- |
%[text] | 1 | 23 | 0.00 |
%[text] | 2 | **11** | 1.23 px |
%[text] | 3 | **8** | 1.53 px |
%[text] | 5 | **5** | 2.42 px |
%[text:table]
%[text] **策略 B（降解析度，每幀都處理）**
%[text:table]
%[text] | 1/D | 尺寸 | 偵測到 | RMS 誤差 | 耗時 |
%[text] | --- | --- | --- | --- | --- |
%[text] | 1 | 480×360 | 23 | 0.00 | 0.384 s |
%[text] | 2 | 240×180 | **23** | **0.74 px** | 0.157 s |
%[text] | 3 | 160×120 | **23** | 1.45 px | 0.128 s |
%[text] | 4 | 120×90 | **23** | 2.25 px | 0.125 s |
%[text:table]
%[text] **第 3、4 小題：降解析度在這份資料上全面勝出。**
%[text:table]
%[text] | 比較 | 丟幀 | 降解析度 |
%[text] | --- | --- | --- |
%[text] | RMS ≈ 1.2–1.5 px 時 | S=2：**11 個樣本** | D=3：**23 個樣本** |
%[text] | RMS ≈ 2.3–2.4 px 時 | S=5：**5 個樣本** | D=4：**23 個樣本** |
%[text] | 耗時 | 全解析度，省不了多少 | D=4 快 **3.1 倍** |
%[text:table]
%[text] **降解析度同時給出更小的誤差、更多的樣本、更短的時間。**
%[text] > ## **為什麼我的預期錯了**
%[text] > 我套用了第 19、20 章「下採樣吃掉小物體」的邏輯，
%[text] > 但**沒有先量這顆球有多大**。
%[text] > 球是 **220 像素**（直徑約 17 px）。縮 4 倍之後還有 14 像素、
%[text] > 直徑 4 px——**還在**。
%[text] > 這和第 22 章練習 1 是完全一樣的錯誤：
%[text] > **推理鏈正確，但我沒檢查前提在這份資料上成不成立。**
%[text] **「偵測到幾幀」為什麼比 RMS 重要？**
%[text] 因為 RMS 只在**兩者都有值**的幀上計算。
%[text] 丟幀的 RMS 看起來還好，是因為**內插幫它補了**——
%[text] 而內插的前提是「球在兩個樣本之間是直線等速運動」。
%[text] 球一旦轉向、彈跳、或在缺口期間被遮擋，**內插會給出一個
%[text] 看起來很合理但完全錯誤的位置**，而 RMS 不會告訴你這件事。
%[text] > **樣本數是資料，內插是假設。** 少了的樣本補不回來。
%[text] **第 5 小題：忘記縮 `MinArea` 的後果。**
fprintf("\n--- 常見錯誤：MinArea 固定在 40 ---\n");
for D = [2 3 4]
    cnt = 0;
    for k = 1:nBall
        r = ch23_ballSegmentFrame(imresize(ballFrames{k}, 1/D));  % 用預設 MinArea=40
        if r.Found, cnt = cnt + 1; end
    end
    fprintf("  D=%d：偵測到 %2d 幀（正確做法是 %d 幀）\n", D, cnt, nBaseline);
end
%[text:table]
%[text] | D | 偵測到 | 正確 |
%[text] | --- | --- | --- |
%[text] | 2 | 19 | 23 |
%[text] | 3 | **0** | 23 |
%[text] | 4 | **0** | 23 |
%[text:table]
%[text] **D = 3 開始就完全失效——0 幀，而且沒有任何錯誤訊息。**
%[text] 面積縮的是 **D²**：220 / 9 = 24 像素，過不了 `MinArea = 40`。
%[text] > **這是本章最危險的一個錯誤，因為它安靜。**
%[text] > 程式跑完、沒有警告、表格產出來了，只是**每一列都是 NaN**。
%[text] > 如果下游只畫「有偵測到的點」，你會看到一張空圖，
%[text] > 然後開始懷疑相機、懷疑光線、懷疑演算法——
%[text] > **而真正的原因是一個沒跟著縮的常數。**
%[text] > 和第 22 章練習 2 的「良品混進一張瑕疵」是同一類問題：
%[text] > **沒有錯誤訊息的失敗最貴。**
%[text] **第 6 小題：結論會因為球很大而改變嗎？會。**
%[text] 球佔 220 像素、直徑 17 px。如果目標只有 20 像素（直徑 5 px）：
%[text] - D = 2 之後只剩 5 像素，直徑 2.5 px
%[text] - D = 3 之後只剩 2 像素——**任何合理的 `MinArea` 都會濾掉它**
%[text] **那時候丟幀就會勝出**，因為它保住了每個樣本的空間精度。
%[text] > **所以正確的做法不是記住「降解析度比較好」，
%[text] > 而是記住這個判準：**
%[text] > $$D_{\max} \approx \sqrt{\frac{\text{目標面積}}{\text{可接受的最小面積}}}$$
%[text] > 先量你的目標有多少像素，再決定能縮幾倍。
%[text] > 這和第 22 章「先量你的瑕疵佔幾個像素」是同一句話。
%[text] 最後一個提醒：**如果瓶頸是取像速率而不是處理速度，
%[text] 降解析度救不了你**——第 11 節量到解析度和取像延遲幾乎無關。
%[text] 那時候只剩下丟幀（或換相機）。

% ========================================================================
% 本解答用到的本地函式

function seconds = runVariant(frames, hoistObjects, preallocate)
%RUNVARIANT 用指定的寫法跑一次逐幀管線，回傳耗時。
%   hoistObjects  strel 是否提到迴圈外
%   preallocate   結果容器是否預先配置
n = numel(frames);
if hoistObjects
    se = strel("disk", 5);
end
t0 = tic;
if preallocate
    C = nan(n, 2);
else
    C = [];
end
for k = 1:n
    bw = imbinarize(rgb2gray(frames{k}));
    if hoistObjects
        bw = imopen(bw, se);
    else
        bw = imopen(bw, strel("disk", 5));
    end
    s = regionprops(bw, "Centroid");
    if ~isempty(s)
        if preallocate
            C(k,:) = s(1).Centroid;
        else
            C(end+1,:) = s(1).Centroid; %#ok<AGROW>
        end
    end
end
seconds = toc(t0);
end

% ------------------------------------------------------------------------
function out = gpuChain(G)
%GPUCHAIN 三個步驟全部在 GPU 上做完，中間不搬回主記憶體。
out = imgaussfilt(imadjust(rgb2gray(G)), 4);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
