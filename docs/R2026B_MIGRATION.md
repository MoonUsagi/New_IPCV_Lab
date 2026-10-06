# R2026b 調整進度

> 本資料夾 `IPCV_Lab_2026b` 是從 `IPCV_Lab_2026a`（R2026a 定稿版，2026-09-30）複製出來的。
> R2026a 版保持原樣不動；所有 R2026b 的修改都在這裡進行。
> 差異的來源與實測數據見 [`../../course_plan/05_R2026b更新對照表.md`](../../course_plan/05_R2026b更新對照表.md)。

---

## 階段一：不需要支援包的修改 ✅（2026-09-30）

| 項目 | 內容 | R2026b 實測 |
|---|---|---|
| **Ch.13** | `vision.AlphaBlender` 已移除：第 12 節改成 `try/catch` 示範錯誤訊息，並說明「R2026a 警告 → R2026b 報錯」的淘汰週期 | ✅ 通過 |
| **Ch.25** | 多相機標定要先 `installMultiSensorCalibrationTools`：`ch25_stereoSystem` 先檢查，沒安裝時該欄回傳 NaN 並說明，其餘兩種方法照常比較 | ✅ 通過（未安裝狀態） |
| **Ch.26** | `teapot.ply` 搬家 → 改用 `which("teapot.ply")`；**§7 平面擬合改寫成 R2026a／R2026b 對照**（`pcfitplane` 1.033° → 0.028°）；README、datalist、`ch26_fitCompare` 說明、陷阱表同步更新 | ✅ 通過 |
| **Ch.29** | App Designer 在 R2026b 可存純文字：改寫「不用 `.mlapp`」的理由（主教材、README、`ch29_GrainApp`、datalist） | ✅ 通過 |
| Ch.00 | 淘汰清單：`vision.AlphaBlender` 改為「R2026b 已移除」 | ✅ 通過 |
| `findLegacyAPI` | 新增 R2026b 的移除／即將移除／行為變更規則（`augmentedImageSource`、EfficientAD、`serial`、Lidar Labeler、`pcfitplane`、`measureIlluminant`…） | — |
| `courseRequirements` | 改成 R2026b 名稱：Point Cloud Toolbox、Visual Inspection Toolbox、YOLOX 新支援包；合併原本重複的 Ch.17–22 項目；Ch.24 補上 ResNet-18 | — |
| `checkEnvironment` | 最低版本改為 R2026b | — |
| 版本標示 | 47 個 Live Script 第二行的「MATLAB R2026a」改為 R2026b；`_template`、`buildSlides` 封面、`assembleHandbook` 預設版本同步 | — |
| `assembleHandbook.py` | 新增 `--measured`：內文數字尚未全部在 R2026b 重測時，使用說明頁會如實註明 | — |

### 階段一驗證結果（R2026b 26.2.0.3386108，2026-09-30）

`verifyChapters`：**44 成功、18 失敗，731 秒**（修改前是 39/62）。**18 個失敗全部是缺支援包**，沒有需要再改的程式：

| 章 | 錯誤 ID | 缺的支援包 |
|---|---|---|
| 09 | `images:sam2:InstallRequired` | Segment Anything Model 2 |
| 10 | `images:imfindcirclesYOLO:missingDependencies` | Circle Detection |
| 15 | `vision:ocr:requiresSupportPackage` | OCR Language Data（`chinesetraditional`） |
| 18, 20, 22, 24 | `nnet_cnn:imagePretrainedNetwork:NotInstalled` 等 | ResNet-18 |
| 19 | `nnet_cnn:supportpackages:InstallRequired` | Visual Inspection Toolbox Model for YOLOX Object Detection |
| 28 | `MATLAB:UndefinedFunction`（`imhypercube`）、找不到 `paviaU.mat` | Hyperspectral Imaging Library |

（每章 main 與 solution 各一個，共 18 個。）

> **「通過」不等於「內容都跑到」**：Ch.17、21、23、27、30 有「支援包不在就說明並跳過」的閘門，所以在沒有支援包的 R2026b 上也會通過。
> 例如 Ch.21 只花 0.4 秒，代表 VLM 段落全部被跳過。這些章節要等支援包裝好、重跑後，才算在 R2026b 驗證完成。

> 階段一結束時，各章內文的數字仍是 R2026a 的量測值；階段二（下方）已逐章重測並更新。

---

## 階段二：安裝支援包並重新量測 ✅ 大部分完成（2026-10-06）

### 1. 請在 R2026b 安裝以下支援包

R2026a 的 42 個支援包**不會**帶到 R2026b，要重新安裝。請用 **Add-Ons → Get Add-Ons** 安裝（10/06 已裝好大部分，缺的見下方第 3 點）：

