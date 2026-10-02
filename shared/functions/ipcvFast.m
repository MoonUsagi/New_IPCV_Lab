function tf = ipcvFast()
%IPCVFAST 是否處於「快速模式」。
%
%   TF = IPCVFAST() 在快速模式下回傳 true。教材中純粹用來展示效能數字的
%   段落（大量 timeit 呼叫、刻意示範慢速做法的比較）可以用它跳過，
%   讓自動驗證與建置不會因為計時而拖到數分鐘。
%
%   學員正常閱讀教材時 IPCVFAST 回傳 false，所有段落都會執行。
%
%   啟用方式（verifyChapters 會自動設定）：
%     setenv("IPCV_FAST", "1")
%
%   關閉：
%     setenv("IPCV_FAST", "")
%
%   使用慣例：只用它跳過**計時展示**，不要用它跳過會影響後續段落的運算。
%   被跳過的段落要印出一行訊息，讓讀者知道發生了什麼。
%
%   範例：
%     if ipcvFast()
%         disp("（快速模式：略過效能比較）")
%     else
%         t = timeit(@() imgaussfilt(I, 3));
%         fprintf("耗時 %.2f 毫秒\n", t*1000);
%     end
%
%   另見 VERIFYCHAPTERS, BUILDHANDBOOK.

tf = ~isempty(getenv("IPCV_FAST"));
end
