# 第 30 章　部署與系統整合

`[產業]`　建議時數 4 小時　｜　對應舊章：無（全新，補大綱缺口 B15）

> ## 本章的一句話
> **部署不是「把程式搬過去」，是和另一個系統簽一份介面契約——影像的大小、型別、記憶體排列、數值範圍、呼叫的頻率。**
> **契約的每一條都要驗證，因為違反它的時候通常不會報錯。**

## 學習目標

1. 判斷一支 MATLAB 函式能不能產生 C 程式碼，以及要改哪些地方
2. 用 MATLAB Coder 產生 MEX 與 C 函式庫，並驗證結果和 MATLAB 版一致
3. 知道固定大小／可變大小、以行為主／以列為主這些介面契約會在哪裡壞掉
4. 匯出與匯入 ONNX 模型，並**用輸出而不是設定欄位**驗證轉換
5. 估算 MATLAB ↔ Python、獨立執行檔、MEX 各自的呼叫成本
6. 用 MATLAB Compiler 打包，並避免 600 MB 的執行檔
7. 為一個產線場景選擇部署方式，並說出它最可能壞在哪裡

## 本章最重要的八課

### 1. 第 29 章的函式不能直接 codegen——壞在介面，不在演算法（§2）

```
Code generation does not support function argument validation for
name-value arguments for entry-point functions.
```

`ch30_countGrainsCG` 改成位置引數、`assert` 驗證、只收 uint8、**用 `-1` 表示自動門檻（不用 NaN）**、三個數值輸出。
演算法一行沒改，第 29 章的回歸測試確認兩版結果一致（93 顆）。

### 2. MEX 快 1.3–2.1 倍，不是 10 倍（§3、練習 2）

| | 時間（256×256） |
|---|---|
| MATLAB | 19.03 ms |
| MEX | 10.41 ms |

結果完全一致（面積最大差 0）。同一張圖三次量到 1.83、1.63、1.26 倍；練習 2 在 256–2048 邊長量到 1.26–2.05 倍，**沒有隨大小單調變化**（我原本預測會變小，被推翻）。`imopen`、`graythresh` 本來就是編譯過的；MEX 省的是函式之間的直譯開銷。

### 3. MEX 保留 `assert`，C 函式庫不保留（§3、§4、練習 1）

| 輸入 | MEX | 產生的 C 函式庫 |
|---|---|---|
| 128×128 影像 | 報錯（expected [256x256]） | **不報錯**（C 不檢查陣列長度） |
| double 影像 | 報錯（expected 'uint8'） | 型別在編譯時固定 |
| `threshold = 2` | `assert` 失敗 | **安靜地執行** |
| `threshold = NaN` | `assert` 失敗 | **安靜地執行**（`NaN < 0` 是 false） |

打開產生的 `ch30_countGrainsCG.c`，五個 `assert` 一個都不在。

### 4. 「Coder 產生的 C 不需要 MATLAB」只在選對目標時成立（§4）

| 目標 | `.c` 檔 | 行數 | 依賴 |
|---|---|---|---|
| MATLAB 主機（預設） | 22 | 7929（R2026a 7734） | **20 個 MathWorks DLL**（libmwmorphop、IPP、TBB、boost），只能在 Windows x64 跑 |
| ARM Cortex-A | 32 | 17566 | **沒有**——可攜的純 C |

直接在 codegen 資料夾編譯會失敗在 `'tmwtypes.h': No such file or directory`。
**用 `packNGo` 打交付包**（本機 11.6 MB、94 個檔），在包裡編譯才成功。

### 5. 以列為主的緩衝區：函式看到轉置的影像，但計數結果一模一樣（§4、練習 3）

一支真正的 C 程式（`ch30_buildCProgram`，不需要 MATLAB Runtime）：

| 輸入檔 | 顆數 | 門檻 | 第一顆面積 | 報錯？ |
|---|---|---|---|---|
| 以行為主 256×256 | 93 | 0.192157 | 138 | 否 |
| **以列為主** 256×256 | **93** | **0.192157** | **61** | **否** |
| **512×512** | **60** | 0.207843 | 558 | **否** |

**這支函式的主要輸出對轉置免疫**，只驗顆數的整合測試抓不到。而主教材 §2 用 `sort(areas)` 比對——**排序正好把訊號藏起來**。
要比**不排序**的輸出或質心。

### 6. ONNX：看起來掉了其實沒掉；看起來沒事其實轉置了（§6、練習 4）