| 支援包 | 章節 | 必要性 |
|---|---|---|
| Image Processing Toolbox Model for Segment Anything Model 2 | 09, 17, 21（02、20 選用） | 必要 |
| Image Processing Toolbox Model for Circle Detection | 10 | 必要 |
| Optical Design and Simulation Library for Image Processing Toolbox | 12 | 必要 |
| Computer Vision Toolbox OCR Language Data | 15 | 必要 |
| Computer Vision Toolbox Model for Text Detection | 15 | 必要 |
| Computer Vision Toolbox Model for Grounding DINO Object Detection | 17, 21 | 必要 |
| Deep Learning Toolbox Model for ResNet-18 Network | 18, 20, 22, 24 | 必要 |
| **Visual Inspection Toolbox Model for YOLOX Object Detection**（新名稱） | 19 | 必要 |
| Computer Vision Toolbox Model for YOLO v4 Object Detection | 19 | 必要 |
| Computer Vision Toolbox Model for SOLOv2 Instance Segmentation | 20 | 必要 |
| Computer Vision Toolbox Model for OpenAI CLIP Network | 21 | 必要 |
| Computer Vision Toolbox Model for moondream Vision Language Model | 21 | 必要 |
| MATLAB Support Package for USB Webcams | 23 | 必要 |
| Hyperspectral Imaging Library for Image Processing Toolbox | 28 | 必要 |
| Deep Learning Toolbox Model for ResNet-50 Network | 18 | 選用 |
| Deep Learning Toolbox Model for MobileNet-v2 Network | 18 | 選用 |
| Deep Learning Toolbox Model for DarkNet-19 Network（原本漏列） | 18 | 選用 |
| Image Processing Toolbox Model for Segment Anything Model（初代 SAM） | 09（只用來重現 §2 的 sam-base 對照） | 選用 |
| Computer Vision Toolbox Model for Vision Transformer Network | 18 | 選用 |
| Computer Vision Toolbox Model for RTMDet Object Detection | 19 | 選用 |
| Computer Vision Toolbox Model for RAFT Optical Flow Estimation | 24 | 選用 |
| Computer Vision Toolbox Model for Object Keypoint Detection | 27 | 選用 |
| MATLAB Support Package for IP Cameras | 23 | 選用 |
| Image Acquisition Toolbox Support Package for OS Generic Video Interface | 23 | 選用 |
| Image Acquisition Toolbox Support Package for GigE Vision Hardware | 23 | 選用 |
| Deep Learning Toolbox Converter for ONNX Model Format | 30 | 選用 |
| Deep Learning Toolbox Converter for PyTorch Model Format | 30 | 選用 |
| **Visual Inspection Toolbox Model for CounTR Object Counting**（R2026b 起要另裝；10/06 重測時才發現） | 22（§9） | 選用 |

另外兩件事：
- **Ch.25**：在 R2026b 命令視窗執行一次 `installMultiSensorCalibrationTools`（安裝多相機標定工具）。
- **Ch.30**：R2026b 的 `pyenv` 需要重新設定（R2026b 不再支援 Python 3.9）；R2026b 不再內附 Java，Ch.28 若用到 `bioformatsread` 需要安裝「MATLAB Support for OpenJDK」。

以上清單與 `setup/courseRequirements.m` 一致。

> **10/06 更正**：原本把初代 SAM 列為 Ch.17 的必要支援包是錯的（R2026a 版就錯了）。
> `segmentAnythingModel` 與 `imsegsam` 不給名稱時，兩個版本都載入 `"sam2-large"`，課程程式沒有任何地方用到初代 SAM。
> 同時把 Ch.17、Ch.20 判斷「有沒有 SAM」的寫法從「名稱含 Segment Anything」改成比對 SAM 2 支援包的全名。

階段三若導入 Student-Teacher 異常偵測，還要另裝它的模型支援包（名稱待確認後再加入清單）。

裝完後執行 `checkEnvironment` 確認；若名稱有出入（特別是 moondream 的大小寫），更新 `setup/courseRequirements.m`。

### 2. 重測結果（2026-10-06）

**方法**：`verifyChapters` 新增 `CaptureDir`。R2026a 與 R2026b 都跑這份程式（`Fast=false`），逐行比對輸出，再找出內文引用 R2026a 數值的地方。

