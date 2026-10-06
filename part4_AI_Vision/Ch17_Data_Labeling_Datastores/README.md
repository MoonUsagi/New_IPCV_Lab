# 第 17 章　資料標註、資料集與 Datastore

`[基礎]`　建議時數 4 小時　｜　對應舊章：**無**（補課綱缺口 B6）

## 學習目標

1. 組裝 `imageDatastore` / `pixelLabelDatastore` / `boxLabelDatastore` 的資料管線
2. **說出為什麼「隨機切分」不保證避開資料洩漏**，並量測自己的切分
3. 使用 `groundTruth` 物件與它的方法（包含標註搬家）
4. 用 Grounding DINO 的**文字提示**自動標註，並**量化它的品質**
5. **說出提示詞為什麼是一個超參數**，以及該用哪個指標挑它
6. 串接 Grounding DINO 與 SAM，用一句英文產生像素級標註

## 內容

| 節 | 主題 |
|---|---|
| 1 | 這一章的位置：模型可以換，資料流程不能重來 |
| 2 | Datastore 三兄弟（含 `labelIDs` 的驗證方法） |
| 3 | `countEachLabel`：先看清楚類別分布 |
| 4 | `combine` 與 `transform`：惰性管線 |
| 5 | **擴增必須和標籤同步——最安靜的錯誤** |
| 6 | **資料切分：先量重複，再選策略** |
| 7 | `groundTruth` 物件與它的方法 |
| 8 | 從 `groundTruth` 產生訓練資料 |
| 9 | **文字提示自動標註：Grounding DINO** |
| 10 | **提示詞是一個超參數** |
| 11 | **選提示詞要看下游是人還是模型** |
| 12 | Grounded SAM：文字 → 框 → 遮罩 |
| 13 | COCO JSON 匯入 |
| 14 | R2026a 注意事項 |
| 15 | 常見陷阱（十二條） |
| 16 | 本章小結 |

## 本章最重要的五課

### 1. 提示詞是一個超參數，而且很敏感（第 10 節）

同一個模型、同一批 20 張影像，**只改英文用字**：

| 提示詞 | 總框數 | precision | recall | AP |
|---|---|---|---|---|
| `"car"` | 65 | 33.8% | **100.0%** | 0.873 |
| `"vehicle"` | 15 | **93.3%** | 63.6% | 0.597 |
| `"a car on the road"` | 38 | 55.3% | 95.5% | **0.908** |

**precision 從 33.8% 到 93.3%、recall 從 63.6% 到 100.0%。**
而且三個指標各有各的贏家。

> **這一章的旋鈕特別不直覺：它是英文用字，不是數值參數。**
> 沒有梯度、沒有單調性、**沒辦法二分搜尋**。只能掃。

練習 4 用六個提示詞打敗了主教材（AP **0.9200** vs 0.9085），
並發現最高性價比的改動是**把 `"car"` 改成 `"a car"`**：
precision 33.8% → 63.6%，recall 只掉 4.5 個百分點。

### 2. 選提示詞要看下游是人還是模型（第 11 節）

`precision` 與 `recall` 是對稱指標，**人工修正成本完全不對稱**：

| 動作 | 成本 |
|---|---|
| 刪掉一個誤框 | 看一眼、按一次 Delete |
| 從頭畫一個漏標 | 要先**發現**它漏了，再對齊四個邊 |

| 提示詞 | 要刪 | 要畫 |
|---|---|---|
| `"car"` | 43 | **0** |
| `"vehicle"` | 1 | **8** |
| `"a car on the road"` | 17 | 1 |

練習 5 把它做成成本模型，並**修正了本節的說法**：
不是「永遠選 recall 最高」，而是**最小化 $a + F/H$**
（$a = t_{adjust}/t_{delete}$、$F$ 誤框、$H$ 命中）。
實測三個提示詞的節省是 26%／36%／**43%**——
最省的是折衷的 `"a car on the road"`，不是 recall 100% 的 `"car"`。

### 3. 分數最高的框可能完全是錯的（第 9 節）

第 1 張影像，提示詞 `"car"`：

| | 框 | 分數 | IoU |
|---|---|---|---|
| 正確答案 | `[126 78 20 16]` | — | — |
| **分數最高** | `[40 79 20 8]` | **0.664** | **0.000** |
| **IoU 最高** | `[126 78 18 15]` | 0.558 | **0.844** |

**分數最高的框完全不是車，真正的車排第二名。**
這是第 9 章「信心分數高不代表是你要的」在 VLM 上的重演。

### 4. 資料切分：重複要量，不能假設（第 6 節）

`vehicles` 295 張影像，近重複門檻 0.99：
**244 個群組，98 張（33%）有近重複夥伴。**

| 策略 | 訓練／測試 | 跨集合近重複 |
|---|---|---|
| 隨機切分 | 207／88 | 27.3% |
| **區塊切分（照順序）** | 207／88 | **40.9%** ← 更糟 |
| **群組感知切分** | 208／87 | **0%** |

**我原本假設「照順序切比較安全」——量出來剛好相反。**
原因：重複影像不相鄰，它們成對出現在第 37/38 與第 283/284 張，
照順序切剛好把每一對拆到兩邊。

> **「照時間順序切」的前提是重複只發生在相鄰樣本。
> 前提不成立時，建議就是錯的。**

練習 3 在 `DigitDataset` 上重做：只有 1.0% 有夥伴，
純隨機切分的洩漏是 0.7%。**不嚴重，但不是 0，而且你只有量過才知道。**

### 5. 擴增與標籤不同步是最安靜的錯誤（第 5 節）

分別對影像與標籤做**隨機**擴增，兩邊的擲骰子不同步：

