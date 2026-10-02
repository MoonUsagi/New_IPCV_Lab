%[text] # 第 NN 章　章節標題
%[text] {"align":"left"}IPCV\_Lab 課程教材　｜　MATLAB R2026b　｜　難度：\[基礎\] \[進階\] \[產業\] 擇一　｜　建議時數：N 小時
%[text] ## 學習目標
%[text] 讀完本章並完成練習後，你應該能夠：
%[text] 1. 動詞開頭的可驗證能力敘述
%[text] 2. 第二項能力
%[text] 3. 第三項能力 \
%[text] ## 前置知識
%[text] 第 X 章（章名）。若尚未完成，建議先回去補。
%[text] ## 環境需求
%[text] 執行下方程式碼確認本章所需項目齊備。若出現「請先執行 ipcvSetup」，
%[text] 請先切換到課程根目錄並執行 `ipcvSetup`。
assert(exist("checkEnvironment","file") == 2, ...
    "請先切換到課程根目錄並執行 ipcvSetup，再回來執行本章。");
checkEnvironment(Chapters="NN");
%%
%[text] # 1. 概念
%[text] 以圖解為主、公式為輔。每個概念配一張示意圖或一段可執行的最小範例。
%[text] 說明「為什麼要有這個方法」「它解決什麼問題」「什麼時候不該用它」。
%%
%[text] # 2. APP 探索
%[text] 本課程的五步驟工作流第 ① ② 步：先用互動式 APP 得到結果，再產生程式碼。
%[text] **操作步驟**
%[text] 1. 開啟 APP：在命令列輸入 `appName` 或從「APP」頁籤啟動
%[text] 2. 載入影像
%[text] 3. 調整參數直到結果可接受
%[text] 4. 匯出 > 產生函式，觀察 MATLAB 幫你寫出來的程式碼 \
%[text] 下方是從 APP 產生、再經過整理的程式碼。
%%
%[text] # 3. 程式實作
%[text] ## 3.1 第一個示範
I = imread("coins.png");
figure
imshow(I)
title("原始影像")
%%
%[text] ## 3.2 第二個示範
%[text] 說明這一段在做什麼、參數怎麼選。
%%
%[text] # 4. 函式化與批次化
%[text] 五步驟工作流第 ③ ④ 步。把上面的實驗碼收斂成一支可重用的函式，
%[text] 再用 `imageDatastore` 套用到整個資料夾。
%[text] 可重用函式放在本章的 `code/` 資料夾，此處只示範呼叫方式。
%%
%[text] # 5. 常見陷阱
%[text:table]
%[text] | 陷阱 | 症狀 | 正確做法 |
%[text] | --- | --- | --- |
%[text] | 資料型別 | `uint8` 運算溢位 | 先 `im2double` 再運算 |
%[text:table]
%%
%[text] # 6. R2026b 新功能
%[text] 本節內容需要 MATLAB R2026b。若使用舊版請略過。
%[text] 需安裝支援包：*（若不需要請刪除此行）*
%%
%[text] # 7. 評估與驗證
%[text] 怎麼判斷結果是好的？用什麼指標？呼應第 12 章（影像品質）與第 19 章（偵測指標）。
%%
%[text] # 8. 本章小結
%[text] 三到五句話總結本章的核心觀念。
%[text] ## 函式速查
%[text:table]
%[text] | 函式 | 用途 | 起始版本 |
%[text] | --- | --- | --- |
%[text] | `imread` | 讀取影像檔 | — |
%[text:table]
%%
%[text] # 9. 練習
%[text] 開啟 `exercise/ChNN_Exercise.m` 完成練習；解答在 `exercise/ChNN_Solution.m`。
%%
%[text] # 10. 延伸閱讀
%[text] - [官方文件標題](https://www.mathworks.com/help/images/)
%[text] - 下一章：第 X 章（章名） \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
