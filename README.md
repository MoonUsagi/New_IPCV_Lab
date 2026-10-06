# IPCV_Lab — 影像處理與電腦視覺實作課程

MATLAB **R2026b** 對標版　｜　6 大模組．31 章．約 102 小時

前身為 [MoonUsagi/IPCV_Lab](https://github.com/MoonUsagi/IPCV_Lab)（R2024b，16 章）。
改版說明見 [`../course_plan/`](../course_plan/)。

---

## 快速開始

```matlab
cd 路徑/到/IPCV_Lab_2026b
ipcvSetup              % 每次開啟 MATLAB 後執行一次
checkEnvironment       % 檢查工具箱與支援包
```

接著開啟 `part0_Foundation/Ch00_Setup/Ch00_Main.m`——用 **Live Editor** 開，
不是一般編輯器。

> **Windows 使用者**：clone 前先執行 `git config --global core.longpaths true`，
> 或把課程放在較短的路徑（例如 `C:\IPCV`）。

---

## 選一條路徑

| 路徑 | 對象 | 章節 | 時數 |
|---|---|---|---|
| **A 影像處理基礎班** | 初學者、非資工背景 | 00, 01, 02, 03, 04, 06, 08 | 21h |
| **B AI 視覺實戰班** | 有影像基礎，要導入深度學習 | 00, 02, 09, 17, 18, 19, 20, 21, 22 | 32h |
| **C 產業檢測與部署班** | AOI／製造業工程師 | 00, 02, 08, 10, 11, 12, 15, 19, 22, 23, 25 | 36h |
| **D 完整學程** | 學校一學期、企業完整培訓 | 全部 31 章 | 102h |

只檢查你這條路徑需要的東西：

```matlab
checkEnvironment(Chapters=["00" "02" "09" "17" "18" "19" "20" "21" "22"])
```

---

## 課程架構

| 模組 | 名稱 | 章節 | 時數 |
|---|---|---|---|
| Part 0 | 導論與環境 | Ch.00 | 2h |
| Part I | 影像處理基礎 | Ch.01–07 | 20h |
| Part II | 分割、量測與品質 | Ch.08–13 | 18h |
| Part III | 特徵與傳統辨識 | Ch.14–16 | 10h |
| Part IV | AI 視覺 | Ch.17–22 | 24h |
| Part V | 動態、3D 與空間視覺 | Ch.23–27 | 18h |
| Part VI | 工程化與部署 | Ch.28–30 | 10h |

---

## 每章的結構

```
ChNN_章名/
├── ChNN_Main.m          # 主教材（用 Live Editor 開啟）
├── README.md            # 章節摘要、函式清單、環境需求
├── code/                # 可重用函式，已自動加入搜尋路徑
├── exercise/            # ChNN_Exercise.m + ChNN_Solution.m
├── data/                # datalist.json 與本章素材
└── assets/              # 圖片與其他附件
```

### 為什麼主教材是 `.m` 而不是 `.mlx`

R2025a 起 MATLAB 支援**純文字 Live Code 格式**。同一個 `.m` 檔：

- 用 **Live Editor** 開啟 → 完整的互動式教材，有格式化文字、表格、內嵌輸出
- 用**一般編輯器**開啟 → 可讀的純文字
- 用 **Git** 比較 → 正常的 diff，不是二進位黑盒

這讓「單一來源」成立：手冊、簡報、程式碼都從同一個檔案產生，改一次改全部。

---

## 工具

| 指令 | 用途 |
|---|---|
| `ipcvSetup` | 設定課程搜尋路徑 |
| `checkEnvironment` | 檢查工具箱與支援包，可輸出 HTML 報告 |
| `courseRequirements` | 查詢各章需求清單 |
| `downloadCourseData` | 下載課程資料集（含快取） |
| `findLegacyAPI` | 掃描已移除／過時的 MATLAB 函式 |
| `verifyChapters` | 執行所有教材與解答，確認全部可跑 |
| `buildHandbook` | 由教材產生 HTML／PDF／Word 手冊 |
| `buildSlides` | 由各章 README 產生 PowerPoint 簡報（需要 MATLAB Report Generator） |

### 產生手冊（HTML／PDF／Word）

```matlab
buildHandbook(Chapters=["00" "01"])        % 測試單章
buildHandbook(Format="pdf")                % 全部，輸出 PDF
buildHandbook(Format="docx")               % 全部，輸出 Word
buildHandbook(Run=false)                   % 不重跑，只轉檔（快）
```

預設 `Run=true` 會**重新執行**教材再匯出，確保手冊裡每一張圖都是當前版本
真正跑出來的結果——這是防止教材腐化最有效的機制。
全部 31 章重跑一次約 40 分鐘（非快速模式）；每章一個檔，輸出在 `build/output`。

### 合併成一本手冊 PDF（封面、目錄、書籤、頁碼）

```
buildHandbook(Format="docx")                                        % 1. MATLAB：重跑並匯出各章 Word
powershell -ExecutionPolicy Bypass -File build\convertHandbookPdf.ps1   % 2. Word：各章轉 PDF（約 2 分鐘）
python build\assembleHandbook.py                                    % 3. 組成 IPCV_Lab_Handbook.pdf
```

步驟 2 需要 Microsoft Word；步驟 3 需要 Python 的 `pypdf` 與 `reportlab`。
輸出 `build/output/IPCV_Lab_Handbook.pdf`：封面 → 使用說明 → 全書目錄（含頁碼）→ 31 章，
每個模組與每一章都有 PDF 書籤。


### 產生簡報（PowerPoint）

```matlab
buildSlides()                              % 每章一份 ChNN_Slides.pptx ＋ 課程說明總覽 IPCV_Lab_Overview.pptx
buildSlides(Chapters=["29" "30"])          % 指定章節
buildSlides(Combined=true)                 % 另外產生合併版 IPCV_Lab_Slides.pptx（總覽在最前面）
```

簡報由各章 `README.md` 的結構產生（一句話、學習目標、最重要的幾課與實測表格、
沒有驗證的部分），總覽由 `build/templates/course_overview.md` 產生。
全部 31 章約 15 秒、合併版 483 張，輸出在 `build/output/slides`。
要 PDF 版時用 PowerPoint 另存（`SaveAs` 格式 32）。
**簡報裡沒有圖**——圖在手冊裡；要放進簡報請從手冊擷取。

### 提交前的品質閘門

```matlab
verifyChapters      % 全部教材與解答都要通過才提交
```

---

## 環境需求

**必要**：MATLAB R2026b、Image Processing Toolbox、Computer Vision Toolbox

其餘依章節而定，執行 `checkEnvironment` 會告訴你缺什麼。完整清單見
`setup/courseRequirements.m`；R2026b 的安裝清單與調整進度見
[`docs/R2026B_MIGRATION.md`](docs/R2026B_MIGRATION.md)。

> **從 R2026a 升上來**：支援包**不會**跟著升級，要為 R2026b 重新安裝。
> Ch.25 的多相機標定要先執行一次 `installMultiSensorCalibrationTools`。

R2026b 的產品重組（本課程受影響的部分）：

| R2026a | R2026b | 用於 |
|---|---|---|
| Lidar Toolbox（點雲函式） | **Point Cloud Toolbox** | Ch.26 |
| Automated Visual Inspection Library | **Visual Inspection Toolbox** | Ch.11, 13, 19, 22 |
| YOLOX 由 Automated Visual Inspection Library 提供 | 另裝 **Visual Inspection Toolbox Model for YOLOX Object Detection** | Ch.19 |
| `estimateMultiCameraParameters` 內建 | 要先 `installMultiSensorCalibrationTools` | Ch.25 |

---

## R2026b 相容性提醒

以下函式在 R2026b **已移除，呼叫會直接報錯**：

`vision.AlphaBlender`（Ch.13 §12 示範錯誤訊息與替代寫法）、`augmentedImageSource`、
`efficientADAnomalyDetector` / `trainEfficientADAnomalyDetector`（改用 Student-Teacher）、`serial`

R2026a 已移除、仍會報錯的：

`segnetLayers` `unetLayers` `unet3dLayers` `deeplabv3plusLayers` `fcnLayers`
（改用 `unet` / `unet3d` / `deeplabv3plus`）

**行為變更**（不報錯、但數字會變）：`pcfitplane` 多了內點 SVD 精修（Ch.26 §7 有兩版對照）、
`measureIlluminant`、`detectCheckerboardPoints`、`estimateMultiCameraParameters`。

掃描你自己的舊專案：

```matlab
findLegacyAPI("路徑/到/你的專案")
```


---

## 開發狀態

| 模組 | 章節 | 狀態 |
|---|---|---|
| 基礎設施（setup / build / 樣板） | — | ✅ 完成並驗證 |
| **Part 0　導論與環境** | Ch.00 | ✅ 完成 |
| **Part I　影像處理基礎** | Ch.01–07 | ✅ **完成（7 章）** |
| **Part II　分割、量測與品質** | Ch.08–13 | ✅ **完成（6 章）** |
| **Part III　特徵與傳統辨識** | Ch.14–16 | ✅ **完成（3 章）** |
| **Part IV　AI 視覺** | Ch.17–22 | ✅ **完成（6 章）** |
| **Part V　動態、3D 與空間視覺** | Ch.23–27 | ✅ **完成（5 章）** |
| **Part VI　工程化與部署** | Ch.28–30 | ✅ **完成（3 章）** |
| 手冊（`buildHandbook`）與簡報（`buildSlides`） | — | ✅ 完成 |


### Part I 的內容地圖

| 章 | 主題 | 一句話重點 |
|---|---|---|
| 01 | 影像的表示 | 影像就是矩陣；`uint8` 溢位是最安靜的錯誤 |
| 02 | 互動式 APP 與五步驟工作流 | APP 找參數、程式碼定結構；**顏色門檻碰上照明變化，調參數救不回來** |
| 03 | 點運算與影像增強 | 只增強亮度通道；**選錯指標會得到相反的結論** |
| 04 | 空間域濾波 | 先判斷雜訊類型再選濾波器；**雙邊濾波會把椒鹽雜訊當邊緣保護** |
| 05 | 頻域與小波 | 週期性條紋是頻域不可取代的場合（+5 dB） |
| 06 | 形態學 | top-hat 的參數有明確物理意義；**先確認前景是白是黑** |
| 07 | 幾何轉換與配準 | **強度式配準會安靜地失敗**，一定要給初始猜測並驗證 |

### Part II 已完成的章節

| 章 | 主題 | 一句話重點 |
|---|---|---|
| 08 | 傳統影像分割 | **用對特徵比選對演算法重要**；GrabCut 的 ROI 是硬天花板 |
| 09 | SAM 與 SAM 2 | SAM 贏在**邊界品質**（BFscore 差 26 個百分點）；**信心分數高不代表是你要的** |
| 10 | 邊緣、直線與圓偵測 | **自動門檻會掩蓋差異**；更新 API 會讓寫死的門檻悄悄失效 |
| 11 | 區域量測與尺度校正 | **周長有四種定義，排序互相矛盾**；校正值必須帶著來歷一起流動 |
| 12 | 影像品質與光學 | **預設 NIQE 在工業影像上會把好壞排反**；`opticalSystem` 是 handle，方法就地修改 |
| 13 | 影像修復與合成 | `inpaintExemplar` **PSNR 全輸、紋理指標 5/8 勝**；評估區域跟著自變數變動會讓結論反向 |

### Part III 的內容地圖

| 章 | 主題 | 一句話重點 |
|---|---|---|
| 14 | 特徵偵測、描述與配對 | **重複性與可配對性無關**（Spearman −0.089）；最佳值落在掃描邊緣不代表找到答案 |
| 15 | 符碼、文字偵測與 OCR | QR 對旋轉免疫、1D 條碼不是；**OCR 不怕雜訊，怕 2 度傾斜** |
| 16 | 傳統物件偵測 | **patch 準確率 1.0000 的模型，當偵測器 precision 只有 0.8%**；挖掘一輪修好 |

### Part IV 已完成的章節

| 章 | 主題 | 一句話重點 |
|---|---|---|
| 17 | 資料標註與 Datastore | **提示詞是超參數**（precision 33.8%→93.3%）；隨機切分有 27% 近重複，群組感知切分 0% |
| 18 | 分類與遷移學習 | **不訓練也能遷移**（約 0.85）；**同一份資料重跑五次差 2–5 個百分點**，小差異一律不可解釋 |
| 19 | 深度學習偵測與評估 | **光是換類別對應，AP 就從 0.261 到 0.483**；一個 mAP 裡有四個決定是你自己下的 |
| 20 | 語意分割與實例分割 | **什麼都不預測的模型拿 95.4% 準確率**；只有逐類別 IoU 講實話 |
| 21 | 視覺語言模型 | **零樣本 0.49 輸給少量標註的 0.85**；提示詞樣板值 31 個百分點，官方樣板最差 |
| 22 | 工業瑕疵檢測 | **一張髒資料就毀掉整個模型**；門檻由過殺／漏檢成本決定，不是 F1 |