| 管線 | 中位偏差 | 最大偏差 | 偏差 > 5px |
|---|---|---|---|
| 錯誤（不同步） | 4.57 px | 20.67 px | **48%** |
| 正確（同步） | **0.33 px** | **2.08 px** | **0%** |

48% 對上理論值 50%（各自 50/50 擲骰，不一致的機率是 1/2）。

> **50% 是最惡毒的數字。** 100% 壞掉你馬上會發現；
> 50% 壞掉的話 loss 會下降、訓練會收斂、準確率只是差一點——
> 差到你會去調學習率、模型容量、資料量，**全都是無關的東西**。

正確做法：**先 `combine` 再 `transform`**，
讓同一個函式同時拿到影像與標籤，擲一次骰子、兩邊共用。

## 練習重點

練習在 `exercise/Ch17_Exercise.m`，解答在 `exercise/Ch17_Solution.m`。

- **練習 1**：`labelIDs` 驗證函式。並提出一個**不依賴亮度**的替代檢查
  （標籤邊界應落在影像梯度上，實測比值 **7.52 倍**）。
- **練習 2**：親手做出不同步的管線並量化（48%）。
- **練習 3**：群組感知切分做成可重用函式 + 門檻掃描。
- **練習 4**：六個提示詞，**打敗主教材**（AP 0.9200），
  並在「找人」上驗證規律——**不成立**（單字最強，和車子相反）。
- **練習 5**：自動標註的總成本模型與損益平衡點。
- **練習 6**：修好 `triangleGroundTruth.mat` 的路徑（**100/100 全修好**），
  並寫一個路徑健康檢查工具。
- **加分題**：Grounded SAM 的品質與**誤差來源分解**——
  總誤差 0.5703 之中，**框幾乎不佔（0%），SAM 本身的上限佔 100%**。
  就算給完美的人工框，Jaccard 也只有 0.430——和 VLM 的框一樣。
  （R2026a 是 15% / 85%、人工框 0.517；比例變了，結論不變。）

## R2026a 注意事項

- **`groundingDinoObjectDetector` 的提示詞放在 `ClassDescriptions`**，
  不是 `detect` 的位置引數。誤傳 `detect(det, I, "car")` 會得到
  「Expected ROI to be one of these types: double, single, uint8...
  Instead its type was string」——**訊息完全沒提到文字提示**。
- **`ClassNames` 唯讀**，換提示詞要重建偵測器。
- **第一次 `detect` 要額外約 10 秒**載入權重。要量穩定速度必須先暖機
  （暖機後約 1.8 秒／張，128×228 小圖）。
- **`read(pxds)` 回傳 `1x1 cell`**，`read(imds)` 直接回傳陣列，
  而 `read(combine(imds,pxds))` 的第 2 格**已經是 categorical**（cell 被剝掉了）。
  寫錯會得到「Cell must be a cell array of character vectors」。
- **`combine` 兩個 transformed datastore 時，transform 必須回傳 cell**，
  否則會 `horzcat(uint8, categorical)` 而報
  「Unable to concatenate a uint8 array and a categorical array」。
- **categorical 的 `imtranslate` FillValues 不能是數字**，
  要傳真正的類別名或 `missing`。
- **`groundTruth.DataSource` 的型別會變**：載入舊 `.mat` 後是 `char`，
  **`changeFilePaths` 之後變成 `groundTruthDataSource` 物件**。
  讀路徑的程式碼要同時處理兩種。
- **`groundTruth.LabelData` 是 timetable（影片來源），而 `istable(timetable)`
  回傳 false。** 用 `istable(x) || istimetable(x)`。
- **`changeFilePaths` 是方法不是函式**；它**修不好也不報錯**，
  改不動的放在回傳值裡。**不檢查回傳值就等於沒修。**
- COCO 匯入的函式是 **`groundTruthFromCOCO(pathToJSON, pathToImages)`**（R2025a 起）。
  `cocoToGroundTruth`／`importCOCO` 都不存在。
- **`splitEachLabel`／`countEachLabel`／`transform`／`subset`／`shuffle`
  都是 datastore 的方法**，`exist` 回傳 0。
- `objectDetectorTrainingData` 的 **`SamplingFactor` 預設不是 1**，
  影片來源會被抽樣。
- `insertObjectAnnotation` 的預設字型 **Roboto-Regular 不含 CJK**（同第 15 章）。
- **ViT 的函式是 `visionTransformer`，不是 `vit`。**
  `which("vit")` 會找到 Communications Toolbox 的
  `comm/commmex/vit.mexw64`（Viterbi 解碼器）——**名稱衝突**。
  `imagePretrainedNetwork` 不支援任何 ViT 名稱。

## 檔案

```
Ch17_Data_Labeling_Datastores/
├── Ch17_Main.m                   主教材（16 節）
├── README.md
├── code/
│   ├── ch17_labelStats.m         類別分布 + 不平衡警告
│   ├── ch17_buildPipeline.m      combine -> transform（影像與標籤同步擴增）
│   ├── ch17_dupGroups.m          近重複偵測與分群
│   ├── ch17_compareSplits.m      三種切分策略的洩漏比較
│   ├── ch17_autoLabel.m          Grounding DINO 批次自動標註
│   ├── ch17_evalAutoLabel.m      標註品質 + 人工修正成本
│   ├── ch17_promptSweep.m        提示詞掃描
│   └── ch17_groundedSAM.m        文字 -> 框 -> 遮罩
├── data/
│   └── datalist.json
└── exercise/
    ├── Ch17_Exercise.m
    └── Ch17_Solution.m
```

## 下一步

**第 18 章**用這一章建好的管線做第一個端到端深度學習任務：
影像分類與遷移學習。第 3 節的平衡取樣、第 4 節的管線、
第 6 節的群組感知切分都會直接用上。
