%[text] # 第 21 章　視覺語言模型與零樣本視覺
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[進階\]　｜　建議時數：4 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 說出 CLIP／Grounding DINO／Moondream 三者的分工與各自的輸入輸出
%[text] 2. 用 CLIP 做零樣本分類與以文搜圖
%[text] 3. **說出為什麼 CLIP 的餘弦相似度不能當信心分數**
%[text] 4. **量化提示詞樣板的影響**，並知道官方建議的樣板未必適合你的領域
%[text] 5. **說出零樣本什麼時候會輸給少量標註**——用數字，不是直覺
%[text] 6. 依成本與任務性質決定該用 VLM 還是訓練專屬模型 \
%[text] ## 前置知識
%[text] 第 17 章（Grounding DINO、提示詞是超參數）、
%[text] 第 18 章（遷移學習的三種策略、雜訊分析）。
%[text] ## 環境需求
%[text] Computer Vision Toolbox、Deep Learning Toolbox，以及三個支援包：
%[text] **OpenAI CLIP**、**Grounding DINO**、**moondream**。
%[text] 缺少時對應段落會跳過並印出訊息。
%[text] > **本章 100% 是 R2026a 的新功能。**
assert(exist("ch21_clipEmbed","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
rng(0);

% **支援包要用「實際呼叫」判斷，不能只查 add-on 清單。**
% 實測發現 CLIP 與 moondream 可以正常運作，
% 但它們不一定出現在 matlab.addons.installedAddons 裡。
hasCLIP  = probeModel(@() clipNetwork("vit-b-16"));
hasMD    = probeModel(@() moondream());
hasGDINO = probeModel(@() groundingDinoObjectDetector("swin-tiny", ClassNames="x"));
fprintf("CLIP %s、moondream %s、Grounding DINO %s\n", ...
    string(hasCLIP), string(hasMD), string(hasGDINO));
%%
%[text] # 1. 這一章的位置：不訓練也能做視覺任務
%[text] 前面二十章的路線是「**準備資料 → 訓練 → 評估**」。
%[text] 這一章的模型**已經訓練好了，而且訓練時沒看過你的類別**。
%[text:table]
%[text] | 章 | 要多少標註 | 要訓練嗎 |
%[text] | --- | --- | --- |
%[text] | 18 分類 | 每類數十張 | 要（或至少訓練一個淺層分類器） |
%[text] | 19 偵測 | 每張都要畫框 | 要 |
%[text] | 20 分割 | 每個像素 | 要 |
%[text] | **21 VLM** | **零** | **不用** |
%[text:table]
%[text] 聽起來像是把前面全部取代掉了。**這一章要用數字說明它沒有。**
%[text] > **本章最重要的一個數字**：在同一批手寫數字測試集上，
%[text] > **CLIP 零樣本 0.49，第 18 章的「特徵抽取 + SVM」0.85**。
%[text] > 後者只用了每類 40 張標註。
%%
%[text] # 2. 三個模型的分工
%[text:table]
%[text] | 模型 | 輸入 | 輸出 | 你要先知道什麼 |
%[text] | --- | --- | --- | --- |
%[text] | **CLIP** | 影像 + **候選文字清單** | 每個候選的相似度 | **所有可能的答案** |
%[text] | **Grounding DINO** | 影像 + 文字 | **框** | 你要找什麼 |
%[text] | **Moondream** | 只有影像 | **一段自由文字** | 什麼都不用 |
%[text:table]
%[text] 三者的能力邊界很清楚：
%[text] - **CLIP 只能在你給的選項裡挑。** 它不會告訴你「這是你沒列出的東西」。
%[text] - **Grounding DINO 給位置，但不會描述。**
%[text] - **Moondream 能說出你沒想到的東西，但輸出不結構化。**
%[text] > 第 17 章 §12 已經把 Grounding DINO 與 SAM 串起來
%[text] > （文字 → 框 → 遮罩）。這一章補上另外兩塊。
%%
%[text] # 3. CLIP 零樣本分類
%[text] 用第 18 章**同一批**測試集，這樣兩章的數字可以直接比。
digitDir = fullfile(matlabroot, "toolbox", "nnet", "nndemos", ...
    "nndatasets", "DigitDataset");
imdsAll = imageDatastore(digitDir, IncludeSubfolders=true, ...
    LabelSource="foldernames");
rng(0);
imdsSub = splitEachLabel(imdsAll, 60, "randomized");
[~, dsTest] = splitEachLabel(imdsSub, 0.67, "randomized");

if ipcvFast()
    nUse = 60;
    disp("（快速模式：用 60 張。完整執行用 200 張。）")
else
    nUse = numel(dsTest.Files);
end
pick = round(linspace(1, numel(dsTest.Files), nUse));
files = string(dsTest.Files(pick)).';
yTrue = dsTest.Labels(pick);
classNames = string(categories(yTrue));
fprintf("\n測試集 %d 張、%d 類\n", numel(files), numel(classNames));

if ~hasCLIP
    disp("（沒有 CLIP 支援包，略過 §3–§7。）")
else
    clip = clipNetwork("vit-b-16");
    [E, embInfo] = ch21_clipEmbed(clip, files);
    fprintf("影像嵌入：%d 維、%.1f 秒（**%.3f 秒/張**）\n", ...
        embInfo.Dim, embInfo.SecTotal, embInfo.SecPerImage);

    [pred, S, zsRep] = ch21_zeroShot(clip, E, ...
        "a photo of " + classNames, classNames, yTrue);
    fprintf("\n零樣本準確率（樣板 ""a photo of {}""）= **%.4f**\n", zsRep.Accuracy);
end
%[text] **0.18。** 這個數字很難看，而且它用的是
%[text] OpenAI 官方建議的標準樣板 `"a photo of {}"`。
%[text] 先不要下結論說「CLIP 不行」——**換個樣板試試。**
%%
%[text] # 4. 提示詞樣板值 31 個百分點
if ~hasCLIP
    disp("（略過。）")
else
    templates = { ...
        "只有類別名",        ""; ...
        "the digit {}",     "the digit {}"; ...
        "a handwritten digit {}", "a handwritten digit {}"; ...
        "完整描述",          "a black and white image of the handwritten digit {}"; ...
        "**a photo of {}**", "a photo of {}" };
    sweepTbl = ch21_promptSweep(clip, E, templates, classNames, yTrue);
    disp(sweepTbl)
end
%[text] 實測（200 張、`vit-b-16`）：
%[text:table]
%[text] | 樣板 | 準確率 |
%[text] | --- | --- |
%[text] | **只有類別名**（`"0"`、`"1"`…） | **0.4900** |
%[text] | `"the digit {}"` | 0.4500 |
%[text] | `"a handwritten digit {}"` | 0.3550 |
%[text] | 完整描述 | 0.2850 |
%[text] | **`"a photo of {}"`（官方標準樣板）** | **0.1800** |
%[text:table]
%[text] **最好 0.49、最差 0.18，差 31 個百分點。
%[text] 而最差的那個正是官方建議的標準樣板。**
%[text] 為什麼？合理的推測是 `"a photo of 3"` 會讓文字編碼器
%[text] 把重點放在「**照片**」這個概念上，而手寫數字是
%[text] 黑白線條圖、不是照片——**樣板引入的字詞把嵌入推離了目標領域**。
%[text] **但這只是推測。** 重點是你不能從語意直覺推出哪個樣板好。
%[text] > **官方建議的樣板是在 ImageNet 那類自然照片上調出來的。
%[text] > 你的領域不同，那個建議就不一定成立。**
%[text] 好消息是掃描很便宜：**影像嵌入只要算一次**（昂貴的部分），
%[text] 換樣板只需要重算 10 句話的文字嵌入，不到一秒。
%[text] > 這是第 17 章「提示詞是超參數」的第二次現身，
%[text] > 而且這次連**官方推薦值都是錯的**。
%[text] ## 4.1 一個反直覺的附帶發現
%[text] 看上表最後一欄「前二名差距中位數」：
%[text:table]
%[text] | 樣板 | 準確率 | 前二名差距 |
%[text] | --- | --- | --- |
%[text] | 只有類別名 | **0.4900** | **0.00237** |
%[text] | `"the digit {}"` | 0.4500 | 0.00134 |
%[text] | `"a photo of {}"` | **0.1800** | **0.00681** |
%[text:table]
%[text] **最準的樣板，前二名的差距反而最小；最不準的樣板差距最大。**
%[text] 也就是說「差距大 = 模型比較確定」**在這裡是反的**。
%[text] > **所以 §5 說「要用差距而不是絕對值」還不夠。**
%[text] > 正確的說法是：**差距也要先校準才能當信心用**，
%[text] > 而且校準必須在**固定樣板之後**做——
%[text] > 換樣板會同時改變準確率與差距的分布。
%%
%[text] # 5. CLIP 的相似度不是信心分數
if ~hasCLIP
    disp("（略過。）")
else
    fprintf("\n相似度分布（樣板 ""a photo of {}""）：\n");
    fprintf("  min %.4f、max %.4f、中位數 %.4f、標準差 %.4f\n", ...
        zsRep.SimMin, zsRep.SimMax, zsRep.SimMedian, zsRep.SimStd);
    fprintf("  **全距只有 %.4f**\n", zsRep.SimRange);
    fprintf("  第一名與第二名的差距：中位數 **%.4f**、最大 %.4f\n", ...
        zsRep.TopGapMedian, zsRep.TopGapMax);

    figure
    tiledlayout(1,2, TileSpacing="compact")
    nexttile
    histogram(S(:), 30); xlabel("餘弦相似度"); ylabel("次數")
    title("所有「影像 x 類別」的相似度"); grid on
    nexttile
    Ssort = sort(S, 1, "descend");
    histogram(Ssort(1,:) - Ssort(2,:), 30)
    xlabel("第一名 - 第二名"); ylabel("次數")
    title("分類決定是靠這個差距做的"); grid on
end
%[text] 實測：
%[text:table]
%[text] | 統計量 | 值 |
%[text] | --- | --- |
%[text] | 相似度 min / max | 0.2143 / 0.2777 |
%[text] | 中位數 | 0.2366 |
%[text] | **全距** | **0.0634** |
%[text] | **第一名與第二名的差距（中位數）** | **0.0068** |
%[text:table]
%[text] **所有相似度都擠在 0.21–0.28 這個窄帶裡，
%[text] 而分類的決定是由小數第三位的差距做出來的。**
%[text] 兩個直接的後果：
%[text] **① 餘弦相似度不是信心分數。**
%[text] 看到 0.28 不要以為「模型很確定」——它的**最低值也有 0.21**。
%[text] 要當信心用必須先在你自己的資料上**校準**。
%[text] **② 不能用固定的相似度門檻做拒絕判斷。**
%[text] 「相似度低於 0.25 就說不知道」這種規則，
%[text] 在這裡會把一半以上的正確答案也拒絕掉。
%[text] **要用「差距」而不是絕對值。**
%[text] > **這是第三次了。**
%[text] > 第 09 章：SAM 的信心分數高不代表是你要的遮罩。
%[text] > 第 17 章：Grounding DINO 分數最高的框 IoU = 0。
%[text] > 這裡：CLIP 的相似度全部擠在一起。
%[text] > **基礎模型給的分數，都要先驗證才能當信心用。**
%%
%[text] # 6. 零樣本 vs 少量標註——本章最重要的比較
%[text] 把第 18 章的結果放進來對照（**同一批測試集**）：
%[text:table]
%[text] | 做法 | 需要的標註 | 需要訓練嗎 | 準確率 |
%[text] | --- | --- | --- | --- |
%[text] | CLIP 零樣本（最差樣板） | **0** | 否 | 0.1800 |
%[text] | CLIP 零樣本（最佳樣板） | **0** | 否 | **0.4900** |
%[text] | 第 18 章：ResNet-18 特徵 + SVM | **每類 40 張** | 幾秒 | **約 0.85** |
%[text:table]
%[text] **每類 40 張標註，換來 36 個百分點。**
%[text] > **零樣本不是免費的效能，是「用效能換標註成本」。**
%[text] 什麼時候零樣本划算？
%[text:table]
%[text] | 情況 | 選哪個 |
%[text] | --- | --- |
%[text] | 完全沒有標註、要快速驗證可行性 | **零樣本** |
%[text] | 類別會一直變動（開放詞彙） | **零樣本** |
%[text] | 類別固定、能標幾十張 | **訓練**（第 18 章策略一） |
%[text] | 領域離自然影像很遠（手寫、X 光、晶圓） | **訓練** |
%[text:table]
%[text] 最後一列是關鍵，而它正是這一節的實驗：
%[text] **手寫數字離 CLIP 的訓練分布很遠**，所以零樣本表現不好。
%[text] 若換成自然照片的分類任務，差距會小得多。
%[text] > 這和第 18 章 §4 的結論是同一件事：
%[text] > **遷移（或零樣本）的效果取決於領域距離。**
%%
%[text] # 7. 以文搜圖
%[text] 影像嵌入**只要算一次**，之後任何查詢都是
%[text] 「一句話的嵌入 + 一次矩陣乘法」。
if ~hasCLIP
    disp("（略過。）")
else
    queries = ["the digit zero", "a round shape", "a straight vertical line"];
    for q = queries
        [ranked, rep] = ch21_textSearch(clip, E, files, q, TopK=5, ...
            TrueLabels=yTrue, Relevant=classNames);
        lbl = yTrue(ranked.("索引"));
        fprintf("\n查詢「%s」（%.4f 秒）前 5 名的真實類別：%s\n", ...
            q, rep.SecQuery, strjoin(string(lbl)', ", "));
        fprintf("  相似度 %s\n", mat2str(round(ranked.("相似度")', 4)));
    end
end
%[text] 實測的三個查詢（前 5 名的**真實**類別）：
%[text:table]
%[text] | 查詢 | 前 5 名的真實類別 | 對不對 |
%[text] | --- | --- | --- |
%[text] | `"the digit zero"` | 1, 1, 9, 1, 9 | **全錯** |
%[text] | `"a round shape"` | **0, 0, 6, 0, 0** | **對** |
%[text] | `"a straight vertical line"` | 1, 7, 1, 2, 3 | **大致對** |
%[text:table]
%[text] **這三個結果放在一起，說明了 CLIP 到底學到了什麼。**
%[text] 問「**the digit zero**」（符號身分）**全錯**；
%[text] 問「**a round shape**」（視覺外觀）**全對**；
%[text] 問「**a straight vertical line**」也對——1 和 7 確實有直筆劃。
%[text] > **CLIP 對應的是「長什麼樣」，不是「它是什麼符號」。**
%[text] > 這正好解釋了 §3–§4 的結果：手寫數字的類別是
%[text] > **符號身分**，而那是 CLIP 最弱的地方。
%[text] > 它的訓練語料裡，「0」這個字元與「一個圓形的手寫筆劃」
%[text] > 之間的連結，遠不如「a round shape」與圓形圖像之間的連結強。
%[text] **這也給了實務上的做法**：用 CLIP 檢索時，
%[text] **描述你要看到的外觀，不要用類別代號**。
%[text] 「a round shape」比「the digit zero」有用得多。
%[text] **查詢只要毫秒等級**，而且資料庫再大也一樣——
%[text] 成本全在「建索引」那一次。
%[text] > **這是 CLIP 最實用的能力，而且完全不需要標註。**
%[text] > 對照第 17 章：那裡要用 Grounding DINO 產生框再人工修；
%[text] > 這裡連類別清單都不用事先定義。
%[text] 但排序品質受限於 §5 的同一個問題：
%[text] **排名可信、絕對分數不可信。**
%[text] 所以檢索介面應該呈現「**前 K 名**」，
%[text] 而不是「相似度超過 X 的全部」。
%%
%[text] # 8. Moondream：讓模型自己說
if ~hasMD
    disp("（沒有 moondream 支援包，略過本節。）")
elseif ipcvFast()
    disp("（快速模式：略過 Moondream。完整執行約 15 秒。）")
else
    capFiles = ["peppers.png"; "visionteam.jpg"];
    [caps, capInfo] = ch21_caption(capFiles.');
    fprintf("\n第一次呼叫（含模型載入）%.1f 秒\n", capInfo.SecFirst);
end
%[text] 實測（`peppers.png`）：
%[text] > *"A purple tablecloth holds a vibrant array of red, green, yellow,
%[text] > and white peppers, onions, and garlic, arranged in a visually
%[text] > appealing composition."*
%[text] `visionteam.jpg`：
%[text] > *"**Six individuals**, dressed in casual attire, stand in a line
%[text] > in a room with a large window, facing the camera with smiles."*
%[text] **描述都是正確的**，而且提到了顏色、物件種類、擺放方式——
%[text] 那些都**不是事先定義的類別**。
%[text] 特別注意第二張：**它數對了人數（六個）**，
%[text] 而那正是第 20 章要用實例分割才能做到的事
%[text] （SOLOv2 也是 6 個 person，但多了一個 frisbee 誤判）。
%[text] 這就是 Moondream 與 CLIP 的根本差別：
%[text] **CLIP 只能在你給的選項裡挑，Moondream 能說出你沒想到的東西。**
%[text] 代價有兩個：
%[text] **① 慢兩個數量級。** 第一次呼叫（含載入）約 14 秒，
%[text] 而 CLIP 是 0.2 秒／張。所以 Moondream 適合
%[text] **離線批次建索引**，不適合即時查詢。
%[text] **② 輸出是不可重現的自然語言。**
%[text] 同一張圖跑兩次可能得到措辭不同的描述，
%[text] 所以**不要拿它的字面輸出去做斷言比對**。
%[text] 要驗證得用語意相似度（例如再用 CLIP 的文字嵌入比較）。
%%
%[text] # 9. 成本比較與決策
%[text] 把本章與前幾章的模型放在一起（T550、單張影像、暖機後）：
%[text:table]
%[text] | 模型 | 每張秒數 | 要標註嗎 | 輸出 |
%[text] | --- | --- | --- | --- |
%[text] | ResNet-18 特徵（第 18 章） | **0.05** | 要（每類數十張） | 512 維向量 |
%[text] | YOLOX small（第 19 章） | 0.06 | 要（訓練時） | 框 + 類別 + 分數 |
%[text] | **CLIP `vit-b-16`** | **0.20** | **不用** | 512 維向量 |
%[text] | Grounding DINO（第 17 章） | 1.8 | **不用** | 框 + 分數 |
%[text] | SOLOv2（第 20 章） | 5.6 | 要（訓練時） | 遮罩 |
%[text] | **Moondream** | **約 14** | **不用** | 自由文字 |
%[text:table]
%[text] **「不用標註」的代價是每張慢 4–280 倍。**
%[text] 決策樹：
%[text] ```
%[text] 類別固定，而且能標幾十張？
%[text]   是 → 第 18 章策略一（特徵 + 淺層分類器）：最快、最準
%[text]   否 ↓
%[text] 需要「位置」嗎？
%[text]   是 → Grounding DINO（+ SAM 要遮罩）
%[text]   否 ↓
%[text] 候選答案列得出來嗎？
%[text]   是 → CLIP 零樣本／檢索
%[text]   否 → Moondream（自由描述）
%[text] ```
%[text] > **最常見的錯誤是跳過第一個問題。**
%[text] > VLM 很吸引人，但「能標三十張」的專案用第 18 章的策略一
%[text] > 又快又準，而且不依賴支援包。
%%
%[text] # 10. R2026a 注意事項
%[text] 1. **支援包要用「實際呼叫」判斷，不能只查 `matlab.addons.installedAddons`。**
%[text]    實測 CLIP 與 moondream 能正常運作，但**不一定出現在清單裡**；
%[text]    而 moondream 的清單名稱是**小寫的 `moondream`**。
%[text]    真的缺套件會丟 `nnet_cnn:supportpackages:InstallRequired`，
%[text]    訊息會指名要裝哪一個。
%[text] 2. **`clipNetwork` 的骨幹只吃 `"vit-b-16"`／`"vit-l-14"`／`"resnet50"`**
%[text]    （不是 `"ViT-B-32"`）。
%[text] 3. `clipNetwork` 的方法是 `classify`、`extractImageEmbeddings`、
%[text]    `extractTextEmbeddings`、`forward`。
%[text] 4. **嵌入要自己做 L2 正規化**才能用內積當餘弦相似度。
%[text] 5. 灰階影像要先 `repmat(I,1,1,3)`（同第 18 章）。
%[text] 6. `moondream` 的方法是 `captionImage`（`exist("captionImage")`
%[text]    回傳 0，因為它是方法不是自由函式）。
%[text] 7. 每個基礎模型都佔顯示記憶體，**用完要 `clear`**（第 17 章 §10.1）。
%%
%[text] # 11. 常見陷阱
%[text] 1. **用官方推薦的提示詞樣板就不再調** → §4：它在這裡是最差的。
%[text] 2. **把餘弦相似度當信心分數** → §5：全距只有 0.063。
%[text] 3. **用固定的相似度門檻拒絕低信心預測** → 要用「差距」。
%[text] 4. **以為零樣本能取代訓練** → §6：0.49 vs 0.85。
%[text] 5. **在領域離自然影像很遠的任務上期待零樣本表現** → 同上。
%[text] 6. **每次查詢都重算影像嵌入** → 只要算一次（§7）。
%[text] 7. **拿 Moondream 的字面輸出做斷言比對** → 它不可重現。
%[text] 8. **只查 add-on 清單判斷套件有沒有裝** → §10 第 1 條。
%[text] 9. **忘記 L2 正規化** → 內積就不是餘弦相似度。
%[text] 10. **基礎模型用完不釋放** → 顯示記憶體累積，推論安靜地變慢。
%%
%[text] # 12. 本章小結
%[text:table]
%[text] | 主題 | 一句話 |
%[text] | --- | --- |
%[text] | 三者分工 | CLIP 在你給的選項裡挑、GDINO 給位置、Moondream 自由描述 |
%[text] | **提示詞樣板** | **值 31 個百分點，而官方標準樣板最差** |
%[text] | **相似度** | **全距 0.063、前二名差 0.0068——不是信心分數** |
%[text] | **零樣本 vs 少量標註** | **0.49 vs 0.85**；每類 40 張換 36 個百分點 |
%[text] | 以文搜圖 | 建索引一次，查詢毫秒等級，不需標註 |
%[text] | **CLIP 學到什麼** | **外觀，不是符號身分**（"a round shape" 全對，"the digit zero" 全錯） |
%[text] | Moondream | 能說出你沒想到的東西，但慢 70 倍且不可重現 |
%[text] | 成本 | 「不用標註」的代價是每張慢 4–280 倍 |
%[text:table]
%[text] 本章把課程的一條主線收了尾：
%[text] > **基礎模型給的分數，沒有一個可以直接當信心用。**
%[text] > 第 09 章的 SAM、第 17 章的 Grounding DINO、這一章的 CLIP，
%[text] > 三次都是同一個結論——**要先在自己的資料上校準。**
%%
%[text] # 13. 練習
%[text] 練習在 `exercise/Ch21_Exercise.m`。
%%
%[text] # 14. 延伸閱讀與下一章
%[text] - `doc clipNetwork` — 注意骨幹名稱
%[text] - `doc moondream` / `doc captionImage`
%[text] - `doc groundingDinoObjectDetector`（第 17 章已用）
%[text] **第 22 章**回到工業現場：只有良品樣本時要怎麼做檢測。
%[text] 那一章會用**異常偵測**處理第 20 章的「前景不到 1%」問題。

function tf = probeModel(fn)
%PROBEMODEL 用「實際呼叫」判斷支援包在不在。
%
%   缺套件會丟 nnet_cnn:supportpackages:InstallRequired；
%   其他錯誤（引數寫錯等）不算缺套件。
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
