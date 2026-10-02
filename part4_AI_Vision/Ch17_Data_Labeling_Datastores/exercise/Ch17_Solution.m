%[text] # 第 17 章　練習解答
%[text] 資料標註、資料集與 Datastore
assert(exist("ch17_dupGroups","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

addons = matlab.addons.installedAddons;
hasGDINO = any(contains(addons.Name, "Grounding DINO"));
hasSAM   = any(contains(addons.Name, "Segment Anything"));

triDir = fullfile(toolboxdir("vision"), "visiondata", "triangleImages");
vroot  = fullfile(toolboxdir("vision"), "visiondata");
%%
%[text] # 解答 1：`labelIDs` 的驗證函式
%[text] 先用**正確**的對應，再故意對反，確認檢查抓得出來。
fprintf("=== 正確的對應 labelIDs = [255 0] ===\n");
r1 = checkLabelIDs(fullfile(triDir,"trainingImages"), ...
    fullfile(triDir,"trainingLabels"), ["triangle" "background"], [255 0]);
disp(r1)

fprintf("\n=== 故意對反 labelIDs = [0 255] ===\n");
r2 = checkLabelIDs(fullfile(triDir,"trainingImages"), ...
    fullfile(triDir,"trainingLabels"), ["triangle" "background"], [0 255]);
disp(r2)
%[text] **檢查抓到了。** 對反之後 `triangle` 佔 97.1% 而且它的區域比較亮——
%[text] 兩個線索都翻過來了，所以警告觸發。
%[text] **第 4 小題：什麼情況下這個檢查會失效？**
%[text] 這個檢查靠兩個假設，**兩個都可能不成立**：
%[text:table]
%[text] | 假設 | 什麼時候不成立 |
%[text] | --- | --- |
%[text] | 目標是少數類 | 語意分割的「道路」「天空」常佔畫面一半以上 |
%[text] | 目標比背景暗 | 目標與背景亮度接近，或目標本身有明暗變化 |
%[text:table]
%[text] 而且類別超過兩個時，「少數類」這個線索完全失去判別力——
%[text] 五個類別各佔 20% 的時候，對應關係有 5! = 120 種排列，
%[text] 像素佔比一個都分不出來。
%[text] **不依賴亮度的替代檢查：邊界一致性。**
%[text] 標籤的邊界應該和影像的**梯度**重合。
%[text] 若對應關係正確，在標籤邊界上取樣的影像梯度強度
%[text] 會明顯高於隨機位置的梯度強度。
%[text] **這個檢查對亮度方向不敏感**（梯度取絕對值），
%[text] 也不依賴類別佔比。下面驗證一下。
bd = boundaryGradientCheck(fullfile(triDir,"trainingImages"), ...
    fullfile(triDir,"trainingLabels"), ["triangle" "background"], [255 0]);
fprintf("\n邊界一致性檢查：\n");
fprintf("  標籤邊界上的平均梯度   = %.4f\n", bd.EdgeGrad);
fprintf("  隨機位置的平均梯度     = %.4f\n", bd.RandomGrad);
fprintf("  比值                   = %.2f 倍\n", bd.Ratio);
%[text] 比值遠大於 1，代表標籤邊界真的落在影像的邊緣上。
%[text] **這個檢查不管哪一類是哪一類都成立**——它驗證的是
%[text] 「標籤圖和影像有沒有對齊」，而不是「哪個 ID 對哪個名字」。
%[text] 所以它和亮度檢查是**互補**的：
%[text] 一個抓對齊錯誤（標籤檔和影像檔配對錯），
%[text] 一個抓命名錯誤（`labelIDs` 順序反了）。
%%
%[text] # 解答 2：讓標籤不同步，然後量它的代價
imdsTri = imageDatastore(fullfile(triDir,"trainingImages"));
pxdsTri = pixelLabelDatastore(fullfile(triDir,"trainingLabels"), ...
    ["triangle" "background"], [255 0]);

% --- 錯誤的管線：影像與標籤各自擲骰子 ---
% **注意這裡的 {} 不是筆誤。** combine 兩個 transformed datastore 時，
% 它會把兩邊的讀取結果 horzcat 起來；transform 直接回傳裸陣列的話，
% 會變成 horzcat(uint8, categorical) 而報
% 「Unable to concatenate a uint8 array and a categorical array」——
% 一個完全看不出原因的錯誤。transform 要自己包一層 cell。
imdsBad = transform(imdsTri, @(I) {randFlip(I)});
pxdsBad = transform(pxdsTri, @(L) {randFlipLabel(L)});
dsBad   = combine(imdsBad, pxdsBad);

% --- 正確的管線 ---
dsGood = ch17_buildPipeline(imdsTri, pxdsTri, OutputSize=[32 32], Augment=true);

N = 50;
offBad  = centroidOffsets(dsBad,  N);
offGood = centroidOffsets(dsGood, N);

fprintf("\n%-14s %10s %10s %14s\n", "管線", "中位偏差", "最大偏差", "偏差>5px 比例");
fprintf("%-14s %10.2f %10.2f %13.0f%%" + "\n", "錯誤（不同步）", ...
    median(offBad), max(offBad), 100*mean(offBad > 5));
fprintf("%-14s %10.2f %10.2f %13.0f%%" + "\n", "正確（同步）", ...
    median(offGood), max(offGood), 100*mean(offGood > 5));
%[text] **第 5 小題：有多少比例的樣本是壞的？為什麼是那個比例？**
%[text] 影像與標籤**各自獨立**決定要不要翻轉，每個都是 50/50。
%[text] 四種組合等機率：
%[text:table]
%[text] | 影像 | 標籤 | 結果 |
%[text] | --- | --- | --- |
%[text] | 不翻 | 不翻 | ✓ 一致 |
%[text] | 翻 | 翻 | ✓ 一致 |
%[text] | 翻 | 不翻 | ✗ **壞掉** |
%[text] | 不翻 | 翻 | ✗ **壞掉** |
%[text:table]
%[text] **所以理論值是 50%。** 實測：
%[text:table]
%[text] | 管線 | 中位偏差 | 最大偏差 | 偏差 > 5px |
%[text] | --- | --- | --- | --- |
%[text] | 錯誤（不同步） | 4.57 px | 20.67 px | **48%** |
%[text] | 正確（同步） | **0.33 px** | **2.08 px** | **0%** |
%[text:table]
%[text] **48% 對上理論的 50%**（50 個樣本的抽樣誤差內）。
%[text] > **這個 50% 是最惡毒的數字。**
%[text] > 若是 100% 壞掉，訓練會完全失敗，你馬上就會發現。
%[text] > 50% 壞掉的話，模型會從剩下一半的樣本學到東西，
%[text] > **loss 會下降、訓練會收斂、準確率只是差一點**——
%[text] > 差到你會以為是模型容量不夠、學習率不對、或資料不夠多。
%[text] > 然後你會花一週調那些**完全無關**的東西。
%%
%[text] # 解答 3：可重複使用的群組感知切分
%[text] 先在 DigitDataset 的子集上跑，看手寫數字有沒有近重複問題。
digitDir = fullfile(matlabroot, "toolbox", "nnet", "nndemos", ...
    "nndatasets", "DigitDataset");
imdsD = imageDatastore(digitDir, IncludeSubfolders=true, LabelSource="foldernames");
imdsSub = splitEachLabel(imdsD, 100, "randomized");   % 每類 100 張 = 1000 張

[imdsTr, imdsTe, rep3] = groupAwareSplit(imdsSub, 0.7);
fprintf("\nDigitDataset 子集（%d 張）：\n", numel(imdsSub.Files));
fprintf("  群組數 %d、有夥伴的影像 %d 張（%.1f%%）\n", ...
    rep3.NumGroups, rep3.NumWithPartner, 100*rep3.NumWithPartner/numel(imdsSub.Files));
fprintf("  訓練 %d／測試 %d，跨集合近重複 %.1f%%" + "\n", ...
    numel(imdsTr.Files), numel(imdsTe.Files), rep3.LeakPct);
fprintf("  同樣資料用純隨機切分：跨集合近重複 %.1f%%" + "\n", rep3.RandomLeakPct);
%%
%[text] ## 門檻掃描
thresholds = [0.90 0.93 0.95 0.97 0.98 0.99 0.995];
nGroups = zeros(size(thresholds));
nPartner = zeros(size(thresholds));

files3 = string(imdsSub.Files).';
% 相似度矩陣只算一次，門檻掃描重複使用。
% Threshold=1：餘弦相似度不可能嚴格大於 1，所以這次呼叫
% 不會產生任何群組、也不會發重複警告——我們只要那個矩陣。
% （不能傳 1.1，ch17_dupGroups 的 mustBeInRange 會擋掉。）
[~, S3] = ch17_dupGroups(files3, Threshold=1);
for k = 1:numel(thresholds)
    G = graph(S3 > thresholds(k), 'omitselfloops');
    g = conncomp(G).';
    sz = accumarray(g, 1);
    nGroups(k) = numel(sz);
    nPartner(k) = nnz(sz(g) > 1);
end

fprintf("\n%-10s %10s %14s %16s\n", "門檻", "群組數", "有夥伴影像", "最大群組大小");
for k = 1:numel(thresholds)
    G = graph(S3 > thresholds(k), 'omitselfloops');
    sz = accumarray(conncomp(G).', 1);
    fprintf("%-10.3f %10d %14d %16d\n", thresholds(k), nGroups(k), nPartner(k), max(sz));
end

figure
yyaxis left
plot(thresholds, nGroups, "o-", LineWidth=1.8); ylabel("群組數")
yyaxis right
plot(thresholds, 100*nPartner/numel(files3), "s--", LineWidth=1.8);
ylabel("有夥伴的影像 (%)")
xlabel("相似度門檻"); title("門檻怎麼選：群組數 vs 被判為重複的比例")
grid on
%[text] 實測（DigitDataset 每類 100 張，共 1000 張）：
%[text:table]
%[text] | 門檻 | 群組數 | 有夥伴影像 | 最大群組 |
%[text] | --- | --- | --- | --- |
%[text] | 0.900 | 808 | 344 | 5 |
%[text] | 0.950 | 933 | 128 | 3 |
%[text] | 0.980 | 986 | 28 | 2 |
%[text] | **0.990** | **995** | **10** | **2** |
%[text] | 0.995 | 998 | 4 | 2 |
%[text:table]
%[text] **手寫數字的重複問題比車輛影格小得多**：
%[text] 門檻 0.99 時只有 **10 張（1.0%）** 有夥伴，
%[text] 而 `vehicles` 是 **98 張（33%）**。
%[text] 對應的切分結果：群組感知 **0.0%**、純隨機 **0.7%**。
%[text] > **0.7% 不算嚴重，但它不是 0。** 而且你只有量過才知道是 0.7%
%[text] > 而不是 27%——`vehicles` 的 27% 也是「看起來沒問題」的資料集。
%[text] **第 5 小題：門檻該怎麼選？**
%[text] 看曲線的**崩塌點**。門檻降低時群組數會下降
%[text] （更多影像被合併成同一群），但下降是**不線性**的：
%[text] - 門檻很高時，只有真正的重複被抓到，群組數接近影像數
%[text] - 門檻降到某個值，**同類但不同張**的影像開始被合併，
%[text]   群組數急遽下降、最大群組急遽變大
%[text] **選在崩塌開始之前。** 從上表看最大群組大小：
%[text] 一旦它跳到幾十張，就代表你把整個類別綁成一群了——
%[text] 那時候群組感知切分會變成「把整個類別放到同一邊」，
%[text] 訓練集裡就沒有那一類了。
%[text] > **實務建議：從 0.99 開始，並且一定要看最大群組大小。**
%[text] > 這個數字比群組總數更能反映門檻有沒有設壞。
%%
%[text] # 解答 4：提示詞工程
if ~hasGDINO
    disp("（沒有 Grounding DINO 支援包，略過解答 4。）")
else
    v = load("vehicleTrainingData.mat"); fnv = fieldnames(v);
    vehicleTbl = v.(fnv{1});

    if ipcvFast()
        nImg = 6; disp("（快速模式：6 張影像。完整執行用 20 張。）")
    else
        nImg = 20;
    end
    idx4 = round(linspace(1, height(vehicleTbl), nImg));
    files4 = fullfile(vroot, string(vehicleTbl.imageFilename(idx4))).';
    gt4 = vehicleTbl.vehicle(idx4);

    prompts4 = [ ...
        "car"                        % 主教材的基準
        "a car"                      % 單字 -> 片語
        "a car on a road"            % 加場景脈絡
        "a small white car"          % 加外觀描述
        "a car seen from behind"     % 加視角
        "car . vehicle . automobile" % 多同義詞並列
        ].';

    tbl4 = ch17_promptSweep(files4, prompts4, gt4, ClassName="car");
    disp(tbl4)

    [bestAP, iAP] = max(tbl4.AP);
    [~, iRec] = max(tbl4.recall);
    fprintf("\nAP 最高：  %-28s %.4f（主教材最佳 0.9085）\n", ...
        tbl4.("提示詞")(iAP), bestAP);
    fprintf("recall 最高：%-26s %.1f%%" + "\n", ...
        tbl4.("提示詞")(iRec), tbl4.recall(iRec));
    if bestAP > 0.9085
        fprintf("**打敗主教材了。**\n");
    else
        fprintf("**沒打敗主教材**（0.9085）——誠實記錄下來。\n");
    end
end
%%
%[text] ## 第 4、5 小題：規律能不能推廣
if ~hasGDINO
    disp("（略過推廣驗證。）")
else
    % 換一個完全不同的類別：找人
    Ip = imread("visionteam.jpg");
    nPeople = 6;      % visionteam.jpg 有 6 個人（第 16 章已確認）
    promptsP = ["person", "a person", "a person standing in an office"].';

    fprintf("\n換類別驗證（visionteam.jpg，已知 %d 個人）：\n", nPeople);
    fprintf("%-34s %8s %10s\n", "提示詞", "框數", "最高分");
    for k = 1:numel(promptsP)
        dp = groundingDinoObjectDetector("swin-tiny", ...
            ClassNames="person", ClassDescriptions=promptsP(k));
        [bbp, scp] = detect(dp, Ip);
        keep = scp >= 0.35;
        fprintf("%-34s %8d %10.3f\n", promptsP(k), nnz(keep), max([scp; 0]));
    end
end
%[text] ## 量到的結果
%[text:table]
%[text] | 提示詞 | 框數 | precision | recall | AP | 刪 | 畫 |
%[text] | --- | --- | --- | --- | --- | --- | --- |
%[text] | `"car"`（主教材基準） | 65 | 33.8% | **100.0%** | 0.8733 | 43 | 0 |
%[text] | `"a car"` | 33 | 63.6% | 95.5% | 0.9136 | 12 | 1 |
%[text] | **`"a car on a road"`** | 46 | 45.7% | 95.5% | **0.9200** | 25 | 1 |
%[text] | `"a small white car"` | 26 | 76.9% | 90.9% | 0.8957 | 6 | 2 |
%[text] | `"a car seen from behind"` | 23 | **82.6%** | 86.4% | 0.8396 | **4** | 3 |
%[text] | `"car . vehicle . automobile"` | 71 | 31.0% | **100.0%** | 0.8719 | 49 | 0 |
%[text:table]
%[text] **打敗主教材了：`"a car on a road"` 的 AP 是 0.9200，
%[text] 主教材最佳是 0.9085。**（差距不大，但方向一致。）
%[text] 三個觀察：
%[text] **① 只是把 `"car"` 改成 `"a car"`，precision 就從 33.8% 跳到 63.6%，
%[text] 而 recall 只掉 4.5 個百分點。** 加一個冠詞讓框數從 65 掉到 33——
%[text] 這是整張表裡「性價比」最高的一個改動。
%[text] **② 多同義詞並列（`"car . vehicle . automobile"`）是最差的策略。**
%[text] 它給了最多的框（71 個）、最低的 precision（31.0%），
%[text] 而 AP 還比單純的 `"car"` 略低。
%[text] 直覺會以為「多給幾個同義詞能提高 recall」——
%[text] recall 確實是 100%，但 `"car"` 也是 100%，**代價卻多了 6 個誤框**。
%[text] **③ 描述越具體，precision 越高、recall 越低。**
%[text] `"a small white car"`（76.9%／90.9%）與
%[text] `"a car seen from behind"`（82.6%／86.4%）都符合這個方向。
%[text] 合理——加上外觀或視角條件就是在**縮小**接受範圍。
%[text] **第 4、5 小題的答案：不要相信「提示詞規律」。**
%[text] 在車輛資料集上找到的規律（例如「加冠詞、加場景脈絡比較好」）
%[text] 換到「找人」時**不成立**。實測：
%[text:table]
%[text] | 提示詞 | 框數（已知 6 人） | 最高分 |
%[text] | --- | --- | --- |
%[text] | `"person"` | 6 ✓ | **0.841** |
%[text] | `"a person"` | 6 ✓ | 0.478 |
%[text] | `"a person standing in an office"` | 6 ✓ | 0.477 |
%[text:table]
%[text] **三個提示詞都找到 6 個人，但信心分數差了 1.76 倍，
%[text] 而且方向和車子相反**——這次是**單字**最強，
%[text] 加冠詞反而讓分數腰斬。
%[text] 若我只在車輛資料集上做實驗，就會寫出
%[text] 「加冠詞比較好」這個**錯的通則**。
%[text] 原因是這些現象來自模型訓練語料的統計，**不是語意規則**：
%[text] - `"car"` 在 COCO 之類的語料裡是極常見的標籤字串
%[text] - `"vehicle"` 是上位詞，在標註語料裡少得多
%[text] - 場景脈絡有時有幫助（縮小搜尋），有時有害（過度限制）
%[text] > **所以提示詞不是「調一次就定案」的設定，
%[text] > 是每個新類別、新資料集都要重新掃一次的超參數。**
%[text] > 而掃描很便宜：20 張 x 6 個提示詞 ≈ 3 分鐘。
%[text] > 比事後發現整批標註有系統性偏差便宜太多。
%[text] **這一題最重要的收穫是方法論**：
%[text] 你在一個資料集上找到的「規律」，**必須在第二個資料集上驗證**
%[text] 才能叫規律。沒驗證過的都只是那個資料集的巧合。
%[text] （第 16 章練習 1 也踩過同一件事：我以為我猜對了背景 patch，
%[text] 其實只是因為場景產生器是我自己寫的。）
%%
%[text] # 解答 5：自動標註的總成本模型
%[text] **第 1 小題：三個時間參數**
%[text] 我用這組估計（依據寫在註解裡，你可以換成自己量的數字）：
t_draw   = 6.0;   % 從頭畫一個框：找目標 + 拖曳四邊 + 選類別
t_delete = 1.0;   % 刪一個框：點一下 + Delete
t_adjust = 2.5;   % 微調邊界：拖兩到四個控制點

fprintf("t_draw = %.1f 秒、t_delete = %.1f 秒、t_adjust = %.1f 秒\n", ...
    t_draw, t_delete, t_adjust);
%[text] 依據：`t_draw` 遠大於 `t_delete`，因為畫框包含
%[text] **視覺搜尋**（找出目標在哪）與**四邊對齊**兩件事，
%[text] 而刪除只需要辨認一個已經標出來的框是錯的。
%[text] `t_adjust` 介於中間：不用搜尋，但要對齊。
%[text] **第 2 小題：總時間公式**
%[text] 設 $N_{GT}$ 是真實目標數、$H$ 是命中數、
%[text] $F$ 是誤框數、$M = N_{GT} - H$ 是漏標數：
%[text] $$T_{manual} = N_{GT} \cdot t_{draw}$$
%[text] $$T_{auto} = F \cdot t_{delete} + M \cdot t_{draw} + H \cdot t_{adjust}$$
%[text] **關鍵是最後一項**：命中框的平均 IoU 只有 0.838，
%[text] 所以**每個命中框都還要調**。忽略這一項會高估自動標註的效益。
% 主教材 §10/§11 的實測數字
promptNames = ["car"; "vehicle"; "a car on the road"];
nGT     = [22; 22; 22];
nHit    = [22; 14; 21];
nFalse  = [43;  1; 17];
nMiss   = nGT - nHit;

T_manual = nGT * t_draw;
T_auto   = nFalse*t_delete + nMiss*t_draw + nHit*t_adjust;

fprintf("\n%-22s %10s %10s %10s %10s\n", "提示詞", "全人工(秒)", "自動(秒)", "省下", "省下%%");
for k = 1:numel(promptNames)
    fprintf("%-22s %10.0f %10.0f %10.0f %9.0f%%" + "\n", promptNames(k), ...
        T_manual(k), T_auto(k), T_manual(k)-T_auto(k), ...
        100*(T_manual(k)-T_auto(k))/T_manual(k));
end
%%
%[text] ## 第 4 小題：損益平衡點
%[text] 自動標註划算的條件是 $T_{auto} < T_{manual}$：
%[text] $$F \cdot t_{delete} + M \cdot t_{draw} + H \cdot t_{adjust} < N_{GT} \cdot t_{draw}$$
%[text] 把 $M = N_{GT} - H$ 代入並整理（設 $r = t_{draw}/t_{delete}$、
%[text] $a = t_{adjust}/t_{delete}$）：
%[text] $$H \cdot (r - a) > F$$
%[text] 也就是 $r > a + F/H$。用實測數字算：
a_ratio = t_adjust / t_delete;
fprintf("\na = t_adjust/t_delete = %.2f\n", a_ratio);
fprintf("\n%-22s %10s %14s %12s\n", "提示詞", "F/H", "需要 r >", "實際 r");
r_actual = t_draw / t_delete;
for k = 1:numel(promptNames)
    need = a_ratio + nFalse(k)/nHit(k);
    fprintf("%-22s %10.2f %14.2f %12.2f  %s\n", promptNames(k), ...
        nFalse(k)/nHit(k), need, r_actual, ...
        string(r_actual > need));
end
%[text] **結論：`"vehicle"` 的門檻最低（$r > 2.57$），`"car"` 最高（$r > 4.45$）。**
%[text] 我估的 $r = 6$ 讓三者都划算，**但差距很大**：
%[text] 若你的標註員刪框沒那麼快（$r$ 接近 3），
%[text] `"car"` 的 43 個誤框就會把效益吃掉。
%[text] > **這就是為什麼 §11 的答案不是「永遠選 recall 最高的」。**
%[text] > 正確的說法是：**recall 的漏標成本最貴（$r$ 倍），
%[text] > 但誤框也不是免費的。** 要選的是讓 $a + F/H$ 最小的提示詞，
%[text] > 而那通常是 precision 與 recall 都不錯的折衷
%[text] > （這裡是 `"a car on the road"`：$F/H = 0.81$）。
%[text] **我要修正主教材 §11 的說法。** 那裡寫
%[text] 「拿 VLM 做預標註時，要優化 recall，不是 precision」——
%[text] 那句話**方向對，但不完整**。完整的說法是：
%[text] **要最小化 $a + F/H$**，漏標的權重是 $r$ 倍所以 recall 更重要，
%[text] 但 precision 太差時誤框的總量還是會壓垮效益。
%%
%[text] ## 第 5 小題：什麼情況下自動標註不划算
%[text] **① 目標類別很罕見。**
%[text] 公式裡的 $H$ 在分母。若一千張影像裡只有五個目標，
%[text] $F/H$ 會非常大——模型在 995 張空影像上產生的每個誤框
%[text] 都要人去刪，而真正省下的畫框只有五個。
%[text] $$\text{1000 張、5 個目標、每張 1 個誤框} \Rightarrow F/H = 200$$
%[text] 這時候**全人工反而快**（而且人可以快速掠過空影像，
%[text] 根本不用逐張處理）。
%[text] **② 系統性偏差會累積成訓練集的錯誤。**
%[text] 主教材 §9 量到「分數最高的框 IoU = 0」。
%[text] 那不是隨機噪音——若模型在某種場景下**固定**把某個東西
%[text] 誤判成車，那批誤框會有**一致的外觀**。
%[text] 人在連續刪除幾百個相似的誤框之後會開始漏刪
%[text] （這是人的注意力特性，不是紀律問題），
%[text] 於是那個系統性偏差就流進訓練集，
%[text] **讓下游模型學到同一個錯誤**。
%[text] **③ 還有第三種，比前兩種更難發現。**
%[text] 自動標註會讓標註分布**偏向模型已經會的東西**。
%[text] VLM 找不到的困難樣本（遮擋、極小、非典型視角）
%[text] 會系統性地變成漏標，而那些**正是最有訓練價值的樣本**。
%[text] > 於是你用自動標註做出一個資料集，
%[text] > 訓練出一個「在簡單樣本上很好、在困難樣本上很差」的模型——
%[text] > **而你的測試集也是同一個流程標的，所以量不出這件事。**
%[text] 這是第 16 章練習 3「資料洩漏」的近親：
%[text] 不是同一張影像出現在兩邊，而是**同一個偏差同時汙染了訓練與評估**。
%[text] **緩解方法**：測試集一定要**全人工標註**，
%[text] 即使訓練集用自動標註。測試集小沒關係，但不能有同源偏差。
%%
%[text] # 解答 6：修好 MathWorks 的路徑
%[text] 先捕捉載入時的警告。
lastwarn("");
ws = warning("off", "all");
gtLoaded = load(fullfile(triDir, "triangleGroundTruth.mat"));
warning(ws);
gfn = fieldnames(gtLoaded);
gTruth = gtLoaded.(gfn{1});

% **注意 DataSource 的型別**：影片來源的 groundTruth 從舊的 .mat 載入後，
% DataSource 是一個 **char 路徑**，不是 groundTruthDataSource 物件。
% 寫 gTruth.DataSource.Source 會報
% 「Dot indexing is not supported for variables of type char」。
srcOrig = string(gTruth.DataSource);
fprintf("原始 DataSource（型別 %s）：\n", class(gTruth.DataSource));
fprintf("  %s\n", srcOrig);
fprintf("  這個檔案存在嗎？%s\n", string(isfile(srcOrig)));

pixPaths = string(gTruth.LabelData.PixelLabelData);
fprintf("\n像素標籤檔 %d 個，第一個：\n  %s\n", numel(pixPaths), pixPaths(1));
fprintf("  存在嗎？%s\n", string(isfile(pixPaths(1))));
%[text] 路徑指向 MathWorks 的建置機器。影片其實就在本機：
localVideo = fullfile(triDir, "triangleVideo.avi");
fprintf("\n本機的影片：%s\n", localVideo);
fprintf("  存在嗎？%s\n", string(isfile(localVideo)));
%%
%[text] ## 用 `changeFilePaths` 修正
%[text] **第 4 小題：`changeFilePaths` 的回傳值是「沒修好的路徑」。**
%[text] 這個回傳值是這個函式最重要的部分——
%[text] 它**不會**因為修不好而報錯，只會安靜地把改不動的留在回傳值裡。
%[text] **不檢查回傳值就等於沒修。**
% 舊路徑的前綴取到 triangleImages 為止——像素標籤檔在
% .../triangleImages/testLabels/ 底下，換掉這個前綴就能一起修好。
oldPrefix = extractBefore(srcOrig, "/triangleVideo.avi");
newPrefix = string(triDir);
fprintf("\n舊前綴：%s\n新前綴：%s\n", oldPrefix, newPrefix);

unresolved = changeFilePaths(gTruth, [oldPrefix newPrefix]);

fprintf("changeFilePaths 回傳 %d 筆未解析的路徑\n", numel(unresolved));
if ~isempty(unresolved)
    fprintf("未解析（前 3 筆）：\n");
    for k = 1:min(3, numel(unresolved))
        fprintf("  %s\n", string(unresolved(k)));
    end
end

% **changeFilePaths 會把 DataSource 的型別換掉。**
% 修正前它是 char，修正後變成 groundTruthDataSource 物件，
% 這時候 string(gTruth.DataSource) 會報
% 「Conversion to string from groundTruthDataSource is not possible」。
% 所以讀路徑要用一個型別無關的存取器（見底下的 srcPath）。
srcFixed = srcPath(gTruth);
fprintf("\n修正後的 DataSource（型別 %s）：\n  %s\n", ...
    class(gTruth.DataSource), srcFixed);
fprintf("  現在存在嗎？%s\n", string(isfile(srcFixed)));

pixFixed = string(gTruth.LabelData.PixelLabelData);
fprintf("像素標籤檔修好的比例：%d/%d\n", ...
    nnz(arrayfun(@isfile, pixFixed)), numel(pixFixed));
%[text] 換掉一個前綴就把**影片來源與全部像素標籤檔**一起修好了。
%[text] > **這正是為什麼要看回傳值。**
%[text] > `changeFilePaths` **修不好也不會報錯**，只會把改不動的
%[text] > 放進回傳值。若只看「有沒有報錯」，你永遠不知道還有幾個壞的。
%%
%[text] ## 第 5 小題：路徑健康檢查工具
%[text] 交接專案時第一件要跑的事。
health = groundTruthHealth(gTruth);
fprintf("\n=== groundTruth 路徑健康報告 ===\n");
fprintf("資料來源型別      ：%s\n", health.SourceType);
fprintf("資料來源檔案      ：%d 個，其中 %d 個找不到\n", ...
    health.NumSourceFiles, health.NumSourceMissing);
fprintf("像素標籤檔        ：%d 個，其中 %d 個找不到\n", ...
    health.NumPixelFiles, health.NumPixelMissing);
fprintf("標籤定義          ：%d 個（%s）\n", ...
    health.NumLabelDefs, strjoin(health.LabelNames, ", "));
if health.Healthy
    fprintf("**結論：路徑全部有效。**\n");
else
    fprintf("**結論：有 %d 個路徑失效，先修路徑再談訓練。**\n", ...
        health.NumSourceMissing + health.NumPixelMissing);
end
%[text] > **把這個檢查放進專案的 CI。** 標註檔的路徑失效
%[text] > 是「換一台電腦就會發生」的事，而它的症狀出現在訓練階段，
%[text] > 離原因很遠。在 CI 裡跑一次，五秒就能知道。
%%
%[text] # 加分題：Grounded SAM 的品質，以及誤差來源分解
if ~(hasGDINO && hasSAM)
    disp("（缺支援包，略過加分題。）")
else
    % triangleImages 有精確的像素 ground truth。放大到 256x256，
    % 因為 32x32 對 VLM 太小（它的骨幹有固定的 patch 大小）。
    dI = dir(fullfile(triDir,"trainingImages","*.jpg"));
    Ismall = imread(fullfile(dI(1).folder, dI(1).name));
    Ibig = repmat(imresize(Ismall, 8, Method="nearest"), 1, 1, 3);

    pxdsB = pixelLabelDatastore(fullfile(triDir,"trainingLabels"), ...
        ["triangle" "background"], [255 0]);
    Lb = read(pxdsB);
    gtMask = imresize(Lb{1} == "triangle", 8, Method="nearest");

    st = regionprops(gtMask, "BoundingBox");
    gtBox = st(1).BoundingBox;
    fprintf("\n真實三角形框：%s、遮罩像素 %d\n", ...
        mat2str(round(gtBox)), nnz(gtMask));

    % --- ① Grounded SAM：VLM 的框 -> SAM 的遮罩 ---
    [masksGS, boxGS, scoreGS] = ch17_groundedSAM(Ibig, "a dark triangle", ...
        ClassName="triangle", Threshold=0.3, MaxObjects=1);
    fprintf("Grounding DINO 的框：%s（分數 %.3f、與真實框 IoU %.3f）\n", ...
        mat2str(round(boxGS(1,:))), scoreGS(1), bboxOverlapRatio(boxGS(1,:), gtBox));

    % --- ② 上限：人工的框 -> SAM 的遮罩 ---
    sam = segmentAnythingModel;
    emb = extractEmbeddings(sam, Ibig);
    maskIdeal = segmentObjectsFromEmbeddings(sam, emb, size(Ibig), ...
        BoundingBox=gtBox);

    m1 = masksGS(:,:,1);
    % 標籤用 ASCII 的 (1)/(2)：CP950 主控台編不出 ①②（第 15 章的教訓）
    j1 = jaccard(m1, gtMask);
    j2 = jaccard(maskIdeal, gtMask);
    fprintf("\n%-28s %8s %8s %8s\n", "遮罩來源", "Jaccard", "Dice", "BFscore");
    fprintf("%-28s %8.4f %8.4f %8.4f\n", "(1) VLM 的框 -> SAM", ...
        j1, dice(m1, gtMask), bfscore(m1, gtMask));
    fprintf("%-28s %8.4f %8.4f %8.4f\n", "(2) 人工的框 -> SAM（上限）", ...
        j2, dice(maskIdeal, gtMask), bfscore(maskIdeal, gtMask));

    % 誤差來源分解
    totalErr = 1 - j1;
    boxErr   = j2 - j1;
    samErr   = 1 - j2;
    fprintf("\n總誤差（1 - Jaccard(1)）      = %.4f\n", totalErr);
    fprintf("  其中「框不準」貢獻          = %.4f（%.0f%%）\n", ...
        boxErr, 100*boxErr/totalErr);
    fprintf("  其中「SAM 本身的上限」貢獻  = %.4f（%.0f%%）\n", ...
        samErr, 100*samErr/totalErr);

    figure
    tiledlayout(1,3, TileSpacing="compact")
    nexttile; imshow(labeloverlay(Ibig, gtMask)); title("真實遮罩")
    nexttile; imshow(labeloverlay(Ibig, m1)); title("① VLM 框 -> SAM")
    nexttile; imshow(labeloverlay(Ibig, maskIdeal)); title("② 人工框 -> SAM")
end
%[text] ## 量到的結果
%[text:table]
%[text] | 遮罩來源 | Jaccard | Dice | BFscore |
%[text] | --- | --- | --- | --- |
%[text] | ① VLM 的框 → SAM | 0.4297 | 0.6011 | **0.7785** |
%[text] | ② 人工的框 → SAM（上限） | **0.5169** | **0.6815** | 0.7193 |
%[text:table]
%[text] Grounding DINO 的框是 `[191 6 64 73]`，真實框 `[193 9 64 72]`，
%[text] **兩者 IoU = 0.904——框抓得很準。**
%[text] **誤差來源分解：**
%[text:table]
%[text] | 來源 | Jaccard 損失 | 佔總誤差 |
%[text] | --- | --- | --- |
%[text] | 框不準（② − ①） | 0.087 | **15%** |
%[text] | SAM 本身的上限（1 − ②） | 0.483 | **85%** |
%[text:table]
%[text] **85% 的誤差不是框造成的，是 SAM 做不好這個形狀。**
%[text] 就算給它完美的人工框，Jaccard 也只有 0.517。
%[text] > **所以這裡該修的不是提示詞。** 換更大的骨幹、
%[text] > 調 `Threshold`、寫更好的英文——全都只能動那 15%。
%[text] 為什麼 SAM 在這麼簡單的圖形上這麼差？合理的推測是
%[text] **它的訓練分布裡沒有這種東西**：純色幾何圖形、
%[text] 硬邊界、無紋理、而且是從 32×32 放大 8 倍來的
%[text] （所以邊緣是階梯狀的）。SAM 學的是自然影像。
%[text] > **基礎模型在它的分布之外會安靜地退化**——
%[text] > 這和第 12 章「預設 NIQE 在工業影像上把好壞排反」是同一件事。
%[text] 順便注意 **BFscore 的排序和 Jaccard／Dice 相反**：
%[text] VLM 的框反而 BFscore 較高（0.7785 vs 0.7193）。
%[text] BFscore 量的是**邊界**的吻合度，Jaccard 量的是**面積**的重疊。
%[text] **又一次兩個指標給出相反排序**——這次是在同一個加分題裡。
%[text] **第 5 小題：誤差是框的誤差還是遮罩的誤差？**
%[text] **把兩者分開的方法就是上面做的那件事**：
%[text:table]
%[text] | 實驗 | 框的來源 | 遮罩的來源 | 量到什麼 |
%[text] | --- | --- | --- | --- |
%[text] | ① | Grounding DINO | SAM | **總誤差** |
%[text] | ② | 人工標註 | SAM | **遮罩本身的上限** |
%[text:table]
%[text] 兩者的差距就是**框的誤差貢獻**：
%[text] $$\text{框的誤差} = \text{Jaccard}_{②} - \text{Jaccard}_{①}$$
%[text] 這個分解在實務上決定你該修哪一邊：
%[text] - 若 ② 已經很低 → **SAM 就是做不好這種形狀**，換框也沒用
%[text] - 若 ② 高而 ① 低 → **框不準**，該去改提示詞或換更大的骨幹
%[text] > **這是誤差來源分解（error attribution），
%[text] > 第 19 章評估偵測器時會再用一次同樣的手法：
%[text] > 把「定位誤差」與「分類誤差」分開量。**
%[text] 一個常見的錯誤是只量 ①，然後憑直覺猜是哪一邊的問題。
%[text] **② 這個上限實驗很便宜（一次 SAM 呼叫），
%[text] 卻直接告訴你天花板在哪。**

% ========================================================================
function r = checkLabelIDs(imgDir, labelDir, classNames, labelIDs)
%CHECKLABELIDS 用兩個獨立線索驗證 labelIDs 的對應關係。
%
%   線索 1：目標類別應該是少數類
%   線索 2：目標覆蓋的區域，在原始影像上應該比背景暗（或亮，視任務而定）
dI = dir(fullfile(imgDir, "*.jpg"));
dL = dir(fullfile(labelDir, "*.png"));
if isempty(dI) || isempty(dL)
    error("checkLabelIDs:noFiles", "找不到影像或標籤檔。");
end

I = imread(fullfile(dI(1).folder, dI(1).name));
L = imread(fullfile(dL(1).folder, dL(1).name));
if size(I,3) > 1, I = im2gray(I); end

n = numel(classNames);
pct = zeros(n,1); meanBright = zeros(n,1);
for k = 1:n
    m = L == labelIDs(k);
    pct(k) = 100 * mean(m(:));
    if any(m(:))
        meanBright(k) = mean(double(I(m)));
    else
        meanBright(k) = NaN;
    end
end

r = table(classNames(:), labelIDs(:), pct, meanBright, ...
    VariableNames=["類別" "labelID" "像素佔比" "區域平均亮度"]);

% 第一類假定是「目標」。它應該是少數類。
if pct(1) > 50
    warning("checkLabelIDs:targetIsMajority", ...
        "「%s」佔了 %.1f%% 的像素——**目標類別通常不會是多數類**。" + ...
        "labelIDs 可能對反了。", classNames(1), pct(1));
end
% 目標區域的亮度不應該和整張影像的平均值一致
overall = mean(double(I(:)));
if ~isnan(meanBright(1)) && abs(meanBright(1) - overall) < 5
    warning("checkLabelIDs:noContrast", ...
        "「%s」區域的平均亮度 %.1f 與整張影像的 %.1f 幾乎相同——" + ...
        "標籤可能沒有對齊到任何實際結構。", ...
        classNames(1), meanBright(1), overall);
end
end

% ========================================================================
function r = boundaryGradientCheck(imgDir, labelDir, classNames, labelIDs)
%BOUNDARYGRADIENTCHECK 不依賴亮度方向的檢查：標籤邊界應該落在影像邊緣上。
dI = dir(fullfile(imgDir, "*.jpg"));
dL = dir(fullfile(labelDir, "*.png"));
nUse = min(20, min(numel(dI), numel(dL)));

eg = zeros(nUse,1); rg = zeros(nUse,1);
for k = 1:nUse
    I = im2double(imread(fullfile(dI(k).folder, dI(k).name)));
    if size(I,3) > 1, I = im2gray(I); end
    L = imread(fullfile(dL(k).folder, dL(k).name));

    Gmag = imgradient(I);                 % 不能對函式回傳值直接索引
    edge = bwperim(L == labelIDs(1));
    if ~any(edge(:)), continue, end

    eg(k) = mean(Gmag(edge));
    % 同樣數量的隨機位置當對照
    idx = randperm(numel(Gmag), nnz(edge));
    rg(k) = mean(Gmag(idx));
end
keep = eg > 0;
r = struct("EdgeGrad", mean(eg(keep)), "RandomGrad", mean(rg(keep)), ...
    "Ratio", mean(eg(keep)) / mean(rg(keep)));
end

% ========================================================================
function I = randFlip(I)
if rand > 0.5, I = fliplr(I); end
end

% ========================================================================
function L = randFlipLabel(L)
if iscell(L), L = L{1}; end
if rand > 0.5, L = fliplr(L); end
end

% ========================================================================
function off = centroidOffsets(ds, N)
%CENTROIDOFFSETS 量影像前景與標籤前景的質心偏差（主教材 §5 的檢查）。
reset(ds);
off = nan(N,1);
for k = 1:N
    if ~hasdata(ds), break, end
    d = read(ds);
    Ik = im2double(d{1});
    Lk = d{2};
    if iscell(Lk), Lk = Lk{1}; end
    Lk = Lk == "triangle";
    if ~any(Lk(:)), continue, end

    fg = Ik < graythresh(Ik);
    if ~any(fg(:)), continue, end

    sL = regionprops(Lk, "Centroid");
    sI = regionprops(fg, "Centroid");
    if isempty(sL) || isempty(sI), continue, end

    cL = sL(1).Centroid;
    cents = reshape([sI.Centroid], 2, []).';
    dists = vecnorm(cents - cL, 2, 2);
    off(k) = min(dists);
end
off = off(~isnan(off));
end

% ========================================================================
function [imdsTrain, imdsTest, report] = groupAwareSplit(imds, trainFrac)
%GROUPAWARESPLIT 群組感知切分，回傳兩個 datastore 與診斷報告。
files = string(imds.Files).';

ws = warning("off", "ch17_dupGroups:duplicatesFound");
[groupId, S, info] = ch17_dupGroups(files);
warning(ws);

n = numel(files);
ug = unique(groupId);
pg = ug(randperm(numel(ug)));
nTrG = round(trainFrac * numel(pg));
isTrain = ismember(groupId, pg(1:nTrG));

trIdx = find(isTrain);
teIdx = find(~isTrain);
imdsTrain = subset(imds, trIdx);
imdsTest  = subset(imds, teIdx);

% 診斷：群組感知 vs 純隨機
leak = 100 * mean(max(S(teIdx, trIdx), [], 2) > info.Threshold);

p = randperm(n);
nTr = round(trainFrac*n);
randLeak = 100 * mean(max(S(p(nTr+1:end), p(1:nTr)), [], 2) > info.Threshold);

report = struct( ...
    "NumGroups",      info.NumGroups, ...
    "NumWithPartner", info.NumWithPartner, ...
    "GroupSizes",     info.GroupSizes, ...
    "LeakPct",        leak, ...
    "RandomLeakPct",  randLeak);
end

% ========================================================================
function p = srcPath(gTruth)
%SRCPATH 型別無關地取出 groundTruth 的資料來源路徑。
%
%   `DataSource` 有兩種可能的型別，而且**同一個物件會在
%   changeFilePaths 之後改變型別**：
%     載入舊 .mat 之後      -> char（就是路徑本身）
%     changeFilePaths 之後  -> groundTruthDataSource 物件（路徑在 .Source）
%
%   所以任何讀取 DataSource 的程式碼都要同時處理兩種情況。
ds = gTruth.DataSource;
if isobject(ds) && isprop(ds, "Source")
    p = string(ds.Source);
else
    p = string(ds);
end
end

% ========================================================================
function h = groundTruthHealth(gTruth)
%GROUNDTRUTHHEALTH 檢查一個 groundTruth 物件的所有檔案路徑是否有效。
% DataSource 可能是 char 路徑，也可能是 groundTruthDataSource 物件
ds = gTruth.DataSource;
if isobject(ds) && isprop(ds, "Source")
    src = string(ds.Source);
else
    src = string(ds);
end
srcMissing = nnz(~arrayfun(@isfile, src));

% 像素標籤檔藏在 LabelData 的 PixelLabelData 欄位裡。
%
% **這裡有一個我第一版寫錯的地方**：影片來源的 LabelData 是
% **timetable**（有 Time 欄），而 `istable(timetable)` 回傳 **false**。
% 所以原本寫 `if istable(ld) && ...` 會整段被跳過，
% 健康報告安靜地回報「像素標籤檔 0 個」——
% **一個檢查工具自己回報「沒問題」，因為它什麼都沒檢查。**
nPix = 0; pixMissing = 0;
ld = gTruth.LabelData;
if (istable(ld) || istimetable(ld)) && ...
        any(strcmp(ld.Properties.VariableNames, "PixelLabelData"))
    pl = string(ld.PixelLabelData);
    pl = pl(pl ~= "" & ~ismissing(pl));
    nPix = numel(pl);
    pixMissing = nnz(~arrayfun(@isfile, pl));
end

h = struct( ...
    "SourceType",       string(class(gTruth.DataSource)), ...
    "NumSourceFiles",   numel(src), ...
    "NumSourceMissing", srcMissing, ...
    "NumPixelFiles",    nPix, ...
    "NumPixelMissing",  pixMissing, ...
    "NumLabelDefs",     height(gTruth.LabelDefinitions), ...
    "LabelNames",       string(gTruth.LabelDefinitions.Name).', ...
    "Healthy",          (srcMissing == 0) && (pixMissing == 0));
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
