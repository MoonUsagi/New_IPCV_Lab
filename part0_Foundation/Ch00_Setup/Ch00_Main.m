%[text] # 第 00 章　課程地圖、環境建置與資料準備
%[text] IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\]　｜　建議時數：2 小時
%[text:tableOfContents]{"heading":"本章目錄"}
%[text] ## 學習目標
%[text] 完成本章後，你應該能夠：
%[text] 1. 確認自己的 MATLAB 環境是否足以進行所選的學習路徑
%[text] 2. 取得課程所需的全部資料集
%[text] 3. 說明本課程的「五步驟工作流」，並知道每一章會如何依循它
%[text] 4. 在遇到環境問題時，自行定位是缺工具箱、缺支援包、還是缺 GPU 記憶體 \
%[text] ## 前置知識
%[text] 無。本章是整套課程的起點。
%%
%[text] # 1. 這套課程在教什麼
%[text] 本課程涵蓋 **6 大模組、31 章、約 102 小時**，從影像的資料表示一路到產線部署。
%[text] 全課程以「**任務／能力**」分類，而不是以「用哪個 APP」分類——APP 是達成任務的
%[text] 手段，會出現在需要它的每一章裡。
%[text:table]
%[text] | 模組 | 名稱 | 章節 | 時數 | 重點 |
%[text] | --- | --- | --- | --- | --- |
%[text] | Part 0 | 導論與環境 | Ch.00 | 2h | 你正在讀的這一章 |
%[text] | Part I | 影像處理基礎 | Ch.01–07 | 20h | 表示、增強、濾波、頻域、形態學、幾何轉換 |
%[text] | Part II | 分割、量測與品質 | Ch.08–13 | 18h | 傳統分割、SAM 2、邊緣、量測、品質、修復 |
%[text] | Part III | 特徵與傳統辨識 | Ch.14–16 | 10h | 特徵比對、條碼與 OCR、傳統偵測 |
%[text] | Part IV | AI 視覺 | Ch.17–22 | 24h | 標註、分類、偵測、分割、視覺語言模型、瑕疵檢測 |
%[text] | Part V | 動態、3D 與空間視覺 | Ch.23–27 | 18h | 串流、追蹤、相機標定、點雲重建、姿態與 AR |
%[text] | Part VI | 工程化與部署 | Ch.28–30 | 10h | 大型影像、應用程式化、部署整合 |
%[text:table]
%%
%[text] # 2. 選一條學習路徑
%[text] 你**不需要**照 00 到 30 全部跑完。依你的目的選一條路徑：
%[text:table]
%[text] | 路徑 | 對象 | 章節 | 時數 |
%[text] | --- | --- | --- | --- |
%[text] | **A 影像處理基礎班** | 初學者、非資工背景 | 00, 01, 02, 03, 04, 06, 08 | 21h |
%[text] | **B AI 視覺實戰班** | 有影像基礎，要導入深度學習 | 00, 02, 09, 17, 18, 19, 20, 21, 22 | 32h |
%[text] | **C 產業檢測與部署班** | AOI／製造業工程師 | 00, 02, 08, 10, 11, 12, 15, 19, 22, 23, 25 | 36h |
%[text] | **D 完整學程** | 學校一學期課程、企業完整培訓 | 全部 31 章 | 102h |
%[text:table]
%[text] 把你選的路徑填進下面的變數，本章後續的環境檢查就只會檢查你真正需要的項目。
learningPath = "B";   % 改成 "A"、"B"、"C" 或 "D"

switch learningPath
    case "A", myChapters = ["00" "01" "02" "03" "04" "06" "08"];
    case "B", myChapters = ["00" "02" "09" "17" "18" "19" "20" "21" "22"];
    case "C", myChapters = ["00" "02" "08" "10" "11" "12" "15" "19" "22" "23" "25"];
    case "D", myChapters = "all";
    otherwise, error("learningPath 必須是 ""A""、""B""、""C"" 或 ""D""。");
end

fprintf("已選擇路徑 %s，共 %s 章\n", learningPath, ...
    string(numel(myChapters)) + ternaryStr(isequal(myChapters,"all"), " (全部)", ""));
%%
%[text] # 3. 設定課程路徑
%[text] 每次重新開啟 MATLAB 後，都要先在**課程根目錄**執行一次 `ipcvSetup`。
%[text] 它會把 `setup`、`shared/functions` 以及每一章的 `code`、`data`、`assets`
%[text] 加入 MATLAB 搜尋路徑。
%[text] 若你希望一勞永逸，可以執行 `ipcvSetup(Save=true)` 把路徑存檔。
assert(exist("checkEnvironment","file") == 2, ...
    "找不到 checkEnvironment。請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");

