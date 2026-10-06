function req = courseRequirements(chapters)
%COURSEREQUIREMENTS 回傳各章節所需的工具箱與支援包清單。
%
%   REQ = COURSEREQUIREMENTS() 回傳涵蓋全部 31 章的需求表。
%
%   REQ = COURSEREQUIREMENTS(CHAPTERS) 只回傳指定章節的需求。CHAPTERS 為章號
%   字串陣列，例如 ["00" "01" "04"]。
%
%   回傳的 table 欄位：
%     Chapter  章號（"00"–"30"）
%     Kind     "Toolbox"（授權工具箱）或 "AddOn"（支援包 / Add-On）
%     Name     名稱，需與 matlab.addons.installedAddons 的 Name 欄位完全一致
%     Level    "required"（缺少則該章無法進行）或 "optional"（僅影響部分單元）
%
%   名稱以 R2026b 為準。與 R2026a 版的差異：
%   - Lidar Toolbox 改名為 Point Cloud Toolbox，並吸收 Computer Vision Toolbox 的
%     通用點雲函式（pcread、pcfitplane、pcregistericp…）→ Ch.26 需要它
%   - Automated Visual Inspection Library（支援包）由 Visual Inspection Toolbox
%     （授權產品）取代：caliper（Ch.11）、insertObjectInImage（Ch.13）、
%     yoloxObjectDetector（Ch.19）、PatchCore／FCDD／FastFlow（Ch.22）都在這裡
%   - YOLOX 的預訓練模型改由「Visual Inspection Toolbox Model for YOLOX Object Detection」提供
%   - 多相機標定（Ch.25）要先執行 installMultiSensorCalibrationTools（不是 Add-On，
%     由 ch25 的程式在執行時檢查）
%   新增章節時只需在此檔加列，checkEnvironment 會自動反映。
%
%   另見 CHECKENVIRONMENT, DOWNLOADCOURSEDATA.

arguments
    chapters (1,:) string = "all"
end

