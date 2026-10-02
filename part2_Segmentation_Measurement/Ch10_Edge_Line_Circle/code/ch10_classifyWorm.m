function [label, isValid] = ch10_classifyWorm(medianLength, calibration, currentFingerprint)
%CH10_CLASSIFYWORM 依校正過的門檻分類，並檢查設定是否與校正時一致。
%
%   LABEL = CH10_CLASSIFYWORM(MEDIANLENGTH, CALIBRATION, CURRENTFINGERPRINT)
%   把中位線段長度與 CALIBRATION.Threshold 比較，回傳分類標籤。
%   若 CURRENTFINGERPRINT 與校正時的指紋不符，**發出警告**。
%
%   [LABEL, ISVALID] = CH10_CLASSIFYWORM(___) 另外回傳指紋是否相符。
%
%   CALIBRATION 需包含三個欄位：
%     Threshold    判斷門檻
%     Fingerprint  產生此門檻時的設定指紋
%     Source       這個門檻是怎麼來的（人類可讀的說明）
%
%   這支函式在做什麼
%   ----------------
%   它做的事情本身微不足道——一個大於小於的比較。真正的內容是那個檢查：
%   **確認你現在用的設定，和當初校正門檻時的設定是同一套。**
%
%   第 10 章第 8.2 節的事故就是這樣發生的：門檻 58 是用舊版骨架化校正的，
%   後來程式改用 `bwskel`，沒有任何機制提醒，於是分類結果悄悄變錯。
%
%   這個模式適用於所有「經驗門檻」
%   ------------------------------
%   只要一個常數是從資料校正出來的，它就和產生它的管線綁定。
%   本課程後面會反覆遇到：
%     第 19 章  物件偵測的信心門檻   ← 與模型版本、訓練資料綁定
%     第 22 章  瑕疵判定的異常分數門檻 ← 與模型、前處理、產線條件綁定
%   欄位會更多，但機制完全相同。
%
%   範例：
%     [len, ~, fp] = ch10_wormLengthWithFingerprint(bw);
%     cal = struct(Threshold=65.1, Fingerprint=fp, Source="2026-09-16 校正");
%
%     ch10_classifyWorm(len, cal, fp);          % 正常
%
%     [lenOld, ~, fpOld] = ch10_wormLengthWithFingerprint(bw, ...
%         SkeletonMethod="bwmorph");
%     ch10_classifyWorm(lenOld, cal, fpOld);    % 會警告
%
%   另見 CH10_WORMLENGTHWITHFINGERPRINT.

arguments
    medianLength       (1,1) double
    calibration        (1,1) struct
    currentFingerprint (1,1) string
end

requiredFields = ["Threshold" "Fingerprint" "Source"];
missing = requiredFields(~isfield(calibration, requiredFields));
if ~isempty(missing)
    error("ch10_classifyWorm:incompleteCalibration", ...
        "CALIBRATION 缺少欄位：%s。門檻必須附帶它的產生條件。", ...
        join(missing, ", "));
end

isValid = strcmp(currentFingerprint, calibration.Fingerprint);

if medianLength > calibration.Threshold
    label = "伸直（長線段）";
else
    label = "蜷曲（短線段）";
end

if isValid
    fprintf("  中位長度 %.1f → %s（門檻 %.1f，設定相符）\n", ...
        medianLength, label, calibration.Threshold);
else
    fprintf("  中位長度 %.1f → %s（門檻 %.1f）\n", ...
        medianLength, label, calibration.Threshold);
    warning("ch10_classifyWorm:fingerprintMismatch", ...
        "設定與校正時不符，這個分類結果不可信。\n" + ...
        "  校正時：%s\n" + ...
        "  現在：  %s\n" + ...
        "  門檻來源：%s\n" + ...
        "請用目前的設定重新校正門檻。", ...
        calibration.Fingerprint, currentFingerprint, calibration.Source);
end
end