| 項目 | 原網路 | 匯出再匯入 |
|---|---|---|
| 輸入正規化 | `zerocenter` | `none`（**但輸出最大差 0**，被轉成網路裡的減法） |
| 輸出維度 | `CB` [1000 8] | **`UU` [8 1000]** |
| top-1 一致 | | 8/8（對齊維度之後） |

`max(y,[],1)` 在匯入網路上**安靜地在錯的軸上取值**。而且**批次 1 張的測試抓不到**：1×1000 用 `max(y)` 剛好取對。

### 7. 成本在邊界，不在演算法（§7、§8、§10）

| 呼叫方式 | 本機實測 |
|---|---|
| MEX | 10.4 ms |
| MATLAB | 19.0 ms |
| 一次 Python 呼叫的開銷（OutOfProcess） | 14–31 ms（傳 8.4 MB 也只多幾毫秒） |
| 純 C 程式（含行程啟動） | 約 90 ms |
| **獨立 exe（含 MATLAB Runtime 啟動）** | **5–8 秒**（R2026a 18–24 秒） |

**演算法的差距不到 2 倍，呼叫方式的差距達數百倍**（R2026b 約 850 倍；R2026a 超過 2000 倍）。

### 8. MATLAB Compiler 預設打包 619.8 MB（§8、加分題）

| 選項 | exe | 建置 |
|---|---|---|
| 預設（自動偵測支援包） | **619.8 MB** | 66.7 秒 |
| `SupportPackages="none"` | **1.45 MB** | 17–21 秒 |

自動偵測包進了 Hyperspectral Imaging Library、Circle Detection、Segment Anything Model——全部沒用到。
**打包後第一個要看的是 `includedSupportPackages.txt`。**
另外：程式碼裡的檔名字串（`"rice.png"`）會被相依性分析當成要打包的檔案，產生「Excluded … Not supported in the MATLAB Runtime environment」警告。

## 其他實測

- **GPU Coder：正確，但慢**（§5）。`bwconncomp` 的 `PixelIdxList` 在 GPU 碼生成不支援（C 碼生成可以）；改用 `bwlabel` 的 `ch30_countGrainsGPU` 每種建法結果都和 MATLAB 完全一致，但：

  | 版本 | 256×256 每次 |
  |---|---|
  | MATLAB（對照） | 11 ms |
  | 前處理，半徑寫死在程式碼 | **約 1 ms** |
  | 前處理，**半徑當參數** | **102 秒** |
  | 完整函式，半徑 `coder.Constant(15)`、可變大小 | 1.5 秒（2048² 是 12.3 秒，MATLAB 443 ms） |

  **執行期的結構元素半徑讓 GPU 前處理慢了約 10 萬倍**——同一行在 CPU MEX 上完全沒問題。`coder.Constant` 固定半徑後，呼叫時傳別的值會報錯。
- **Simulink**：MATLAB Function 區塊直接呼叫 `ch30_countGrainsCG`，第一次模擬 29.7 秒（編譯區塊）、第二次 0.8 秒，每步 93 顆。
- **ROS 2 `sensor_msgs/Image`**：`mono8`、`rgb8` 來回一致；**`bgr8` 紅藍對調**——`rosWriteImage` 照原順序寫入 RGB，`rosReadImage` 相信 `encoding` 把它當 BGR 轉回。
- **Python**：`2**53 + 1` 轉 double 差 1、轉 int64 才對；cell → tuple；沒有 numpy 時矩陣 → memoryview（列行順序正確）。
- **strel 的半徑**：我原本以為必須是編譯時常數，實測 MEX 在半徑 5/10/15/25 都與 MATLAB 一致——**印象是錯的**。
- **環境變數 `NoDefaultCurrentDirectoryInExePath`**：讓 codegen 失敗在「'xxx_mex.bat' 不是內部或外部命令」，連 `y = x + 1` 都編不過。`ch30_buildMex` 只在 MATLAB 行程內清掉它。

## R2026b 注意事項

- **codegen 失敗時不再把原因印在命令視窗**，只丟 `emlc:compilationError`（「To view the report, open(...)」）。
  要在程式裡拿到原因，用 `-reportinfo` 讀 `Messages`；**那個變數建在 base 工作區**，包進函式就讀不到，所以寫成 `ch30_codegenMessages`。
- **`load("buildInfo.mat")` 會警告**要求改用 `loadBuildInfo`（R2026a 沒有這個函式），`ch30_buildCProgram` 依版本分支。
- **獨立 exe 的 Runtime 啟動快了 3–4 倍**：R2026a 18–24 秒 → R2026b 第一次 7.4–7.8 秒、之後約 5.2 秒。
- ONNX 匯入多印三行進度訊息；這個模型**仍然**產生自訂層 `Transpose_To_ReshapeLayer1000`（我原本預期 R2026b 會改成內建層，猜錯了）。

