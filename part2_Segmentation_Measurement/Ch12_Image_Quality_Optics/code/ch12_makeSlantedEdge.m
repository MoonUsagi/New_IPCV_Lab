function E = ch12_makeSlantedEdge(h, w, angleDeg, sensorSigma)
%CH12_MAKESLANTEDEDGE 產生模糊量已知的合成斜邊，用於驗證 MTF 量測。
%
%   E = CH12_MAKESLANTEDEDGE(H, W) 產生 H×W 的斜邊影像，預設傾斜 5 度、
%   感測器模糊 sigma = 0.6 像素。
%
%   E = CH12_MAKESLANTEDEDGE(H, W, ANGLEDEG, SENSORSIGMA) 指定傾斜角度與
%   模擬的感測器模糊量。
%
%   為什麼要「已知模糊量」
%   ----------------------
%   這支函式的用途**不是**產生好看的測試圖，而是產生一張
%   **理論 MTF 可以手算出來**的影像，用來驗證量測程式。
%
%   高斯模糊的 MTF 是 exp(-2*pi^2*sigma^2*f^2)，令它等於 0.5 可得
%
%       f50 = sqrt(log(2) / (2*pi^2*sigma^2))
%
%   所以只要知道 SENSORSIGMA，就知道正確答案是多少。
%   第 12 章第 8.1 節用這個性質檢驗 ch12_measureMTF，
%   發現它在最銳利端偏低 8.9%、最模糊端偏高 9.5%。
%   **沒有這支函式，就不會知道那兩個數字。**
%
%   為什麼邊要「斜」
%   ----------------
%   正對齊的邊只能在整數像素位置取樣，解析度被像素格點鎖死。
%   斜邊讓每一列的邊界落在**不同的次像素位置**；把所有列依邊緣質心
%   對齊疊合之後，就得到一條**超取樣**的邊緣剖面。
%   這是斜邊法（ISO 12233）能達到次像素解析度的全部原因。
%
%   角度不能太小也不能太大：
%     · 太小（< 2 度）→ 各列的次像素位置分布不均，超取樣不完整
%     · 太大（> 15 度）→ 邊緣在單列內跨越太多像素，剖面被拉寬
%   ISO 12233 建議約 5 度，本函式的預設值。
%
%   範例：
%     E = ch12_makeSlantedEdge(256, 256, 5, 0.6);
%     [f50, f20] = ch12_measureMTF(E);
%
%     theory = sqrt(log(2) / (2*pi^2*0.6^2));
%     fprintf("實測 %.4f、理論 %.4f、比值 %.3f\n", f50, theory, f50/theory);
%
%   另見 CH12_MEASUREMTF, ESFRCHART, MEASURESHARPNESS.

arguments
    h (1,1) double {mustBePositive, mustBeInteger}
    w (1,1) double {mustBePositive, mustBeInteger}
    angleDeg    (1,1) double {mustBeInRange(angleDeg, 0.5, 44)} = 5
    sensorSigma (1,1) double {mustBeNonnegative}                = 0.6
end

if angleDeg < 2 || angleDeg > 15
    warning("ch12_makeSlantedEdge:angleOutsideISO", ...
        "傾斜角 %.1f 度落在 ISO 12233 建議範圍（約 2–15 度）之外。" + ...
        "太小會讓次像素取樣不完整，太大會把邊緣剖面拉寬。", angleDeg);
end

[X, Y] = meshgrid(1:w, 1:h);

% 邊界位置隨列號線性移動，這就是「斜」的來源
edgeX = w/2 + tand(angleDeg) * (Y - h/2);

E = double(X > edgeX);

if sensorSigma > 0
    E = imgaussfilt(E, sensorSigma);
end

% 壓到 [0.1 0.9]，避免邊緣剖面被 0 與 1 截斷（真實感測器也不會到全黑全白）
E = 0.1 + 0.8*E;
end