% 每一列：章號, 種類, 名稱, 層級
raw = [
    % ---- 全課程共同基礎 -------------------------------------------------
    "*" , "Toolbox", "Image Processing Toolbox"                                       , "required"
    "*" , "Toolbox", "Computer Vision Toolbox"                                        , "required"

    % ---- Part 0 ---------------------------------------------------------
    "00", "Toolbox", "Image Processing Toolbox"                                       , "required"

    % ---- Part I 影像處理基礎 --------------------------------------------
    "01", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "02", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "02", "AddOn"  , "Image Processing Toolbox Model for Segment Anything Model 2"    , "optional"
    "03", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "03", "Toolbox", "Deep Learning Toolbox"                                          , "optional"
    "04", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "05", "Toolbox", "Wavelet Toolbox"                                                , "required"
    "05", "Toolbox", "Signal Processing Toolbox"                                      , "optional"
    "06", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "07", "Toolbox", "Image Processing Toolbox"                                       , "required"

    % ---- Part II 分割、量測與品質 ---------------------------------------
    "08", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "08", "Toolbox", "Statistics and Machine Learning Toolbox"                        , "optional"
    "09", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "09", "AddOn"  , "Image Processing Toolbox Model for Segment Anything Model 2"    , "required"
    "09", "AddOn"  , "Image Processing Toolbox Model for Segment Anything Model"      , "optional"
    "10", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "10", "AddOn"  , "Image Processing Toolbox Model for Circle Detection"            , "required"
    "11", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "11", "Toolbox", "Visual Inspection Toolbox"                                      , "optional"
    "12", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "12", "AddOn"  , "Optical Design and Simulation Library for Image Processing Toolbox", "required"
    "12", "Toolbox", "Optimization Toolbox"                                           , "optional"
    "13", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "13", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "13", "Toolbox", "Visual Inspection Toolbox"                                      , "optional"

    % ---- Part III 特徵與傳統辨識 ----------------------------------------
    "14", "Toolbox", "Computer Vision Toolbox"                                        , "required"
    "15", "Toolbox", "Computer Vision Toolbox"                                        , "required"
    "15", "AddOn"  , "Computer Vision Toolbox OCR Language Data"                      , "required"
    "15", "AddOn"  , "Computer Vision Toolbox Model for Text Detection"               , "required"
    "16", "Toolbox", "Computer Vision Toolbox"                                        , "required"
    "16", "Toolbox", "Statistics and Machine Learning Toolbox"                        , "required"

    % ---- Part IV AI 視覺 ------------------------------------------------
    "17", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "17", "AddOn"  , "Computer Vision Toolbox Model for Grounding DINO Object Detection", "required"
    "17", "AddOn"  , "Image Processing Toolbox Model for Segment Anything Model 2"    , "required"
    "18", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "18", "Toolbox", "Statistics and Machine Learning Toolbox"                        , "required"
    "18", "AddOn"  , "Deep Learning Toolbox Model for ResNet-18 Network"              , "required"
    "18", "AddOn"  , "Deep Learning Toolbox Model for ResNet-50 Network"              , "optional"
    "18", "AddOn"  , "Deep Learning Toolbox Model for MobileNet-v2 Network"           , "optional"
    "18", "AddOn"  , "Deep Learning Toolbox Model for DarkNet-19 Network"             , "optional"
    "18", "AddOn"  , "Computer Vision Toolbox Model for Vision Transformer Network"   , "optional"
    "18", "Toolbox", "Parallel Computing Toolbox"                                     , "optional"
    "19", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "19", "Toolbox", "Visual Inspection Toolbox"                                      , "required"
    "19", "AddOn"  , "Visual Inspection Toolbox Model for YOLOX Object Detection"     , "required"
    "19", "AddOn"  , "Computer Vision Toolbox Model for YOLO v4 Object Detection"     , "required"
    "19", "AddOn"  , "Computer Vision Toolbox Model for RTMDet Object Detection"      , "optional"
    "19", "Toolbox", "Parallel Computing Toolbox"                                     , "optional"
    "20", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "20", "AddOn"  , "Deep Learning Toolbox Model for ResNet-18 Network"              , "required"
    "20", "AddOn"  , "Computer Vision Toolbox Model for SOLOv2 Instance Segmentation" , "required"
    "20", "AddOn"  , "Image Processing Toolbox Model for Segment Anything Model 2"    , "optional"
    "20", "Toolbox", "Parallel Computing Toolbox"                                     , "optional"
    "21", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "21", "AddOn"  , "Computer Vision Toolbox Model for OpenAI CLIP Network"          , "required"
    "21", "AddOn"  , "Computer Vision Toolbox Model for moondream Vision Language Model", "required"
    "21", "AddOn"  , "Computer Vision Toolbox Model for Grounding DINO Object Detection", "required"
    "21", "AddOn"  , "Image Processing Toolbox Model for Segment Anything Model 2"    , "required"
    "22", "Toolbox", "Deep Learning Toolbox"                                          , "required"
    "22", "Toolbox", "Visual Inspection Toolbox"                                      , "required"
    "22", "AddOn"  , "Deep Learning Toolbox Model for ResNet-18 Network"              , "required"
    "22", "AddOn"  , "Visual Inspection Toolbox Model for CounTR Object Counting"     , "optional"

    % ---- Part V 動態、3D 與空間視覺 -------------------------------------
    "23", "Toolbox", "Image Acquisition Toolbox"                                      , "required"
    "23", "AddOn"  , "MATLAB Support Package for USB Webcams"                         , "required"
    "23", "AddOn"  , "MATLAB Support Package for IP Cameras"                          , "optional"
    "23", "AddOn"  , "Image Acquisition Toolbox Support Package for OS Generic Video Interface", "optional"
    "23", "AddOn"  , "Image Acquisition Toolbox Support Package for GigE Vision Hardware", "optional"
    "24", "Toolbox", "Computer Vision Toolbox"                                        , "required"
    "24", "Toolbox", "Deep Learning Toolbox"                                          , "optional"
    "24", "AddOn"  , "Deep Learning Toolbox Model for ResNet-18 Network"              , "required"
    "24", "Toolbox", "Sensor Fusion and Tracking Toolbox"                             , "optional"
    "24", "AddOn"  , "Computer Vision Toolbox Model for RAFT Optical Flow Estimation" , "optional"
    "25", "Toolbox", "Computer Vision Toolbox"                                        , "required"
    "26", "Toolbox", "Computer Vision Toolbox"                                        , "required"
    "26", "Toolbox", "Point Cloud Toolbox"                                            , "required"
    "26", "Toolbox", "Navigation Toolbox"                                             , "optional"
    "27", "Toolbox", "Computer Vision Toolbox"                                        , "required"
    "27", "AddOn"  , "Computer Vision Toolbox Model for Object Keypoint Detection"    , "optional"

    % ---- Part VI 工程化與部署 -------------------------------------------
    "28", "Toolbox", "Image Processing Toolbox"                                       , "required"
    "28", "AddOn"  , "Hyperspectral Imaging Library for Image Processing Toolbox"     , "required"
    "28", "Toolbox", "Medical Imaging Toolbox"                                        , "optional"
    "29", "Toolbox", "MATLAB Test"                                                    , "optional"
    "30", "Toolbox", "MATLAB Coder"                                                   , "required"
    "30", "Toolbox", "GPU Coder"                                                      , "optional"
    "30", "Toolbox", "Embedded Coder"                                                 , "optional"
    "30", "AddOn"  , "Deep Learning Toolbox Converter for ONNX Model Format"          , "optional"
    "30", "AddOn"  , "Deep Learning Toolbox Converter for PyTorch Model Format"       , "optional"
    "30", "Toolbox", "Simulink"                                                       , "optional"
    "30", "Toolbox", "MATLAB Compiler"                                                , "optional"
    "30", "Toolbox", "ROS Toolbox"                                                    , "optional"
    ];

req = table(raw(:,1), raw(:,2), raw(:,3), raw(:,4), ...
    VariableNames=["Chapter" "Kind" "Name" "Level"]);

if ~(isscalar(chapters) && chapters == "all")
    keep = ismember(req.Chapter, [chapters, "*"]);
    req = req(keep,:);
end
end