## 檔案

| 檔案 | 說明 |
|---|---|
| `Ch30_Main.m` | 主教材（13 節） |
| `code/ch30_countGrainsCG.m` | codegen 友善的顆粒計數（位置引數、`assert`、`-1` 表示自動門檻） |
| `code/ch30_countGrainsGPU.m` | GPU Coder 版（`bwlabel` 取代 `bwconncomp` 的 `PixelIdxList`） |
| `code/ch30_buildMex.m` | 建 MEX（固定／可變大小）或 C 函式庫，有快取，處理環境變數陷阱 |
| `code/ch30_buildCProgram.m` | `packNGo` 打交付包，在包裡編一支純 C 呼叫端 |
| `code/ch30_codegenMessages.m` | 讀 `codegen -reportinfo` 的診斷訊息（R2026b 失敗時不再印原因；變數建在 base 工作區） |
| `code/ch30_onnxRoundTrip.m` | ONNX 匯出→匯入→比輸出，偵測維度轉置 |
| `code/ch30_pythonBridge.m` | Python 型別對照與呼叫成本（不改 `pyenv`） |
| `code/ch30_grainCLI.m` | 命令列介面層（給 Compiler 打包；失敗時非零結束碼） |
| `code/ch30_buildStandalone.m` | MATLAB Compiler 打包與執行，有快取 |
| `exercise/Ch30_Exercise.m` | 六題練習 + 加分題 |
| `exercise/Ch30_Solution.m` | 解答（含實測數字） |

## 環境需求與執行時間

| 產品 | 用在 | 沒有時 |
|---|---|---|
| MATLAB Coder + C 編譯器（本機 MSVC 2019） | §2–§4、練習 1–3 | 顯示既有量測值 |
| GPU Coder + CUDA（本機 12.1） | §5 | 顯示檢查結果 |
| Deep Learning Toolbox + ONNX 轉換器 | §6、練習 4 | 略過 |
| Python（`pyenv`） | §7、練習 5 | 略過 |
| MATLAB Compiler | §8、加分題 | 顯示既有量測值 |
| Simulink、ROS Toolbox | §9 | 略過 |

**所有建置產物都放在 `tempdir`**（`ch30_build`、`ch30_standalone_*`），不寫進課程資料夾。
第一次執行主教材要建置 MEX、可變大小 MEX、C 函式庫、C 程式、exe，**合計約 4–5 分鐘**；之後重用快取。
GPU Coder 的建置每次 3–6 分鐘，主教材**只在 `setenv("IPCV_CH30_GPU_BUILD", "1")` 之後**才建置；
否則有快取就用快取，沒有就只顯示既有量測值（見 §5）。

## 沒有驗證的部分

- **PyTorch 匯入**（`importNetworkFromPyTorch`）與 **TensorFlow 匯出**：本機的 Python 沒有 `torch`、`tensorflow`。
- **ONNX Runtime 推論**：沒有 `onnxruntime`，只驗證了 MATLAB 自己的來回。
- **OpenCV 互通**：沒有安裝 OpenCV Interface 支援包，Python 端也沒有 `cv2`。
- **numpy**：本機 Python 沒有 numpy，numpy 端的記憶體排列沒有驗證。
- **`coder.rowMajor` / `cfg.RowMajor`**：只確認了選項存在，沒有實測產生的程式碼。
- **硬體在環（HIL）、Jetson、ARM 實機**：ARM 目標只驗證了「產生的程式碼不依賴 libmw」，沒有在 ARM 上編譯執行。
- **PLC、OPC UA、資料庫、MATLAB Production Server**：需要設備或伺服器。
- **R2026a 移除 MATLAB Compiler 支援的訓練偵測器函式清單**：請查版本說明，本章沒有逐一測試。

## 延伸閱讀

- `doc codegen`、`doc coder.typeof`、`doc coder.config`、`doc packNGo`、`doc coder.rowMajor`
- `doc coder.gpuConfig`、`doc coder.checkGpuInstall`
- `doc exportONNXNetwork`、`doc importNetworkFromONNX`、`doc importNetworkFromPyTorch`
- `doc pyenv`、`doc pyrun`；MATLAB Engine API for Python
- `doc compiler.build.standaloneApplication`、`doc isdeployed`
- `doc ros2message`、`doc rosReadImage`
