# 第 01 章　影像在 MATLAB 中的表示

`[基礎]`　建議時數 3 小時　｜　對應舊章：`01.Basic`

## 學習目標

1. 說明影像在 MATLAB 中就是一個矩陣，並正確判讀它的尺寸與資料型別
2. 在彩色、灰階、二值三種影像型態之間轉換，並知道每次轉換失去了什麼
3. 依任務選擇適當的色彩空間（RGB／HSV／L\*a\*b\*／YCbCr）
4. 避開整數型別運算溢位這個最常見的初學陷阱
5. 用 `imageDatastore` 把單張影像的處理擴展到整個資料夾

## 前置

第 00 章。請確認已執行 `ipcvSetup`。

## 內容

| 節 | 主題 |
|---|---|
| 1 | 概念：影像就是矩陣 |
| 2 | 三種影像型態與轉換（含 Otsu 門檻） |
| 3 | 色彩通道與色彩空間（RGB／HSV／L\*a\*b\*） |
| 4 | 索引影像 |
| 5 | **資料型別：最常見的陷阱** |
| 6 | 檔案 I/O 與中繼資料 |
| 7 | 互動式檢視工具（含 R2026a 的 `uidraw`／`uipaint`） |
| 8 | 函式化與批次化（`imageDatastore`） |
| 9 | 常見陷阱 |
| 10 | R2026a 新功能小結 |

## 核心函式

`imread` `imwrite` `imfinfo` `imshow` `imshowpair` `montage`
`im2gray` `imbinarize` `graythresh` `im2double` `im2uint8`
`rgb2hsv` `rgb2lab` `lab2rgb` `rgb2ind` `imlincomb`
`imageViewer` `uidraw` `uipaint` `createMask` `labeloverlay` `imageDatastore`

## R2026a 新增

| 功能 | 說明 | 版本 |
|---|---|---|
| `imageViewer` 像素資訊、標題、比例尺 | 取代舊的 `imtool` | R2025a |
| `uidraw` 九種 ROI 標註形狀 | 互動繪製並匯出成遮罩 | R2026a |
| `uipaint` 筆刷遮罩 | 塗抹產生二值遮罩 | R2026a |
| `linkviewers` 多視圖同步 | 比較多張影像 | R2026a |

## 環境需求

Image Processing Toolbox。無額外支援包。

```matlab
checkEnvironment(Chapters="01")
```

## 資料

全部使用 MATLAB 內建影像（`peppers.png`、`coins.png`、`rice.png`、
`cameraman.tif`、`hands1.jpg`），不需下載。清單見 `data/datalist.json`。

## 本章函式

| 檔案 | 用途 |
|---|---|
| `code/ch01_imageSummary.m` | 摘要影像性質，回傳單列 table；示範函式化與 `arguments` 驗證 |
| `code/myColorMask.m` | 依色相與飽和度建立遮罩；處理色相跨越 0／1 邊界的情況（加分題解答） |

## 練習

`exercise/Ch01_Exercise.m` 五題 + 一題加分題，解答在 `Ch01_Solution.m`。
建議先自己寫過一遍。

重點題：**練習 4** 是一段有溢位 bug 的程式碼，MATLAB 不會給任何警告，
要靠理解型別才找得出來。

## 下一章

第 02 章　互動式 APP 與五步驟工作流——把本章手寫的色彩篩選，改用
Color Thresholder 互動調出來，再讓 APP 產生等價的程式碼。