disp("課程路徑已設定。")
%%
%[text] # 4. 檢查環境
%[text] `checkEnvironment` 會比對你選定路徑所需的工具箱與支援包，列出缺少的項目。
%[text] **必要（required）** 缺少代表該章完全無法進行；**選用（optional）** 只影響部分單元。
report = checkEnvironment(Chapters=myChapters);
%%
%[text] ## 4.1 把結果存成報告
%[text] 企業內訓時，可以請每位學員先跑這一段，把 HTML 報告回傳給講師，
%[text] 開課前就能確認全班環境一致。
reportFile = fullfile(tempdir, "ipcv_env_report.html");
checkEnvironment(Chapters=myChapters, ReportFile=reportFile, Verbose=false);
fprintf("環境報告：%s\n", reportFile);
%%
%[text] ## 4.2 缺少項目怎麼辦
%[text] 支援包一律從 **首頁 > 附加功能 > 取得附加功能（Add-On Explorer）** 安裝，
%[text] 搜尋 `checkEnvironment` 列出的名稱即可。
%[text] 本課程用到的支援包中，以下幾個是 **R2026a 才有的新項目**，
%[text] 也是本次改版最主要的賣點所在：
%[text:table]
%[text] | 支援包 | 用於 | 帶來什麼 |
%[text] | --- | --- | --- |
%[text] | Image Processing Toolbox Model for Segment Anything Model 2 | Ch.09, 17, 21 | SAM 2 零樣本分割與自動標註 |
%[text] | Computer Vision Toolbox Model for Grounding DINO Object Detection | Ch.17, 21 | 用一句話就能偵測物件 |
%[text] | Computer Vision Toolbox Model for OpenAI CLIP Network | Ch.21 | 零樣本分類、以文搜圖 |
%[text] | Image Processing Toolbox Model for Circle Detection | Ch.10 | 深度學習圓形偵測 |
%[text] | Optical Design and Simulation Library for Image Processing Toolbox | Ch.12 | 光學系統設計與模擬 |
%[text:table]
%%
%[text] # 5. GPU 與記憶體
%[text] Part IV（AI 視覺）的訓練單元會用到 GPU。沒有 GPU 也能跑，只是慢很多。
%[text] 下面這段會告訴你可用的 GPU 記憶體，以及教材該怎麼配合你的硬體。
if exist("canUseGPU","file") == 2 && canUseGPU
    d = gpuDevice;
    freeGB = d.AvailableMemory / 1e9;
    fprintf("GPU：%s\n可用記憶體：%.1f GB\n\n", d.Name, freeGB);
    if freeGB < 6
        fprintf(['建議：可用記憶體低於 6 GB。訓練單元請採用教材提供的「小記憶體設定」——\n' ...
                 '  · MiniBatchSize 調小（教材預設值的一半）\n' ...
                 '  · 影像尺寸用教材的較小選項\n' ...
                 '  · 優先使用預訓練模型推論，訓練單元改跑教材附的精簡資料集\n']);
    else
        fprintf("記憶體充足，可直接使用教材預設訓練設定。\n");
    end
else
    fprintf(['偵測不到可用 GPU。深度學習章節仍可執行，但：\n' ...
             '  · 推論（使用預訓練模型）可接受，只是較慢\n' ...
             '  · 訓練單元請改用教材提供的精簡資料集，或改看教材內附的訓練結果\n']);
end
%%
%[text] # 6. 取得課程資料
%[text] 本課程的資料分三種來源，`downloadCourseData` 會處理需要下載的部分：
%[text] 1. **MATLAB 內建影像**（如 `coins.png`、`cameraman.tif`）——不需下載，直接可用
%[text] 2. **課程自備小型素材**——已隨教材附上，在各章的 `data` 資料夾
%[text] 3. **大型資料集與模型權重**——不放在版本庫，執行下面的指令下載 \
%[text] 下載內容會放進本機快取，重複執行不會重新下載。
if exist("downloadCourseData","file") == 2
    downloadCourseData(Chapters=myChapters, DryRun=true);   % 先看看要下載什麼
else
    disp("downloadCourseData 尚未安裝，略過。")
