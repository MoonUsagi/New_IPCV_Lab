function [opsys, designNote] = ch12_makeAchromat(focalLength, semiDiameter, options)
%CH12_MAKEACHROMAT 依薄透鏡消色差條件建立膠合雙合透鏡。
%
%   OPSYS = CH12_MAKEACHROMAT(FOCALLENGTH, SEMIDIAMETER) 回傳一個
%   opticalSystem 物件：冕牌（N-BK7）+ 火石（F2）膠合，含像面。
%
%   [OPSYS, DESIGNNOTE] = CH12_MAKEACHROMAT(___) 另外回傳一段人類可讀的
%   設計說明，記錄用了什麼玻璃、算出什麼半徑、以及**設計的限制**。
%
%   名稱-值引數：
%     CrownGlass   冕牌玻璃，預設 "N-BK7"
%     FlintGlass   火石玻璃，預設 "F2"
%     FirstRadius  第一面半徑（自由參數），預設 0.6*FOCALLENGTH
%     CrownThick   冕牌厚度，預設 4
%     FlintThick   火石厚度，預設 2.5
%
%   消色差原理
%   ----------
%   玻璃的折射率隨波長變化（色散），所以單透鏡的藍光與紅光焦點不同。
%   把兩片色散差很大的玻璃組合，讓色散互相抵消：
%
%       phi   = phi1 + phi2                （總光焦度）
%       phi1/V1 + phi2/V2 = 0              （消色差條件）
%
%   V 是阿貝數（色散的倒數指標），phi = 1/f。解出：
%
%       phi1 = phi / (1 - V2/V1)
%       phi2 = -phi1 * V2/V1
%
%   實測效果（第 12 章第 10.4–10.5 節，f=100、f/10）：
%
%       項目                  單透鏡      消色差鏡     改善
%       RMS 點徑 486nm       0.035209    0.001777    19.8x
%       RMS 點徑 588nm       0.006611    0.001157     5.7x
%       RMS 點徑 656nm       0.023620    0.001442    16.4x
%       RMS 全距（色差）      0.028598    0.000620    46.1x
%       焦點位移 (mm)          1.5461      0.0501    30.9x
%
%   注意「改善最大的是藍光」：單透鏡的 focus 本來就是對主波長最佳化的，
%   所以主波長能改善的空間最小。
%
%   本函式的限制（必讀）
%   --------------------
%   **這是薄透鏡近似。** 它忽略了元件厚度與膠合面的實際光焦度，
%   所以算出來的焦距**不會剛好**等於 FOCALLENGTH。
%   實測 FOCALLENGTH=100 時得到約 100.7 mm（差 0.7%）。
%
%   要做真正的設計，還需要迭代最佳化球面像差、彗差與場曲——
%   那是 Optical System Designer APP 搭配 Optimization Toolbox 的工作。
%   本函式的用途是**產生一個能示範消色差效果的合理起點**。
%
%   另一個限制：`Radius` 的絕對值必須遠大於 `SemiDiameter`，
%   否則球面會退化成接近半球，光線追跡會失敗或給出無意義的結果。
%   本函式會檢查並警告。
%
%   範例：
%     [dbl, note] = ch12_makeAchromat(100, 5);
%     disp(note)
%
%     focus(dbl);                       % 注意：handle 物件，就地修改
%     info = paraxialInfo(dbl);
%     s    = spot(dbl);
%     fprintf("f=%.3f mm、f/%.2f、RMS 全距 %.6f\n", ...
%         info.FocalLength, info.FNumber, max(s.RMS)-min(s.RMS));
%
%   另見 OPTICALSYSTEM, ADDREFRACTIVESURFACE, PARAXIALINFO, SPOT,
%   GLASSLIBRARY, OPTICALSYSTEMDESIGNER.

arguments
    focalLength  (1,1) double {mustBePositive}
    semiDiameter (1,1) double {mustBePositive}
    options.CrownGlass  (1,1) string = "N-BK7"
    options.FlintGlass  (1,1) string = "F2"
    options.FirstRadius (1,1) double = NaN
    options.CrownThick  (1,1) double {mustBePositive} = 4
    options.FlintThick  (1,1) double {mustBePositive} = 2.5
end

if exist("opticalSystem", "file") == 0
    error("ch12_makeAchromat:noOptics", ...
        "找不到 opticalSystem。本函式需要 " + ...
        "Optical Design and Simulation Library for Image Processing Toolbox。");
end

