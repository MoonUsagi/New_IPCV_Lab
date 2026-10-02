function detResults = ch19_mapClasses(raw, keepClasses, targetName)
%CH19_MAPCLASSES 把偵測器的原始類別對應到你的資料集類別。
%
%   DETRESULTS = CH19_MAPCLASSES(RAW, KEEPCLASSES, TARGETNAME) 只保留
%   標籤屬於 KEEPCLASSES 的框，並把它們全部改標成 TARGETNAME，
%   回傳可直接餵給 EVALUATEOBJECTDETECTION 的 table。
%
%   **這個函式看起來只是換標籤，但它是一個會大幅改變分數的決定。**
%
%   COCO 有 80 個類別，你的資料集可能只有一個 `vehicle`。
%   哪些 COCO 類別算「vehicle」？`car` 一定算。`truck` 呢？
%   `bus` 呢？這不是模型能回答的問題——**是你要定義的**。
%
%   實測（40 張車輛影像、YOLOX small-coco、IoU 0.5）：
%
%     對應方式                    框數  precision  recall      AP
%     只把 car 當車                141     19.9%    60.9%   0.2610
%     car + truck                  180     20.6%    80.4%   0.4678
%     **car + truck + bus**        190     20.5%    84.8%  **0.4827**
%     再加 motorcycle              190     20.5%    84.8%   0.4827
%
%   **AP 從 0.261 到 0.483，相對提升 85%——而模型完全沒有改變。**
%
%   三個要注意的地方：
%
%   **① 這不是「調參數」，是「定義任務」。**
%   你不能為了讓分數好看而事後挑一個對應方式，
%   那等於用測試集調超參數。對應方式應該在**看到分數之前**
%   依任務語意決定，然後就固定。
%
%   **② 加 `motorcycle` 完全沒有效果**（框數與分數都沒動），
%   因為這批影像裡根本沒有被判成機車的東西。
%   **對應清單要從實際偵測到的類別推導，不要憑空想。**
%   先看 CH19_RUNDETECTOR 回傳的 ClassCounts。
%
%   **③ recall 漲了 24 個百分點，precision 幾乎沒動。**
%   加入 `truck`／`bus` 補進來的是**原本被漏掉的真車**，
%   而不是新的誤判。這說明漏標的原因是**類別名稱不合**，
%   不是模型看不到那些車。
%
%   另見 CH19_RUNDETECTOR, CH19_CLASSMAPPING, EVALUATEOBJECTDETECTION.

arguments
    raw table
    keepClasses (1,:) string {mustBeNonempty}
    targetName  (1,1) string {mustBeNonzeroLengthText}
end

n = height(raw);
Boxes = cell(n,1); Scores = cell(n,1); Labels = cell(n,1);

for k = 1:n
    L = raw.Labels{k};
    if isempty(L)
        Boxes{k}  = zeros(0,4);
        Scores{k} = zeros(0,1);
        Labels{k} = categorical(strings(0,1), targetName);
        continue
    end
    keep = ismember(string(L), keepClasses);
    Boxes{k}  = raw.Boxes{k}(keep,:);
    Scores{k} = raw.Scores{k}(keep);
    % 全部改標成同一個目標類別
    Labels{k} = repmat(categorical(targetName, targetName), nnz(keep), 1);
end

detResults = table(Boxes, Scores, Labels);
end