end
%%
%[text] # 7. 每一章長什麼樣子
%[text] 全部 31 章結構一致，你可以預期在同樣的位置找到同樣的東西：
%[text:table]
%[text] | 檔案／資料夾 | 內容 |
%[text] | --- | --- |
%[text] | `ChNN_Main.m` | 主教材。用 Live Editor 開啟，逐段執行 |
%[text] | `code/` | 可重用函式，已加入搜尋路徑 |
%[text] | `exercise/` | 練習題與解答 |
%[text] | `data/` | 本章素材與資料清單 |
%[text] | `README.md` | 章節摘要、函式清單、環境需求 |
%[text:table]
%[text] 主教材檔是 **純文字 Live Code 格式（.m）**——用 Live Editor 開啟會是完整的
%[text] 互動式教材，用一般文字編輯器開啟則是可讀的純文字，也能用 Git 做版本比對。
%%
%[text] # 8. 五步驟工作流
%[text] 這是貫穿全課程的方法論。每一章的實作都走同一條路徑，
%[text] 目的是讓你養成「從探索到交付」的完整習慣，而不是停在「跑出一張圖」。
%[text:table]
%[text] | 步驟 | 做什麼 | 產出 |
%[text] | --- | --- | --- |
%[text] | ① 互動探索 | 用 APP 調參數，快速確認方法可行 | 一組可接受的參數 |
%[text] | ② 產生程式碼 | APP 的「產生函式／指令碼」 | 一段能重現結果的程式碼 |
%[text] | ③ 函式化 | 加上 `arguments` 驗證、命名、註解 | 一支可重用的函式 |
%[text] | ④ 批次化 | 用 `imageDatastore` 套用到整個資料夾 | 一份可跑全資料集的流程 |
%[text] | ⑤ 評估與部署 | 量化好壞，必要時產生 C／CUDA 程式碼 | 可交付的成果 |
%[text:table]
%[text] 多數教學到 ② 就結束了。本課程的重點在 ③ 到 ⑤——那才是真正能用在工作上的部分。
%%
%[text] # 9. 版本策略與相容性
%[text] 本教材對標 **R2026a**。幾個你該知道的版本事實：
%[text] - **R2025b 的 Image Processing 與 Computer Vision Toolbox 都只有錯誤修正，沒有新功能。**
%[text] 因此若你從 R2024b 升級，實質的新功能集中在 R2025a 與 R2026a 兩版。
%[text] - 產線環境若需鎖版，R2025b 是穩定的選擇；研發導入則建議 R2026a。 \
%[text] ## R2026a 的相容性地雷
%[text] 如果你手上有舊教材或舊專案，以下幾項會直接出問題：
%[text:table]
%[text] | 項目 | 影響 | 改用 |
%[text] | --- | --- | --- |
%[text] | `segnetLayers` `unetLayers` `unet3dLayers` `deeplabv3plusLayers` `fcnLayers` | **已移除，直接報錯** | `unet` `unet3d` `deeplabv3plus` |
%[text] | `vision.AlphaBlender` | **R2026b 已移除** | `imblend` `insertObjectMask` |
%[text] | `insertText` | 預設字型變更，輸出外觀不同 | 無需改，但舊截圖需重拍 |
%[text] | `estimateGeometricTransform` | 舊 API | `estgeotform2d` |
%[text] | SAM 預設模型 | 改為 `sam2-large` | 需安裝 SAM 2 支援包 |
%[text:table]
%[text] 下面這段會掃描你指定的資料夾，找出用到已移除函式的舊程式碼。
%[text] 把路徑改成你自己的專案資料夾即可。
legacyFolder = pwd;    % 改成你要掃描的資料夾
findLegacyAPI(legacyFolder);
%%
%[text] # 10. 常見問題排除
%[text:table]
%[text] | 症狀 | 原因 | 解法 |
%[text] | --- | --- | --- |
%[text] | `git clone` 失敗，訊息含 `Filename too long` | Windows 路徑上限 260 字元 | 執行 `git config --global core.longpaths true`，或把課程放在較短的路徑如 `C:\IPCV` |
%[text] | 找不到 `checkEnvironment` 等函式 | 沒執行 `ipcvSetup` | 切到課程根目錄執行 `ipcvSetup` |
%[text] | 訓練時 `Out of memory on device` | GPU 記憶體不足 | 調小 `MiniBatchSize`、縮小輸入影像、改用較小的骨幹網路 |
%[text] | 第一次呼叫模型時卡很久 | 正在下載模型權重 | 屬正常，權重約 100 MB–2 GB，下載一次後會快取 |
%[text] | 中文顯示成方框 | 字型缺失 | 圖上文字改用英文，或 `set(groot,"defaultAxesFontName","Microsoft JhengHei")` |
%[text:table]
%%
%[text] # 11. 本章小結
%[text] 你現在應該已經：選好了一條學習路徑、確認環境可用、知道缺什麼要裝什麼、
%[text] 也知道每一章會長什麼樣子。
%[text] 最重要的一件事：**每次開 MATLAB 先執行 `ipcvSetup`**。
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 |
%[text] | --- | --- |
%[text] | `ipcvSetup` | 設定課程搜尋路徑 |
%[text] | `checkEnvironment` | 檢查工具箱與支援包 |
%[text] | `courseRequirements` | 查詢各章需求清單 |
%[text] | `downloadCourseData` | 下載課程資料集 |
%[text] | `findLegacyAPI` | 掃描已移除／過時的函式 |
%[text] | `matlabRelease` | 查詢 MATLAB 版本 |
%[text] | `matlab.addons.installedAddons` | 列出已安裝的附加功能 |
%[text] | `canUseGPU` `gpuDevice` | 檢查 GPU 可用性與記憶體 |
%[text:table]
%%
%[text] # 12. 練習
%[text] 開啟 `exercise/Ch00_Exercise.m` 完成三題環境檢查練習。
%%
%[text] # 13. 下一步
%[text] - 路徑 A：前往 **第 01 章　影像在 MATLAB 中的表示**
%[text] - 路徑 B：前往 **第 02 章　互動式 APP 與五步驟工作流**
%[text] - 路徑 C：前往 **第 02 章**，之後接第 08 章 \

function s = ternaryStr(cond, a, b)
if cond, s = a; else, s = b; end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
