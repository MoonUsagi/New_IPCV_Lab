%[text] # 第 21 章　練習解答
%[text] 視覺語言模型與零樣本視覺
assert(exist("ch21_clipEmbed","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

hasCLIP = probeModel(@() clipNetwork("vit-b-16"));
hasMD   = probeModel(@() moondream());
fprintf("CLIP %s、moondream %s\n", string(hasCLIP), string(hasMD));

vd = fullfile(toolboxdir("vision"), "visiondata");
digitDir = fullfile(matlabroot, "toolbox", "nnet", "nndemos", ...
    "nndatasets", "DigitDataset");
imdsAll = imageDatastore(digitDir, IncludeSubfolders=true, LabelSource="foldernames");
rng(0);
imdsSub = splitEachLabel(imdsAll, 60, "randomized");
[dsTrain, dsTest] = splitEachLabel(imdsSub, 0.67, "randomized");

if ipcvFast()
    nUse = 60; disp("（快速模式：60 張。完整執行 200 張。）")
else
    nUse = numel(dsTest.Files);
end
pick = round(linspace(1, numel(dsTest.Files), nUse));
files = string(dsTest.Files(pick)).';
yTrue = dsTest.Labels(pick);
classNames = string(categories(yTrue));

if hasCLIP
    clip = clipNetwork("vit-b-16");
    E = ch21_clipEmbed(clip, files);          % 影像嵌入只算一次
    fprintf("影像嵌入完成：%s\n", mat2str(size(E)));
end
%%
%[text] # 解答 1：打敗 0.49
%[text] 依 §7 的發現（CLIP 對應的是外觀不是符號），
%[text] 設計方向以「外觀」與「手寫」為主。
if ~hasCLIP
    disp("（沒有 CLIP，略過。）")
else
    templates = { ...
        "只有類別名（主教材最佳）", ""; ...
        "英文數字名",              "{}"; ...          % 後面會換成英文名
        "the handwritten numeral {}", "the handwritten numeral {}"; ...
        "a pen stroke forming {}",    "a pen stroke forming the number {}"; ...
        "white {} on black",          "a white number {} written on a black background"; ...
        "數字 {} 的形狀",             "the shape of the number {}" };

    % 「英文數字名」要換掉類別名本身，所以另外處理
    engNames = ["zero" "one" "two" "three" "four" ...
                "five" "six" "seven" "eight" "nine"];

    tbl1 = ch21_promptSweep(clip, E, templates(setdiff(1:size(templates,1),2), :), ...
        classNames, yTrue);
    disp(tbl1)

    ws = warning("off", "ch21_zeroShot:narrowSimilarityBand");
    [~, ~, rEng] = ch21_zeroShot(clip, E, engNames, classNames, yTrue);
    [~, ~, rEngT] = ch21_zeroShot(clip, E, ...
        "the handwritten digit " + engNames, classNames, yTrue);
    warning(ws);
    fprintf("\n英文數字名（zero, one, ...）             準確率 %.4f\n", rEng.Accuracy);
    fprintf("the handwritten digit + 英文名          準確率 %.4f\n", rEngT.Accuracy);

    best = max([tbl1.("準確率"); rEng.Accuracy; rEngT.Accuracy]);
    fprintf("\n本題最佳 %.4f（主教材最佳 0.4900）→ %s\n", best, ...
        string(best > 0.49) + "");
end
%[text] 量到的結果（快速模式 60 張）：
%[text:table]
%[text] | 樣板 | 準確率 |
%[text] | --- | --- |
%[text] | **`"white {} on black"`** | **0.5333** |
%[text] | **`"數字 {} 的形狀"`** | **0.5333** |
%[text] | 只有類別名（主教材最佳） | 0.4833 |
%[text] | `"a pen stroke forming {}"` | 0.4333 |
%[text] | 英文數字名（zero, one…） | 0.4167 |
%[text] | `"the handwritten numeral {}"` | 0.3833 |
%[text:table]
%[text] **打敗主教材了**（0.5333 vs 0.4900）。
%[text] **第 4、5 小題：規律是什麼？能推廣嗎？**
%[text] 贏的兩個樣板有一個共同點：**它們描述的是「看起來如何」**
%[text] （白色寫在黑底上、某個數字的形狀），
%[text] 而不是「這是什麼」。這和 §7 的發現一致。
%[text] 輸的兩個也一致：`"the handwritten numeral"` 與英文數字名
%[text] 都是**更抽象的符號指稱**，離視覺外觀更遠。
%[text] > **但第 5 點必須做。** 第 17 章練習 4 已經示範過：
%[text] > 在車輛資料集上找到的提示詞規律，換到「找人」就不成立。
%[text] > **沒有在第二個資料集上驗證過的規律，只是巧合。**
%[text] 解答 2 剛好就是那個驗證——它換到自然照片上。
%%
%[text] # 解答 2：領域距離的對照實驗
carFiles = string(fullfile(vd,"vehicles", ...
    {dir(fullfile(vd,"vehicles","*.jpg")).name})).';
signFiles = string(fullfile(vd,"stopSignImages", ...
    {dir(fullfile(vd,"stopSignImages","*.jpg")).name})).';
nPer = min([numel(carFiles) numel(signFiles) 41]);
rng(0);
carFiles = carFiles(randperm(numel(carFiles), nPer));
signFiles = signFiles(randperm(numel(signFiles), nPer));
filesNat = [carFiles; signFiles].';
yNat = categorical([repmat("car",nPer,1); repmat("stopSign",nPer,1)]);
natClasses = string(categories(yNat));

if ~hasCLIP
    disp("（略過。）")
else
    Enat = ch21_clipEmbed(clip, filesNat);
    ws = warning("off", "ch21_zeroShot:narrowSimilarityBand");
    [~, ~, rNat] = ch21_zeroShot(clip, Enat, "a photo of a " + natClasses, ...
        natClasses, yNat);
    warning(ws);
    fprintf("\n自然照片（車 vs 停止標誌，%d 張）準確率 = **%.4f**\n", ...
        numel(filesNat), rNat.Accuracy);
    fprintf("  相似度 %.4f-%.4f（全距 %.4f）、前二名差距中位數 %.4f\n", ...
        rNat.SimMin, rNat.SimMax, rNat.SimRange, rNat.TopGapMedian);

    % 公平比較：超越隨機的幅度
    accNat = rNat.Accuracy;  chNat = 1/numel(natClasses);
    accDig = 0.18;           chDig = 1/10;      % 主教材 §3 同樣的樣板
    fprintf("\n%-22s %10s %10s %14s\n", "任務", "準確率", "隨機基準", "超越隨機幅度");
    fprintf("%-22s %10.4f %10.2f %14.4f\n", "自然照片 2 類", accNat, chNat, ...
        (accNat-chNat)/(1-chNat));
    fprintf("%-22s %10.4f %10.2f %14.4f\n", "手寫數字 10 類", accDig, chDig, ...
        (accDig-chDig)/(1-chDig));
end
%[text] 量到的結果：
%[text:table]
%[text] | 任務 | 準確率 | 隨機基準 | **超越隨機幅度** |
%[text] | --- | --- | --- | --- |
%[text] | 自然照片 2 類（車 vs 停止標誌，82 張） | **0.8415** | 0.50 | **0.6829** |
%[text] | 手寫數字 10 類（同樣的樣板） | 0.1800 | 0.10 | **0.0889** |
%[text:table]
%[text] **超越隨機的幅度差了 7.7 倍，而且這次沒有撞到天花板**
%[text] （0.8415 不是 1.0000，所以第 18 章練習 1 的問題沒有重演）。
%[text] **還有一個更有說服力的證據：相似度的分布。**
%[text:table]
%[text] | 任務 | 相似度全距 | 前二名差距中位數 |
%[text] | --- | --- | --- |
%[text] | 自然照片 | **0.1879** | **0.0395** |
%[text] | 手寫數字 | 0.0634 | 0.0068 |
%[text:table]
%[text] **在領域內的資料上，相似度會攤開、前二名的差距大 6 倍。**
%[text] 所以 §5 講的「窄帶」**本身就是領域不匹配的症狀**，
%[text] 不是 CLIP 的固有性質。
%[text] > **這比準確率更能說明問題**：準確率會受類別數影響，
%[text] > 但相似度的分布是模型內部狀態的直接反映。
%[text] **第 5 小題：支持還是反駁？**
%[text] 用「超越隨機的幅度」比才公平（第 18 章練習 1 的教訓）。
%[text] 手寫數字用同樣的 `"a photo of {}"` 樣板只有 0.18，
%[text] 而隨機基準是 0.10——**超越隨機的幅度接近 0.09，幾乎等於沒學到**。
%[text] 自然照片的幅度看上面的輸出。
%[text] > **若自然照片的幅度明顯高，就支持「領域距離」的解釋。**
%[text] 但要注意兩個限制：
%[text] **① 天花板效應。** 車 vs 停止標誌可能太好分（第 18 章練習 1
%[text] 就是撞到 1.0000 才失敗的）。若這裡也接近 1.0，
%[text] 那只能說「至少不矛盾」，不能說「證明了」。
%[text] **② 任務難度也變了。** 兩個類別 vs 十個類別、
%[text] 差異明顯 vs 高度相似——**領域距離不是唯一的變數**。
%[text] 要乾淨地隔離領域距離，得固定任務難度只改領域
%[text] （例如把同一批數字做風格轉換），這個設計做不到。
%%
%[text] # 解答 3：把相似度變成可用的信心
%[text] **關鍵：校準集與評估集要分開**（否則就是第 16 章練習 3 的洩漏）。
if ~hasCLIP
    disp("（略過。）")
else
    % 固定樣板（§4.1：換樣板會同時改變準確率與差距分布）
    ws = warning("off", "ch21_zeroShot:narrowSimilarityBand");
    [predAll, Sall] = ch21_zeroShot(clip, E, classNames, classNames, yTrue);
    warning(ws);
    Ssort = sort(Sall, 1, "descend");
    gapAll = (Ssort(1,:) - Ssort(2,:)).';
    correct = predAll(:) == yTrue(:);

    n = numel(gapAll);
    rng(0); p = randperm(n);
    iCal = p(1:round(n/2));  iEva = p(round(n/2)+1:end);

    Ts = linspace(0, prctile(gapAll, 95), 12);
    accCal = nan(size(Ts)); rejCal = nan(size(Ts));
    for k = 1:numel(Ts)
        keep = gapAll(iCal) >= Ts(k);
        rejCal(k) = 1 - mean(keep);
        if any(keep), accCal(k) = mean(correct(iCal(keep))); end
    end

    fprintf("\n%-10s %12s %16s\n", "門檻T", "拒絕率", "被接受的準確率");
    for k = 1:numel(Ts)
        fprintf("%-10.4f %11.1f%% %15.4f\n", Ts(k), 100*rejCal(k), accCal(k));
    end

    % 找出校準集上達到 0.8 準確率的最小門檻
    ok = find(accCal >= 0.8, 1);
    if isempty(ok)
        fprintf("\n**校準集上沒有任何門檻能達到 0.80 的準確率。**\n");
        fprintf("最高只到 %.4f（拒絕率 %.1f%%）\n", max(accCal), ...
            100*rejCal(find(accCal==max(accCal),1)));
    else
        Tstar = Ts(ok);
        keepE = gapAll(iEva) >= Tstar;
        fprintf("\n校準集選出的門檻 T = %.4f（拒絕率 %.1f%%）\n", ...
            Tstar, 100*rejCal(ok));
        fprintf("**在評估集上**：拒絕率 %.1f%%、被接受的準確率 %.4f\n", ...
            100*(1-mean(keepE)), mean(correct(iEva(keepE))));
    end

    figure
    yyaxis left;  plot(Ts, 100*rejCal, "o-", LineWidth=1.8); ylabel("拒絕率 (%)")
    yyaxis right; plot(Ts, accCal, "s--", LineWidth=1.8);   ylabel("被接受的準確率")
    xlabel("前二名差距的門檻 T"); grid on
    title("拒絕低信心樣本的取捨（校準集）")
end
%[text] ## 量到的結果——**門檻沒有轉移過去**
%[text] 校準集上掃描的結果：
%[text:table]
%[text] | 門檻 T | 拒絕率 | 被接受的準確率 |
%[text] | --- | --- | --- |
%[text] | 0.0000 | 0% | 0.4667 |
%[text] | 0.0025 | 60.0% | 0.7500 |
%[text] | **0.0038** | **73.3%** | **0.8750** |
%[text] | 0.0057 | 90.0% | 1.0000 |
%[text:table]
%[text] 校準集選出 T = 0.0038（達到 0.875）。
%[text] **搬到評估集上：拒絕率同樣 73.3%，但準確率只有 0.5000。**
%[text] **從 0.875 掉到 0.500——門檻完全沒有轉移過去。**
%[text] > **這就是為什麼第 2 小題要求把校準集與評估集分開。**
%[text] > 若省掉這一步，你會回報「拒絕 73% 可以換到 87.5% 準確率」，
%[text] > 而實際上只有 50%。
%[text] 為什麼會差這麼多？因為**校準集只有 30 張**，
%[text] 而在窄帶分布下，門檻附近的樣本非常密集——
%[text] 少數幾張的運氣就會移動整條曲線。
%[text] 這是第 18 章 §6.1 的老問題：**樣本太少，估計不穩。**
%[text] **第 6 小題：要 80% 準確率得拒絕多少？**
%[text] 在校準集上是 73.3%，**但那個數字不可信**（見上）。
%[text] 誠實的答案是：**用這個設定估不出來**——
%[text] 要先有更大的校準集。而那本身就是結論：
%[text] > **當所有相似度都擠在一起時，沒有任何門檻能把對與錯分開。**
%[text] > 拒絕率拉到很高只會同時丟掉對的和錯的。
%[text] 若真的做不到，實務上的選項是：
%[text] 1. **換樣板**（§4：好樣板能把準確率從 0.18 拉到 0.49）
%[text] 2. **改用 CLIP 嵌入 + 分類器**（解答 5）
%[text] 3. **接受它只是個粗篩**，後面一定要有人工
%%
%[text] # 解答 4：外觀描述 vs 類別代號
if ~hasCLIP
    disp("（略過。）")
else
    % 每個數字的外觀描述（刻意用筆劃的形狀，不提數字本身）
    shapeDesc = [ ...
        "a closed oval loop"                      % 0
        "a single vertical stroke"                % 1
        "a curve with a flat horizontal base"     % 2
        "two stacked curves open to the left"     % 3
        "two strokes crossing to form a corner"   % 4
        "a horizontal top bar above a curve"      % 5
        "a loop at the bottom with a curved tail" % 6
        "a horizontal bar with a diagonal stroke" % 7
        "two stacked closed loops"                % 8
        "a loop at the top with a straight tail"  % 9
        ];
    codeDesc = "the digit " + classNames;

    fprintf("\n%-6s %16s %16s\n", "類別", "代號式 P@5", "外觀式 P@5");
    pCode = zeros(10,1); pShape = zeros(10,1);
    for k = 1:numel(classNames)
        [rc, ~] = ch21_textSearch(clip, E, files, codeDesc(k), TopK=5, ...
            TrueLabels=yTrue, Relevant=classNames(k));
        [rs, ~] = ch21_textSearch(clip, E, files, shapeDesc(k), TopK=5, ...
            TrueLabels=yTrue, Relevant=classNames(k));
        pCode(k)  = mean(string(yTrue(rc.("索引"))) == classNames(k));
        pShape(k) = mean(string(yTrue(rs.("索引"))) == classNames(k));
        fprintf("%-6s %16.2f %16.2f\n", classNames(k), pCode(k), pShape(k));
    end
    fprintf("\n平均 P@5：代號式 **%.3f**、外觀式 **%.3f**\n", ...
        mean(pCode), mean(pShape));
    [~, iWin] = max(pShape - pCode);
    [~, iLose] = min(pShape - pCode);
    fprintf("外觀描述贏最多：類別 %s（+%.2f）\n", classNames(iWin), ...
        pShape(iWin)-pCode(iWin));
    fprintf("外觀描述輸最多：類別 %s（%.2f）\n", classNames(iLose), ...
        pShape(iLose)-pCode(iLose));
end
%[text] ## 量到的結果——**平均打平，但逐類別差異巨大**
%[text:table]
%[text] | | 代號式 P@5 | 外觀式 P@5 |
%[text] | --- | --- | --- |
%[text] | **平均** | **0.200** | **0.200** |
%[text] | 類別 0 | 0.00 | **0.60** |
%[text] | 類別 6 | **0.60** | 0.00 |
%[text] | 類別 2 | 0.20 | 0.60 |
%[text] | 類別 4、5 | 0.40 | 0.00 |
%[text:table]
%[text] **平均完全打平（0.200 vs 0.200），這和我的預期不同。**
%[text] §7 看到「a round shape」全對、「the digit zero」全錯，
%[text] 我原本預期外觀描述會全面勝出。**十個類別平均下來沒有。**
%[text] 但逐類別看，差異非常大：類別 0 外觀式贏 0.60，
%[text] 類別 6 反而輸 0.60。
%[text] > **§7 的觀察是對的，但它是一個「類別 0 的現象」，
%[text] > 不是一個通則。** 單一例子推不出規律——
%[text] > 這是第 17 章練習 4、第 18 章 §6 反覆出現的同一個教訓。
%[text] 為什麼類別 0 特別吃外觀描述？因為「閉合的橢圓環」
%[text] 是一個**乾淨而且獨特**的描述。而 6 的「底部有環加彎尾」
%[text] 和 9、8 的描述重疊太多，寫得再仔細也分不開。
%[text] **第 5 小題：哪些數字的外觀描述比較難寫？**
%[text] **3 和 8、6 和 9** 最難——它們的外觀描述會高度重疊
%[text] （「兩個疊起來的曲線」vs「兩個疊起來的閉合環」；
%[text] 「底部有環」vs「頂部有環」）。
%[text] 而那正是它們在混淆矩陣裡互相混淆的原因。
%[text] > **外觀描述的可分辨性，就是 CLIP 在這個任務上的能力上限。**
%[text] > 若你用文字都寫不出兩個類別的差別，
%[text] > CLIP 也不可能靠文字把它們分開。
%[text] **這給了一個實用的事前檢查**：
%[text] 要用 CLIP 做零樣本分類之前，先問自己
%[text] 「**我能不能用一句話講清楚每個類別長什麼樣，而且彼此不重複？**」
%[text] 答不出來的話，零樣本大概不會work。
%%
%[text] # 解答 5：CLIP 嵌入當特徵
if ~hasCLIP
    disp("（略過。）")
else
    trFiles = string(dsTrain.Files).';
    yTr = dsTrain.Labels;
    if ipcvFast()
        pickTr = round(linspace(1, numel(trFiles), 120));
        trFiles = trFiles(pickTr); yTr = yTr(pickTr);
    end
    Etr = ch21_clipEmbed(clip, trFiles);

    t = tic;
    mdlCLIP = fitcecoc(Etr.', yTr, Learners="linear");
    secFit = toc(t);
    predCLIP = predict(mdlCLIP, E.');
    accCLIP = mean(predCLIP(:) == yTrue(:));

    fprintf("\n%-28s %14s %10s\n", "做法", "標註需求", "準確率");
    fprintf("%-28s %14s %10.4f\n", "CLIP 零樣本（最佳樣板）", "0", 0.49);
    fprintf("%-28s %14s %10.4f\n", "**CLIP 嵌入 + SVM**", ...
        sprintf("%d 張", numel(trFiles)), accCLIP);
    fprintf("%-28s %14s %10s\n", "ResNet-18 特徵 + SVM（第 18 章）", "每類 40", "約 0.85");
    fprintf("擬合分類器只要 %.2f 秒\n", secFit);
    clear clip
end
%[text] 量到的結果（快速模式，**訓練集只有 120 張**）：
%[text:table]
%[text] | 做法 | 標註需求 | 準確率 |
%[text] | --- | --- | --- |
%[text] | CLIP 零樣本（最佳樣板） | 0 | 0.4900 |
%[text] | **CLIP 嵌入 + SVM** | 120 張 | **0.6000** |
%[text] | ResNet-18 特徵 + SVM（第 18 章） | 400 張 | 約 0.85 |
%[text:table]
%[text] > **注意這個比較不公平**：快速模式下 CLIP 只用了 120 張訓練，
%[text] > 第 18 章用了 400 張。完整執行時兩者才對等。
%[text] **第 5 小題：CLIP 的嵌入是好特徵嗎？**
%[text] **比零樣本好（0.60 vs 0.49），但比 ResNet-18 差。**
%[text] 這個結果比我原本預期的更有意思：
%[text] > **區分十個數字所需要的資訊，本來就在 CLIP 的嵌入裡，
%[text] > 只是「用文字去取」的方式取不出來。**
%[text] 這修正了 §6 對「零樣本為什麼差」的解釋。
%[text] 原本的說法是「領域距離遠，所以嵌入不好」；
%[text] 更精確的說法是：
%[text:table]
%[text] | 問題 | 在哪一端 |
%[text] | --- | --- |
%[text] | 影像嵌入有沒有包含足夠的資訊？ | **有**（SVM 取得出來） |
%[text] | **文字嵌入能不能對到那些資訊？** | **不能**（零樣本只有 0.49） |
%[text:table]
%[text] **瓶頸在兩端都有，而且可以分開量：**
%[text:table]
%[text] | 比較 | 差距 | 代表什麼 |
%[text] | --- | --- | --- |
%[text] | 零樣本 0.49 → CLIP 嵌入+SVM 0.60 | **+0.11** | **文字端**的損失 |
%[text] | CLIP 嵌入+SVM 0.60 → ResNet 0.85 | **+0.25** | **影像端**的落差 |
%[text:table]
%[text] 所以「零樣本為什麼差」的完整答案是**兩個原因疊加**：
%[text] 文字嵌入對不上（+0.11），而且 CLIP 的影像編碼器
%[text] 在手寫數字上本來就不如 ImageNet 訓練的 ResNet（+0.25）。
%[text] **影像端的問題還比較大。**
%[text] （再次提醒：上面的 0.60 是用 120 張訓練得到的，
%[text] 完整執行時這個分解的比例可能會變。）
%[text] 這也解釋了 §7 的現象：用外觀描述（"a round shape"）
%[text] 比用符號代號（"the digit zero"）有效——
%[text] **外觀描述比較接近影像編碼器實際編碼的東西。**
%[text] > 這是第 17 章加分題「誤差來源分解」的同一個手法：
%[text] > 把一個總體的失敗拆成兩端，找出瓶頸在哪一端。
%%
%[text] # 解答 6：Moondream 的輸出可重現嗎
if ~hasMD || ~hasCLIP || ipcvFast()
    disp("（缺套件或處於快速模式，略過。）")
else
    md = moondream();
    I1 = imread("peppers.png");
    I2 = imread("visionteam.jpg");

    caps1 = strings(5,1);
    for k = 1:5
        caps1(k) = string(captionImage(md, I1));
    end
    cap2 = string(captionImage(md, I2));
    clear md

    fprintf("\n同一張圖的五個描述：\n");
    for k = 1:5
        fprintf("  %d. %s\n", k, caps1(k));
    end
    fprintf("\n字面完全相同的比例：%.0f%%" + "\n", ...
        100*mean(caps1 == caps1(1)));

    % 用 CLIP 的文字嵌入量語意相似度
    clip2 = clipNetwork("vit-b-16");
    Tc = double(extractTextEmbeddings(clip2, [caps1; cap2].'));
    Tc = Tc ./ vecnorm(Tc);
    Sc = Tc.' * Tc;
    within = Sc(1:5, 1:5);
    within = within(triu(true(5),1));
    across = Sc(1:5, 6);
    fprintf("\n同一張圖的描述之間：語意相似度 %.4f ± %.4f\n", ...
        mean(within), std(within));
    fprintf("不同圖的描述之間：    語意相似度 %.4f ± %.4f\n", ...
        mean(across), std(across));
    fprintf("**差距 %.4f**\n", mean(within) - mean(across));
    clear clip2
end
%[text] **第 5 小題：Moondream 的輸出穩不穩定？**
%[text] 看兩組相似度的差距。
%[text] - **同一張圖的五個描述**之間的語意相似度應該明顯較高
%[text] - **不同圖的描述**之間應該低得多
%[text] 若差距很大 → **措辭會變，但語意是穩定的**。
%[text] 那代表你可以信任它的**內容**，但不能信任它的**字串**。
%[text] > **實務上的做法**：
%[text] > 不要用 `strcmp` 比對 Moondream 的輸出，
%[text] > 要用語意嵌入（例如 CLIP 的文字編碼器）比較。
%[text] **這一題最值得注意的是方法本身：用 CLIP 來評估 Moondream。**
%[text] 兩個 VLM 的能力互補——一個產生自由文字，
%[text] 另一個把文字變成可以量距離的向量。
%%
%[text] # 加分題：決策樹的成本模型
%[text] **第 1 小題：三個成本參數**（用 §9 的實測值）
c_label   = 8;        % 標註一張影像（看圖 + 選類別 + 存檔）
c_zs      = 0.20;     % CLIP 零樣本每張（§9 實測）
c_tr      = 0.05;     % ResNet-18 特徵 + SVM 每張（§9 實測）
c_train   = 30;       % 訓練一次（抽特徵 + 擬合），一次性
fprintf("\nc_label %.1f 秒、零樣本 %.2f 秒/張、訓練後 %.2f 秒/張、訓練 %.0f 秒\n", ...
    c_label, c_zs, c_tr, c_train);

%[text] **第 2、3 小題：總成本與損益平衡點**
%[text] 設要處理 $M$ 張影像、標註 $N$ 張：
%[text] $$T_{zs} = M \cdot c_{zs}$$
%[text] $$T_{tr} = N \cdot c_{label} + c_{train} + M \cdot c_{tr}$$
N = 400;                       % 每類 40 張 x 10 類
Mgrid = round(logspace(2, 6, 9));
fprintf("\n%-12s %14s %14s %10s\n", "影像數 M", "零樣本(秒)", "標註+訓練(秒)", "誰便宜");
for M = Mgrid
    Tzs = M*c_zs;
    Ttr = N*c_label + c_train + M*c_tr;
    fprintf("%-12d %14.0f %14.0f %10s\n", M, Tzs, Ttr, ...
        string(Tzs < Ttr) + "");
end
Mstar = (N*c_label + c_train) / (c_zs - c_tr);
fprintf("\n**損益平衡點 M* = %.0f 張**\n", Mstar);
%[text] **只看時間成本，超過約 2 萬張影像，標註 + 訓練就比零樣本便宜。**
%[text] 而那還沒算準確率的差別。
%[text] **第 4 小題：把錯誤的成本加進來**
c_error = 30;                  % 每答錯一張的下游成本
acc_zs = 0.49; acc_tr = 0.85;
fprintf("\n%-12s %16s %16s %10s\n", "影像數 M", "零樣本總成本", "訓練總成本", "誰便宜");
for M = Mgrid
    Tzs = M*c_zs + M*(1-acc_zs)*c_error;
    Ttr = N*c_label + c_train + M*c_tr + M*(1-acc_tr)*c_error;
    fprintf("%-12d %16.0f %16.0f %10s\n", M, Tzs, Ttr, string(Tzs < Ttr) + "");
end
Mstar2 = (N*c_label + c_train) / ...
    ((c_zs + (1-acc_zs)*c_error) - (c_tr + (1-acc_tr)*c_error));
fprintf("\n**加入錯誤成本後，損益平衡點降到 M* = %.0f 張**\n", Mstar2);
%[text] **加入準確率之後，平衡點從兩萬張掉到幾百張。**
%[text] 因為零樣本每答錯一張都有下游成本，而它錯得多很多。
%[text] > **「不用標註」聽起來免費，但錯誤是有價的。**
%[text] > 一旦把錯誤成本算進去，「標 400 張」很快就回本。
%[text] **第 5 小題：什麼時候即使一百萬張，零樣本仍然是對的？**
%[text] 至少三種情況：
%[text] **① 類別會一直變動。** 電商的商品標籤、社群的內容分類——
%[text] 每加一個新類別，訓練路線就要重新標註與重訓，
%[text] 而零樣本只要加一句文字。**成本模型裡的 $N \cdot c_{label}$
%[text] 不是一次性的，而是每次變動都要再付一次。**
%[text] **② 標註需要專家。** 醫學影像要醫師、晶圓瑕疵要資深工程師。
%[text] `c_label` 不是 8 秒，可能是幾分鐘而且時薪很高——
%[text] 平衡點會往右移好幾個數量級。
%[text] **③ 錯誤成本很低而且有人覆核。**
%[text] 若零樣本只是**粗篩**，後面一定有人看，
%[text] 那 `c_error` 接近 0，平衡點回到只看時間的那個版本。
%[text] > **決策樹的第一個問題「能不能標幾十張」之所以放在最前面，
%[text] > 就是因為它決定了後面所有成本的量級。**

% ========================================================================
function tf = probeModel(fn)
%PROBEMODEL 用「實際呼叫」判斷支援包在不在（主教材 §10 第 1 條）。
try
    m = fn(); %#ok<NASGU>
    clear m
    tf = true;
catch ME
    tf = ~contains(ME.identifier, "supportpackages", IgnoreCase=true) && ...
         ~contains(ME.message, "support package", IgnoreCase=true);
end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