| 章 | R2026b 的變化 | 教材的處理 |
|---|---|---|
| **Ch.11** | `caliper` 的 `Width` 預設從 50 改成掃描線長的 10%，量到的寬度少 15% | 明確寫 `Width=50`；新增一段教材與一條陷阱 |
| **Ch.12** | `measureIlluminant` 先線性化再平均 | 光源值、白平衡 5.5%（原 6.5%）；補「R2026a 其實把 sRGB 當線性值用」 |
| **Ch.13** | 同一個 `rng(0)` 抽到的物件數不同 | 補「固定種子只保證同一版本可重現」 |
| **Ch.17 解答** | SAM 對人工框與 VLM 框輸出相同遮罩 | 誤差分解 15/85% → 0/100%；BFscore 反向排序消失 |
| **Ch.18 解答** | 淺層網路 0.865 → 0.870 | 差距 5.5 → 6.0 個百分點，結論不變 |
| **Ch.22** | FCDD 可以只給良品；EfficientAD 移除；CounTR 要另裝 | `ch22_trainAnomaly(data,"fcdd")` 改成可訓練（T550 GPU 25.5 秒）；§8 與狀態表改寫 |
| **Ch.25** | `detectCheckerboardPoints` 改進，`mono` 10/10（原 9/10） | 主教材、解答、README 的 `mono` 數字全部更新；邊角差 200 → 225 px |
| **Ch.26 解答** | `pcfitplane` 精修 | NaN→0 的平面差 6.3° → 5.2° |
| **Ch.30** | codegen 失敗不再印原因；`load(buildInfo.mat)` 警告；exe 啟動 18–24 秒 → 5–8 秒 | 改用 `-reportinfo`、`loadBuildInfo`（依版本分支）；「1000 倍」改成「數百倍」 |
| Ch.09 | SAM 2 遮罩差 1 像素 | README 兩個數字 |
| Ch.04、10、14、16、19、23、24、28、29 | 只有計時 | 不改 |

**R2026b 全課程驗證：62/62 通過（快速模式 1502 秒，2026-10-06）。**

另外修正了兩個 **R2026a 版就有的錯**：初代 SAM 其實沒用到（需求清單與 Ch.17／20 的判斷式）；3 個練習檔的表格缺標記。

### 3. 還沒重測的（缺選用支援包或工具）

| 章 | 要安裝的 | 現在的狀態 |
|---|---|---|
| Ch.18 | MobileNet-v2、ResNet-50、DarkNet-19 | 骨幹比較只剩 resnet18；內文保留 R2026a 的數字 |
| Ch.19 | **YOLO v4（必要）**、RTMDet | 對應段落跳過 |
| Ch.22 | CounTR、Student-Teacher | §9 CounTR 跳過；Student-Teacher 是階段三 |
| Ch.24 | RAFT | 跳過 |
| Ch.25 | `installMultiSensorCalibrationTools` | §10 只比兩種方法；內文保留 R2026a 的三方法數字並加註 |
| Ch.27 | Object Keypoint Detection | HRNet 段落跳過 |
| Ch.30 | PyTorch 轉換器 | PyTorch 段落跳過 |

裝好之後重跑這幾章，再更新對應的數字。

### 4. 最後一步
重建 R2026b 版手冊與簡報（`assembleHandbook.py --release R2026b --measured ...`）。

---

## 階段三：導入 R2026b 新功能 ⏳

候選清單（依 `05_R2026b更新對照表.md` 第五節），優先順序：

| 優先 | 章 | 新功能 |
|---|---|---|
| 1 | Ch.08 | `imbinarize` 回傳門檻（**注意單位是影像資料單位，`graythresh` 是正規化值**）；`HistogramRangeMode="data-range"`（實測有可疑行為，導入前要先確認） |
| 1 | Ch.11 | `regionprops` 的 `HasBorderConnections`（rice 93 顆中 24 顆碰邊）；Visual Inspection Toolbox 的 `imageToWorldPlane` |
| 1 | Ch.24 | `sam2VideoObjectSegmenter`（SAM 2 影片分割）與 Kalman 追蹤對照 |
| 1 | Ch.26 | `sfm` 物件、`bundleAdjustment` 的 Huber／Cauchy 損失、`disparitySGM` 範圍不再限於 128 |
| 1 | Ch.30 | GPU Coder 深度學習碼生成不依賴 cuDNN（`coder.DeepLearningConfig("none")`）；`PyTorchModel` |
| 2 | Ch.22 | Student-Teacher 異常偵測（取代 EfficientAD；實測比較結構異常 vs 邏輯異常） |
| 2 | Ch.18–20 | 自動混合精度訓練（可能讓 4 GB GPU 跑得動訓練段落） |
| 2 | Ch.29 | `UIFigureFixture`、App Designer 純文字格式 |
| 3 | 其他 | `uiannotate`、`bwpropfilt3`、`pcclusterprops`、Moondream 1.6B、`readBarcode` 的 `GaussianSigma`… |
