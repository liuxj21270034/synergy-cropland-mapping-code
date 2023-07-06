;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;menu
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro globalmapping_define_buttons, buttonInfo

    ;Define system parameter
    defsysv, '!g_nullValue', 'Nothing'
    defsysv, '!b_true', 0
    defsysv, '!b_false', 1
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create first menu "Cropland Mapping"
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ENVI_DEFINE_MENU_BUTTON, buttonInfo, VALUE = 'Cropland Mapping', $
    /MENU, REF_VALUE = 'Basic Tools', /SIBLING, POSITION = 'after'
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Cultivated Land Area Calculation" Secondary Menu 
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Cultivated Land Area Calculation', $
    UVALUE = 'AdminRegionCropArea', event_pro ='proAdminRegionCropArea', REF_VALUE = 'Cropland Mapping'
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy Data Generation" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy Data Generation', $
    UVALUE = 'CreateSynergyMap', event_pro ='proCreateSynergyMap', REF_VALUE = 'Cropland Mapping'    
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy Data Correction" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy Data Correction', $
    UVALUE = 'ModifyWithSynergyMap', event_pro ='proModifyWithSynergyMap', REF_VALUE = 'Cropland Mapping'
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Calculation of Proportional Data" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Calculation of Proportional Data', $
    UVALUE = 'CalProportionData', event_pro ='proCalProportionData', REF_VALUE = 'Cropland Mapping'
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Exception Handling" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Exception Handling', $
    UVALUE = 'NaNValueKiller', event_pro ='proNaNValueKiller', REF_VALUE = 'Cropland Mapping'


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Preliminary Synergy of Cropland with Precision" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Cropland with Precision', /MENU, REF_VALUE = 'Cropland Mapping', POSITION = 'last', /SEPARATOR
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Five Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Five Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithFive', event_pro ='proCalCroplandSynergyWithFive', REF_VALUE = 'Synergy of Cropland with Precision'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Six Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Six Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithSix', event_pro ='proCalCroplandSynergyWithSix', REF_VALUE = 'Synergy of Cropland with Precision'



  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Preliminary Synergy of Cropland with Statistical Accuracy" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Cropland with Statistical Accuracy', /MENU, REF_VALUE = 'Cropland Mapping', POSITION = 'last'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Three Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Three Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithThreeByRegion', event_pro ='proCalCroplandSynergyWithThreeByRegion', REF_VALUE = 'Synergy of Cropland with Statistical Accuracy'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Four Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Four Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithFourByRegion', event_pro ='proCalCroplandSynergyWithFourByRegion', REF_VALUE = 'Synergy of Cropland with Statistical Accuracy'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Five Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Five Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithFiveByRegion', event_pro ='proCalCroplandSynergyWithFiveByRegion', REF_VALUE = 'Synergy of Cropland with Statistical Accuracy'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Six Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Six Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithSixByRegion', event_pro ='proCalCroplandSynergyWithSixByRegion', REF_VALUE = 'Synergy of Cropland with Statistical Accuracy'
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Seven Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Seven Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithSevenByRegion', event_pro ='proCalCroplandSynergyWithSevenByRegion', REF_VALUE = 'Synergy of Cropland with Statistical Accuracy'    



  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Preliminary Synergy of Cropland with Sample Accuracy" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Cropland with Sample Accuracy', /MENU, REF_VALUE = 'Cropland Mapping', POSITION = 'last'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Three Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Three Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithThreeByAccuracy', event_pro ='proCalCroplandSynergyWithThreeByAccuracy', REF_VALUE = 'Synergy of Cropland with Sample Accuracy'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Four Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Four Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithFourByAccuracy', event_pro ='proCalCroplandSynergyWithFourByAccuracy', REF_VALUE = 'Synergy of Cropland with Sample Accuracy'
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Five Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Five Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithFiveByAccuracy', event_pro ='proCalCroplandSynergyWithFiveByAccuracy', REF_VALUE = 'Synergy of Cropland with Sample Accuracy'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Six Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Six Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithSixByAccuracy', event_pro ='proCalCroplandSynergyWithSixByAccuracy', REF_VALUE = 'Synergy of Cropland with Sample Accuracy'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Synergy of Seven Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Synergy of Seven Cropland Products', $
    UVALUE = 'CalCroplandSynergyWithSevenByAccuracy', event_pro ='proCalCroplandSynergyWithSevenByAccuracy', REF_VALUE = 'Synergy of Cropland with Sample Accuracy'


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Maximum of Multiple Cropland Products" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Maximum of Multiple Cropland Products', /MENU, REF_VALUE = 'Cropland Mapping', POSITION = 'last' 
 
  ;;Create "Max of Three Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Max of Three Cropland Products', $
    UVALUE = 'CalCroplandMaximumValueWithThree', event_pro ='proCalCroplandMaximumValueWithThree', REF_VALUE = 'Maximum of Multiple Cropland Products'

  ;;Create "Max of Four Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Max of Four Cropland Products', $
    UVALUE = 'CalCroplandMaximumValueWithFour', event_pro ='proCalCroplandMaximumValueWithFour', REF_VALUE = 'Maximum of Multiple Cropland Products'
 
  ;;Create "Max of Five Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Max of Five Cropland Products', $
    UVALUE = 'CalCroplandMaximumValueWithFive', event_pro ='proCalCroplandMaximumValueWithFive', REF_VALUE = 'Maximum of Multiple Cropland Products'

  ;;Create "Max of Six Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Max of Six Cropland Products', $
    UVALUE = 'CalCroplandMaximumValueWithSix', event_pro ='proCalCroplandMaximumValueWithSix', REF_VALUE = 'Maximum of Multiple Cropland Products'

  ;;Create "Max of Seven Cropland Products" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Max of Seven Cropland Products', $
    UVALUE = 'CalCroplandMaximumValueWithSeven', event_pro ='proCalCroplandMaximumValueWithSeven', REF_VALUE = 'Maximum of Multiple Cropland Products'    


  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Cropland Data Correction" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Cropland Data Correction', /MENU, REF_VALUE = 'Cropland Mapping', POSITION = 'last', /SEPARATOR
  
  ;;Create "Greater Than Statistical Value" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Greater Than Statistical Value', $
    UVALUE = 'CalCroplandAdjustMorethanStat', event_pro ='proCalCroplandAdjustMorethanStat', REF_VALUE = 'Cropland Data Correction'
    
  ;;Create "Close to statistical value" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Close to statistical value', $
    UVALUE = 'CalCroplandAdjustClosetoStat', event_pro ='proCalCroplandAdjustClosetoStat', REF_VALUE = 'Cropland Data Correction'
    
  ;;Create "Accurately Close to Statistical Value" Third Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Accurately Close to Statistical Value', $
    UVALUE = 'CalCroplandAdjustEqualtoStat', event_pro ='proCalCroplandAdjustEqualtoStat', REF_VALUE = 'Cropland Data Correction'
 
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Data Resampling with Integer" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Data Resampling with Integer', $
    UVALUE = 'CroplandResampleInt', event_pro ='proCroplandResampleInt', REF_VALUE = 'Cropland Mapping'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Data Resampling with Non-integer" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Data Resampling with Non-integer', $
    UVALUE = 'CroplandResampleFloat', event_pro ='proCroplandResampleFloat', REF_VALUE = 'Cropland Mapping'

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Multi-level Region Correction Data Integration" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Multi-level Region Correction Data Integration', $
    UVALUE = 'MultiRegionAdjustMerge', event_pro ='proMultiRegionAdjustMerge', REF_VALUE = 'Cropland Mapping'    
   
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Subregion Blank Fill" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Subregion Blank Fill', $
    UVALUE = 'SubRegionBlankFill', event_pro ='proSubRegionBlankFill', REF_VALUE = 'Cropland Mapping'
    
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;Create "Sub-region Obfuscation Accuracy Calculation" Secondary Menu
  ENVI_DEFINE_MENU_BUTTON, buttonInfo,  VALUE = 'Sub-region Obfuscation Accuracy Calculation', $
    UVALUE = 'SubRegionConfusionMaxtrix', event_pro ='proSubRegionConfusionMaxtrix', REF_VALUE = 'Cropland Mapping'

END





















