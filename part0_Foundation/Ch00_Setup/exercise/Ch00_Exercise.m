%[text] # 第 00 章　練習
%[text] 環境建置　｜　建議時間：20 分鐘
%[text] 這三題的目的，是讓你之後遇到環境問題時能自己查，而不是卡住。
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup。");
%%
%[text] # 練習 1：查詢單一章節的需求
%[text] 不執行 `checkEnvironment`，改用 `courseRequirements` 查出
%[text] **第 22 章（工業瑕疵檢測）** 需要哪些工具箱與支援包，
%[text] 並分別列出必要與選用項目。
%[text] **預期**：至少會看到 Deep Learning Toolbox 與 AVI Library。

% TODO 查詢並分類列出


%%
%[text] # 練習 2：判斷某條路徑是否可行
%[text] 寫一段程式回答：「我現在的環境能不能完整上完**路徑 B（AI 視覺實戰班）**？」
%[text] 若不行，印出還缺哪些項目。
%[text] **要求**：用 `checkEnvironment` 的回傳值判斷，不要靠讀螢幕輸出。
%[text] **提示**：回傳的 table 有 `Installed` 與 `Level` 欄位。
pathB = ["00" "02" "09" "17" "18" "19" "20" "21" "22"];

% TODO 判斷並回報


%%
%[text] # 練習 3：掃描舊程式碼
%[text] 建立一個暫存資料夾，在裡面放一支刻意使用舊 API 的腳本，
%[text] 再用 `findLegacyAPI` 掃描它，解讀結果。
%[text] **要求**：你的測試腳本至少要包含一個「已移除」等級與一個「建議更新」等級的函式。
%[text] **提示**：已移除的有 `unetLayers`、`fcnLayers` 等；
%[text] 建議更新的有 `estimateGeometricTransform`、`trainNetwork` 等。
testDir = fullfile(tempdir, "ch00_legacy_test");
if ~isfolder(testDir), mkdir(testDir); end

% TODO 寫出測試腳本、掃描、說明每一筆結果的意義


%%
%[text] # 加分題：擴充相容性規則
%[text] `findLegacyAPI` 的規則表寫在 `shared/functions/findLegacyAPI.m` 的
%[text] `legacyRules` 區域函式裡。
%[text] 查閱 MathWorks 的 Release Notes，找出**一個**本課程規則表尚未收錄、
%[text] 但在 R2026a 已被移除或標示為即將移除的影像／視覺函式，把它加進規則表。
%[text] 這題沒有標準答案——重點是讓你習慣「新版出來就去看 Release Notes」。
%[text] 起點：[Image Processing Toolbox Release Notes](https://www.mathworks.com/help/images/release-notes.html)

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