% --- 從玻璃庫讀出真實的 Nd 與 Vd，不要寫死 --------------------------
[n1, V1] = glassIndex(options.CrownGlass);
[n2, V2] = glassIndex(options.FlintGlass);

if V1 <= V2
    error("ch12_makeAchromat:glassOrderWrong", ...
        "冕牌玻璃的阿貝數必須大於火石玻璃（目前 %s V=%.2f、%s V=%.2f）。" + ...
        "消色差條件 phi1/V1 + phi2/V2 = 0 需要兩者色散差異夠大，" + ...
        "且正光焦度那片要是低色散的冕牌。", ...
        options.CrownGlass, V1, options.FlintGlass, V2);
end

% --- 薄透鏡消色差條件 -----------------------------------------------
phi  = 1/focalLength;
phi1 = phi / (1 - V2/V1);
phi2 = -phi1 * V2/V1;

R1 = options.FirstRadius;
if isnan(R1)
    R1 = 0.6 * focalLength;
end

% 冕牌：phi1 = (n1-1)(1/R1 - 1/R2)
invR2 = 1/R1 - phi1/(n1-1);
R2 = 1/invR2;

% 火石：phi2 = (n2-1)(1/R2 - 1/R3)
invR3 = invR2 - phi2/(n2-1);
R3 = 1/invR3;

% --- 幾何合理性檢查 -------------------------------------------------
ratios = abs([R1 R2 R3]) / semiDiameter;
if any(ratios < 2)
    warning("ch12_makeAchromat:steepSurface", ...
        "有曲面的 |Radius|/SemiDiameter = %.2f < 2，球面接近半球。" + ...
        "光線追跡可能失敗或給出無意義的結果。" + ...
        "請加大 FirstRadius 或縮小 SemiDiameter。", min(ratios));
end

% --- 組裝 -----------------------------------------------------------
opsys = opticalSystem;
addRefractiveSurface(opsys, Radius=R1, Material=options.CrownGlass, ...
    DistanceToNext=options.CrownThick, SemiDiameter=semiDiameter);
addRefractiveSurface(opsys, Radius=R2, Material=options.FlintGlass, ...
    DistanceToNext=options.FlintThick, SemiDiameter=semiDiameter);
% 最後一面不給 Material：玻璃庫沒有 "air"，省略就是環境介質
addRefractiveSurface(opsys, Radius=R3, ...
    DistanceToNext=focalLength, SemiDiameter=semiDiameter);
addImagePlane(opsys);

designNote = sprintf( ...
    "消色差雙合透鏡（薄透鏡近似）\n" + ...
    "  冕牌 %s  Nd=%.4f Vd=%.2f  厚 %.1f mm\n" + ...
    "  火石 %s  Nd=%.4f Vd=%.2f  厚 %.1f mm\n" + ...
    "  目標焦距 %.1f mm、半口徑 %.2f mm（約 f/%.1f）\n" + ...
    "  元件焦距 f1=%+.3f、f2=%+.3f mm\n" + ...
    "  曲率半徑 R1=%+.3f、R2=%+.3f、R3=%+.3f mm\n" + ...
    "  |R|/SD 比 %.1f / %.1f / %.1f（需 >> 1）\n" + ...
    "  限制：薄透鏡近似忽略厚度，實際焦距會與目標差約 1%%", ...
    options.CrownGlass, n1, V1, options.CrownThick, ...
    options.FlintGlass, n2, V2, options.FlintThick, ...
    focalLength, semiDiameter, focalLength/(2*semiDiameter), ...
    1/phi1, 1/phi2, R1, R2, R3, ratios(1), ratios(2), ratios(3));
designNote = string(designNote);
end

% ========================================================================
function [nd, vd] = glassIndex(name)
%GLASSINDEX 從玻璃庫查出 Nd 與 Vd。
%
%   把折射率寫死在程式裡是個壞習慣：同一個牌號在不同目錄可能有
%   微小差異，而且改玻璃時很容易忘記改常數。直接查庫。

lib = glassLibrary;
glasses = lib.Glasses;

nd = NaN; vd = NaN;
for k = 1:numel(glasses)
    if string(glasses(k).Name) == name
        nd = glasses(k).Nd;
        vd = glasses(k).Vd;
        return
    end
end

error("ch12_makeAchromat:glassNotFound", ...
    "玻璃庫中找不到 ""%s""。可用 glassLibrary 列出全部 %d 種玻璃。", ...
    name, numel(glasses));
end
