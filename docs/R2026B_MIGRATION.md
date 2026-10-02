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

> **還沒改的**：各章內文裡「本機實測」的數字大多仍是 **R2026a** 的量測值。
> 例如 Ch.30 解答開頭寫「數字是在 MATLAB R2026a 上跑出來的」——在階段二重測之前，這句話是正確的，所以保留。

---

## 階段二：安裝支援包並重新量測 ⏳（需要你先安裝）

### 1. 請在 R2026b 安裝以下支援包

R2026a 的 42 個支援包**不會**帶到 R2026b，R2026b 目前 0 個。請用 **Add-Ons → Get Add-Ons** 安裝：

| 支援包 | 章節 | 必要性 |
|---|---|---|
| Image Processing Toolbox Model for Segment Anything Model 2 | 09, 17, 21（02 選用） | 必要 |
| Image Processing Toolbox Model for Segment Anything Model | 17（09、20 選用） | 必要 |
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
| Computer Vision Toolbox Model for Vision Transformer Network | 18 | 選用 |
| Computer Vision Toolbox Model for RTMDet Object Detection | 19 | 選用 |
| Computer Vision Toolbox Model for RAFT Optical Flow Estimation | 24 | 選用 |
| Computer Vision Toolbox Model for Object Keypoint Detection | 27 | 選用 |
| MATLAB Support Package for IP Cameras | 23 | 選用 |
| Image Acquisition Toolbox Support Package for OS Generic Video Interface | 23 | 選用 |
| Image Acquisition Toolbox Support Package for GigE Vision Hardware | 23 | 選用 |
| Deep Learning Toolbox Converter for ONNX Model Format | 30 | 選用 |
| Deep Learning Toolbox Converter for PyTorch Model Format | 30 | 選用 |

另外兩件事：
- **Ch.25**：在 R2026b 命令視窗執行一次 `installMultiSensorCalibrationTools`（安裝多相機標定工具）。
- **Ch.30**：R2026b 的 `pyenv` 需要重新設定（R2026b 不再支援 Python 3.9）；R2026b 不再內附 Java，Ch.28 若用到 `bioformatsread` 需要安裝「MATLAB Support for OpenJDK」。

以上清單與 `setup/courseRequirements.m` 一致。階段三若導入 Student-Teacher 異常偵測，還要另裝它的模型支援包（名稱待確認後再加入清單）。

裝完後執行 `checkEnvironment` 確認；若名稱有出入（特別是 moondream 的大小寫），更新 `setup/courseRequirements.m`。

### 2. 裝完之後我會做的事
1. 在 R2026b 跑完整 `verifyChapters`（62 個檔案）。
2. **重測內文數字**：逐章比對 R2026b 的輸出與內文引用的數字，差異超過量級的地方改寫（像 Ch.26 那樣保留兩版對照）。
   已知一定要重測的：Ch.12（`measureIlluminant`）、Ch.25（棋盤格偵測改進）、Ch.30（ONNX 內建層、`codegen` 錯誤訊息）、Ch.19（YOLOX 換了支援包）。
3. 重建 R2026b 版手冊與簡報。

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
