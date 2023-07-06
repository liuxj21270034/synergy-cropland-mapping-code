;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land area calculation, according to the administrative division unit to statistics of the existing cultivated land achievement data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proAdminRegionCropArea, event

    base = widget_auto_base(title = 'Cultivated land area calculation')
    inputFileName1 = widget_outf(base, prompt = 'Classification of cultivated land',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Administrative division code',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Excel Doc', uvalue = 'inputFileName4', $
        default = '', /auto)

    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4

    ;;;;;Use administrative division statistical functions
    functionResult = FuncAdminRegionCropArea(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, r_FID = r_FID)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Calculation of cultivated land area data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
function FuncAdminRegionCropArea, inputFileName1, inputFileName2, inputFileName3, $
    inputFileName4, r_FID = r_FID

    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;Obtain farmland proportion or category data（0,1）
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;Administrative division code
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;Pixel Area Data
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1   ;;Cultivated land ratio or type
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2   ;;Administrative division code
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3   ;;Pixel Area Data
    
    ;;;;Take the minimum range of three data
    arrayCount = 3
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate over all pixels to get unique values
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;Get farmland classification data, ratio data or 0,1 value
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;Get administrative division code
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;Get pixel area
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)            
            
            ;;Get the current unique value
            tileData2 = tileData2[sort(tileData2)]
            curUniqData2 = tileData2[uniq(tileData2)]
            
            tileData3 = tileData3[sort(tileData3)]
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData2 = curUniqData2
               uniqData3 = curUniqData3   
                           
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endif else begin
               uniqData2 = [curUniqData2, lastUniqData2]
               uniqData3 = [curUniqData3, lastUniqData3]
               
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays
    uniqData2 = uniqData2[sort(uniqData2)]
    uniqData2 = uniqData2[uniq(uniqData2)]
    
    uniqData3 = uniqData3[sort(uniqData3)]
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    resultData = DBLARR(n_elements(uniqData2))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to calculate the cultivated area
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Arable land area calculation'], title = 'Arable land area calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;Get farmland classification data, ratio data or 0,1 value
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
;            ;;Remove Nan Value
;            index = where(finite(tileData1, /NAN), count)
;            if count gt 0 then begin
;                tileData1[index] = 0.0
;            endif
            
            ;;Get administrative division code
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;Get Pixel Area Data
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index3 = where(tileData3 lt 0.0, count3)
            if count3 gt 0 then begin
                tileData3[index3] = 0.0
            endif
            
            for m = 0LL, n_elements(uniqData2) - 1 do begin
                index2 = where(tileData2 eq uniqData2[m], count2)
                if count2 gt 0 then begin
                    resultData[m] = resultData[m] + total(tileData1[index2] * tileData3[index2])
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Output results
    fieldName = ['CropArea']
    ExportDataToExcel, inputFileName4, resultData, fieldName, uniqData2, $
        n_elements(fieldName), n_elements(uniqData2)

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Calculate synergy data, calculate synergy data according to rules
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCreateSynergyMap, event

    base = widget_auto_base(title = 'Synergy Data Computing')
    inputFileName1 = widget_outf(base, prompt = 'Class Data Product_1',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class Data Product_2',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class Data Product_3', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class Data Product_4', uvalue = 'inputFileName4', $
        default = '', /auto)
    outputFileName = widget_outf(base, prompt = 'Synergy Result', uvalue = 'outputFileName', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    outputFileName = baseclass.outputFileName
    
    ;;;;;Call the data synergy function
    functionResult = FuncCreateSynergyMap(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, outputFileName, r_fid = r_fid)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Calculate Synergy Data
function FuncCreateSynergyMap, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, outputFileName, r_fid = r_fid

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName

    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4    
    
    ;;Take the minimum range of four classified product data
    arrayCount = 4
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Create a new file for output
    OPENW, unit, outputFileName, /get_lun
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Synergy Data Computing'], title = 'Synergy Data Computing', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)            
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine            
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            ;;Make sum of four sets of classified data products
            resultData = tileData1 + tileData2 + tileData3 + tileData4
            

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit, resultData
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy data', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    r_FID = resultFID
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
    
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Synergy data modificaiton, according to the Synergy data results and related statistical data results to re-correct the fused dat
pro proModifyWithSynergyMap, event

    base = widget_auto_base(title = 'Synergy data modification')
    inputFileName1 = widget_outf(base, prompt = 'Synergy data',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Administrative division code',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Statistics of administrative divisions',uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Pixel Area Data',uvalue = 'inputFileName4', $
        default = '', /auto)
    outputFileName = widget_outf(base, prompt = 'Modified Data', uvalue = 'outputFileName', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3   
    inputFileName4 = baseclass.inputFileName4 
    outputFileName = baseclass.outputFileName
    
    ;;;;;Call the data synergy function
    functionResult = FuncModifyWithSynergyMap(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, outputFileName, r_fid = r_fid)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Modify the data according to Synergy data and statistical data
function FuncModifyWithSynergyMap, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, outputFileName, r_fid = r_fid

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName

    ;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
        ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4
    
    ;;Take the minimum range of four classified product data
    arrayCount = 4
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)            
            
            ;Get the current unique value
            tileData1 = tileData1[sort(tileData1)]
            curUniqData1 = tileData1[uniq(tileData1)]
            
            tileData2 = tileData2[sort(tileData2)]
            curUniqData2 = tileData2[uniq(tileData2)]
            
            tileData3 = tileData3[sort(tileData3)]
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1
               uniqData2 = curUniqData2
               uniqData3 = curUniqData3
                           
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]
               uniqData2 = [curUniqData2, lastUniqData2]
               uniqData3 = [curUniqData3, lastUniqData3]
               
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Synergy data
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    uniqData2 = uniqData2[sort(uniqData2)]    ;;Administrative division code
    uniqData2 = uniqData2[uniq(uniqData2)]
    
    uniqData3 = uniqData3[sort(uniqData3)]    ;;Statistics of administrative divisions
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    synergyData = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    statData = DBLARR(n_elements(uniqData2))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Administrative Division Statistics'], title = 'Administrative Division Statistics', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Synergy data
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif
            
            ;;Calculate the area of each Synergy data value in each administrative division unit
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    tempData1 = tileData1[index1]
                    tempData4 = tileData4[index1]
                    for n = 0LL, n_elements(uniqData1) - 1 do begin
                        index2 = where(tempData1 eq uniqData1[n], count2)
                        if count2 gt 0 then begin
                            synergyData[n, m] = synergyData[n, m] + total(tempData4[index2])
                        endif
                    endfor
                endif
            endfor
            
            ;;Determine the statistical value in each administrative division unit
            for m = 0LL, n_elements(uniqData2) - 1 do begin
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    statData[m] = tileData3[index1[0]]
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Modify the original data according to Synergy data area and statistical data area
    iterateSumArea = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    
    ;;Accumulate the area of every possible situation in Calculate Synergy Data
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        iterateSumArea[i, *] = iterateSumArea[i, *] + synergyData[i, *]
        for j = i + 1, n_elements(uniqData1) - 1 do begin
            iterateSumArea[i, *] = iterateSumArea[i, *] + synergyData[j, *]
        endfor
    endfor
    
    ;;Relative error of Calculate Synergy Data area and 
    areaDifference = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        areaDifference[i, *] = abs(iterateSumArea[i, *] - statData[*]) / statData[*]
    endfor
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Determine the effective area of Synergy data'], title = 'Determine the effective area of Synergy data', base = base
    ENVI_REPORT_INC, base, n_elements(uniqData2)
    
    ;;Determine the serial number corresponding to the smallest relative error
    flagData = BYTARR(n_elements(uniqData1), n_elements(uniqData2))
    for i = 0LL, n_elements(uniqData2) - 1 do begin
        flag = 0B
        tempData = areaDifference[*, i]
        minValue = min(tempData, max = maxValue)
        for j = 0LL, n_elements(uniqData1) - 1 do begin
            flagData[j, i] = flag
            if areaDifference[j, i] eq minValue then begin
                flag = 1B
                flagData[j, i] = flag
            endif
        endfor
        
        ;Progress bar, showing calculation progress
        ENVI_REPORT_STAT, base, i, n_elements(uniqData2)
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Finally, the statistical data matching results are used to modify Synergy data
    ;;Create a new file for output
    OPENW, unit, outputFileName, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels and perform Synergy data modification
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Synergy data modification'], title = 'Synergy data modification', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Synergy data
            resultData = BYTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            resultData[*, *] = 0B
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code
            
            ;;Modify the current data block
            for m = 0LL, n_elements(uniqData1) - 1 do begin
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    for n = 0LL, n_elements(index1) - 1 do begin
                        tempValue = tileData2[index1[n]]
                        for mm = 0LL, n_elements(uniqData2) - 1 do begin
                            if tempValue eq uniqData2[mm] then begin
                                resultData[index1[n]] = flagData[m, mm]
                            endif
                        endfor
                    endfor
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit, resultData
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Modification of synergy data', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    r_FID = resultFID

    return, 1

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Calculation of cultivated land ratio data
pro proCalProportionData, event

    base = widget_auto_base(title = 'Calculation of cultivated land ratio data')
    inputFileName1 = widget_outf(base, prompt = 'Low resolution image',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'High resolution image',uvalue = 'inputFileName2', $
        default = '', /auto)
    outputFileName = widget_outf(base, prompt = 'Result of ratio data', uvalue = 'outputFileName', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    outputFileName = baseclass.outputFileName
    
    ;;;;;Call a function that calculates ratio data
    functionResult = FuncCalProportionData(inputFileName1, inputFileName2, $
        outputFileName, r_fid = r_fid)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)    

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;A function that calculates ratio data
function FuncCalProportionData, inputFileName1, inputFileName2, $
        outputFileName, r_fid = r_fid

    return, 1

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Arable land area calculation of 6 sets of products, mapped to the proportion of cultivated land, and then calculate the cultiva
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandArea, event

    base = widget_auto_base(title = 'Arable land area calculation')
    inputFileName1 = widget_outf(base, prompt = 'Arable land Synergy data', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Average ratio of cultivated land', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Area file in Excel', uvalue = 'inputFileName6', $
        default = '', /auto)    

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3   
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    
    ;;;;;Call the data synergy function
    functionResult = FuncCalCroplandArea(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, inputFileName6)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call function of calculation of cultivated land area data
function FuncCalCroplandArea, inputFileName1, inputFileName2, inputFileName3, $
        inputFileName4, inputFileName5, inputFileName6

    ;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
        ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4
    
    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5    
    
    ;;Take the minimum range of four classified product data
    arrayCount = 5
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)            
            
            ;Get the current unique value
            tileData1 = tileData1[sort(tileData1)]
            curUniqData1 = tileData1[uniq(tileData1)]
            
            tileData2 = tileData2[sort(tileData2)]
            curUniqData2 = tileData2[uniq(tileData2)]
            
            tileData3 = tileData3[sort(tileData3)]
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1
               uniqData2 = curUniqData2
               uniqData3 = curUniqData3
                           
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]
               uniqData2 = [curUniqData2, lastUniqData2]
               uniqData3 = [curUniqData3, lastUniqData3]
               
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Synergy data
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    uniqData2 = uniqData2[sort(uniqData2)]    ;;Administrative division code
    uniqData2 = uniqData2[uniq(uniqData2)]
    
    uniqData3 = uniqData3[sort(uniqData3)]    ;;Statistics of administrative divisions
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    synergyData = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Administrative Division Statistics'], title = 'Administrative Division Statistics', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Synergy data
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio of cultivated land                 
            
            ;;Calculate the area of each Synergy data value in each administrative division unit
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    tempData1 = tileData1[index1]
                    tempData4 = tileData4[index1]
                    tempData5 = tileData5[index1]
                    for n = 0LL, n_elements(uniqData1) - 1 do begin
                        index2 = where(tempData1 eq uniqData1[n], count2)
                        if count2 gt 0 then begin
                            tempData4_1 = tempData4[index2]
                            tempData5_1 = tempData5[index2]
                            tempData6 = tempData4_1 * tempData5_1
                            synergyData[n, m] = synergyData[n, m] + total(tempData6)
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Output results
    resultDataSize = size(synergyData)
    
    tableIndex = 0
    ExportDataToExcel, inputFileName6, synergyData, uniqData1, uniqData2, $
        resultDataSize[1], resultDataSize[2]

    return, 1


end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Preliminary synergy of cultivated land (precision)-six sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithSix, event

    base = widget_auto_base(title = 'Preliminary synergy of cultivated land (precision)-six sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputPara1 = widget_param(base, prompt = 'Cultivated land ratio of class product 01', uvalue = 'inputPara1', $
        default = 0.9, /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputPara2 = widget_param(base, prompt = 'Cultivated land ratio of class product 02', uvalue = 'inputPara2', $
        default = 0.85, /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputPara3 = widget_param(base, prompt = 'Cultivated land ratio of class product 03', uvalue = 'inputPara3', $
        default = 0.8, /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputPara4 = widget_param(base, prompt = 'Cultivated land ratio of class product 04', uvalue = 'inputPara4', $
        default = 0.75, /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputPara5 = widget_param(base, prompt = 'Cultivated land ratio of class product 05', uvalue = 'inputPara5', $
        default = 0.7, /auto)
    inputFileName6 = widget_outf(base, prompt = 'Class product 06', uvalue = 'inputFileName6', $
        default = '', /auto)
    inputPara6 = widget_param(base, prompt = 'Cultivated land ratio of class product 06', uvalue = 'inputPara6', $
        default = 0.65, /auto)
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)        

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputPara1 = baseclass.inputPara1
    inputFileName2 = baseclass.inputFileName2
    inputPara2 = baseclass.inputPara2
    inputFileName3 = baseclass.inputFileName3
    inputPara3 = baseclass.inputPara3
    inputFileName4 = baseclass.inputFileName4
    inputPara4 = baseclass.inputPara4
    inputFileName5 = baseclass.inputFileName5
    inputPara5 = baseclass.inputPara5
    inputFileName6 = baseclass.inputFileName6
    inputPara6 = baseclass.inputPara6
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call function of preliminary synergy of cultivated land (precision)-six sets of products
    functionResult = funcCalCroplandSynergyWithSix(inputFileName1, inputPara1, $
        inputFileName2, inputPara2, $
        inputFileName3, inputPara3, $
        inputFileName4, inputPara4, $
        inputFileName5, inputPara5, $
        inputFileName6, inputPara6, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call function of preliminary synergy of cultivated land (precision)-six sets of products
function funcCalCroplandSynergyWithSix, inputFileName1, inputPara1, $
        inputFileName2, inputPara2, $
        inputFileName3, inputPara3, $
        inputFileName4, inputPara4, $
        inputFileName5, inputPara5, $
        inputFileName6, inputPara6, $
        outputFileName1, outputFileName2
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2       

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read six sets of farmland product data and ratio data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    classRatio1 = inputPara1
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    classRatio2 = inputPara2
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    classRatio3 = inputPara3
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    classRatio4 = inputPara4

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    classRatio5 = inputPara5
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    classRatio6 = inputPara6    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 6
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1, 1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 1, 0], $
                        [1, 1, 1, 1, 0, 1], $
                        [1, 1, 1, 0, 1, 1], $
                        [1, 1, 0, 1, 1, 1], $
                        [1, 0, 1, 1, 1, 1], $
                        [0, 1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 0, 0], $
                        [1, 1, 1, 0, 1, 0], $
                        [1, 1, 0, 1, 1, 0], $
                        [1, 0, 1, 1, 1, 0], $
                        [0, 1, 1, 1, 1, 0], $
                        [1, 1, 1, 0, 0, 1], $
                        [1, 1, 0, 1, 0, 1], $
                        [1, 0, 1, 1, 0, 1], $
                        [0, 1, 1, 1, 0, 1], $
                        [1, 1, 0, 0, 1, 1], $
                        [1, 0, 1, 0, 1, 1], $
                        [0, 1, 1, 0, 1, 1], $
                        [1, 0, 0, 1, 1, 1], $
                        [0, 1, 0, 1, 1, 1], $
                        [0, 0, 1, 1, 1, 1], $
                        [1, 1, 1, 0, 0, 0], $
                        [1, 1, 0, 1, 0, 0], $
                        [1, 0, 1, 1, 0, 0], $
                        [0, 1, 1, 1, 0, 0], $
                        [1, 1, 0, 0, 1, 0], $
                        [1, 0, 1, 0, 1, 0], $
                        [0, 1, 1, 0, 1, 0], $
                        [1, 0, 0, 1, 1, 0], $
                        [0, 1, 0, 1, 1, 0], $
                        [0, 0, 1, 1, 1, 0], $
                        [1, 1, 0, 0, 0, 1], $
                        [1, 0, 1, 0, 0, 1], $
                        [0, 1, 1, 0, 0, 1], $
                        [1, 0, 0, 1, 0, 1], $
                        [0, 1, 0, 1, 0, 1], $
                        [0, 0, 1, 1, 0, 1], $
                        [1, 0, 0, 0, 1, 1], $
                        [0, 1, 0, 0, 1, 1], $
                        [0, 0, 1, 0, 1, 1], $
                        [0, 0, 0, 1, 1, 1], $
                        [1, 1, 0, 0, 0, 0], $
                        [1, 0, 1, 0, 0, 0], $
                        [1, 0, 0, 1, 0, 0], $
                        [1, 0, 0, 0, 1, 0], $
                        [1, 0, 0, 0, 0, 1], $
                        [0, 1, 1, 0, 0, 0], $
                        [0, 1, 0, 1, 0, 0], $
                        [0, 1, 0, 0, 1, 0], $
                        [0, 1, 0, 0, 0, 1], $
                        [0, 0, 1, 1, 0, 0], $
                        [0, 0, 1, 0, 1, 0], $
                        [0, 0, 1, 0, 0, 1], $
                        [0, 0, 0, 1, 1, 0], $
                        [0, 0, 0, 1, 0, 1], $
                        [0, 0, 0, 0, 1, 1], $
                        [1, 0, 0, 0, 0, 0], $
                        [0, 1, 0, 0, 0, 0], $
                        [0, 0, 1, 0, 0, 0], $
                        [0, 0, 0, 1, 0, 0], $
                        [0, 0, 0, 0, 1, 0], $
                        [0, 0, 0, 0, 0, 1], $
                        [0, 0, 0, 0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    OPENW, unit2, outputFileName2, /get_lun    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land synergy calculation'], title = 'Cultivated land synergy calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the current block data of six sets of cultivated land products
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value
            resultData1 = tileData6
            tempData1 = tileData6
            
            for m = 0LL, synergyRankLine - 1 do begin
                tempData1 = abs(tileData1 - synergyRankArray[0, m]) + abs(tileData2 - synergyRankArray[1, m]) + $
                            abs(tileData3 - synergyRankArray[2, m]) + abs(tileData4 - synergyRankArray[3, m]) + $
                            abs(tileData5 - synergyRankArray[4, m]) + abs(tileData6 - synergyRankArray[5, m])
                index1 = where(tempData1 eq 0, count1)
                if count1 gt 0 then begin
                    resultData1[index1] = m + 1
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = (tileData1 * classRatio1) + (tileData2 * classRatio2) + $
                        (tileData3 * classRatio3) + (tileData4 * classRatio4) + $
                        (tileData5 * classRatio5) + (tileData6 * classRatio6)

            resultData2 = tempData2 / 6.0
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy data', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Average ratio', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ENVI_OPEN_FILE, outputFileName2, r_fid = r_fid2
    if r_fid2 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land preliminary synergy (statistical value accuracy)-six sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithSixByRegion, event

    base = widget_auto_base(title = 'Cultivated land preliminary synergy (statistical value accuracy)-six sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Class product 06', uvalue = 'inputFileName6', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName8', $
        default = '', /auto)
    inputFileName9 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName9', $
        default = '', /auto)        
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)

    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call function of cultivated land preliminary synergy (statistical value accuracy)-six sets of products
    functionResult = funcCalCroplandSynergyWithSixByRegion(inputFileName1, inputFileName2, inputFileName3, $
        inputFileName4, inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land preliminary synergy (statistical value accuracy)-six sets of products
function funcCalCroplandSynergyWithSixByRegion, inputFileName1, inputFileName2, inputFileName3, $
        inputFileName4, inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    proDeleteFile, file_name = outputFileName2       

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read six sets of farmland product data and ratio data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;First set of product
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;Second set of product
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;Third set of product
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;Fourth set of product
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;Fifth set of product
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
        
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6    ;;Sixth set of product
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif


    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;Administrative division code
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;Statistics of administrative divisions
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;Pixel Area Data
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1    ;;First set of product
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2    ;;Second set of product
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3    ;;Third set of product
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4    ;;Fourth set of product

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5    ;;Fifth set of product
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6    ;;Sixth set of product
    
       
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7    ;;Administrative division code
    
    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8    ;;Statistics of administrative divisions
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9    ;;Pixel Area Data
    
    ;;Product count
    productCount = 6
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 9
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns7
    nsArray[7] = ns8
    nsArray[8] = ns9
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl7
    nlArray[7] = nl8
    nlArray[8] = nl9
       
    nlStd = min(nlArray, max = maxValue)

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to get the unique value of Administrative division code and statistical data
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine

            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)            
            
            ;;Get unique value of administrative division code
            tileData7 = tileData7[sort(tileData7)]
            curUniqData7 = tileData7[uniq(tileData7)]
            
            ;;Get unique value of Statistics of administrative divisions
            tileData8 = tileData8[sort(tileData8)]
            curUniqData8 = tileData8[uniq(tileData8)]            
            
            if i eq 0 and j eq 0 then begin
               uniqData7 = curUniqData7
               lastUniqData7 = uniqData7
               
               uniqData8 = curUniqData8
               lastUniqData8 = uniqData8
            endif else begin
               uniqData7 = [curUniqData7, lastUniqData7]               
               lastUniqData7 = uniqData7
               
               uniqData8 = [curUniqData8, lastUniqData8]               
               lastUniqData8 = uniqData8
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get unique value of administrative division code
    uniqData7 = uniqData7[sort(uniqData7)]
    uniqData7 = uniqData7[uniq(uniqData7)]
    
    ;;Get unique value of Administrative Division Statistics
    uniqData8 = uniqData8[sort(uniqData8)]
    uniqData8 = uniqData8[uniq(uniqData8)]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to calculate the area of each set of cultivated land products
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;Cultivated land area of each set of cultivated land products
    regionCropArea1 = DBLARR(n_elements(uniqData7))
    regionCropArea2 = DBLARR(n_elements(uniqData7))
    regionCropArea3 = DBLARR(n_elements(uniqData7))
    regionCropArea4 = DBLARR(n_elements(uniqData7))
    regionCropArea5 = DBLARR(n_elements(uniqData7))
    regionCropArea6 = DBLARR(n_elements(uniqData7))
    
    ;;The statistical value in each area is used to determine the statistical value of the area, excluding the inconsistency between 
    regionStatOptions = DBLARR(n_elements(uniqData7), n_elements(uniqData8))
    
    ;;Progress Bar
    ENVI_REPORT_INIT, ['分区Arable land area calculation'], title = '分区Arable land area calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the first set of products
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the second set of products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the third set of products
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the fourth set of products
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the fifth set of products
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the sixth set of products
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Pixel Area Data
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index9 = where(tileData9 lt 0.0, count9)
            if count9 gt 0 then begin
                tileData9[index9] = 0.0
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;Calculate the area of arable land for each set of products, the unique value of Administrative division code is uniqData7
            for m = 0LL, n_elements(uniqData7) - 1 do begin
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    regionCropArea1[m] = regionCropArea1[m] + total(tileData1[index7] * tileData9[index7])
                    regionCropArea2[m] = regionCropArea2[m] + total(tileData2[index7] * tileData9[index7])
                    regionCropArea3[m] = regionCropArea3[m] + total(tileData3[index7] * tileData9[index7])
                    regionCropArea4[m] = regionCropArea4[m] + total(tileData4[index7] * tileData9[index7])
                    regionCropArea5[m] = regionCropArea5[m] + total(tileData5[index7] * tileData9[index7])
                    regionCropArea6[m] = regionCropArea6[m] + total(tileData6[index7] * tileData9[index7])
                endif
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;Calculate the statistical value in each administrative division
            for m = 0LL, n_elements(uniqData7) - 1 do begin         ;;Iterate through each Administrative division code
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    tempData1 = tileData7[index7]   ;;Current administrative division code data
                    tempData2 = tileData8[index7]   ;;Statistics of the current Administrative division code
                    
                    for n = 0LL, n_elements(uniqData8) - 1 do begin     ;;Iterate through each Administrative Division Statistics value
                        index8 = where(tempData2 eq uniqData8[n], count8)
                        if count8 gt 0 then begin
                            regionStatOptions[m, n] = regionStatOptions[m, n] + count8
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Compare the error between the arable land area of each set of products and the value of Administrative Division Statistics
    ;;Determine the statistics in each area
    regionStatData = DBLARR(n_elements(uniqData7))
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        tempData = regionStatOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            regionStatData[m] = uniqData8[index[0]]
        endif
    endfor

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    ;;Compare the statistic area of each set of products with the statistical value of each area, determine the fusion order accordin    
    regionStatDifProduct = DBLARR(n_elements(uniqData7), productCount)
    regionProductSort = LONARR(n_elements(uniqData7), productCount)
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        regionStatDifProduct[m, 0] = abs(regionStatData[m] - regionCropArea1[m])
        regionStatDifProduct[m, 1] = abs(regionStatData[m] - regionCropArea2[m])
        regionStatDifProduct[m, 2] = abs(regionStatData[m] - regionCropArea3[m])
        regionStatDifProduct[m, 3] = abs(regionStatData[m] - regionCropArea4[m])
        regionStatDifProduct[m, 4] = abs(regionStatData[m] - regionCropArea5[m])
        regionStatDifProduct[m, 5] = abs(regionStatData[m] - regionCropArea6[m])
        
        ;;Start sorting
        tempData = regionStatDifProduct[m, *]
        sortIndex = sort(tempData)
        
        for n = 0LL, n_elements(sortIndex) - 1 do begin
            if sortIndex[n] eq 0 then begin
                regionProductSort[m, n] = fid1
            endif
            
            if sortIndex[n] eq 1 then begin
                regionProductSort[m, n] = fid2
            endif
            
            if sortIndex[n] eq 2 then begin
                regionProductSort[m, n] = fid3
            endif

            if sortIndex[n] eq 3 then begin
                regionProductSort[m, n] = fid4
            endif
            
            if sortIndex[n] eq 4 then begin
                regionProductSort[m, n] = fid5
            endif
            
            if sortIndex[n] eq 5 then begin
                regionProductSort[m, n] = fid6
            endif
        endfor  
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix(Six sets of products)
    synergyRankArray = [[1,1,1,1,1,1], $
                        [1,1,1,1,1,0], $
                        [1,1,1,1,0,1], $
                        [1,1,1,0,1,1], $
                        [1,1,0,1,1,1], $
                        [1,0,1,1,1,1], $
                        [0,1,1,1,1,1], $
                        [1,1,1,1,0,0], $
                        [1,1,1,0,1,0], $
                        [1,1,0,1,1,0], $
                        [1,0,1,1,1,0], $
                        [0,1,1,1,1,0], $
                        [1,1,1,0,0,1], $
                        [1,1,0,1,0,1], $
                        [1,0,1,1,0,1], $
                        [0,1,1,1,0,1], $
                        [1,1,0,0,1,1], $
                        [1,0,1,0,1,1], $
                        [0,1,1,0,1,1], $
                        [1,0,0,1,1,1], $
                        [0,1,0,1,1,1], $
                        [0,0,1,1,1,1], $
                        [1,1,1,0,0,0], $
                        [1,1,0,1,0,0], $
                        [1,1,0,0,1,0], $
                        [1,1,0,0,0,1], $
                        [1,0,1,1,0,0], $
                        [1,0,1,0,1,0], $
                        [1,0,1,0,0,1], $
                        [1,0,0,1,1,0], $
                        [1,0,0,1,0,1], $
                        [1,0,0,0,1,1], $
                        [0,1,1,1,0,0], $
                        [0,1,1,0,1,0], $
                        [0,1,1,0,0,1], $
                        [0,1,0,1,1,0], $
                        [0,1,0,1,0,1], $
                        [0,1,0,0,1,1], $
                        [0,0,1,1,1,0], $
                        [0,0,1,1,0,1], $
                        [0,0,1,0,1,1], $
                        [0,0,0,1,1,1], $
                        [1,1,0,0,0,0], $
                        [1,0,1,0,0,0], $
                        [1,0,0,1,0,0], $
                        [1,0,0,0,1,0], $
                        [1,0,0,0,0,1], $
                        [0,1,1,0,0,0], $
                        [0,1,0,1,0,0], $
                        [0,1,0,0,1,0], $
                        [0,1,0,0,0,1], $
                        [0,0,1,1,0,0], $
                        [0,0,1,0,1,0], $
                        [0,0,1,0,0,1], $
                        [0,0,0,1,1,0], $
                        [0,0,0,1,0,1], $
                        [0,0,0,0,1,1], $
                        [1,0,0,0,0,0], $
                        [0,1,0,0,0,0], $
                        [0,0,1,0,0,0], $
                        [0,0,0,1,0,0], $
                        [0,0,0,0,1,0], $
                        [0,0,0,0,0,1], $
                        [0,0,0,0,0,0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    OPENW, unit2, outputFileName2, /get_lun    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, Calculate synergy value
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land zoning synergy'], title = 'Cultivated land zoning synergy', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Output value
            resultData1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            synergyResult = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            
            ;;Temporarily convert the cultivated land ratio data to 0 and 1 values
            tileDataCopy1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            tileDataCopy2 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy3 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy4 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy5 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy6 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate through each Administrative division code
            for n = 0LL, n_elements(uniqData7) - 1 do begin
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Six sets of product errors based on current administrative divisions
                ;;Get the product with the smallest error
                dims1[1] = tileStartSample
                dims1[2] = tileEndSample
                dims1[3] = tileStartLine
                dims1[4] = tileEndLine
    
                tileData1 = ENVI_GET_DATA(fid = regionProductSort[n, 0], dims = dims1, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy1[*, *] = 0L
                index1 = where(tileData1 gt 0.0, count1)
                if count1 gt 0 then begin
                    tileDataCopy1[index1] = 1L
                endif 
                
                ;;Get the product with the second smallest error                
                dims2[1] = tileStartSample
                dims2[2] = tileEndSample
                dims2[3] = tileStartLine
                dims2[4] = tileEndLine
                
                tileData2 = ENVI_GET_DATA(fid = regionProductSort[n, 1], dims = dims2, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy2[*, *] = 0L
                index2 = where(tileData2 gt 0.0, count2)
                if count2 gt 0 then begin
                    tileDataCopy2[index2] = 1L
                endif                 
                
                ;;Get the product with the third smallest error                 
                dims3[1] = tileStartSample
                dims3[2] = tileEndSample
                dims3[3] = tileStartLine
                dims3[4] = tileEndLine
                
                tileData3 = ENVI_GET_DATA(fid = regionProductSort[n, 2], dims = dims3, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy3[*, *] = 0L
                index3 = where(tileData3 gt 0.0, count3)
                if count3 gt 0 then begin
                    tileDataCopy3[index3] = 1L
                endif                                 
                
                ;;Get the product with the fourth smallest error                 
                dims4[1] = tileStartSample
                dims4[2] = tileEndSample
                dims4[3] = tileStartLine
                dims4[4] = tileEndLine
                
                tileData4 = ENVI_GET_DATA(fid = regionProductSort[n, 3], dims = dims4, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy4[*, *] = 0L
                index4 = where(tileData4 gt 0.0, count4)
                if count4 gt 0 then begin
                    tileDataCopy4[index4] = 1L
                endif                                 
                
                ;;Get the product with the fifth smallest error                 
                dims5[1] = tileStartSample
                dims5[2] = tileEndSample
                dims5[3] = tileStartLine
                dims5[4] = tileEndLine
                
                tileData5 = ENVI_GET_DATA(fid = regionProductSort[n, 4], dims = dims5, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy5[*, *] = 0L
                index5 = where(tileData5 gt 0.0, count5)
                if count5 gt 0 then begin
                    tileDataCopy5[index5] = 1L
                endif
                
                ;;Get the product with the sixth smallest error                 
                dims6[1] = tileStartSample
                dims6[2] = tileEndSample
                dims6[3] = tileStartLine
                dims6[4] = tileEndLine
                
                tileData6 = ENVI_GET_DATA(fid = regionProductSort[n, 5], dims = dims6, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy6[*, *] = 0L
                index6 = where(tileData6 gt 0.0, count6)
                if count6 gt 0 then begin
                    tileDataCopy6[index6] = 1L
                endif                

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value
                tempData1 = tileDataCopy1
                
                for m = 0LL, synergyRankLine - 1 do begin
                    tempData1 = abs(tileDataCopy1 - synergyRankArray[0, m]) + abs(tileDataCopy2 - synergyRankArray[1, m]) + $
                                abs(tileDataCopy3 - synergyRankArray[2, m]) + abs(tileDataCopy4 - synergyRankArray[3, m]) + $
                                abs(tileDataCopy5 - synergyRankArray[4, m]) + abs(tileDataCopy6 - synergyRankArray[5, m])
                    index1 = where(tempData1 eq 0, count1)
                    if count1 gt 0 then begin
                        resultData1[index1] = LONG(m + 1)
                    endif
                endfor

                index2 = where(tileData7 eq uniqData7[n], count2)
                if count2 gt 0 then begin
                    synergyResult[index2] = resultData1[index2]
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, synergyResult
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1
            tempData2[*, *] = tempData2[*, *] + tileData2[*, *] + tileData3[*, *] + $
                          tileData4[*, *] + tileData5[*, *] + tileData6[*, *]
                          
            tempData3 = tileDataCopy1
            tempData3[*, *] = tempData3[*, *] + tileDataCopy2[*, *] + tileDataCopy3[*, *] + $
                          tileDataCopy4[*, *] + tileDataCopy5[*, *] + tileDataCopy6[*, *]
            
            resultData2 = tileData1
            resultData2[*, *] = tempData2[*, *] / tempData3[*, *]     
                                 
            index3 = where(tempData3 eq 0, count3)
            if count3 gt 0 then begin
                resultData2[index3] = 0.0
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 3, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy data of each area', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Average ratio', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ENVI_OPEN_FILE, outputFileName2, r_fid = r_fid2
    if r_fid2 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land preliminary synergy (statistical value accuracy)-seven sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithSevenByRegion, event

    base = widget_auto_base(title = 'Cultivated land preliminary synergy (statistical value accuracy)-seven sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Class product 06', uvalue = 'inputFileName6', $
        default = '', /auto)
    inputFileName10 = widget_outf(base, prompt = 'Class product 07', uvalue = 'inputFileName10', $
        default = '', /auto)        

    inputFileName7 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName8', $
        default = '', /auto)
    inputFileName9 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName9', $
        default = '', /auto)        
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)

    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    inputFileName10 = baseclass.inputFileName10
    
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call the function of cultivated land preliminary synergy (statistical value accuracy)-seven sets of products
    functionResult = funcCalCroplandSynergyWithSevenByRegion(inputFileName1, inputFileName2, inputFileName3, $
        inputFileName4, inputFileName5, inputFileName6, inputFileName10, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of cultivated land preliminary synergy (statistical value accuracy)-seven sets of products
function funcCalCroplandSynergyWithSevenByRegion, inputFileName1, inputFileName2, inputFileName3, $
        inputFileName4, inputFileName5, inputFileName6, inputFileName10, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    proDeleteFile, file_name = outputFileName2       

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read seven sets of farmland product data and ratio data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;First set of product
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;Second set of product
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;Third set of product
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;Fourth set of product
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;Fifth set of product
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
        
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6    ;;Sixth set of product
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName10, r_fid = fid10    ;;Seventh set of product
    if fid10 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif


    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;Administrative division code
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;Statistics of administrative divisions
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;Pixel Area Data
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1    ;;First set of product
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2    ;;Second set of product
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3    ;;Third set of product
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4    ;;Fourth set of product

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5    ;;Fifth set of product
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6    ;;Sixth set of product
    
    ENVI_FILE_QUERY, fid10, dims = dims10, nb = nb10, ns = ns10, nl = nl10, data_type = data_type10    ;;Seventh set of product    
    
       
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7    ;;Administrative division code
    
    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8    ;;Statistics of administrative divisions
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9    ;;Pixel Area Data
    
    ;;Product count
    productCount = 7
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 10
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns10
    nsArray[7] = ns7
    nsArray[8] = ns8
    nsArray[9] = ns9
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl10
    nlArray[7] = nl7
    nlArray[8] = nl8
    nlArray[9] = nl9
       
    nlStd = min(nlArray, max = maxValue)

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to get the unique value of Administrative division code and statistical data
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine

            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)            
            
            ;;Get unique value of administrative division code
            tileData7 = tileData7[sort(tileData7)]
            curUniqData7 = tileData7[uniq(tileData7)]
            
            ;;Get unique value of Statistics of administrative divisions
            tileData8 = tileData8[sort(tileData8)]
            curUniqData8 = tileData8[uniq(tileData8)]            
            
            if i eq 0 and j eq 0 then begin
               uniqData7 = curUniqData7
               lastUniqData7 = uniqData7
               
               uniqData8 = curUniqData8
               lastUniqData8 = uniqData8
            endif else begin
               uniqData7 = [curUniqData7, lastUniqData7]               
               lastUniqData7 = uniqData7
               
               uniqData8 = [curUniqData8, lastUniqData8]               
               lastUniqData8 = uniqData8
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get unique value of administrative division code
    uniqData7 = uniqData7[sort(uniqData7)]
    uniqData7 = uniqData7[uniq(uniqData7)]
    
    ;;Get unique value of Administrative Division Statistics
    uniqData8 = uniqData8[sort(uniqData8)]
    uniqData8 = uniqData8[uniq(uniqData8)]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to calculate the area of seven sets of cultivated land products
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;Area of cultivated land divided by seven sets of cultivated land products
    regionCropArea1 = DBLARR(n_elements(uniqData7))
    regionCropArea2 = DBLARR(n_elements(uniqData7))
    regionCropArea3 = DBLARR(n_elements(uniqData7))
    regionCropArea4 = DBLARR(n_elements(uniqData7))
    regionCropArea5 = DBLARR(n_elements(uniqData7))
    regionCropArea6 = DBLARR(n_elements(uniqData7))
    regionCropArea10 = DBLARR(n_elements(uniqData7))
    
    ;;The statistical value in each area is used to determine the statistical value of the area,Excluded because of an inconsistency between the Administrative division code and Statistics of administrative divisions
    regionStatOptions = DBLARR(n_elements(uniqData7), n_elements(uniqData8))
    
    ;;Progress Bar
    ENVI_REPORT_INIT, ['Arable land area calculation of each region'], title = 'Arable land area calculation of each region', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the first set of products
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the second set of products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the third set of products
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the fourth set of products
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the fifth set of products
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the sixth set of products
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the seventh set of products
            dims10[1] = tileStartSample
            dims10[2] = tileEndSample
            dims10[3] = tileStartLine
            dims10[4] = tileEndLine
            
            tileData10 = ENVI_GET_DATA(fid = fid10, dims = dims10, pos = 0) 
           
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Pixel Area Data
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index9 = where(tileData9 lt 0.0, count9)
            if count9 gt 0 then begin
                tileData9[index9] = 0.0
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;Calculate the area of arable land for each set of products, the unique value of Administrative division code is uniqData7
            for m = 0LL, n_elements(uniqData7) - 1 do begin
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    regionCropArea1[m] = regionCropArea1[m] + total(tileData1[index7] * tileData9[index7])
                    regionCropArea2[m] = regionCropArea2[m] + total(tileData2[index7] * tileData9[index7])
                    regionCropArea3[m] = regionCropArea3[m] + total(tileData3[index7] * tileData9[index7])
                    regionCropArea4[m] = regionCropArea4[m] + total(tileData4[index7] * tileData9[index7])
                    regionCropArea5[m] = regionCropArea5[m] + total(tileData5[index7] * tileData9[index7])
                    regionCropArea6[m] = regionCropArea6[m] + total(tileData6[index7] * tileData9[index7])
                    regionCropArea10[m] = regionCropArea10[m] + total(tileData10[index7] * tileData9[index7])   ;Seventh set of cultivated land products
                endif
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;Calculate the statistical value in each administrative division
            for m = 0LL, n_elements(uniqData7) - 1 do begin         ;;Iterate through each Administrative division code
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    tempData1 = tileData7[index7]   ;;Current administrative division code data
                    tempData2 = tileData8[index7]   ;;Statistics of the current Administrative division code
                    
                    for n = 0LL, n_elements(uniqData8) - 1 do begin     ;;Iterate through each Administrative Division Statistics value
                        index8 = where(tempData2 eq uniqData8[n], count8)
                        if count8 gt 0 then begin
                            regionStatOptions[m, n] = regionStatOptions[m, n] + count8
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Compare the error between the arable land area of each set of products and the value of Administrative Division Statistics
    ;;Determine the statistics in each area
    regionStatData = DBLARR(n_elements(uniqData7))
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        tempData = regionStatOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            regionStatData[m] = uniqData8[index[0]]
        endif
    endfor

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    ;;Compare the statistic area of each set of products with the statistical value of each area, determine the fusion order accordin    
    regionStatDifProduct = DBLARR(n_elements(uniqData7), productCount)
    regionProductSort = LONARR(n_elements(uniqData7), productCount)
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        regionStatDifProduct[m, 0] = abs(regionStatData[m] - regionCropArea1[m])
        regionStatDifProduct[m, 1] = abs(regionStatData[m] - regionCropArea2[m])
        regionStatDifProduct[m, 2] = abs(regionStatData[m] - regionCropArea3[m])
        regionStatDifProduct[m, 3] = abs(regionStatData[m] - regionCropArea4[m])
        regionStatDifProduct[m, 4] = abs(regionStatData[m] - regionCropArea5[m])
        regionStatDifProduct[m, 5] = abs(regionStatData[m] - regionCropArea6[m])
        regionStatDifProduct[m, 6] = abs(regionStatData[m] - regionCropArea10[m])   ;Seventh set of cultivated land products
        
        ;;Start sorting
        tempData = regionStatDifProduct[m, *]
        sortIndex = sort(tempData)
        
        for n = 0LL, n_elements(sortIndex) - 1 do begin
            if sortIndex[n] eq 0 then begin
                regionProductSort[m, n] = fid1
            endif
            
            if sortIndex[n] eq 1 then begin
                regionProductSort[m, n] = fid2
            endif
            
            if sortIndex[n] eq 2 then begin
                regionProductSort[m, n] = fid3
            endif

            if sortIndex[n] eq 3 then begin
                regionProductSort[m, n] = fid4
            endif
            
            if sortIndex[n] eq 4 then begin
                regionProductSort[m, n] = fid5
            endif
            
            if sortIndex[n] eq 5 then begin
                regionProductSort[m, n] = fid6
            endif
            
            if sortIndex[n] eq 6 then begin
                regionProductSort[m, n] = fid10
            endif            
        endfor  
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix(Seven sets of products)
    synergyRankArray = [[1, 1, 1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 1, 1, 0], $
                        [1, 1, 1, 1, 1, 0, 1], $
                        [1, 1, 1, 1, 0, 1, 1], $
                        [1, 1, 1, 0, 1, 1, 1], $
                        [1, 1, 0, 1, 1, 1, 1], $
                        [1, 0, 1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 1, 0, 0], $
                        [1, 1, 1, 1, 0, 1, 0], $
                        [1, 1, 1, 0, 1, 1, 0], $
                        [1, 1, 0, 1, 1, 1, 0], $
                        [1, 0, 1, 1, 1, 1, 0], $
                        [1, 1, 1, 1, 0, 0, 1], $
                        [1, 1, 1, 0, 1, 0, 1], $
                        [1, 1, 0, 1, 1, 0, 1], $
                        [1, 0, 1, 1, 1, 0, 1], $
                        [1, 1, 1, 0, 0, 1, 1], $
                        [1, 1, 0, 1, 0, 1, 1], $
                        [1, 0, 1, 1, 0, 1, 1], $
                        [1, 1, 0, 0, 1, 1, 1], $
                        [1, 0, 1, 0, 1, 1, 1], $
                        [1, 0, 0, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 0, 0, 0], $
                        [1, 1, 1, 0, 1, 0, 0], $
                        [1, 1, 1, 0, 0, 1, 0], $
                        [1, 1, 1, 0, 0, 0, 1], $
                        [1, 1, 0, 1, 1, 0, 0], $
                        [1, 1, 0, 1, 0, 1, 0], $
                        [1, 1, 0, 1, 0, 0, 1], $
                        [1, 1, 0, 0, 1, 1, 0], $
                        [1, 1, 0, 0, 1, 0, 1], $
                        [1, 1, 0, 0, 0, 1, 1], $
                        [1, 0, 1, 1, 1, 0, 0], $
                        [1, 0, 1, 1, 0, 1, 0], $
                        [1, 0, 1, 1, 0, 0, 1], $
                        [1, 0, 1, 0, 1, 1, 0], $
                        [1, 0, 1, 0, 1, 0, 1], $
                        [1, 0, 1, 0, 0, 1, 1], $
                        [1, 0, 0, 1, 1, 1, 0], $
                        [1, 0, 0, 1, 1, 0, 1], $
                        [1, 0, 0, 1, 0, 1, 1], $
                        [1, 0, 0, 0, 1, 1, 1], $
                        [1, 1, 1, 0, 0, 0, 0], $
                        [1, 1, 0, 1, 0, 0, 0], $
                        [1, 1, 0, 0, 1, 0, 0], $
                        [1, 1, 0, 0, 0, 1, 0], $
                        [1, 1, 0, 0, 0, 0, 1], $
                        [1, 0, 1, 1, 0, 0, 0], $
                        [1, 0, 1, 0, 1, 0, 0], $
                        [1, 0, 1, 0, 0, 1, 0], $
                        [1, 0, 1, 0, 0, 0, 1], $
                        [1, 0, 0, 1, 1, 0, 0], $
                        [1, 0, 0, 1, 0, 1, 0], $
                        [1, 0, 0, 1, 0, 0, 1], $
                        [1, 0, 0, 0, 1, 1, 0], $
                        [1, 0, 0, 0, 1, 0, 1], $
                        [1, 0, 0, 0, 0, 1, 1], $
                        [1, 1, 0, 0, 0, 0, 0], $
                        [1, 0, 1, 0, 0, 0, 0], $
                        [1, 0, 0, 1, 0, 0, 0], $
                        [1, 0, 0, 0, 1, 0, 0], $
                        [1, 0, 0, 0, 0, 1, 0], $
                        [1, 0, 0, 0, 0, 0, 1], $
                        [1, 0, 0, 0, 0, 0, 0], $
                        [0, 1, 1, 1, 1, 1, 1], $
                        [0, 1, 1, 1, 1, 1, 0], $
                        [0, 1, 1, 1, 1, 0, 1], $
                        [0, 1, 1, 1, 0, 1, 1], $
                        [0, 1, 1, 0, 1, 1, 1], $
                        [0, 1, 0, 1, 1, 1, 1], $
                        [0, 0, 1, 1, 1, 1, 1], $
                        [0, 1, 1, 1, 1, 0, 0], $
                        [0, 1, 1, 1, 0, 1, 0], $
                        [0, 1, 1, 0, 1, 1, 0], $
                        [0, 1, 0, 1, 1, 1, 0], $
                        [0, 0, 1, 1, 1, 1, 0], $
                        [0, 1, 1, 1, 0, 0, 1], $
                        [0, 1, 1, 0, 1, 0, 1], $
                        [0, 1, 0, 1, 1, 0, 1], $
                        [0, 0, 1, 1, 1, 0, 1], $
                        [0, 1, 1, 0, 0, 1, 1], $
                        [0, 1, 0, 1, 0, 1, 1], $
                        [0, 0, 1, 1, 0, 1, 1], $
                        [0, 1, 0, 0, 1, 1, 1], $
                        [0, 0, 1, 0, 1, 1, 1], $
                        [0, 0, 0, 1, 1, 1, 1], $
                        [0, 1, 1, 1, 0, 0, 0], $
                        [0, 1, 1, 0, 1, 0, 0], $
                        [0, 1, 1, 0, 0, 1, 0], $
                        [0, 1, 1, 0, 0, 0, 1], $
                        [0, 1, 0, 1, 1, 0, 0], $
                        [0, 1, 0, 1, 0, 1, 0], $
                        [0, 1, 0, 1, 0, 0, 1], $
                        [0, 1, 0, 0, 1, 1, 0], $
                        [0, 1, 0, 0, 1, 0, 1], $
                        [0, 1, 0, 0, 0, 1, 1], $
                        [0, 0, 1, 1, 1, 0, 0], $
                        [0, 0, 1, 1, 0, 1, 0], $
                        [0, 0, 1, 1, 0, 0, 1], $
                        [0, 0, 1, 0, 1, 1, 0], $
                        [0, 0, 1, 0, 1, 0, 1], $
                        [0, 0, 1, 0, 0, 1, 1], $
                        [0, 0, 0, 1, 1, 1, 0], $
                        [0, 0, 0, 1, 1, 0, 1], $
                        [0, 0, 0, 1, 0, 1, 1], $
                        [0, 0, 0, 0, 1, 1, 1], $
                        [0, 1, 1, 0, 0, 0, 0], $
                        [0, 1, 0, 1, 0, 0, 0], $
                        [0, 1, 0, 0, 1, 0, 0], $
                        [0, 1, 0, 0, 0, 1, 0], $
                        [0, 1, 0, 0, 0, 0, 1], $
                        [0, 0, 1, 1, 0, 0, 0], $
                        [0, 0, 1, 0, 1, 0, 0], $
                        [0, 0, 1, 0, 0, 1, 0], $
                        [0, 0, 1, 0, 0, 0, 1], $
                        [0, 0, 0, 1, 1, 0, 0], $
                        [0, 0, 0, 1, 0, 1, 0], $
                        [0, 0, 0, 1, 0, 0, 1], $
                        [0, 0, 0, 0, 1, 1, 0], $
                        [0, 0, 0, 0, 1, 0, 1], $
                        [0, 0, 0, 0, 0, 1, 1], $
                        [0, 1, 0, 0, 0, 0, 0], $
                        [0, 0, 1, 0, 0, 0, 0], $
                        [0, 0, 0, 1, 0, 0, 0], $
                        [0, 0, 0, 0, 1, 0, 0], $
                        [0, 0, 0, 0, 0, 1, 0], $
                        [0, 0, 0, 0, 0, 0, 1], $
                        [0, 0, 0, 0, 0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    OPENW, unit2, outputFileName2, /get_lun    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, Calculate synergy value
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land zoning synergy'], title = 'Cultivated land zoning synergy', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Output value
            resultData1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            synergyResult = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            
            ;;Temporarily convert the cultivated land ratio data to 0 and 1 values
            tileDataCopy1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            tileDataCopy2 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy3 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy4 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy5 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy6 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy10 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)                                 

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate through each Administrative division code
            for n = 0LL, n_elements(uniqData7) - 1 do begin
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Seven sets of product errors based on current administrative divisions
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the product with the smallest error
                dims1[1] = tileStartSample
                dims1[2] = tileEndSample
                dims1[3] = tileStartLine
                dims1[4] = tileEndLine
    
                tileData1 = ENVI_GET_DATA(fid = regionProductSort[n, 0], dims = dims1, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy1[*, *] = 0L
                index1 = where(tileData1 gt 0.0, count1)
                if count1 gt 0 then begin
                    tileDataCopy1[index1] = 1L
                endif 
                
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the product with the second smallest error                
                dims2[1] = tileStartSample
                dims2[2] = tileEndSample
                dims2[3] = tileStartLine
                dims2[4] = tileEndLine
                
                tileData2 = ENVI_GET_DATA(fid = regionProductSort[n, 1], dims = dims2, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy2[*, *] = 0L
                index2 = where(tileData2 gt 0.0, count2)
                if count2 gt 0 then begin
                    tileDataCopy2[index2] = 1L
                endif                 
                
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the product with the third smallest error                 
                dims3[1] = tileStartSample
                dims3[2] = tileEndSample
                dims3[3] = tileStartLine
                dims3[4] = tileEndLine
                
                tileData3 = ENVI_GET_DATA(fid = regionProductSort[n, 2], dims = dims3, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy3[*, *] = 0L
                index3 = where(tileData3 gt 0.0, count3)
                if count3 gt 0 then begin
                    tileDataCopy3[index3] = 1L
                endif                                 
                
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the product with the fourth smallest error                 
                dims4[1] = tileStartSample
                dims4[2] = tileEndSample
                dims4[3] = tileStartLine
                dims4[4] = tileEndLine
                
                tileData4 = ENVI_GET_DATA(fid = regionProductSort[n, 3], dims = dims4, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy4[*, *] = 0L
                index4 = where(tileData4 gt 0.0, count4)
                if count4 gt 0 then begin
                    tileDataCopy4[index4] = 1L
                endif                                 
                
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the product with the fifth smallest error                 
                dims5[1] = tileStartSample
                dims5[2] = tileEndSample
                dims5[3] = tileStartLine
                dims5[4] = tileEndLine
                
                tileData5 = ENVI_GET_DATA(fid = regionProductSort[n, 4], dims = dims5, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy5[*, *] = 0L
                index5 = where(tileData5 gt 0.0, count5)
                if count5 gt 0 then begin
                    tileDataCopy5[index5] = 1L
                endif
                
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the product with the sixth smallest error                 
                dims6[1] = tileStartSample
                dims6[2] = tileEndSample
                dims6[3] = tileStartLine
                dims6[4] = tileEndLine
                
                tileData6 = ENVI_GET_DATA(fid = regionProductSort[n, 5], dims = dims6, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy6[*, *] = 0L
                index6 = where(tileData6 gt 0.0, count6)
                if count6 gt 0 then begin
                    tileDataCopy6[index6] = 1L
                endif 
                
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the 7th smallest error product                 
                dims10[1] = tileStartSample
                dims10[2] = tileEndSample
                dims10[3] = tileStartLine
                dims10[4] = tileEndLine
                
                tileData10 = ENVI_GET_DATA(fid = regionProductSort[n, 6], dims = dims10, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy10[*, *] = 0L
                index10 = where(tileData10 gt 0.0, count10)
                if count10 gt 0 then begin
                    tileDataCopy10[index10] = 1L
                endif                                               

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value
                tempData1 = tileDataCopy1
                
                for m = 0LL, synergyRankLine - 1 do begin
                    tempData1 = abs(tileDataCopy1 - synergyRankArray[0, m]) + abs(tileDataCopy2 - synergyRankArray[1, m]) + $
                                abs(tileDataCopy3 - synergyRankArray[2, m]) + abs(tileDataCopy4 - synergyRankArray[3, m]) + $
                                abs(tileDataCopy5 - synergyRankArray[4, m]) + abs(tileDataCopy6 - synergyRankArray[5, m]) + $
                                abs(tileDataCopy10 - synergyRankArray[6, m])
                    index1 = where(tempData1 eq 0, count1)
                    if count1 gt 0 then begin
                        resultData1[index1] = LONG(m + 1)
                    endif
                endfor

                index2 = where(tileData7 eq uniqData7[n], count2)
                if count2 gt 0 then begin
                    synergyResult[index2] = resultData1[index2]
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, synergyResult
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1
            tempData2[*, *] = tempData2[*, *] + tileData2[*, *] + tileData3[*, *] + $
                          tileData4[*, *] + tileData5[*, *] + tileData6[*, *] + tileData10[*, *]
                          
            tempData3 = tileDataCopy1
            tempData3[*, *] = tempData3[*, *] + tileDataCopy2[*, *] + tileDataCopy3[*, *] + $
                          tileDataCopy4[*, *] + tileDataCopy5[*, *] + tileDataCopy6[*, *] + tileDataCopy10[*, *]
            
            resultData2 = tileData1
            resultData2[*, *] = tempData2[*, *] / tempData3[*, *]     
                                 
            index3 = where(tempData3 eq 0, count3)
            if count3 gt 0 then begin
                resultData2[index3] = 0.0
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 3, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy data of each area', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Average ratio', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ENVI_OPEN_FILE, outputFileName2, r_fid = r_fid2
    if r_fid2 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land preliminary synergy (statistical value accuracy)-three sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithThreeByRegion, event

    base = widget_auto_base(title = 'Cultivated land preliminary synergy (statistical value accuracy)-three sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName8', $
        default = '', /auto)
    inputFileName9 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName9', $
        default = '', /auto)
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Function of cultivated land preliminary synergy (statistical value accuracy)-three sets of products
    functionResult = funcCalCroplandSynergyWithThreeByRegion(inputFileName1, inputFileName2, $
        inputFileName3, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of cultivated land preliminary synergy (statistical value accuracy)-three sets of products
function funcCalCroplandSynergyWithThreeByRegion, inputFileName1, inputFileName2, $
        inputFileName3, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    proDeleteFile, file_name = outputFileName2       

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read three sets of farmland product data and ratio data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;First set of product
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;Second set of product
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;Third set of product
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;Administrative division code
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;Statistics of administrative divisions
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;Pixel Area Data
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1    ;;First set of product
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2    ;;Second set of product
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3    ;;Third set of product

    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7    ;;Administrative division code
    
    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8    ;;Statistics of administrative divisions
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9    ;;Pixel Area Data
    
    ;;Product count
    productCount = 3
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 6
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns7
    nsArray[4] = ns8
    nsArray[5] = ns9
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl7
    nlArray[4] = nl8
    nlArray[5] = nl9
       
    nlStd = min(nlArray, max = maxValue)

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to get the unique value of Administrative division code and statistical data
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine

            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)            
            
            ;;Get unique value of administrative division code
            tileData7 = tileData7[sort(tileData7)]
            curUniqData7 = tileData7[uniq(tileData7)]
            
            ;;Get unique value of Statistics of administrative divisions
            tileData8 = tileData8[sort(tileData8)]
            curUniqData8 = tileData8[uniq(tileData8)]
            
            if i eq 0 and j eq 0 then begin
               uniqData7 = curUniqData7
               lastUniqData7 = uniqData7
               
               uniqData8 = curUniqData8
               lastUniqData8 = uniqData8
            endif else begin
               uniqData7 = [curUniqData7, lastUniqData7]               
               lastUniqData7 = uniqData7
               
               uniqData8 = [curUniqData8, lastUniqData8]               
               lastUniqData8 = uniqData8
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get unique value of administrative division code
    uniqData7 = uniqData7[sort(uniqData7)]
    uniqData7 = uniqData7[uniq(uniqData7)]
    
    ;;Get unique value of Administrative Division Statistics
    uniqData8 = uniqData8[sort(uniqData8)]
    uniqData8 = uniqData8[uniq(uniqData8)]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to calculate the area of each set of cultivated land products
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;Area of cultivated land divided by three sets of cultivated land products
    regionCropArea1 = DBLARR(n_elements(uniqData7))
    regionCropArea2 = DBLARR(n_elements(uniqData7))
    regionCropArea3 = DBLARR(n_elements(uniqData7))
    
    ;;The statistical value in each area is used to determine the statistical value of the area,Excluded because of an inconsistency between the Administrative division code and Statistics of administrative divisions
    regionStatOptions = DBLARR(n_elements(uniqData7), n_elements(uniqData8))
    
    ;;Progress Bar
    ENVI_REPORT_INIT, ['Arable land area calculation of each region'], title = 'Arable land area calculation of each region', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the first set of products
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the second set of products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the third set of products
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Pixel Area Data
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index9 = where(tileData9 lt 0.0, count9)
            if count9 gt 0 then begin
                tileData9[index9] = 0.0
            endif

   
            ;;Calculate the area of arable land for each set of products, the unique value of Administrative division code is uniqData7
            for m = 0LL, n_elements(uniqData7) - 1 do begin
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    regionCropArea1[m] = regionCropArea1[m] + total(tileData1[index7] * tileData9[index7])
                    regionCropArea2[m] = regionCropArea2[m] + total(tileData2[index7] * tileData9[index7])
                    regionCropArea3[m] = regionCropArea3[m] + total(tileData3[index7] * tileData9[index7])
                endif
            endfor
            
            ;;Calculate the statistical value in each administrative division
            for m = 0LL, n_elements(uniqData7) - 1 do begin         ;;Iterate through each Administrative division code
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    tempData1 = tileData7[index7]   ;;Current administrative division code data
                    tempData2 = tileData8[index7]   ;;Statistics of the current Administrative division code
                    
                    for n = 0LL, n_elements(uniqData8) - 1 do begin     ;;Iterate through each Administrative Division Statistics value
                        index8 = where(tempData2 eq uniqData8[n], count8)
                        if count8 gt 0 then begin
                            regionStatOptions[m, n] = regionStatOptions[m, n] + count8
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Compare the error between the arable land area of each set of products and the value of Administrative Division Statistics
    ;;Determine the statistics in each area
    regionStatData = DBLARR(n_elements(uniqData7))
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        tempData = regionStatOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            regionStatData[m] = uniqData8[index[0]]
        endif
    endfor

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    ;;Compare the statistic area of each set of products with the statistical value of each area, determine the fusion order accordin    
    regionStatDifProduct = DBLARR(n_elements(uniqData7), productCount)
    regionProductSort = LONARR(n_elements(uniqData7), productCount)
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        regionStatDifProduct[m, 0] = abs(regionStatData[m] - regionCropArea1[m])
        regionStatDifProduct[m, 1] = abs(regionStatData[m] - regionCropArea2[m])
        regionStatDifProduct[m, 2] = abs(regionStatData[m] - regionCropArea3[m])
        
        ;;Start sorting
        tempData = regionStatDifProduct[m, *]
        sortIndex = sort(tempData)
        
        for n = 0LL, n_elements(sortIndex) - 1 do begin
            if sortIndex[n] eq 0 then begin
                regionProductSort[m, n] = fid1
            endif
            
            if sortIndex[n] eq 1 then begin
                regionProductSort[m, n] = fid2
            endif
            
            if sortIndex[n] eq 2 then begin
                regionProductSort[m, n] = fid3
            endif
        endfor  
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Establish three sets of product synergy level matrix
    synergyRankArray = [[1, 1, 1], $
                        [1, 1, 0], $
                        [1, 0, 1], $
                        [0, 1, 1], $
                        [1, 0, 0], $
                        [0, 1, 0], $
                        [0, 0, 1], $
                        [0, 0, 0]]
                            
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    OPENW, unit2, outputFileName2, /get_lun    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, Calculate synergy value
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land zoning synergy'], title = 'Cultivated land zoning synergy', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Output value
            resultData1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            synergyResult = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            
            ;;Temporarily convert the cultivated land ratio data to 0 and 1 values
            tileDataCopy1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            tileDataCopy2 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy3 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate through each Administrative division code
            for n = 0LL, n_elements(uniqData7) - 1 do begin
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Three sets of product errors based on current administrative divisions
                dims1[1] = tileStartSample
                dims1[2] = tileEndSample
                dims1[3] = tileStartLine
                dims1[4] = tileEndLine
    
                tileData1 = ENVI_GET_DATA(fid = regionProductSort[n, 0], dims = dims1, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy1[*, *] = 0L
                index1 = where(tileData1 gt 0.0, count1)
                if count1 gt 0 then begin
                    tileDataCopy1[index1] = 1L
                endif 
                
                dims2[1] = tileStartSample
                dims2[2] = tileEndSample
                dims2[3] = tileStartLine
                dims2[4] = tileEndLine
                
                tileData2 = ENVI_GET_DATA(fid = regionProductSort[n, 1], dims = dims2, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy2[*, *] = 0L
                index2 = where(tileData2 gt 0.0, count2)
                if count2 gt 0 then begin
                    tileDataCopy2[index2] = 1L
                endif                 
                
                dims3[1] = tileStartSample
                dims3[2] = tileEndSample
                dims3[3] = tileStartLine
                dims3[4] = tileEndLine
                
                tileData3 = ENVI_GET_DATA(fid = regionProductSort[n, 2], dims = dims3, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy3[*, *] = 0L
                index3 = where(tileData3 gt 0.0, count3)
                if count3 gt 0 then begin
                    tileDataCopy3[index3] = 1L
                endif

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value
                tempData1 = tileDataCopy1
                
                for m = 0LL, synergyRankLine - 1 do begin
                    tempData1 = abs(tileDataCopy1 - synergyRankArray[0, m]) + abs(tileDataCopy2 - synergyRankArray[1, m]) + $
                                abs(tileDataCopy3 - synergyRankArray[2, m])

                    index1 = where(tempData1 eq 0, count1)
                    if count1 gt 0 then begin
                        resultData1[index1] = LONG(m + 1)
                    endif
                endfor

                index2 = where(tileData7 eq uniqData7[n], count2)
                if count2 gt 0 then begin
                    synergyResult[index2] = resultData1[index2]
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, synergyResult
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1
            tempData2[*, *] = tempData2[*, *] + tileData2[*, *] + tileData3[*, *]
                          
            tempData3 = tileDataCopy1
            tempData3[*, *] = tempData3[*, *] + tileDataCopy2[*, *] + tileDataCopy3[*, *]
            
            resultData2 = tileData1
            resultData2[*, *] = tempData2[*, *] / tempData3[*, *]
            
            index3 = where(tempData3 eq 0, count3)
            if count3 gt 0 then begin
                resultData2[index3] = 0.0
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 3, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy data of each area', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Average ratio', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ENVI_OPEN_FILE, outputFileName2, r_fid = r_fid2
    if r_fid2 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land preliminary synergy (statistical value accuracy)-four sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithFourByRegion, event

    base = widget_auto_base(title = 'Cultivated land preliminary synergy (statistical value accuracy)-four sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName8', $
        default = '', /auto)
    inputFileName9 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName9', $
        default = '', /auto)
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Function of cultivated land preliminary synergy (statistical value accuracy)-four sets of products
    functionResult = funcCalCroplandSynergyWithFourByRegion(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of cultivated land preliminary synergy (statistical value accuracy)-four sets of products
function funcCalCroplandSynergyWithFourByRegion, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    proDeleteFile, file_name = outputFileName2       

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read four sets of farmland product data and ratio data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;First set of product
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;Second set of product
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;Third set of product
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;Fourth set of product
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;Administrative division code
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;Statistics of administrative divisions
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;Pixel Area Data
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1    ;;First set of product
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2    ;;Second set of product
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3    ;;Third set of product
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4    ;;Fourth set of product

    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7    ;;Administrative division code
    
    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8    ;;Statistics of administrative divisions
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9    ;;Pixel Area Data
    
    ;;Product count
    productCount = 4
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 7
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns7
    nsArray[5] = ns8
    nsArray[6] = ns9
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl7
    nlArray[5] = nl8
    nlArray[6] = nl9
       
    nlStd = min(nlArray, max = maxValue)

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to get the unique value of Administrative division code and statistical data
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine

            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)            
            
            ;;Get unique value of administrative division code
            tileData7 = tileData7[sort(tileData7)]
            curUniqData7 = tileData7[uniq(tileData7)]
            
            ;;Get unique value of Statistics of administrative divisions
            tileData8 = tileData8[sort(tileData8)]
            curUniqData8 = tileData8[uniq(tileData8)]
            
            if i eq 0 and j eq 0 then begin
               uniqData7 = curUniqData7
               lastUniqData7 = uniqData7
               
               uniqData8 = curUniqData8
               lastUniqData8 = uniqData8
            endif else begin
               uniqData7 = [curUniqData7, lastUniqData7]               
               lastUniqData7 = uniqData7
               
               uniqData8 = [curUniqData8, lastUniqData8]               
               lastUniqData8 = uniqData8
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get unique value of administrative division code
    uniqData7 = uniqData7[sort(uniqData7)]
    uniqData7 = uniqData7[uniq(uniqData7)]
    
    ;;Get unique value of Administrative Division Statistics
    uniqData8 = uniqData8[sort(uniqData8)]
    uniqData8 = uniqData8[uniq(uniqData8)]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to calculate the area of each set of cultivated land products
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;Area of cultivated land divided by four sets of cultivated land products
    regionCropArea1 = DBLARR(n_elements(uniqData7))
    regionCropArea2 = DBLARR(n_elements(uniqData7))
    regionCropArea3 = DBLARR(n_elements(uniqData7))
    regionCropArea4 = DBLARR(n_elements(uniqData7))
    
    ;;The statistical value in each area is used to determine the statistical value of the area,Excluded because of an inconsistency between the Administrative division code and Statistics of administrative divisions
    regionStatOptions = DBLARR(n_elements(uniqData7), n_elements(uniqData8))
    
    ;;Progress Bar
    ENVI_REPORT_INIT, ['Arable land area calculation of each region'], title = 'Arable land area calculation of each region', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the first set of products
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the second set of products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the third set of products
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the fourth set of products
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)

            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Pixel Area Data
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index9 = where(tileData9 lt 0.0, count9)
            if count9 gt 0 then begin
                tileData9[index9] = 0.0
            endif

   
            ;;Calculate the area of arable land for each set of products, the unique value of Administrative division code is uniqData7
            for m = 0LL, n_elements(uniqData7) - 1 do begin
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    regionCropArea1[m] = regionCropArea1[m] + total(tileData1[index7] * tileData9[index7])
                    regionCropArea2[m] = regionCropArea2[m] + total(tileData2[index7] * tileData9[index7])
                    regionCropArea3[m] = regionCropArea3[m] + total(tileData3[index7] * tileData9[index7])
                    regionCropArea4[m] = regionCropArea4[m] + total(tileData4[index7] * tileData9[index7])
                endif
            endfor
            
            ;;Calculate the statistical value in each administrative division
            for m = 0LL, n_elements(uniqData7) - 1 do begin         ;;Iterate through each Administrative division code
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    tempData1 = tileData7[index7]   ;;Current administrative division code data
                    tempData2 = tileData8[index7]   ;;Statistics of the current Administrative division code
                    
                    for n = 0LL, n_elements(uniqData8) - 1 do begin     ;;Iterate through each Administrative Division Statistics value
                        index8 = where(tempData2 eq uniqData8[n], count8)
                        if count8 gt 0 then begin
                            regionStatOptions[m, n] = regionStatOptions[m, n] + count8
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Compare the error between the arable land area of each set of products and the value of Administrative Division Statistics
    ;;Determine the statistics in each area
    regionStatData = DBLARR(n_elements(uniqData7))
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        tempData = regionStatOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            regionStatData[m] = uniqData8[index[0]]
        endif
    endfor

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    ;;Compare the statistic area of each set of products with the statistical value of each area, determine the fusion order accordin    
    regionStatDifProduct = DBLARR(n_elements(uniqData7), productCount)
    regionProductSort = LONARR(n_elements(uniqData7), productCount)
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        regionStatDifProduct[m, 0] = abs(regionStatData[m] - regionCropArea1[m])
        regionStatDifProduct[m, 1] = abs(regionStatData[m] - regionCropArea2[m])
        regionStatDifProduct[m, 2] = abs(regionStatData[m] - regionCropArea3[m])
        regionStatDifProduct[m, 3] = abs(regionStatData[m] - regionCropArea4[m])
        
        ;;Start sorting
        tempData = regionStatDifProduct[m, *]
        sortIndex = sort(tempData)
        
        for n = 0LL, n_elements(sortIndex) - 1 do begin
            if sortIndex[n] eq 0 then begin
                regionProductSort[m, n] = fid1
            endif
            
            if sortIndex[n] eq 1 then begin
                regionProductSort[m, n] = fid2
            endif
            
            if sortIndex[n] eq 2 then begin
                regionProductSort[m, n] = fid3
            endif

            if sortIndex[n] eq 3 then begin
                regionProductSort[m, n] = fid4
            endif
        endfor  
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Establish four sets of product fusion level matrix
    synergyRankArray = [[1, 1, 1, 1], $
                        [1, 1, 1, 0], $
                        [1, 1, 0, 1], $
                        [1, 0, 1, 1], $
                        [0, 1, 1, 1], $
                        [1, 1, 0, 0], $
                        [1, 0, 1, 0], $
                        [0, 1, 1, 0], $
                        [1, 0, 0, 1], $
                        [0, 1, 0, 1], $
                        [0, 0, 1, 1], $
                        [1, 0, 0, 0], $
                        [0, 1, 0, 0], $
                        [0, 0, 1, 0], $
                        [0, 0, 0, 1], $
                        [0, 0, 0, 0]]
                            
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    OPENW, unit2, outputFileName2, /get_lun    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, Calculate synergy value
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land zoning synergy'], title = 'Cultivated land zoning synergy', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Output value
            resultData1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            synergyResult = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            
            ;;Temporarily convert the cultivated land ratio data to 0 and 1 values
            tileDataCopy1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            tileDataCopy2 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy3 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy4 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate through each Administrative division code
            for n = 0LL, n_elements(uniqData7) - 1 do begin
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Six sets of product errors based on current administrative divisions
                dims1[1] = tileStartSample
                dims1[2] = tileEndSample
                dims1[3] = tileStartLine
                dims1[4] = tileEndLine
    
                tileData1 = ENVI_GET_DATA(fid = regionProductSort[n, 0], dims = dims1, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy1[*, *] = 0L
                index1 = where(tileData1 gt 0.0, count1)
                if count1 gt 0 then begin
                    tileDataCopy1[index1] = 1L
                endif 
                
                dims2[1] = tileStartSample
                dims2[2] = tileEndSample
                dims2[3] = tileStartLine
                dims2[4] = tileEndLine
                
                tileData2 = ENVI_GET_DATA(fid = regionProductSort[n, 1], dims = dims2, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy2[*, *] = 0L
                index2 = where(tileData2 gt 0.0, count2)
                if count2 gt 0 then begin
                    tileDataCopy2[index2] = 1L
                endif                 
                
                dims3[1] = tileStartSample
                dims3[2] = tileEndSample
                dims3[3] = tileStartLine
                dims3[4] = tileEndLine
                
                tileData3 = ENVI_GET_DATA(fid = regionProductSort[n, 2], dims = dims3, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy3[*, *] = 0L
                index3 = where(tileData3 gt 0.0, count3)
                if count3 gt 0 then begin
                    tileDataCopy3[index3] = 1L
                endif                                 
                
                dims4[1] = tileStartSample
                dims4[2] = tileEndSample
                dims4[3] = tileStartLine
                dims4[4] = tileEndLine
                
                tileData4 = ENVI_GET_DATA(fid = regionProductSort[n, 3], dims = dims4, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy4[*, *] = 0L
                index4 = where(tileData4 gt 0.0, count4)
                if count4 gt 0 then begin
                    tileDataCopy4[index4] = 1L
                endif

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value
                tempData1 = tileDataCopy1
                
                for m = 0LL, synergyRankLine - 1 do begin
                    tempData1 = abs(tileDataCopy1 - synergyRankArray[0, m]) + abs(tileDataCopy2 - synergyRankArray[1, m]) + $
                                abs(tileDataCopy3 - synergyRankArray[2, m]) + abs(tileDataCopy4 - synergyRankArray[3, m])

                    index1 = where(tempData1 eq 0, count1)
                    if count1 gt 0 then begin
                        resultData1[index1] = LONG(m + 1)
                    endif
                endfor

                index2 = where(tileData7 eq uniqData7[n], count2)
                if count2 gt 0 then begin
                    synergyResult[index2] = resultData1[index2]
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, synergyResult
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1
            tempData2[*, *] = tempData2[*, *] + tileData2[*, *] + tileData3[*, *] + $
                          tileData4[*, *]
                          
            tempData3 = tileDataCopy1
            tempData3[*, *] = tempData3[*, *] + tileDataCopy2[*, *] + tileDataCopy3[*, *] + $
                          tileDataCopy4[*, *]
            
            resultData2 = tileData1
            resultData2[*, *] = tempData2[*, *] / tempData3[*, *]
            
            index3 = where(tempData3 eq 0, count3)
            if count3 gt 0 then begin
                resultData2[index3] = 0.0
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 3, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy data of each area', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Average ratio', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ENVI_OPEN_FILE, outputFileName2, r_fid = r_fid2
    if r_fid2 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land preliminary synergy (precision)-five sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithFive, event

    base = widget_auto_base(title = 'Cultivated land preliminary synergy (precision)-five sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)        
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Function of cultivated land preliminary synergy (precision)-five sets of products
    functionResult = funcCalCroplandSynergyWithFive(inputFileName1, $
        inputFileName2, $
        inputFileName3, $
        inputFileName4, $
        inputFileName5, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of cultivated land preliminary synergy (precision)-five sets of products
function funcCalCroplandSynergyWithFive, inputFileName1, $
        inputFileName2, $
        inputFileName3, $
        inputFileName4, $
        inputFileName5, $
        outputFileName1, outputFileName2
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read five sets of farmland product data and ratio data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 5
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 0], $
                        [1, 1, 1, 0, 1], $
                        [1, 1, 0, 1, 1], $
                        [1, 0, 1, 1, 1], $
                        [0, 1, 1, 1, 1], $
                        [1, 1, 1, 0, 0], $
                        [1, 1, 0, 1, 0], $
                        [1, 0, 1, 1, 0], $
                        [0, 1, 1, 1, 0], $
                        [1, 1, 0, 0, 1], $
                        [1, 0, 1, 0, 1], $
                        [0, 1, 1, 0, 1], $
                        [1, 0, 0, 1, 1], $
                        [0, 1, 0, 1, 1], $
                        [0, 0, 1, 1, 1], $
                        [1, 1, 0, 0, 0], $
                        [1, 0, 1, 0, 0], $
                        [0, 1, 1, 0, 0], $
                        [1, 0, 0, 1, 0], $
                        [0, 1, 0, 1, 0], $
                        [0, 0, 1, 1, 0], $
                        [1, 0, 0, 0, 1], $
                        [0, 1, 0, 0, 1], $
                        [0, 0, 1, 0, 1], $
                        [0, 0, 0, 1, 1], $
                        [1, 0, 0, 0, 0], $
                        [0, 1, 0, 0, 0], $
                        [0, 0, 1, 0, 0], $
                        [0, 0, 0, 1, 0], $
                        [0, 0, 0, 0, 1], $
                        [0, 0, 0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    
    OPENW, unit2, outputFileName2, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land synergy calculation'], title = 'Cultivated land synergy calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the current block data of five sets of cultivated land products
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            tileDataCopy1 = tileData1
            index = where(tileDataCopy1 gt 0.0, count)
            if count gt 0 then begin
                tileDataCopy1[index] = 1.0D
            endif
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            tileDataCopy2 = tileData2
            index = where(tileDataCopy2 gt 0.0, count)
            if count gt 0 then begin
                tileDataCopy2[index] = 1.0D
            endif
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            tileDataCopy3 = tileData3
            index = where(tileDataCopy3 gt 0.0, count)
            if count gt 0 then begin
                tileDataCopy3[index] = 1.0D
            endif
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            tileDataCopy4 = tileData4
            index = where(tileDataCopy4 gt 0.0, count)
            if count gt 0 then begin
                tileDataCopy4[index] = 1.0D
            endif            
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            tileDataCopy5 = tileData5
            index = where(tileDataCopy5 gt 0.0, count)
            if count gt 0 then begin
                tileDataCopy5[index] = 1.0D
            endif                        
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value      
            resultData1 = INTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = tileData5
            
            for m = 0LL, synergyRankLine - 1 do begin
                tempData1 = abs(tileDataCopy1 - synergyRankArray[0, m]) + abs(tileDataCopy2 - synergyRankArray[1, m]) + $
                            abs(tileDataCopy3 - synergyRankArray[2, m]) + abs(tileDataCopy4 - synergyRankArray[3, m]) + $
                            abs(tileDataCopy5 - synergyRankArray[4, m])
                index1 = where(tempData1 eq 0, count1)
                if count1 gt 0 then begin
                    resultData1[index1] = m + 1
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1 + tileData2 + $
                        tileData3 + tileData4 + $
                        tileData5
                        
            tempDataCopy2 = tileDataCopy1 + tileDataCopy2 + $
                            tileDataCopy3 + tileDataCopy4 + $
                            tileDataCopy5
            
            resultData2 = tempData2 / tempDataCopy2
            
            index2 = where(finite(resultData2) eq 0, count2)
            if count2 gt 0 then begin
                resultData2[index2] = 0.0D
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Free memory
    FREE_LUN, unit2
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 2, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Matrix sorting', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy ratio', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName2, r_fid = r_fid2
    if r_fid2 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end    
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land preliminary synergy (statistical value accuracy)-five sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithFiveByRegion, event

    base = widget_auto_base(title = 'Cultivated land preliminary synergy (statistical value accuracy)-five sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName8', $
        default = '', /auto)
    inputFileName9 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName9', $
        default = '', /auto)        
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Function of cultivated land preliminary synergy (statistical value accuracy)-five sets of products
    functionResult = funcCalCroplandSynergyWithFiveByRegion(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of cultivated land preliminary synergy (statistical value accuracy)-five sets of products
function funcCalCroplandSynergyWithFiveByRegion, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, $
        inputFileName7, inputFileName8, inputFileName9, $
        outputFileName1, outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2       

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read five sets of farmland product data and ratio data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;First set of product
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;Second set of product
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;Third set of product
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;Fourth set of product
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;Fifth set of product
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;Administrative division code
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;Statistics of administrative divisions
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;Pixel Area Data
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1    ;;First set of product
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2    ;;Second set of product
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3    ;;Third set of product
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4    ;;Fourth set of product

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5    ;;Fifth set of product
    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7    ;;Administrative division code
    
    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8    ;;Statistics of administrative divisions
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9    ;;Pixel Area Data
    
    ;;Product count
    productCount = 5
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 8
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns7
    nsArray[6] = ns8
    nsArray[7] = ns9
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl7
    nlArray[6] = nl8
    nlArray[7] = nl9
       
    nlStd = min(nlArray, max = maxValue)

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to get the unique value of Administrative division code and statistical data
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine

            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)            
            
            ;;Get unique value of administrative division code
            tileData7 = tileData7[sort(tileData7)]
            curUniqData7 = tileData7[uniq(tileData7)]
            
            ;;Get unique value of Statistics of administrative divisions
            tileData8 = tileData8[sort(tileData8)]
            curUniqData8 = tileData8[uniq(tileData8)]            
            
            if i eq 0 and j eq 0 then begin
               uniqData7 = curUniqData7
               lastUniqData7 = uniqData7
               
               uniqData8 = curUniqData8
               lastUniqData8 = uniqData8
            endif else begin
               uniqData7 = [curUniqData7, lastUniqData7]               
               lastUniqData7 = uniqData7
               
               uniqData8 = [curUniqData8, lastUniqData8]               
               lastUniqData8 = uniqData8
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get unique value of administrative division code
    uniqData7 = uniqData7[sort(uniqData7)]
    uniqData7 = uniqData7[uniq(uniqData7)]
    
    ;;Get unique value of Administrative Division Statistics
    uniqData8 = uniqData8[sort(uniqData8)]
    uniqData8 = uniqData8[uniq(uniqData8)]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels to calculate the area of each set of cultivated land products
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;Cultivated land area of each set of cultivated land products
    regionCropArea1 = DBLARR(n_elements(uniqData7))
    regionCropArea2 = DBLARR(n_elements(uniqData7))
    regionCropArea3 = DBLARR(n_elements(uniqData7))
    regionCropArea4 = DBLARR(n_elements(uniqData7))
    regionCropArea5 = DBLARR(n_elements(uniqData7))
    
    ;;The statistical value in each area is used to determine the statistical value of the area,Excluded because of an inconsistency between the Administrative division code and Statistics of administrative divisions
    regionStatOptions = DBLARR(n_elements(uniqData7), n_elements(uniqData8))
    
    ;;Progress Bar
    ENVI_REPORT_INIT, ['Arable land area calculation of each region'], title = 'Arable land area calculation of each region', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the first set of products
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the second set of products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the third set of products
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the fourth set of products
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get farmland data for the fifth set of products
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Statistics of administrative divisions
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Pixel Area Data
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index9 = where(tileData9 lt 0.0, count9)
            if count9 gt 0 then begin
                tileData9[index9] = 0.0
            endif
            
            ;;Calculate the area of arable land for each set of products, the unique value of Administrative division code is uniqData7
            for m = 0LL, n_elements(uniqData7) - 1 do begin
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    regionCropArea1[m] = regionCropArea1[m] + total(tileData1[index7] * tileData9[index7])
                    regionCropArea2[m] = regionCropArea2[m] + total(tileData2[index7] * tileData9[index7])
                    regionCropArea3[m] = regionCropArea3[m] + total(tileData3[index7] * tileData9[index7])
                    regionCropArea4[m] = regionCropArea4[m] + total(tileData4[index7] * tileData9[index7])
                    regionCropArea5[m] = regionCropArea5[m] + total(tileData5[index7] * tileData9[index7])
                endif
            endfor
            
            ;;Calculate the statistical value in each administrative division
            for m = 0LL, n_elements(uniqData7) - 1 do begin         ;;Iterate through each Administrative division code
                index7 = where(tileData7 eq uniqData7[m], count7)
                if count7 gt 0 then begin
                    tempData1 = tileData7[index7]   ;;Current administrative division code data
                    tempData2 = tileData8[index7]   ;;Statistics of the current Administrative division code
                    
                    for n = 0LL, n_elements(uniqData8) - 1 do begin     ;;Iterate through each Administrative Division Statistics value
                        index8 = where(tempData2 eq uniqData8[n], count8)
                        if count8 gt 0 then begin
                            regionStatOptions[m, n] = regionStatOptions[m, n] + count8
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Compare the error between the arable land area of each set of products and the value of Administrative Division Statistics
    ;;Determine the statistics in each area
    regionStatData = DBLARR(n_elements(uniqData7))
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        tempData = regionStatOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            regionStatData[m] = uniqData8[index[0]]
        endif
    endfor

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    ;;Compare the statistic area of each set of products with the statistical value of each area, determine the fusion order accordin    
    regionStatDifProduct = DBLARR(n_elements(uniqData7), productCount)
    regionProductSort = LONARR(n_elements(uniqData7), productCount)
    
    for m = 0LL, n_elements(uniqData7) - 1 do begin
        regionStatDifProduct[m, 0] = abs(regionStatData[m] - regionCropArea1[m])
        regionStatDifProduct[m, 1] = abs(regionStatData[m] - regionCropArea2[m])
        regionStatDifProduct[m, 2] = abs(regionStatData[m] - regionCropArea3[m])
        regionStatDifProduct[m, 3] = abs(regionStatData[m] - regionCropArea4[m])
        regionStatDifProduct[m, 4] = abs(regionStatData[m] - regionCropArea5[m])
        
        ;;Start sorting
        tempData = regionStatDifProduct[m, *]
        sortIndex = sort(tempData)
        
        for n = 0LL, n_elements(sortIndex) - 1 do begin
            if sortIndex[n] eq 0 then begin
                regionProductSort[m, n] = fid1
            endif
            
            if sortIndex[n] eq 1 then begin
                regionProductSort[m, n] = fid2
            endif
            
            if sortIndex[n] eq 2 then begin
                regionProductSort[m, n] = fid3
            endif

            if sortIndex[n] eq 3 then begin
                regionProductSort[m, n] = fid4
            endif
            
            if sortIndex[n] eq 4 then begin
                regionProductSort[m, n] = fid5
            endif
        endfor  
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 0], $
                        [1, 1, 1, 0, 1], $
                        [1, 1, 0, 1, 1], $
                        [1, 0, 1, 1, 1], $
                        [0, 1, 1, 1, 1], $
                        [1, 1, 1, 0, 0], $
                        [1, 1, 0, 1, 0], $
                        [1, 0, 1, 1, 0], $
                        [0, 1, 1, 1, 0], $
                        [1, 1, 0, 0, 1], $
                        [1, 0, 1, 0, 1], $
                        [0, 1, 1, 0, 1], $
                        [1, 0, 0, 1, 1], $
                        [0, 1, 0, 1, 1], $
                        [0, 0, 1, 1, 1], $
                        [1, 1, 0, 0, 0], $
                        [1, 0, 1, 0, 0], $
                        [1, 0, 0, 1, 0], $
                        [1, 0, 0, 0, 1], $
                        [0, 1, 1, 0, 0], $
                        [0, 1, 0, 1, 0], $
                        [0, 1, 0, 0, 1], $
                        [0, 0, 1, 1, 0], $
                        [0, 0, 1, 0, 1], $
                        [0, 0, 0, 1, 1], $
                        [1, 0, 0, 0, 0], $
                        [0, 1, 0, 0, 0], $
                        [0, 0, 1, 0, 0], $
                        [0, 0, 0, 1, 0], $
                        [0, 0, 0, 0, 1], $
                        [0, 0, 0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    OPENW, unit2, outputFileName2, /get_lun    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, Calculate synergy value
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land zoning synergy'], title = 'Cultivated land zoning synergy', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get administrative division code
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Output value
            resultData1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            synergyResult = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
            
            ;;Temporarily convert the cultivated land ratio data to 0 and 1 values
            tileDataCopy1 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            tileDataCopy2 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy3 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy4 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)
                                 
            tileDataCopy5 = LONARR(tileEndSample - tileStartSample + 1, $
                                 tileEndLine - tileStartLine + 1)

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate through each Administrative division code
            for n = 0LL, n_elements(uniqData7) - 1 do begin
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Six sets of product errors based on current administrative divisions
                dims1[1] = tileStartSample
                dims1[2] = tileEndSample
                dims1[3] = tileStartLine
                dims1[4] = tileEndLine
    
                tileData1 = ENVI_GET_DATA(fid = regionProductSort[n, 0], dims = dims1, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy1[*, *] = 0L
                index1 = where(tileData1 gt 0.0, count1)
                if count1 gt 0 then begin
                    tileDataCopy1[index1] = 1L
                endif 
                
                dims2[1] = tileStartSample
                dims2[2] = tileEndSample
                dims2[3] = tileStartLine
                dims2[4] = tileEndLine
                
                tileData2 = ENVI_GET_DATA(fid = regionProductSort[n, 1], dims = dims2, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy2[*, *] = 0L
                index2 = where(tileData2 gt 0.0, count2)
                if count2 gt 0 then begin
                    tileDataCopy2[index2] = 1L
                endif                 
                
                dims3[1] = tileStartSample
                dims3[2] = tileEndSample
                dims3[3] = tileStartLine
                dims3[4] = tileEndLine
                
                tileData3 = ENVI_GET_DATA(fid = regionProductSort[n, 2], dims = dims3, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy3[*, *] = 0L
                index3 = where(tileData3 gt 0.0, count3)
                if count3 gt 0 then begin
                    tileDataCopy3[index3] = 1L
                endif                                 
                
                dims4[1] = tileStartSample
                dims4[2] = tileEndSample
                dims4[3] = tileStartLine
                dims4[4] = tileEndLine
                
                tileData4 = ENVI_GET_DATA(fid = regionProductSort[n, 3], dims = dims4, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy4[*, *] = 0L
                index4 = where(tileData4 gt 0.0, count4)
                if count4 gt 0 then begin
                    tileDataCopy4[index4] = 1L
                endif                                 
                
                dims5[1] = tileStartSample
                dims5[2] = tileEndSample
                dims5[3] = tileStartLine
                dims5[4] = tileEndLine
                
                tileData5 = ENVI_GET_DATA(fid = regionProductSort[n, 4], dims = dims5, pos = 0)
                
                ;;Convert to 0, 1 value
                tileDataCopy5[*, *] = 0L
                index5 = where(tileData5 gt 0.0, count5)
                if count5 gt 0 then begin
                    tileDataCopy5[index5] = 1L
                endif              

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value
                tempData1 = tileDataCopy1
                
                for m = 0LL, synergyRankLine - 1 do begin
                    tempData1 = abs(tileDataCopy1 - synergyRankArray[0, m]) + abs(tileDataCopy2 - synergyRankArray[1, m]) + $
                                abs(tileDataCopy3 - synergyRankArray[2, m]) + abs(tileDataCopy4 - synergyRankArray[3, m]) + $
                                abs(tileDataCopy5 - synergyRankArray[4, m])
                    index1 = where(tempData1 eq 0, count1)
                    if count1 gt 0 then begin
                        resultData1[index1] = LONG(m + 1)
                    endif
                endfor

                index2 = where(tileData7 eq uniqData7[n], count2)
                if count2 gt 0 then begin
                    synergyResult[index2] = resultData1[index2]
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, synergyResult
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1
            tempData2[*, *] = tempData2[*, *] + tileData2[*, *] + tileData3[*, *] + $
                          tileData4[*, *] + tileData5[*, *]
                          
            tempData3 = tileDataCopy1
            tempData3[*, *] = tempData3[*, *] + tileDataCopy2[*, *] + tileDataCopy3[*, *] + $
                          tileDataCopy4[*, *] + tileDataCopy5[*, *]
            
            resultData2 = tileData1
            resultData2[*, *] = tempData2[*, *] / tempData3[*, *]
            
            index3 = where(tempData3 eq 0, count3)
            if count3 gt 0 then begin
                resultData2[index3] = 0.0
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 3, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy data of each area', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Average ratio', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ENVI_OPEN_FILE, outputFileName2, r_fid = r_fid2
    if r_fid2 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land data correction (requires that the cumulative value of synergy is greater than the statistical value)
pro proCalCroplandAdjustMorethanStat, event

    base = widget_auto_base(title = 'Cultivated land data correction (cumulative value is greater than statistical value)')
    inputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'inputFileName5', $
        default = '', /auto)
        
    inputFileName2 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName6 = widget_outf(base, prompt = 'Administrative area after adjustment', uvalue = 'inputFileName6', $
        default = '', /auto)
    inputFileName7 = widget_outf(base, prompt = 'Administrative number after correction', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Cultivated land statistics and iterative area of each fusion value', uvalue = 'inputFileName8', $
        default = '', /auto)            

    outputFileName1 = widget_outf(base, prompt = 'Correction data results', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Cultivated land combination results', uvalue = 'outputFileName2', $
        default = '', /auto)
    outputFileName3 = widget_outf(base, prompt = 'Correction ratio data', uvalue = 'outputFileName3', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3   
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5

    inputFileName6 = baseclass.inputFileName6
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8   
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    outputFileName3 = baseclass.outputFileName3    
    
    ;;;;;Call the data synergy function
    functionResult = funcCalCroplandAdjustMorethanStat(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, $
        outputFileName1, outputFileName2, outputFileName3)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of cultivated land data correction (requires that the cumulative value of synergy is greater than the statisticalValue
function funcCalCroplandAdjustMorethanStat, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
    inputFileName7, inputFileName8, outputFileName1, outputFileName2, outputFileName3

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2
    
    proDeleteFile, file_name = outputFileName3

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1      ;;Arable land Synergy data
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2      ;;Administrative division code
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3      ;;Administrative Division Statistics
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4      ;;Pixel Area Data
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5      ;;Arable land synergy ratio
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4
    
    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ;;Take the minimum range of four classified product data
    arrayCount = 5
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate over all pixels and calculate unique values
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)      ;;Arable land Synergy data
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)      ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)      ;;Administrative Division Statistics            
            
            ;Get the current unique value
            tileData1 = tileData1[sort(tileData1)]      ;;Arable land Synergy data
            curUniqData1 = tileData1[uniq(tileData1)]
            
            tileData2 = tileData2[sort(tileData2)]      ;;Administrative division code
            curUniqData2 = tileData2[uniq(tileData2)]
            
            tileData3 = tileData3[sort(tileData3)]      ;;Administrative Division Statistics
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1
               uniqData2 = curUniqData2
               uniqData3 = curUniqData3
                           
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]
               uniqData2 = [curUniqData2, lastUniqData2]
               uniqData3 = [curUniqData3, lastUniqData3]
               
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Arable land Synergy data
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    uniqData2 = uniqData2[sort(uniqData2)]    ;;Administrative division code
    uniqData2 = uniqData2[uniq(uniqData2)]
    
    uniqData3 = uniqData3[sort(uniqData3)]    ;;Administrative Division Statistics
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    synergyData = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    statDataStat = DBLARR(n_elements(uniqData2), n_elements(uniqData3))
    statData = DBLARR(n_elements(uniqData2))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Administrative Division Statistics'], title = 'Administrative Division Statistics', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Synergy data
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area  
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif                    
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio                    
            
            ;;Calculate the area of each Synergy data value in each administrative division unit
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    tempData1 = tileData1[index1]
                    tempData4 = tileData4[index1]
                    tempData5 = tileData5[index1]
                    for n = 0LL, n_elements(uniqData1) - 1 do begin
                        index2 = where(tempData1 eq uniqData1[n], count2)
                        if count2 gt 0 then begin
                            synergyData[n, m] = synergyData[n, m] + total(tempData4[index2] * tempData5[index2])
                        endif
                    endfor
                endif
            endfor
            
            ;;Calculate the statistical value in each administrative division unit
            for m = 0LL, n_elements(uniqData2) - 1 do begin
                index1 = where(tileData2 eq uniqData2[m], count1)
                ;;Get the unique value of the statistical data corresponding to the current Administrative division code
                if count1 gt 0 then begin
                    tempData3 = tileData3[index1]
                    for n = 0LL, n_elements(uniqData3) - 1 do begin
                        index3 = where(tempData3 eq uniqData3[n], count3)
                        if count3 gt 0 then begin
                            statDataStat[m, n] = statDataStat[m, n] + count3
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;To decide which statistics are available
    for m = 0LL, n_elements(uniqData2) - 1 do begin
        tempData7 = statDataStat[m, *]
        maxValue = max(tempData7, min = minValue)
        index7 = where(tempData7 eq maxValue, count7)
        if count7 gt 0 then begin
            statData[m] = uniqData3[index7[0]]
        endif
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Modify the original data according to Synergy data area and statistical data area
    iterateSumArea = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    
    ;;Accumulate the area of every possible situation in Calculate Synergy Data
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        for j = 0LL, i do begin
            iterateSumArea[i, *] = iterateSumArea[i, *] + synergyData[j, *]
        endfor
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;The first output should be the statistical area of each administrative division unit, then each synergy
    columnNameStrArray = STRARR(n_elements(uniqData1)+1)
    columnNameStrArray[0] = "Arable land area statistics"
    for i = 1, n_elements(uniqData1) do begin
        columnNameStrArray[i] = string(uniqData1[i - 1])
    endfor
    
    tableContents = DBLARR(n_elements(uniqData2), n_elements(uniqData1) + 1)
    for i = 0, n_elements(uniqData2) - 1 do begin
        tableContents[i, 0] = statData[i]
        for j = 0, n_elements(uniqData1) - 1 do begin
            tableContents[i, j + 1] = iterateSumArea[j, i]
        endfor
    endfor 
    
    ExportDataToExcel, inputFileName8, tableContents, columnNameStrArray, uniqData2, $
        n_elements(columnNameStrArray), n_elements(uniqData2)
    
    ;;Relative error of Calculate Synergy Data area and ，（如果当前区域的统计数据为0，则校正数据值也设置为0）
    areaDifference = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    areaDifferenceFlag = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    areaStat = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        areaDifference[i, *] = abs(iterateSumArea[i, *] - statData[*]) * statData[*]
        areaDifferenceFlag[i, *] = iterateSumArea[i, *] - statData[*]
        areaStat[i, *] = statData[*]
    endfor
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Determine the effective area of Synergy data'], title = 'Determine the effective area of Synergy data', base = base
    ENVI_REPORT_INC, base, n_elements(uniqData2)
    
    ;;Determine the serial number corresponding to the smallest relative error
    flagData = BYTARR(n_elements(uniqData1), n_elements(uniqData2))   ;;;;;uniqData1Synergy data，uniqData2 administrative division
    columnIndex = ['Reserved cultivated land', 'Remove cultivated land']
    flagDataOutput = DBLARR(n_elements(columnIndex), n_elements(uniqData2))

    for i = 0LL, n_elements(uniqData2) - 1 do begin
        flag = 1B
        flagIndex = 1B
        
        tempData = areaDifference[*, i]
        minValue = min(tempData, max = maxValue)
        for j = 0LL, n_elements(uniqData1) - 1 do begin
            if areaStat[j, i] eq 0.0 then begin
                flag = 0B
            endif
        
            flagData[j, i] = flag
            
            for m = 0LL, n_elements(columnIndex) - 1 do begin
                flagDataOutput[m, i] = flagDataOutput[m, i] + flag
            endfor
            
            if flagIndex eq 0B then begin
                flag = 0B
                flagIndex = 1B
            endif

            if areaDifference[j, i] eq minValue and areaDifferenceFlag[j, i] ge 0 then begin
                flag = 0B
            endif
            
            if areaDifference[j, i] eq minValue and areaDifferenceFlag[j, i] lt 0 then begin
                flagIndex = 0B
            endif

        endfor
        
        ;Progress bar, showing calculation progress
        ENVI_REPORT_STAT, base, i, n_elements(uniqData2)
    endfor    
    
    ;Output the corrected serial number value
    flagDataOutput = transpose(flagDataOutput)
    resultDataSize = size(flagDataOutput)
    
    ExportDataToExcel, inputFileName7, flagDataOutput, columnIndex, uniqData2, $
        n_elements(columnIndex), n_elements(uniqData2)
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Finally, the statistical data matching results are used to modify Synergy data
    ;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    OPENW, unit2, outputFileName2, /get_lun
    
    OPENW, unit3, outputFileName3, /get_lun   
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels and perform Synergy data modification
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Statistically corrected area data
    uniqData4 = [0, 1]
    synergyData2 = DBLARR(n_elements(uniqData4), n_elements(uniqData2))
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Synergy data modification'], title = 'Synergy data modification', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Synergy data
            resultData = BYTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            resultData[*, *] = 0B
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code

            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area 
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif         
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio
            
            ;;Modify the current data block
            for m = 0LL, n_elements(uniqData1) - 1 do begin
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    for n = 0LL, n_elements(index1) - 1 do begin
                        tempValue = tileData2[index1[n]]
                        for mm = 0LL, n_elements(uniqData2) - 1 do begin
                            if tempValue eq uniqData2[mm] then begin
                                resultData[index1[n]] = flagData[m, mm]
                            endif
                        endfor
                    endfor
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData
            
            resultData2 = resultData * tileData1
            writeu, unit2, resultData2
            
            ;Calculate the arable land area of each administrative division unit after correction
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    tempData1 = resultData[index1]
                    tempData4 = tileData4[index1]
                    tempData5 = tileData5[index1]
                    for n = 0LL, n_elements(uniqData4) - 1 do begin
                        index2 = where(tempData1 eq uniqData4[n], count2)
                        if count2 gt 0 then begin
                            synergyData2[n, m] = synergyData2[n, m] + total(tempData4[index2] * tempData5[index2])
                        endif
                    endfor
                endif
            endfor
            
            ;Calculate the corrected ratio data
            resultData3 = resultData * tileData5
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit3, resultData3            
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish       
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    FREE_LUN, unit3
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Modification of synergy data', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Arable land combination', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName3, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Corrected ratio data', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName2, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName3, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('校正后比例Error', /ERROR)
        return, 0
    end    
    
    ;将每个行政区划的每个Arable land combination的面积输出
    synergyData2 = transpose(synergyData2)
    resultDataSize = size(synergyData2)
    
    tableIndex = 0
    uniqData4 = ['Not cultivated land', 'Is cultivated land']
    ExportDataToExcel, inputFileName6, synergyData2, uniqData4, uniqData2, $
        n_elements(uniqData4), n_elements(uniqData2)

    return, 1

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land data correction (requires that the synergy cumulative value is close to the statistical value)
pro proCalCroplandAdjustClosetoStat, event

    base = widget_auto_base(title = 'Cultivated land data correction (requires that the synergy cumulative value is close to the statistical value)')
    inputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'inputFileName5', $
        default = '', /auto)        
        
    inputFileName2 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName6 = widget_outf(base, prompt = 'Administrative area after adjustment', uvalue = 'inputFileName6', $
        default = '', /auto)
    inputFileName7 = widget_outf(base, prompt = 'Administrative number after correction', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Cultivated land statistics and iterative area of each fusion value', uvalue = 'inputFileName8', $
        default = '', /auto)            

    outputFileName1 = widget_outf(base, prompt = 'Correction data results', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Cultivated land combination results', uvalue = 'outputFileName2', $
        default = '', /auto)
    outputFileName3 = widget_outf(base, prompt = 'Correction ratio data', uvalue = 'outputFileName3', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3   
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5

    inputFileName6 = baseclass.inputFileName6
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8   
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    outputFileName3 = baseclass.outputFileName3    
    
    ;;;;;Function of cultivated land data correction (requires that the synergy cumulative value is close to the statistical value)
    functionResult = funcCalCroplandAdjustClosetoStat(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, $
        outputFileName1, outputFileName2, outputFileName3)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of cultivated land data correction (requires that the synergy cumulative value is close to the statistical value)
function funcCalCroplandAdjustClosetoStat, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
    inputFileName7, inputFileName8, outputFileName1, outputFileName2, outputFileName3

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2
    
    proDeleteFile, file_name = outputFileName3

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1      ;;Arable land Synergy data
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2      ;;Administrative division code
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3      ;;Administrative Division Statistics
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4      ;;Pixel Area Data
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5      ;;Arable land synergy ratio
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4
    
    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ;;Take the minimum range of four classified product data
    arrayCount = 5
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate over all pixels and calculate unique values
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)      ;;Arable land Synergy data
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)      ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)      ;;Administrative Division Statistics            
            
            ;Get the current unique value
            tileData1 = tileData1[sort(tileData1)]      ;;Arable land Synergy data
            curUniqData1 = tileData1[uniq(tileData1)]
            
            tileData2 = tileData2[sort(tileData2)]      ;;Administrative division code
            curUniqData2 = tileData2[uniq(tileData2)]
            
            tileData3 = tileData3[sort(tileData3)]      ;;Administrative Division Statistics
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1
               uniqData2 = curUniqData2
               uniqData3 = curUniqData3
                           
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]
               uniqData2 = [curUniqData2, lastUniqData2]
               uniqData3 = [curUniqData3, lastUniqData3]
               
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Arable land Synergy data
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    uniqData2 = uniqData2[sort(uniqData2)]    ;;Administrative division code
    uniqData2 = uniqData2[uniq(uniqData2)]
    
    uniqData3 = uniqData3[sort(uniqData3)]    ;;Administrative Division Statistics
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    synergyData = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    statDataStat = DBLARR(n_elements(uniqData2), n_elements(uniqData3))
    statData = DBLARR(n_elements(uniqData2))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Administrative Division Statistics'], title = 'Administrative Division Statistics', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Synergy data
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area  
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif                    
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio                    
            
            ;;Calculate the area of each Synergy data value in each administrative division unit
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    tempData1 = tileData1[index1]
                    tempData4 = tileData4[index1]
                    tempData5 = tileData5[index1]
                    for n = 0LL, n_elements(uniqData1) - 1 do begin
                        index2 = where(tempData1 eq uniqData1[n], count2)
                        if count2 gt 0 then begin
                            synergyData[n, m] = synergyData[n, m] + total(tempData4[index2] * tempData5[index2])
                        endif
                    endfor
                endif
            endfor
            
            ;;Calculate the statistical value in each administrative division unit
            for m = 0LL, n_elements(uniqData2) - 1 do begin
                index1 = where(tileData2 eq uniqData2[m], count1)
                ;;Get the unique value of the statistical data corresponding to the current Administrative division code
                if count1 gt 0 then begin
                    tempData3 = tileData3[index1]
                    for n = 0LL, n_elements(uniqData3) - 1 do begin
                        index3 = where(tempData3 eq uniqData3[n], count3)
                        if count3 gt 0 then begin
                            statDataStat[m, n] = statDataStat[m, n] + count3
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;To decide which statistics are available
    for m = 0LL, n_elements(uniqData2) - 1 do begin
        tempData7 = statDataStat[m, *]
        maxValue = max(tempData7, min = minValue)
        index7 = where(tempData7 eq maxValue, count7)
        if count7 gt 0 then begin
            statData[m] = uniqData3[index7[0]]
        endif
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Modify the original data according to Synergy data area and statistical data area
    iterateSumArea = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    
    ;;Accumulate the area of every possible situation in Calculate Synergy Data
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        for j = 0LL, i do begin
            iterateSumArea[i, *] = iterateSumArea[i, *] + synergyData[j, *]
        endfor
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;The first output should be the statistical area of each administrative division unit, then each synergy
    columnNameStrArray = STRARR(n_elements(uniqData1)+1)
    columnNameStrArray[0] = "Arable land area statistics"
    for i = 1, n_elements(uniqData1) do begin
        columnNameStrArray[i] = string(uniqData1[i - 1])
    endfor
    
    tableContents = DBLARR(n_elements(uniqData2), n_elements(uniqData1) + 1)
    for i = 0, n_elements(uniqData2) - 1 do begin
        tableContents[i, 0] = statData[i]
        for j = 0, n_elements(uniqData1) - 1 do begin
            tableContents[i, j + 1] = iterateSumArea[j, i]
        endfor
    endfor 
    
    ExportDataToExcel, inputFileName8, tableContents, columnNameStrArray, uniqData2, $
        n_elements(columnNameStrArray), n_elements(uniqData2)
    
    ;;Relative error of Calculate Synergy Data area and ,(If the statistical data of the current area is 0, the correction data value is also set to 0)
    areaDifference = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    areaDifferenceFlag = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    areaStat = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        areaDifference[i, *] = abs(iterateSumArea[i, *] - statData[*])
        areaDifferenceFlag[i, *] = iterateSumArea[i, *] - statData[*]
        areaStat[i, *] = statData[*]
    endfor
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Determine the effective area of Synergy data'], title = 'Determine the effective area of Synergy data', base = base
    ENVI_REPORT_INC, base, n_elements(uniqData2)
    
    ;;Determine the serial number corresponding to the smallest relative error
    flagData = BYTARR(n_elements(uniqData1), n_elements(uniqData2))   ;;;;;uniqData1Synergy data，uniqData2 administrative division
    columnIndex = ['Reserved cultivated land', 'Remove cultivated land']
    flagDataOutput = DBLARR(n_elements(columnIndex), n_elements(uniqData2))

    for i = 0LL, n_elements(uniqData2) - 1 do begin
        flag = 1B
        flagIndex = 1B
        
        tempData = areaDifference[*, i]
        minValue = min(tempData, max = maxValue)
        minValueIndex = where(tempData eq minValue, count)
        
        if count gt 0 then begin
            for j = 0LL, n_elements(uniqData1) - 1 do begin
                if areaStat[j, i] eq 0.0 then begin
                    flag = 0B
                endif
            
                flagData[j, i] = flag
                
                for m = 0LL, n_elements(columnIndex) - 1 do begin
                    flagDataOutput[m, i] = flagDataOutput[m, i] + flag
                endfor
                
                if flagIndex eq 0B then begin
                    flag = 0B
                    flagIndex = 1B
                endif
    
                if j eq minValueIndex[count - 1] and iterateSumArea[j, i] gt 0 then begin
                    flag = 0B
                endif
                 
                if j eq minValueIndex[count - 1] and iterateSumArea[j, i] le 0 then begin
                    flagIndex = 0B
                endif
            endfor
        endif
        
        ;Progress bar, showing calculation progress
        ENVI_REPORT_STAT, base, i, n_elements(uniqData2)
        
    endfor    
    
    ;Output the corrected serial number value
    flagDataOutput = transpose(flagDataOutput)
    resultDataSize = size(flagDataOutput)
    
    ExportDataToExcel, inputFileName7, flagDataOutput, columnIndex, uniqData2, $
        n_elements(columnIndex), n_elements(uniqData2)
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Finally, the statistical data matching results are used to modify Synergy data
    ;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    OPENW, unit2, outputFileName2, /get_lun
    
    OPENW, unit3, outputFileName3, /get_lun   
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels and perform Synergy data modification
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Statistically corrected area data
    uniqData4 = [0, 1]
    synergyData2 = DBLARR(n_elements(uniqData4), n_elements(uniqData2))
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Synergy data modification'], title = 'Synergy data modification', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Synergy Code
            resultData = BYTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            resultData[*, *] = 0B
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code

            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area 
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif         
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio
            
            ;;Modify the current data block
            for m = 0LL, n_elements(uniqData1) - 1 do begin
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    for n = 0LL, n_elements(index1) - 1 do begin
                        tempValue = tileData2[index1[n]]
                        for mm = 0LL, n_elements(uniqData2) - 1 do begin
                            if tempValue eq uniqData2[mm] then begin
                                resultData[index1[n]] = flagData[m, mm]
                            endif
                        endfor
                    endfor
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData
            
            resultData2 = resultData * tileData1
            writeu, unit2, resultData2
            
            ;Calculate the arable land area of each administrative division unit after correction?????
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    tempData1 = resultData[index1]
                    tempData4 = tileData4[index1]
                    tempData5 = tileData5[index1]
                    for n = 0LL, n_elements(uniqData4) - 1 do begin
                        index2 = where(tempData1 eq uniqData4[n], count2)
                        if count2 gt 0 then begin
                            synergyData2[n, m] = synergyData2[n, m] + total(tempData4[index2] * tempData5[index2])
                        endif
                    endfor
                endif
            endfor
            
            ;Calculate the corrected ratio data
            resultData3 = resultData * tileData5
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit3, resultData3            
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish       
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    FREE_LUN, unit3
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Modification of synergy data', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Cultivated land synergy code', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName3, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Corrected ratio data', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName2, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName3, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end    
    
    ;Output the area of each Arable land combination of each administrative division
    synergyData2 = transpose(synergyData2)
    resultDataSize = size(synergyData2)
    
    tableIndex = 0
    uniqData4 = ['Not cultivated land', 'Is cultivated land']
    ExportDataToExcel, inputFileName6, synergyData2, uniqData4, uniqData2, $
        n_elements(uniqData4), n_elements(uniqData2)

    return, 1

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land data correction (requires that the integrated value of synergy is close to the statistical value)
pro proCalCroplandAdjustEqualtoStat, event

    base = widget_auto_base(title = 'Cultivated land data correction (requires that the integrated value of synergy is close to the statistical value)')
    inputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'inputFileName5', $
        default = '', /auto)        
        
    inputFileName2 = widget_outf(base, prompt = 'Administrative division code', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Administrative Division Statistics', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName6 = widget_outf(base, prompt = 'Process data output', uvalue = 'inputFileName6', $
        default = '', /auto)

    outputFileName1 = widget_outf(base, prompt = 'Correction data results', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Cultivated land combination results', uvalue = 'outputFileName2', $
        default = '', /auto)
    outputFileName3 = widget_outf(base, prompt = 'Correction ratio data', uvalue = 'outputFileName3', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3   
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    outputFileName3 = baseclass.outputFileName3    
    
    ;;;;;Function of cultivated land data correction (requires that the integrated value of synergy is close to the statistical value)
    functionResult = funcCalCroplandAdjustEqualtoStat(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
        outputFileName1, outputFileName2, outputFileName3)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of cultivated land data correction (requires that the integrated value of synergy is close to the statistical value)
function funcCalCroplandAdjustEqualtoStat, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
    outputFileName1, outputFileName2, outputFileName3

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2
    
    proDeleteFile, file_name = outputFileName3

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1      ;;Arable land Synergy data
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2      ;;Administrative division code
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3      ;;Administrative Division Statistics
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4      ;;Pixel Area Data
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5      ;;Arable land synergy ratio
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4
    
    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the minimum range of all input data
    arrayCount = 5
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate over all pixels and calculate unique values
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine
            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)      ;;Preliminary Synergy Code
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)      ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)      ;;Administrative Division Statistics            
            
            ;Get the current unique value
            tileData1 = tileData1[sort(tileData1)]      ;;Preliminary Synergy Code
            curUniqData1 = tileData1[uniq(tileData1)]
            
            tileData2 = tileData2[sort(tileData2)]      ;;Administrative division code
            curUniqData2 = tileData2[uniq(tileData2)]
            
            tileData3 = tileData3[sort(tileData3)]      ;;Administrative Division Statistics
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1
               uniqData2 = curUniqData2
               uniqData3 = curUniqData3
                           
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]
               uniqData2 = [curUniqData2, lastUniqData2]
               uniqData3 = [curUniqData3, lastUniqData3]
               
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Preliminary Synergy Code
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    uniqData2 = uniqData2[sort(uniqData2)]    ;;Administrative division code
    uniqData2 = uniqData2[uniq(uniqData2)]
    
    uniqData3 = uniqData3[sort(uniqData3)]    ;;Administrative Division Statistics
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    ;;The corresponding cultivated land area of each preliminary Synergy Code in each Administrative division code
    synergyData = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    
    ;;Statistical value corresponding to each Administrative division code (Due to the inaccurate fit between the data, one administrative division may correspond to multiple statistical values)
    statDataStat = DBLARR(n_elements(uniqData2), n_elements(uniqData3))
    
    ;;Statistical value corresponding to each Administrative division code (calibration standard)
    statData = DBLARR(n_elements(uniqData2))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Administrative Division Statistics'], title = 'Administrative Division Statistics', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine
            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Preliminary Synergy Code
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area  
            
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif                    
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Preliminary Synergy ratio                    
            
            ;;Calculate the area of cultivated land corresponding to each preliminary Synergy Code in each administrative division
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the Administrative division code
                index2 = where(tileData2 eq uniqData2[m], count2)
                if count2 gt 0 then begin
                    tempData1 = tileData1[index2]
                    tempData4 = tileData4[index2]
                    tempData5 = tileData5[index2]
                    for n = 0LL, n_elements(uniqData1) - 1 do begin   ;;In determining the preliminary Synergy Code
                        index1 = where(tempData1 eq uniqData1[n], count1)
                        if count1 gt 0 then begin
                            synergyData[n, m] = synergyData[n, m] + total(tempData4[index1] * tempData5[index1])
                        endif
                    endfor
                endif
            endfor
            
            ;;Calculate the statistical value of cultivated land corresponding to each administrative division
            for m = 0LL, n_elements(uniqData2) - 1 do begin
                index2 = where(tileData2 eq uniqData2[m], count2)
                ;;Get the unique value of the statistical data corresponding to the current Administrative division code
                if count2 gt 0 then begin
                    tempData3 = tileData3[index2]
                    for n = 0LL, n_elements(uniqData3) - 1 do begin
                        index3 = where(tempData3 eq uniqData3[n], count3)
                        if count3 gt 0 then begin
                            statDataStat[m, n] = statDataStat[m, n] + count3
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;to decide which statistical value is the value corresponding to the administrative division
    for m = 0LL, n_elements(uniqData2) - 1 do begin
        tempData7 = statDataStat[m, *]
        maxValue = max(tempData7, min = minValue)
        index7 = where(tempData7 eq maxValue, count7)
        if count7 gt 0 then begin
            statData[m] = uniqData3[index7[0]]
        endif
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Modify the original data according to Synergy data area and statistical data area
    ;;The cumulative value of the cultivated land area corresponding to the preliminary Synergy Code in each administrative division
    iterateSumArea = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    
    ;;Accumulate the area of every possible situation in Calculate Synergy Data
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        for j = 0LL, i do begin
            iterateSumArea[i, *] = iterateSumArea[i, *] + synergyData[j, *]
        endfor
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Relative error of Calculate Synergy Data area and 
    areaDifference = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    areaLastDifference = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    areaAbsDifference = DBLARR(n_elements(uniqData1), n_elements(uniqData2))
    
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        areaDifference[i, *] = iterateSumArea[i, *] - statData[*]      ;;Preliminary Synergy Code cumulative cultivated area minus statistics
        if i gt 0LL then begin
            areaLastDifference[i, *] = statData[*] - iterateSumArea[i - 1, *]
        endif
        areaAbsDifference[i, *] = abs(iterateSumArea[i, *] - statData[*])
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;The core link, determine the preliminary Synergy Code to be retained
    ENVI_REPORT_INIT, ['Determine the preliminary Synergy Code to keep'], title = 'Determine the preliminary Synergy Code to keep', base = base
    ENVI_REPORT_INC, base, n_elements(uniqData2)
    
    ;;Preliminary Synergy Code (14or15) to be retained in each administrative region
    regionSelectKeySynergyCode = LONARR(n_elements(uniqData2))
    regionSelectKeySynergyArea = DBLARR(n_elements(uniqData2))

    for i = 0LL, n_elements(uniqData2) - 1 do begin
        tempData = areaDifference[*, i]
        tempLastData = areaLastDifference[*, i]
        tempAbsData = areaAbsDifference[*, i]
        
        minValue = min(tempAbsData, max = maxValue)
        minValueIndex = where(tempAbsData eq minValue, count)
        if count gt 0 then begin
            ;;Note that if the area of the first initial Synergy Code is greater than the statistical value
            if minValueIndex[0] eq 0 then begin
                if tempData[minValueIndex[0]] ge 0 then begin
                    regionSelectKeySynergyCode[i] = uniqData1[minValueIndex[0]]
                    regionSelectKeySynergyArea[i] = statData[i]
                end else begin
                    ;;Encountered a problem, there are multiple minimum values
                    nextIndex = minValueIndex[n_elements(minValueIndex) - 1] + 1
                    if nextIndex lt n_elements(uniqData1) then begin 
                        regionSelectKeySynergyCode[i] = uniqData1[nextIndex]
                        regionSelectKeySynergyArea[i] = abs(tempData[minValueIndex[0]])
                    endif else begin
                        regionSelectKeySynergyCode[i] = uniqData1[n_elements(uniqData1) - 1]
                        regionSelectKeySynergyArea[i] = abs(tempData[minValueIndex[0]])
                    endelse
                endelse
            end else begin
                if tempData[minValueIndex[0]] ge 0 then begin    ;;When the accumulated value is greater than or equal to the statistical value, it is directly selected randomly in the current Synergy Code
                    regionSelectKeySynergyCode[i] = uniqData1[minValueIndex[0]]
                    regionSelectKeySynergyArea[i] = abs(tempLastData[minValueIndex[0]])
                endif else begin    ;;When the accumulated value is less than the statistical value, it needs to be randomly selected in the next Synergy Code
                    ;;Encountered a problem, there are multiple minimum values
                    nextIndex = minValueIndex[n_elements(minValueIndex) - 1] + 1
                    if nextIndex lt n_elements(uniqData1) then begin 
                        regionSelectKeySynergyCode[i] = uniqData1[nextIndex]
                        regionSelectKeySynergyArea[i] = abs(tempData[minValueIndex[0]])
                    endif else begin
                        regionSelectKeySynergyCode[i] = uniqData1[n_elements(uniqData1) - 1]
                        regionSelectKeySynergyArea[i] = abs(tempData[minValueIndex[0]])
                    endelse
                endelse
            endelse
        endif
        
        ;Progress bar, showing calculation progress
        ENVI_REPORT_STAT, base, i, n_elements(uniqData2)
    endfor

    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Find the number of pixels of the key initial Synergy Code in each administrative division
    regionSelectKeySynergyPixelCount = LONARR(n_elements(uniqData2))
    
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Calculate the number of pixels in the key initial Synergy Code'], title = 'Calculate the number of pixels in the key initial Synergy Code', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Preliminary Synergy Code
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code

            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area 
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif         
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio
            
            ;;Calculate the number of pixels corresponding to the key initial Synergy Code
            for m = 0LL, n_elements(uniqData2) - 1 do begin   ;;Administrative division code
                index2 = where(tileData2 eq uniqData2(m), count2)
                if count2 gt 0 then begin
                    tempData1 = tileData1[index2]
                    index1 = where(tempData1 eq regionSelectKeySynergyCode[m], count1)
                    if count1 gt 0 then begin
                        regionSelectKeySynergyPixelCount[m] = regionSelectKeySynergyPixelCount[m] + count1
                    endif
                endif
            endfor
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Record all information corresponding to the key initial Synergy Code in each administrative division
    ;;Find the maximum number of key initial codes
    regionSelectKeySynergyPixelCountMax = max(regionSelectKeySynergyPixelCount, min = minValue)
    
    ;;Calculate the cultivated area of key initial code pixels
    regionSelectKeySynergyPixelArea = DBLARR(n_elements(uniqData2), regionSelectKeySynergyPixelCountMax)
    
    ;;Record the serial number of key initial code pixels, similar to i++ in C++
    regionSelectKeySynergyPixelIndex = LONARR(n_elements(uniqData2))
    
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Record the pixel information corresponding to the key initial Synergy Code'], title = 'Record the pixel information corresponding to the key initial Synergy Code', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Preliminary Synergy Code
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code

            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area 
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif         
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio
            
            ;;Record key initial code information
            for m = 0LL, n_elements(uniqData2) - 1 do begin   ;;Administrative division code
                index2 = where(tileData2 eq uniqData2(m), count2)
                if count2 gt 0 then begin
                    tempData1 = tileData1[index2]   ;;Obtain the initial Synergy Code corresponding to the current Administrative division code
                    tempData4 = tileData4[index2]   ;;Get pixel area
                    tempData5 = tileData5[index2]   ;;Get Average ratio of cultivated land
                    
                    index1 = where(tempData1 eq regionSelectKeySynergyCode[m], count1)
                    if count1 gt 0 then begin
                        for n = 0LL, n_elements(index1) - 1 do begin
                            regionSelectKeySynergyPixelArea[m, regionSelectKeySynergyPixelIndex[m]] = tempData4[index1[n]] * tempData5[index1[n]]
                            regionSelectKeySynergyPixelIndex[m] = regionSelectKeySynergyPixelIndex[m] + 1
                        endfor
                    endif
                endif
            endfor
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Random selection meets
    ;;Key initial Synergy Code to be retained
    regionSelectKeySynergyPixelFlag = BYTARR(n_elements(uniqData2), regionSelectKeySynergyPixelCountMax)
    
    ;;遍历所有Administrative division code, and select the pixels corresponding to the key initial Synergy Code against the accurately corrected statistical area values
    for i = 0LL, n_elements(uniqData2) - 1 do begin
        curTempPixelArea = 0.0
        lastTempPixelArea = 0.0    
        savedFlag = 1B
        
        curPixelCount = regionSelectKeySynergyPixelCount[i]
        if curPixelCount gt 0 then begin
            randomPixelArray = randomu(undefinevar, curPixelCount)
            randomPixelIndex = sort(randomPixelArray)
            for j = 0LL, curPixelCount - 1 do begin   ;;Traverse all the pixels corresponding to the key initial Synergy Code
                curTempPixelArea = curTempPixelArea + regionSelectKeySynergyPixelArea[i, randomPixelIndex[j]]
                curDif = curTempPixelArea - regionSelectKeySynergyArea[i]
                if curDif ge 0.0 then begin
                    if j eq 0LL then begin
                        regionSelectKeySynergyPixelFlag[i, randomPixelIndex[j]] = savedFlag                
                        savedFlag = 0B
                    endif else begin
                        lastDif = abs(lastTempPixelArea - regionSelectKeySynergyArea[i])
                        if lastDif lt curDif then begin   ;;If the last initial Synergy Code is closer to the key value, the current Synergy Code pixels are not retained
                            regionSelectKeySynergyPixelFlag[i, randomPixelIndex[j]] = 0B
                            savedFlag = 0B
                        endif
                    endelse
                endif else begin
                    regionSelectKeySynergyPixelFlag[i, randomPixelIndex[j]] = savedFlag
                endelse

                lastTempPixelArea = curTempPixelArea
            endfor
        endif else begin
            regionSelectKeySynergyPixelFlag[i, *] = 0B
        endelse
    endfor

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Accurate correction based on the preliminary Synergy Code reserved above
    ;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    OPENW, unit2, outputFileName2, /get_lun
    
    OPENW, unit3, outputFileName3, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for accurate correction
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
        
    ;;Initialize the serial number of the key initial Synergy Code
    regionSelectKeySynergyPixelIndex[*] = 0
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Accurate data correction'], title = 'Accurate data correction', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Preliminary Synergy Code
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code

            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Statistics of administrative divisions
            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)   ;;Pixel area 
            ;;If Pixel area data is less than 0,set data value 0
            index4 = where(tileData4 lt 0.0, count4)
            if count4 gt 0 then begin
                tileData4[index4] = 0.0
            endif         
            
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)   ;;Average ratio
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;Output Results
            resultData = BYTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            resultData[*, *] = 0B
            
            ;;Accurately correct the current data block
            for m = 0LL, n_elements(uniqData2) - 1 do begin       ;;Administrative division code
                ;;;;;;;;;;;;;;TEST
                if uniqData2[m] eq 26407 then begin
                    test = 0
                endif
            
                index2 = where(tileData2 eq uniqData2[m], count2)
                if count2 gt 0 then begin
                    for n = 0LL, n_elements(index2) - 1 do begin      ;;No wonder it's slow, you need to pass the serial numbers in index2 one by one
                        curValue1 = tileData1[index2[n]]
                        if curValue1 lt regionSelectKeySynergyCode[m] then begin
                            resultData[index2[n]] = 1B
                        endif
                        
                        if curValue1 gt regionSelectKeySynergyCode[m] then begin
                            resultData[index2[n]] = 0B
                        endif
                        
                        if curValue1 eq regionSelectKeySynergyCode[m] then begin
                            resultData[index2[n]] = regionSelectKeySynergyPixelFlag[m, regionSelectKeySynergyPixelIndex[m]]
                            regionSelectKeySynergyPixelIndex[m] = regionSelectKeySynergyPixelIndex[m] + 1
                        endif
                    endfor
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData
            
            resultData2 = resultData * tileData1
            writeu, unit2, resultData2
            
            ;Calculate the corrected ratio data
            resultData3 = resultData * tileData5
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit3, resultData3            
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    FREE_LUN, unit3
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;All data related to the output area
    basicColumnCount = 5
    columnNames = STRARR(basicColumnCount + n_elements(uniqData1))
    columnNames[0] = "Administrative division code"
    columnNames[1] = "Statistics of cultivated land in administrative divisions"
    columnNames[2] = "Precise Synergy Code"
    columnNames[3] = "The area to be refined for the preliminary preliminary Synergy Code"
    columnNames[4] = "Accurate preliminary number of pixels corresponding to Synergy Code"
    
    startIndex = basicColumnCount
    endIndex = basicColumnCount + n_elements(uniqData1) - 1
    for i = startIndex, endIndex do begin     ;;Preliminary Synergy Code
        columnNames[i] = string(uniqData1[i - startIndex]) + "SynergyCode"
    endfor
    
    tableNS = n_elements(columnNames)
    
    tableData = DBLARR(tableNS, n_elements(uniqData2))
    tableData[0, *] = uniqData2[*]
    tableData[1, *] = statData[*]
    tableData[2, *] = regionSelectKeySynergyCode[*]
    tableData[3, *] = regionSelectKeySynergyArea[*]
    tableData[4, *] = regionSelectKeySynergyPixelCount[*]
    
    ;;Output the area of cultivated land corresponding to each preliminary Synergy Code in the area
    startIndex = basicColumnCount
    endIndex = basicColumnCount + n_elements(uniqData1) - 1
    for i = startIndex, endIndex do begin
        tableData[i, *] = iterateSumArea[i - startIndex, *]
    endfor
    
    tableData = transpose(tableData)
    
    tableName = "regionData"
    
    ExportDataToExcel2, inputFileName6, tableName, tableData, columnNames, $
        tableNS, n_elements(uniqData2)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Modification of synergy data', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Cultivated land synergy code', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName3, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Corrected ratio data', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName2, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName3, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end

    return, 1

end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land data resampling (integer multiples)
pro proCroplandResampleInt, event

    base = widget_auto_base(title = 'Cultivated land data resampling (integer multiples)')
        
    inputFileName1 = widget_outf(base, prompt = 'Cultivated land data products',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputPara1 = widget_param(base, prompt = 'Target sampling resolution', uvalue = 'inputPara1', $
        default = 0, /auto)
    outputFileName1 = widget_outf(base, prompt = 'Resampling results', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputPara1 = baseclass.inputPara1
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the resampling function of cultivated land data
    functionResult = funcCroplandResampleInt(inputFileName1, inputPara1, outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)    

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the resampling function of cultivated land data
function funcCroplandResampleInt, inputFileName1, inputPara1, outputFileName1

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    ;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ;;;;Get the resolution information of cultivated land data
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1    
        
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    resolution1 = (map_info1.ps[0] + map_info1.ps[1]) / 2.0
    
    resolution2 = inputPara1
    
    ;;;;First, the number of rows and columns of the resampled output image should be determined
    ns = floor(ns1 * resolution1 / resolution2)
    nl = floor(nl1 * resolution1 / resolution2)
    
    ;;;;Total amount control, traversing based on the target resampled data ranks
    
    ;;;;Determine the re-sampling ratio, if re-sampling from 250 meters to 500 meters, the re-sampling ratio is 2: 1
    ratioResolution = ceil(resolution2 / resolution1)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Arable land resampling'], title = 'Arable land resampling', base = base
    ENVI_REPORT_INC, base, nl
    
    ;;Create a new file for output
    OPENW, unit, outputFileName1, /get_lun
    
    nsStep = 5000
    
    ;Traverse each block 
    for i = 0LL, nl - 1 do begin
        for j = 0LL, ns - 1, nsStep do begin
            curNS = nsStep
            curNL = 1
            curNSStart = j
            curNSEnd = j + nsStep - 1
            curNLStart = i
            curNLEnd = i
            
            if j + nsStep ge ns - 1 then begin
                curNS = ns - 1 - j + 1
                curNSStart = j
                curNSEnd = ns - 1
            endif
        
            ;;Create a new array for calculating the proportion of cultivated land
            curData = LINDGEN(curNS, 1)
            curData = curData + 1
            curRebinData = rebin(curData, curNS * ratioResolution, ratioResolution, /sample)
            
            ;Get the data of the current block
            dims1[1] = curNSStart * ratioResolution
            dims1[2] = (curNSEnd + 1) * ratioResolution - 1
            dims1[3] = i * ratioResolution
            dims1[4] = (i + 1) * ratioResolution - 1
            
            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            resultData = curRebinData * tileData1
            
            sumData1 = DBLARR(curNS * ratioResolution)
            sumData2 = DBLARR(curNS * ratioResolution)
            
            for n = 0LL, ratioResolution - 1 do begin
                tempData1 = resultData[*, n]
                tempData2 = curRebinData[*, n]
                
                tempSumData1 = DBLARR(curNS * ratioResolution)
                tempSumData2 = DBLARR(curNS * ratioResolution)
                
                for m = 0LL, ratioResolution - 1 do begin
                    tempData3 = shift(tempData1, m)
                    tempData4 = shift(tempData2, m)
                    
                    tempSumData1 += tempData3
                    tempSumData2 += tempData4
                endfor
                
                sumData1 += tempSumData1
                sumData2 += tempSumData2
            endfor
            
            finalResult = sumData1[*] / sumData2[*]
            
            ;;Get the required data
            index = indgen(curNS)
            index = index * ratioResolution + ratioResolution - 1
            
            finalResult = finalResult[index]
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit, finalResult
        endfor            
            
        ;Progress bar, showing the calculation progress of change intensity
        ENVI_REPORT_STAT, base, i + 1, nl
    endfor

    ;;Free memory
    FREE_LUN, unit
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    map_info1.ps[0] = resolution2
    map_info1.ps[1] = resolution2
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = ns, nl = nl, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Resampling data', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    r_FID = resultFID

    return, 1
    
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Cultivated land data resampling (non-integer multiples)
pro proCroplandResampleFloat, event

    base = widget_auto_base(title = 'Cultivated land data resampling (non-integer multiples)')
        
    inputFileName1 = widget_outf(base, prompt = 'Cultivated land data products',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputPara1 = widget_param(base, prompt = 'Target sampling resolution', uvalue = 'inputPara1', $
        default = 0, /auto)
    outputFileName1 = widget_outf(base, prompt = 'Resampling results', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputPara1 = baseclass.inputPara1
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the resampling function of cultivated land data
    functionResult = funcCroplandResampleFloat(inputFileName1, inputPara1, outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)    

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the resampling function of cultivated land data
function funcCroplandResampleFloat, inputFileName1, inputPara1, outputFileName1

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    ;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ;;;;Get the resolution information of cultivated land data
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1    
        
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    resolution1 = (map_info1.ps[0] + map_info1.ps[1]) / 2.0
    
    resolution2 = inputPara1
    
    ;;;;First, the number of rows and columns of the resampled output image should be determined
    ns = floor(ns1 * resolution1 / resolution2)
    nl = floor(nl1 * resolution1 / resolution2)
    
    ;;;;Total amount control, traversing based on the target resampled data ranks
    
    ;;;;Determine the re-sampling ratio, if re-sampling from 250 meters to 500 meters, the re-sampling ratio is 2: 1
    ratioResolution = FIX(resolution2 / resolution1)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Arable land resampling'], title = 'Arable land resampling', base = base
    ENVI_REPORT_INC, base, nl
    
    ;;Create a new file for output
    OPENW, unit, outputFileName1, /get_lun
    
    ;Traverse each block 
    for i = 0LL, nl - 1 do begin
        ;;Create a new array for calculating the proportion of cultivated land
        curData = LINDGEN(ns, 1)
        curData = curData + 1
        curRebinData = rebin(curData, ns * ratioResolution, ratioResolution, /sample)
        
        ;Get the data of the current block
        dims1[1] = 0
        dims1[2] = ns * ratioResolution - 1
        dims1[3] = i * ratioResolution
        dims1[4] = (i + 1) * ratioResolution - 1
        
        tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
        
        resultData = curRebinData * tileData1
        
        sumData1 = DBLARR(ns * ratioResolution)
        sumData2 = DBLARR(ns * ratioResolution)
        
        for j = 0LL, ratioResolution - 1 do begin
            tempData1 = resultData[*, j]
            tempData2 = curRebinData[*, j]
            
            tempSumData1 = DBLARR(ns * ratioResolution)
            tempSumData2 = DBLARR(ns * ratioResolution)
            
            for m = 0LL, ratioResolution - 1 do begin
                tempData3 = shift(tempData1, m)
                tempData4 = shift(tempData2, m)
                
                tempSumData1 += tempData3
                tempSumData2 += tempData4
            endfor
            
            sumData1 += tempSumData1
            sumData2 += tempSumData2
        endfor
        
        finalResult = sumData1[*] / sumData2[*]
        
        ;;Get the required data
        index = indgen(ns)
        index = index * ratioResolution + ratioResolution - 1
        
        finalResult = finalResult[index]
        
        ;Write the calculation result of the current block data to the unit memory
        writeu, unit, finalResult
        
        ;Progress bar, showing the calculation progress of change intensity
        ENVI_REPORT_STAT, base, i + 1, nl
    endfor

    ;;Free memory
    FREE_LUN, unit
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    map_info1.ps[0] = resolution2
    map_info1.ps[1] = resolution2
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = ns, nl = nl, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Resampling data', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    r_FID = resultFID

    return, 1
    
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Subregion blank fill
pro proSubRegionBlankFill, event

    base = widget_auto_base(title = 'Subregion blank fill')
    inputFileName1 = widget_outf(base, prompt = 'Administrative division code of subregion', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Subregion correction data', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Provincial regional correction data', uvalue = 'inputFileName3', $
        default = '', /auto)

    outputFileName1 = widget_outf(base, prompt = 'Subsregion blank fill result', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3   
    
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the blank filling function of the subarea
    functionResult = FuncSubRegionBlankFill(inputFileName1, inputFileName2, $
        inputFileName3, outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the blank filling function of the subarea
function FuncSubRegionBlankFill, inputFileName1, inputFileName2, inputFileName3, outputFileName1

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1

    ;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ;;Take the minimum range of four classified product data
    arrayCount = 3
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;Get the current unique value
            tileData1 = tileData1[sort(tileData1)]
            curUniqData1 = tileData1[uniq(tileData1)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1                           
               lastUniqData1 = uniqData1
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]               
               lastUniqData1 = uniqData1
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Administrative division code
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    regionSum = DBLARR(n_elements(uniqData1))
    subRegionSum = DBLARR(n_elements(uniqData1))
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Count of cultivated land pixels in sub-regions'], title = 'Count of cultivated land pixels in sub-regions', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Administrative division code of subregion
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Subregion correction data
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Provincial regional correction data
            
            ;;Calculate the sum of correction data in each administrative division unit
            for m = 0LL, n_elements(uniqData1) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    subRegionSum[m] += total(tileData2[index1])
                    regionSum[m] += total(tileData3[index1])
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Analyze each sub-region
    regionFlag = BYTARR(n_elements(uniqData1))
    for i = 0LL, n_elements(uniqData1) - 1 do begin
        if subRegionSum[i] gt 0 then begin
            regionFlag[i] = 0
        endif else begin
            regionFlag[i] = 1
        endelse
    endfor    
        

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, fill in the blank value of sub
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Sub-area blank area fill'], title = 'Sub-area blank area fill', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Administrative division code of subregion
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Subregion correction data
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Provincial regional correction data
            
            resultData = tileData2
            
            ;;Calculate the sum of correction data in each administrative division unit
            for m = 0LL, n_elements(uniqData1) - 1 do begin     ;;First determine the Administrative division code
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    resultData[index1] = (tileData3[index1] * regionFlag[m]) + tileData2[index1]
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type2, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Subregion blank fill', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end

    return, 1

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Multi-level area correction data integration,
;;Compare the corrected cultivated land data area of the previous level area with the corrected cultivated land data area of the sub-area in each sub-area,
;;Integrate multi-level areas based on comparison results
pro proMultiRegionAdjustMerge, event

    ;;For the need to output process data
    defsysv, '!g_yes', 'Output process data'
    defsysv, '!g_no', 'Does not output process data'
    droplistSelection = [!g_yes, !g_no]

    ;;Create dialog
    base = widget_auto_base(title = 'Multi-level area correction data integration')
    
    inputFileName1 = widget_outf(base, prompt = 'Administrative division code of subregion', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Administrative division code of Region', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Cropland proportion data after sub-region correction', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Cropland proportion data after regional correction', uvalue = 'inputFileName4', $
        default = '', /auto)
        
    inputFileName5 = widget_outf(base, prompt = 'Pixel Area Data', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Cultivated Land Products Preliminary Synergy Code', uvalue = 'inputFileName6', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Cultivated Land Products Preliminary Synergy ratio', uvalue = 'inputFileName8', $
        default = '', /auto)        
    inputFileName7 = widget_outf(base, prompt = 'Statistics of cultivated land in sub-regions', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName9 = widget_outf(base, prompt = 'Regional cultivated land statistics', uvalue = 'inputFileName9', $
        default = '', /auto)

    pmenu = widget_pmenu(base, prompt = 'Whether to output process data', list = droplistSelection, uvalue='menu', /auto)        
    inputFileName10 = widget_outf(base, prompt = 'Integration of process output data', uvalue = 'inputFileName10', $
        default = '', /auto)

    outputFileName1 = widget_outf(base, prompt = 'Cultivated land integration data after multi-level correction (0,1)', uvalue = 'outputFileName1', $
        default = '', /auto)        
    outputFileName2 = widget_outf(base, prompt = 'Cultivated land integration code after multi-level correction', uvalue = 'outputFileName2', $
        default = '', /auto)        
    outputFileName3 = widget_outf(base, prompt = 'Cultivated land integration ratio after multi-level correction', uvalue = 'outputFileName3', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1   ;;Administrative division code of subregion
    inputFileName2 = baseclass.inputFileName2   ;;Cropland proportion data after sub-region correction
    inputFileName3 = baseclass.inputFileName3   ;;Administrative division code of Region
    inputFileName4 = baseclass.inputFileName4   ;;Cropland proportion data after regional correction
    inputFileName5 = baseclass.inputFileName5   ;;Pixel Area Data
    inputFileName6 = baseclass.inputFileName6   ;;Arable products Synergy Code
    inputFileName7 = baseClass.inputFileName7   ;;Statistics of cultivated land in sub-regions
    inputFileName8 = baseClass.inputFileName8   ;;Cultivated land product Synergy ratio data
    inputFileName9 = baseClass.inputFileName9   ;;Regional cultivated land statistics
    
    pmenu = baseclass.menu
    inputFileName10 = baseClass.inputFileName10  ;;Process output data
    
    outputFileName1 = baseclass.outputFileName1   ;;Multi-level corrected farmland data
    outputFileName2 = baseclass.outputFileName2   ;;Cultivated land product Synergy Code after multi-level correction
    outputFileName3 = baseclass.outputFileName3   ;;Multi-level corrected arable land proportion data
    
    ;;;;;Function of multi-level area correction data integration
    functionResult = funcMultiRegionAdjustMerge(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, inputFileName9, $
        droplistSelection[pmenu], inputFileName10, $
        outputFileName1, outputFileName2, outputFileName3)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Function of multi-level area correction data integration
function funcMultiRegionAdjustMerge, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, inputFileName9, $
        isOutputData, inputFileName10, $
        outputFileName1, outputFileName2, outputFileName3

    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName2
    
    ;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName3

    ;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1      ;;Administrative division code of subregion
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2      ;;Cropland proportion data after sub-region correction
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3      ;;Administrative division code of Region
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4      ;;Cropland proportion data after regional correction
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5      ;;Pixel Area Data
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6      ;;Arable products Synergy Code
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7      ;;Statistics of cultivated land in sub-regions
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    
    
    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8      ;;Cultivated land product Synergy ratio data
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9      ;;Regional cultivated land statistics
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    
    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1   ;;Administrative division code of subregion

    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2   ;;Cropland proportion data after sub-region correction
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3   ;;Administrative division code of Region
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4   ;;Cropland proportion data after regional correction
    
    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5   ;;Pixel Area Data
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6   ;;Arable products Synergy Code
    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7   ;;Statistics of cultivated land in sub-regions

    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8   ;;Cultivated land product Synergy ratio data
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9   ;;Regional cultivated land statistics
    
    ;;;;Take the minimum range of nine classified product data
    arrayCount = 9
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns7
    nsArray[7] = ns8
    nsArray[8] = ns9
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl7
    nlArray[7] = nl8
    nlArray[8] = nl9
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate over all pixels and calculate unique values
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Administrative division code of subregion and its unique value
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)    ;;Administrative division code of subregion
            
            ;Get unique value of administrative division code of subregion
            tileData1 = tileData1[sort(tileData1)]
            curUniqData1 = tileData1[uniq(tileData1)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1                           
               lastUniqData1 = uniqData1
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]               
               lastUniqData1 = uniqData1
            endelse
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get unique value of administrative division code of Region
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine

            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)    ;;Administrative division code of Region
            
            ;Get unique value of regional administrative division code
            tileData3 = tileData3[sort(tileData3)]
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData3 = curUniqData3                           
               lastUniqData3 = uniqData3
            endif else begin
               uniqData3 = [curUniqData3, lastUniqData3]               
               lastUniqData3 = uniqData3
            endelse
   
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain the Synergy Code of cultivated land products and its unique value
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine

            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)    ;;Arable products Synergy Code
            
            ;;;;Get the unique value of Synergy Code
            tileData6 = tileData6[sort(tileData6)]
            curUniqData6 = tileData6[uniq(tileData6)]
            
            if i eq 0 and j eq 0 then begin
               uniqData6 = curUniqData6                           
               lastUniqData6 = uniqData6
            endif else begin
               uniqData6 = [curUniqData6, lastUniqData6]               
               lastUniqData6 = uniqData6
            endelse
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain subregional arable land statistics and its unique value
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine

            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)    ;;Statistics of cultivated land in sub-regions
            
            ;;;;Get the unique value of sub-region cultivated land statistics
            tileData7 = tileData7[sort(tileData7)]
            curUniqData7 = tileData7[uniq(tileData7)]
            
            if i eq 0 and j eq 0 then begin
               uniqData7 = curUniqData7
               lastUniqData7 = uniqData7
            endif else begin
               uniqData7 = [curUniqData7, lastUniqData7]
               lastUniqData7 = uniqData7
            endelse
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain regional cultivated land statistical data and its unique value
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine

            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)    ;;Regional cultivated land statistics
            
            ;;;;Get the unique value of regional cultivated land statistics
            tileData9 = tileData9[sort(tileData9)]
            curUniqData9 = tileData9[uniq(tileData9)]
            
            if i eq 0 and j eq 0 then begin
               uniqData9 = curUniqData9
               lastUniqData9 = uniqData9
            endif else begin
               uniqData9 = [curUniqData9, lastUniqData9]
               lastUniqData9 = uniqData9
            endelse
            
            ;;;;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;;;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;Then calculate the unique value of the entire data from the set of unique values in the block
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Administrative division code of subregion unique value
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    uniqData3 = uniqData3[sort(uniqData3)]    ;;Unique value of administrative division code of Region
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    uniqData6 = uniqData6[sort(uniqData6)]    ;;Unique value of cultivated land product Synergy Code
    uniqData6 = uniqData6[uniq(uniqData6)]
    
    uniqData7 = uniqData7[sort(uniqData7)]    ;;Unique value of sub-region cultivated land statistics
    uniqData7 = uniqData7[uniq(uniqData7)]
    
    uniqData9 = uniqData9[sort(uniqData9)]    ;;Unique value of regional cultivated land statistics
    uniqData9 = uniqData9[uniq(uniqData9)]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels and calculate the corrected area of cultivated land in each sub-region
    regionAreaBasedSubRegion = DBLARR(n_elements(uniqData1))     ;;Calculate the area-corrected cultivated land area of each sub-area
    subRegionAreaBasedSubRegion = DBLARR(n_elements(uniqData1))  ;;Calculate the sub-region corrected cultivated land area of each sub-region

    ;;;;;;;;;;;;;;;;;;;;;;Statistics in each sub-region,Excluded because of an inconsistency between the Administrative division code and Statistics of administrative divisions
    subRegionStatOptions = DBLARR(n_elements(uniqData1), n_elements(uniqData7))
    
    ;;;;;;;;;;;;;;;;;;;;;;Statistics in each area,Excluded because of an inconsistency between the Administrative division code and Statistics of administrative divisions
    regionStatOptions = DBLARR(n_elements(uniqData3), n_elements(uniqData9))
    
    ;;;;;;;;;;;;;;;;;;;;;;One more thing to know: to which region does each subregion belong
    matchRegionCodeBasedSubRegionOptions = DBLARR(n_elements(uniqData1), n_elements(uniqData3))
    
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;Progress Bar
    ENVI_REPORT_INIT, ['Arable land area calculation of Subregion'], title = 'Arable land area calculation of Subregion', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Administrative division code of subregion
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Cropland proportion data after sub-region correction
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Administrative division code of Region
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Cropland proportion data after regional correction
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Pixel Area Data
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index5 = where(tileData5 lt 0.0, count5)
            if count5 gt 0 then begin
                tileData5[index5] = 0.0
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Statistics of cultivated land in sub-regions
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Regional cultivated land statistics
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)            
            
            ;;;;Calculate the area of cultivated land in each sub-regional unit
            for m = 0LL, n_elements(uniqData1) - 1 do begin     ;;First traverse each Administrative division code of subregion
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    subRegionAreaBasedSubRegion[m] += total(tileData2[index1] * tileData5[index1]) ;;Pixel area multiplied by sub-region cultivated land ratio data
                    regionAreaBasedSubRegion[m] += total(tileData4[index1] * tileData5[index1])    ;;Pixel area times area cultivated land ratio data
                endif
            endfor

            ;;Calculate the statistical value in each sub-administrative division unit
            for m = 0LL, n_elements(uniqData1) - 1 do begin
                index1 = where(tileData1 eq uniqData1[m], count1)
                ;;Get the unique value of the statistical data corresponding to the current sub-Administrative Division code
                if count1 gt 0 then begin
                    tempData7 = tileData7[index1]
                    for n = 0LL, n_elements(uniqData7) - 1 do begin
                        index2 = where(tempData7 eq uniqData7[n], count2)
                        if count2 gt 0 then begin
                            subRegionStatOptions[m, n] = subRegionStatOptions[m, n] + count2
                        endif
                    endfor
                endif
            endfor

            ;;Calculate the statistical value in each administrative division unit
            for m = 0LL, n_elements(uniqData3) - 1 do begin
                index1 = where(tileData3 eq uniqData3[m], count1)
                ;;Get the unique value of the statistical data corresponding to the current Administrative division code
                if count1 gt 0 then begin
                    tempData9 = tileData9[index1]
                    for n = 0LL, n_elements(uniqData9) - 1 do begin
                        index2 = where(tempData9 eq uniqData9[n], count2)
                        if count2 gt 0 then begin
                            regionStatOptions[m, n] = regionStatOptions[m, n] + count2
                        endif
                    endfor
                endif
            endfor
            
            ;;Calculate to which region each sub-region belongs
            for m = 0LL, n_elements(uniqData1) - 1 do begin
                index1 = where(tileData1 eq uniqData1[m], count1)
                ;;Get the region code corresponding to the current subregion
                if count1 gt 0 then begin
                    tempData3 = tileData3[index1]
                    for n = 0LL, n_elements(uniqData3) - 1 do begin
                        index2 = where(tempData3 eq uniqData3[n], count2)
                        if count2 gt 0 then begin
                            matchRegionCodeBasedSubRegionOptions[m, n] = matchRegionCodeBasedSubRegionOptions[m, n] + count2
                        endif
                    endfor
                endif
            endfor
          
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the statistical value in the area, the statistical value in the sub-area
    ;;Determine the statistics in each subregion
    subRegionStatData = DBLARR(n_elements(uniqData1))
    
    for m = 0LL, n_elements(uniqData1) - 1 do begin
        tempData = subRegionStatOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            subRegionStatData[m] = uniqData7[index[0]]
        endif
    endfor
    
    ;;Determine the statistics in each area
    regionStatData = DBLARR(n_elements(uniqData3))
    
    for m = 0LL, n_elements(uniqData3) - 1 do begin
        tempData = regionStatOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            regionStatData[m] = uniqData9[index[0]]
        endif
    endfor
    
    ;;Determine which region code each subregion belongs to
    matchRegionCodeBasedSubRegion = DBLARR(n_elements(uniqData1))
    
    for m = 0LL, n_elements(uniqData1) - 1 do begin
        tempData = matchRegionCodeBasedSubRegionOptions[m, *]
        maxValue = max(tempData, min = minValue)
        
        index = where(tempData eq maxValue, count)
        if count gt 0 then begin
            matchRegionCodeBasedSubRegion[m] = uniqData3[index[0]]
        endif
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Analyze each sub-region and calculate new regional statistics
    ;;Signs of the relationship between cultivated land area and sub-region
    ;;--0--represents that the area of the area is larger than the area of the subarea
    ;;--1--represents that the area of the area is less than or equal to the area of the subarea
    flagSubAndRegion = BYTARR(n_elements(uniqData1))   ;;Calculate the flag of each sub-region

    for i = 0LL, n_elements(uniqData1) - 1 do begin   ;;Traverse each Administrative division code of subregion
        if regionAreaBasedSubRegion[i] gt subRegionAreaBasedSubRegion[i] then begin   ;;Area area is greater than sub-area area (to be recalibrated)
            flagSubAndRegion[i] = 0B
        endif else begin                                                              ;;Area area is less than or equal to sub-area area (need to be subtracted from area cultivated area)
            flagSubAndRegion[i] = 1B
        endelse
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the new statistical standard value in each area according to the area comparison results of the sub-areas
    statData = DBLARR(n_elements(uniqData3))
    
    ;;;Traverse each area (summing the area of corrected cultivated land calculated according to the sub-area range,Sub-region corrected arable land area of the sub-region less than or equal to the sub-region area)
    regionAllGreaterThanSubRegionFlag = BYTARR(n_elements(uniqData3))   ;;See if the area is larger than the sub-area
    
    for i = 0LL, n_elements(uniqData3) - 1 do begin
        statData[i] = regionStatData[i]     ;;Use the area's cultivated land statistics to subtract the value of those areas with large sub-areas
        regionFlag = 0
        
        for j = 0LL, n_elements(uniqData1) - 1 do begin     ;;;;Traverse each subregion
            if matchRegionCodeBasedSubRegion[j] eq uniqData3[i] then begin    ;;;;;Make sure the current subregion belongs to this region
                if flagSubAndRegion[j] eq 1B then begin
                    statData[i] = statData[i] - subRegionAreaBasedSubRegion[j]
                    regionFlag = regionFlag + 1
                endif
            endif
        endfor
        
        ;;If the area of cultivated land in the area is larger than that of the sub-area,The statistical standard value is set to 0.0
        if regionFlag eq 0 then begin
            regionAllGreaterThanSubRegionFlag[i] = 1B
        endif
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;According to the new statistical standard to correct the area of the pixels larger than the area of the sub-area
    synergyData = DBLARR(n_elements(uniqData6), n_elements(uniqData3))    ;;Cultivated land area value corresponding to each Preliminary Synergy Code in each area(Remove the larger area of the sub-region)
    
    synergyDataBaseRegion = DBLARR(n_elements(uniqData6), n_elements(uniqData3))    ;;Cultivated land area value corresponding to each Preliminary Synergy Code in each area
    
    synergyDataBaseSubRegion = DBLARR(n_elements(uniqData6), n_elements(uniqData1)) ;;Cultivated land area value corresponding to each Preliminary Synergy Code in each sub-region
    
    ;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Area recalibration'], title = 'Area recalibration', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Administrative division code of subregion
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain the corrected ratio data of the cultivated land in the sub-region
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get regional administrative division code
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain the area corrected farmland proportion data
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Pixel Area Data
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index5 = where(tileData5 lt 0.0, count5)
            if count5 gt 0 then begin
                tileData5[index5] = 0.0
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;Get arable products Synergy Code
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine

            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get cultivated land product Synergy ratio data
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine

            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
          
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the area of cultivated land corresponding to Synergy Code of each cultivated land product in each area
            for m = 0LL, n_elements(uniqData3) - 1 do begin     ;;First determine the area Administrative division code
                index1 = where(tileData3 eq uniqData3[m], count1)
                if count1 gt 0 then begin
                    tempData1 = tileData1[index1]   ;;Administrative division code of subregion
                    tempData5 = tileData5[index1]   ;;Pixel area
                    tempData6 = tileData6[index1]   ;;Arable products Synergy Code
                    tempData8 = tileData8[index1]   ;;Cultivated land product Synergy ratio data
                    
                    for n = 0LL, n_elements(uniqData6) - 1 do begin     ;;Determine the Synergy Code of cultivated land products
                        index2 = where(tempData6 eq uniqData6[n], count2)
                        if count2 gt 0 then begin
                            tempData11 = tempData1[index2]    ;;Administrative division code of subregion
                            tempData55 = tempData5[index2]    ;;Pixel area
                            tempData88 = tempData8[index2]    ;;Cultivated land product Synergy ratio data

                            for mm = 0LL, n_elements(uniqData1) - 1 do begin   ;;Determine whether the sub-region participates in recalibration
                                index3 = where(tempData11 eq uniqData1[mm], count3)
                                if count3 gt 0 AND flagSubAndRegion[mm] eq 0B then begin
                                    synergyData[n, m] = synergyData[n, m] + total(tempData55[index3] * tempData88[index3])
                                endif
                            endfor
                        endif
                    endfor
                endif
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the cultivated land area of each Preliminary Synergy Code in each area
            for m = 0LL, n_elements(uniqData3) - 1 do begin   ;;Administrative division code of Region 
                index1 = where(tileData3 eq uniqData3[m], count1)
                if count1 gt 0 then begin
                    tempData5 = tileData5[index1]   ;;Pixel area
                    tempData6 = tileData6[index1]   ;;Preliminary Synergy Code
                    tempData8 = tileData8[index1]   ;;Preliminary Synergy ratio

                    for n = 0LL, n_elements(uniqData6) - 1 do begin     ;;Preliminary Synergy Code
                        index2 = where(tempData6 eq uniqData6[n], count2)
                        if count2 gt 0 then begin
                            ;;Arable land area calculation
                            synergyDataBaseRegion[n, m] = synergyDataBaseRegion[n, m] + total(tempData5[index2] * tempData8[index2])
                        endif
                    endfor
                endif
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the cultivated land area of each Preliminary Synergy Code in each sub-region
            for m = 0LL, n_elements(uniqData1) - 1 do begin   ;;Administrative division code of subregion 
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    tempData5 = tileData5[index1]   ;;Pixel area
                    tempData6 = tileData6[index1]   ;;Preliminary Synergy Code
                    tempData8 = tileData8[index1]   ;;Preliminary Synergy ratio

                    for n = 0LL, n_elements(uniqData6) - 1 do begin     ;;Preliminary Synergy Code
                        index2 = where(tempData6 eq uniqData6[n], count2)
                        if count2 gt 0 then begin
                            ;;Arable land area calculation
                            synergyDataBaseSubRegion[n, m] = synergyDataBaseSubRegion[n, m] + total(tempData5[index2] * tempData8[index2])
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Modify the original data according to Synergy data area and statistical data area
    iterateSumArea = DBLARR(n_elements(uniqData6), n_elements(uniqData3))
    
    ;;Accumulate the area of every possible situation in Calculate Synergy Data
    for i = 0LL, n_elements(uniqData6) - 1 do begin
        for j = 0LL, i do begin
            iterateSumArea[i, *] = iterateSumArea[i, *] + synergyData[j, *]
        endfor
    endfor
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Relative error of Calculate Synergy Data area and ,(If the statistical data of the current area is 0, the correction data value is also set to 0)
    areaDifference = DBLARR(n_elements(uniqData6), n_elements(uniqData3))
    areaDifferenceFlag = DBLARR(n_elements(uniqData6), n_elements(uniqData3))
    areaStat = DBLARR(n_elements(uniqData6), n_elements(uniqData3))
    for i = 0LL, n_elements(uniqData6) - 1 do begin
        areaDifference[i, *] = abs(iterateSumArea[i, *] - statData[*])
        areaDifferenceFlag[i, *] = iterateSumArea[i, *] - statData[*]
        areaStat[i, *] = statData[*]
    endfor
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Determine the effective area of Synergy data'], title = 'Determine the effective area of Synergy data', base = base
    ENVI_REPORT_INC, base, n_elements(uniqData2)
    
    ;;Determine the serial number corresponding to the smallest relative error
    flagData = BYTARR(n_elements(uniqData6), n_elements(uniqData3))
    
    ;;Record which Primary Synergy Code to keep in each area
    flagDataOutput = BYTARR(n_elements(uniqData3))

    for i = 0LL, n_elements(uniqData3) - 1 do begin       ;;Regional code
        flag = 1B
        flagIndex = 1B
        
        tempData = areaDifference[*, i]
        minValue = min(tempData, max = maxValue)
        minValueIndex = where(tempData eq minValue, count)
        
        if count gt 0 then begin
            for j = 0LL, n_elements(uniqData6) - 1 do begin     ;;Preliminary Synergy Code
                if areaStat[j, i] eq 0.0 then begin
                    flag = 0B
                endif
            
                flagData[j, i] = flag
                
                ;;Record which Primary Synergy Code is kept in each area,Achieve new statistical standards
                flagDataOutput[i] = flagDataOutput[i] + flag
                
                if flagIndex eq 0B then begin
                    flag = 0B
                    flagIndex = 1B
                endif
    
                if j eq minValueIndex[count - 1] and iterateSumArea[j, i] gt 0 then begin
                    flag = 0B
                endif
                 
                if j eq minValueIndex[count - 1] and iterateSumArea[j, i] le 0 then begin
                    flagIndex = 0B
                endif
            endfor
        endif
        
        ;Progress bar, showing calculation progress
        ENVI_REPORT_STAT, base, i, n_elements(uniqData2)
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Finally, the statistical data matching results are used to modify Synergy data
    ;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    OPENW, unit2, outputFileName2, /get_lun
    
    OPENW, unit3, outputFileName3, /get_lun   
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels and perform Synergy data modification
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Multilevel Synergy data modification'], title = 'Multilevel Synergy data modification', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Administrative division code of subregion
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain the corrected ratio data of the cultivated land in the sub-region
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get regional administrative division code
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain the area corrected farmland proportion data
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Pixel Area Data
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            ;;If Pixel area data is less than 0,set data value 0
            index5 = where(tileData5 lt 0.0, count5)
            if count5 gt 0 then begin
                tileData5[index5] = 0.0
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get arable products Synergy Code
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine

            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get cultivated land product Synergy ratio data
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine

            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            resultData = BYTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            resultData[*, *] = 0B
            
            ;;;;;;;;;;;Convert the sub-region corrected cultivated land ratio data to 0,1 values
            tileDataCopy2 = BYTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tileDataCopy2[*, *] = 0B
            
            index1 = where(tileData2 gt 0.0, count1)
            if count1 gt 0 then begin
                tileDataCopy2[index1] = 1B      ;;Sub-region corrected data (0,1)
            endif
            
            ;;;;;;;;;;;Convert area corrected cultivated land ratio data to 0,1 values
            tileDataCopy4 = BYTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tileDataCopy4[*, *] = 0B
            
            index1 = where(tileData4 gt 0.0, count1)
            if count1 gt 0 then begin
                tileDataCopy4[index1] = 1B      ;;Data after area correction (0,1)
            endif
            
            ;;Modify the current data block
            for m = 0LL, n_elements(uniqData6) - 1 do begin
                index1 = where(tileData6 eq uniqData6[m], count1)
                if count1 gt 0 then begin
                    for n = 0LL, n_elements(index1) - 1 do begin
                        tempValue = tileData3[index1[n]]
                        for mm = 0LL, n_elements(uniqData3) - 1 do begin
                            if tempValue eq uniqData3[mm] then begin
                                resultData[index1[n]] = flagData[m, mm]
                            endif
                        endfor
                    endfor
                endif
            endfor

            ;;For areas where the area is smaller than the area of the sub-area,Subregion correction data instead of correction value
            for m = 0LL, n_elements(uniqData1) - 1 do begin
                index1 = where(tileData1 eq uniqData1[m], count1)
                if count1 gt 0 then begin
                    if flagSubAndRegion[m] eq 1B then begin
                        resultData[index1] = tileDataCopy2[index1]
                    endif
                endif
            endfor
            
            ;;For areas where the area is larger than the sub-area,Replace calibration data with area calibration data
            for m = 0LL, n_elements(uniqData3) - 1 do begin
                index3 = where(tileData3 eq uniqData3[m], count3)
                if count3 gt 0 then begin
                    if regionAllGreaterThanSubRegionFlag[m] eq 1B then begin
                        resultData[index3] = tileDataCopy4[index3]
                    endif
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData
            
            resultData2 = resultData * tileData6
            writeu, unit2, resultData2
            
;            ;Calculate the arable land area of each administrative division unit after correction
;            for m = 0LL, n_elements(uniqData3) - 1 do begin     ;;First determine the Administrative division code
;                index1 = where(tileData3 eq uniqData3[m], count1)
;                if count1 gt 0 then begin
;                    tempData1 = resultData[index1]    ;;Calibration data
;                    tempData5 = tileData5[index1]     ;;Pixel area
;                    tempData8 = tileData8[index1]     ;;Arable land ratio
;                    for n = 0LL, n_elements(uniqData4) - 1 do begin
;                        index2 = where(tempData1 eq uniqData4[n], count2)
;                        if count2 gt 0 then begin
;                            synergyData2[n, m] = synergyData2[n, m] + total(tempData5[index2] * tempData8[index2])
;                        endif
;                    endfor
;                endif
;            endfor
            
            ;Calculate the corrected ratio data
            resultData3 = resultData * tileData8
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit3, resultData3
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Free memory
    FREE_LUN, unit1
    FREE_LUN, unit2
    FREE_LUN, unit3    
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Export intermediate data to an Excel file
    case isOutputData of
        !g_yes: begin     ;;;;;;;;;;;;;;;;;;;;;;Output process data
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Subregion related data
            basicColumnCount = 6
            columnNames = STRARR(basicColumnCount + n_elements(uniqData6))
            
            columnNames[0] = "Administrative division code of subregion"
            columnNames[1] = "Statistics of cultivated land in sub-regions"
            columnNames[2] = "Sub-regional area corrected for cultivated land"
            columnNames[3] = "Sub-region corrected cultivated land area"
            columnNames[4] = "Area code to which the subarea belongs"
            columnNames[5] = "Relationship between cultivated land area and sub-region"
            
            startIndex = basicColumnCount
            endIndex = startIndex + n_elements(uniqData6) - 1
            for i = startIndex, endIndex do begin     ;;Preliminary Synergy Code
                columnNames[i] = string(uniqData6[i - startIndex]) + "SynergyCode" 
            endfor
            
            tableNS = n_elements(columnNames)
            
            tableData = DBLARR(tableNS, n_elements(uniqData1))
            tableData[0, *] = uniqData1[*]
            tableData[1, *] = subRegionStatData[*]
            tableData[2, *] = regionAreaBasedSubRegion[*]
            tableData[3, *] = subRegionAreaBasedSubRegion[*]
            tableData[4, *] = matchRegionCodeBasedSubRegion[*]
            tableData[5, *] = flagSubAndRegion[*]
            
            ;;Output the cultivated land area corresponding to each Preliminary Synergy Code in the sub-region
            for i = startIndex, endIndex do begin
                tableData[i, *] = synergyDataBaseSubRegion[i - startIndex, *]
            endfor
            
            tableData = transpose(tableData)
            
            tableName = "SubRegionData"
            
            ExportDataToExcel2, inputFileName10, tableName, tableData, columnNames, $
                tableNS, n_elements(uniqData1)
                
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Regional data
            basicColumnCount = 5
            columnNames = STRARR(basicColumnCount + n_elements(uniqData6) + n_elements(uniqData6))
            
            columnNames[0] = "Administrative division code of Region"
            columnNames[1] = "Regional cultivated land statistics"
            columnNames[2] = "New statistical standard after removing the corrected area of a larger subregion"
            columnNames[3] = "Are the area areas larger than the sub-area area(not recorrection)"
            columnNames[4] = "Regional Reserve Synergy Code"
            
            startIndex = basicColumnCount
            endIndex = basicColumnCount + n_elements(uniqData6) - 1
            for i = startIndex, endIndex do begin     ;;Preliminary Synergy Code
                columnNames[i] = string(uniqData6[i - startIndex]) + "SynergyCode"
            endfor
            
            startIndex = startIndex + n_elements(uniqData6)
            endIndex = endIndex + n_elements(uniqData6)
            for i = startIndex, endIndex do begin
                columnNames[i] = string(uniqData6[i - startIndex]) + "SynergyCodeIntegrated"
            endfor
            
            tableNS = n_elements(columnNames)
            
            tableData = DBLARR(tableNS, n_elements(uniqData3))
            tableData[0, *] = uniqData3[*]
            tableData[1, *] = regionStatData[*]
            tableData[2, *] = statData[*]
            tableData[3, *] = regionAllGreaterThanSubRegionFlag[*]
            tableData[4, *] = flagDataOutput[*]
            
            ;;Output the area of cultivated land corresponding to each preliminary Synergy Code in the area
            startIndex = basicColumnCount
            endIndex = startIndex + n_elements(uniqData6) - 1
            for i = startIndex, endIndex do begin
                tableData[i, *] = synergyDataBaseRegion[i - startIndex, *]
            endfor
            
            startIndex = endIndex + 1
            endIndex = startIndex + n_elements(uniqData6) - 1
            for i = startIndex, endIndex do begin
                tableData[i, *] = synergyData[i - startIndex, *]
            endfor
            
            tableData = transpose(tableData)
            
            tableName = "regionData"
            
            ExportDataToExcel2, inputFileName10, tableName, tableData, columnNames, $
                tableNS, n_elements(uniqData3)
        end
        ;;;;;;;;;;;;;;;;;;;;;;Does not output process data
        !g_no: begin

        end            
    endcase
     
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Multi-level area correction integrated data', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type6, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Multi-level area correction integration of Cultivated land synergy code', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName3, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type8, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Integrating farmland proportion data after multi-level regional correction', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName2, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName3, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end    
    
;    ;Output the area of each Arable land combination of each administrative division
;    synergyData2 = transpose(synergyData2)
;    resultDataSize = size(synergyData2)
;    
;    tableIndex = 0
;    uniqData4 = ['Not cultivated land', 'Arable land']
;    ExportDataToExcel, inputFileName6, synergyData2, uniqData4, uniqData2, $
;        n_elements(uniqData4), n_elements(uniqData2)

    return, 1

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Sub-region obfuscation accuracy calculation, According to the sample to calculate the confusion matrix of each sub-region, Adjusted confusion matrix
;;Sample data1 represents Arable land，2 represents Not cultivated land
pro proSubRegionConfusionMaxtrix, event

    base = widget_auto_base(title = 'Sub-region obfuscation accuracy calculation')
    inputFileName1 = widget_outf(base, prompt = 'Cultivated land data products', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Subregional code', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Sample data', uvalue = 'inputFileName3', $
        default = '', /auto)

    outputFileName1 = widget_outf(base, prompt = 'Confusion precision matrix Excel (please create in advance)', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Accuracy output result', uvalue = 'outputFileName2', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call the function of Sub-region obfuscation accuracy calculation
    functionResult = funcSubRegionConfusionMaxtrix(inputFileName1, inputFileName2, $
        inputFileName3, outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION) 

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Sub-region obfuscation accuracy calculation
function funcSubRegionConfusionMaxtrix, inputFileName1, inputFileName2, $
        inputFileName3, outputFileName1, outputFileName2

    ;;;;Get input data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1      ;;Arable land product data
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2      ;;Subregional code data
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3      ;;Sample data
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ;;Take the minimum range of four classified product data
    arrayCount = 3
    nsArray = LONARR(arrayCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    
    nsStd = min(nsArray, max = max)
    
    nlArray = LONARR(arrayCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    
    nlStd = min(nlArray, max = max)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate over all pixels and perform Unique value calculation
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Unique value calculation'], title = 'Unique value calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)    ;;Cultivated land data products
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)    ;;Subregional code
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)    ;;Sample data            
            
            ;Get the current unique value
            tileData1 = tileData1[sort(tileData1)]
            curUniqData1 = tileData1[uniq(tileData1)]
            
            tileData2 = tileData2[sort(tileData2)]
            curUniqData2 = tileData2[uniq(tileData2)]
            
            tileData3 = tileData3[sort(tileData3)]
            curUniqData3 = tileData3[uniq(tileData3)]
            
            if i eq 0 and j eq 0 then begin
               uniqData1 = curUniqData1
               uniqData2 = curUniqData2
               uniqData3 = curUniqData3
                           
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endif else begin
               uniqData1 = [curUniqData1, lastUniqData1]
               uniqData2 = [curUniqData2, lastUniqData2]
               uniqData3 = [curUniqData3, lastUniqData3]
               
               lastUniqData1 = uniqData1
               lastUniqData2 = uniqData2
               lastUniqData3 = uniqData3
            endelse
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Get the unique values of all arrays  
    uniqData1 = uniqData1[sort(uniqData1)]    ;;Unique value of cultivated land data products,0,1 or other value,Cultivated land data products are ratio data
    uniqData1 = uniqData1[uniq(uniqData1)]
    
    ;;;;;;;;;;;;;;;Arable land products must be determined in advance,0 means not cultivated land and 1 means arable land
    uniqData1 = [0, 1]
    
    uniqData2 = uniqData2[sort(uniqData2)]    ;;Unique value of subregional code
    uniqData2 = uniqData2[uniq(uniqData2)]
    
    uniqData3 = uniqData3[sort(uniqData3)]    ;;Sample data unique value, 1,2, other
    uniqData3 = uniqData3[uniq(uniqData3)]
    
    ;;;;;;;;;;;;;;;The value of the sample must be determined in advance,1 means arable land and 2 means not cultivated land
    uniqData3 = [1, 2]
    
    ;;Create an output form,The first dimension is the sub-regional code,The second dimension is the cultivated land product,The third dimension is sample data
    columnCount = 5
    confusionData = DBLARR(n_elements(uniqData2), columnCount)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels and count the errors and omissions
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Sub-region classification accuracy statistics'], title = 'Sub-region classification accuracy statistics', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Arable land product data
            
            ;Cultivated land data products are proportional data,Need to process into 0, 1 data,Assign all values greater than 0 in Arable land data to 1
            index1 = where(tileData1 gt 0, count1)
            if count1 gt 0 then begin
                tileData1[index1] = 1
            endif
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Subregional code data
            
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)  ;;Sample data
            
            ;;Calculate the classification accuracy of Arable land products within each administrative division
            for m = 0LL, n_elements(uniqData2) - 1 do begin     ;;First determine the sub-regional code
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    tempData1 = tileData1[index1]   ;;Arable land data
                    tempData3 = tileData3[index1]   ;;Sample data
                    
                    for n = 0LL, n_elements(uniqData3) - 1 do begin   ;;Traverse the unique values of the sample data
                        index2 = where(tempData3 eq uniqData3[n], count2)
                        if count2 gt 0 then begin
                            tempData6 = tempData1[index2]
                            
                            for mn = 0LL, n_elements(uniqData1) - 1 do begin    ;;Traverse the unique value of Arable land data
                                index3 = where(tempData6 eq uniqData1[mn], count3)
                                if count3 gt 0 then begin
                                    confusionData[m, n*2+mn] = confusionData[m, n*2+mn] + count3
                                endif
                            endfor
                        endif
                    endfor
                endif
            endfor
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;Use the confusion matrix to calculate the overall accuracy,The number of correctly classified pixels divided by the total number of pixels
    for i = 0LL, n_elements(uniqData2) - 1 do begin
        totalSampleCount = confusionData[i, 0] + confusionData[i, 1] + confusionData[i, 2] + confusionData[i, 3]
        if totalSampleCount eq 0 then begin
            confusionData[i, 4] = 0
        endif else begin
            confusionData[i, 4] = (confusionData[i, 1] + confusionData[i, 2]) / totalSampleCount
        endelse
    endfor
    

    ;Output the corrected serial number value, Not cultivated land corresponding to the 10-Arable land sample, Arable land corresponding to 11-Arable land sample, Not cultivated land corresponding to the 20-Not cultivated land sample, Arable land corresponding to 21-Not cultivated land
    columnIndex = ['Arable land sample to Not cultivated land', 'Arable land sample to Arable land', 'Not cultivated land sample to Not cultivated land', 'Not cultivated land sample to Arable land', 'Overall accuracy']

    ExportDataToExcel, outputFileName1, confusionData, columnIndex, uniqData2, $
        n_elements(columnIndex), n_elements(uniqData2)

    ;;Output the overall accuracy of each administrative division
    ;;Create a new file for output
    OPENW, unit1, outputFileName2, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Output the overall accuracy calculated for each administrative division
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;Progress Bar
    ENVI_REPORT_INIT, ['Overall accuracy output'], title = 'Overall accuracy output', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;Get the data of the current block
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)  ;;Arable land product data
            
            ;Create a new data result
            resultData = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)  ;;Administrative division code
            
            ;;Fill in the value of overall accuracy for each administrative division
            for m = 0LL, n_elements(uniqData2) - 1 do begin
                index1 = where(tileData2 eq uniqData2[m], count1)
                if count1 gt 0 then begin
                    resultData[index1] = confusionData[m, 4]
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData
                        
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 5, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Overall accuracy of administrative divisions', $
    map_info = map_info1, $
    /write, /open    
    
    return, 1
     
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Arable land preliminary fusion (sample accuracy)-three sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithThreeByAccuracy, event

    base = widget_auto_base(title = 'Arable land preliminary fusion (sample accuracy)-three sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Classification accuracy 01', uvalue = 'inputFileName2', $
        default = '', /auto)

    inputFileName3 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Classification accuracy 02', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName5 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Classification accuracy 03', uvalue = 'inputFileName6', $
        default = '', /auto)

        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call the function of Arable land preliminary fusion (sample accuracy)-three sets of products
    functionResult = funcCalCroplandSynergyWithThreeByAccuracy(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Arable land preliminary fusion (sample accuracy)-three sets of products
function funcCalCroplandSynergyWithThreeByAccuracy, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, $
    inputFileName5, inputFileName6, $
    outputFileName1, outputFileName2
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read three sets of Arable land product data and classification accuracy data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;The first set of Arable land products
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;The first set of Arable land product accuracy
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;The second set of Arable land products
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;The second set of Arable land product accuracy
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;The third set of Arable land products
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6    ;;The third set of Arable land product accuracy
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 6
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1, 1, 1], $
                        [1, 1, 0], $
                        [1, 0, 1], $
                        [0, 1, 1], $
                        [1, 0, 0], $
                        [0, 1, 0], $
                        [0, 0, 1], $
                        [0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    
    OPENW, unit2, outputFileName2, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land synergy calculation'], title = 'Cultivated land synergy calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Combine Arable land data and Arable land precision data into two large arrays
            productCount = 3
            cropData = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            cropAccuracy = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData2 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData3 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain Arable land product data and its accuracy data
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Arable land product data01
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            tileDataCopy1 = tileData1
            index = where(tileDataCopy1 gt 0, count)
            if count gt 0 then begin
                tileDataCopy1[index] = 1
            endif
            
            cropData[0, *, *] = tileDataCopy1[*, *]
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain accuracy data 01 of Arable land products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            cropAccuracy[0, *, *] = tileData2[*, *]

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Arable land product data02
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            tileDataCopy3 = tileData3
            index = where(tileDataCopy3 gt 0, count)
            if count gt 0 then begin
                tileDataCopy3[index] = 1
            endif
            
            cropData[1, *, *] = tileDataCopy3[*, *]

            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain accuracy data of Arable land products 02            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            cropAccuracy[1, *, *] = tileData4[*, *]
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get Arable land product data03
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            tileDataCopy5 = tileData5
            index = where(tileDataCopy5 gt 0, count)
            if count gt 0 then begin
                tileDataCopy5[index] = 1
            endif
            
            cropData[2, *, *] = tileDataCopy5[*, *]
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain accuracy data of Arable land products 03
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            cropAccuracy[2, *, *] = tileData6[*, *]
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Sort the classification data according to the accuracy of each administrative division
            for m = 0LL, productCount - 1 do begin
                for n = 0LL, productCount - m - 2 do begin
                    tempData1[*, *] = cropAccuracy[n + 1, *, *] - cropAccuracy[n, *, *]
                    
                    index1 = where(tempData1 gt 0, count1)
                    if count1 gt 0 then begin
                        tempData2[index1] = cropData[n + 1, index1]
                        cropData[n + 1, index1] = cropData[n, index1]
                        cropData[n, index1] = tempData2[index1]
                    endif
                endfor
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value      
            resultData1 = INTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = tileData1
            
            for m = 0LL, synergyRankLine - 1 do begin
                tempData1 = abs(cropData[0, *, *] - synergyRankArray[0, m]) + abs(cropData[1, *, *] - synergyRankArray[1, m]) + $
                            abs(cropData[2, *, *] - synergyRankArray[2, m])
                index1 = where(tempData1 eq 0, count1)
                if count1 gt 0 then begin
                    resultData1[index1] = m + 1
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1 + tileData3 + $
                        tileData5
                        
            tempDataCopy2 = tileDataCopy1 + tileDataCopy3 + $
                            tileDataCopy5
            
            resultData2 = tempDataCopy2
            
            index2 = where(tempDataCopy2 ne 0, count2)
            if count2 gt 0 then begin
                resultData2[index2] = tempData2[index2] / tempDataCopy2[index2]
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Free memory
    FREE_LUN, unit2
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 2, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Integration result', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy ratio', $
    map_info = map_info1, $
    /write, /open 
    
    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Arable land preliminary fusion (sample accuracy)-four sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithFourByAccuracy, event

    base = widget_auto_base(title = 'Arable land preliminary fusion (sample accuracy)-four sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Classification accuracy 01', uvalue = 'inputFileName2', $
        default = '', /auto)

    inputFileName3 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Classification accuracy 02', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName5 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Classification accuracy 03', uvalue = 'inputFileName6', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Classification accuracy 04', uvalue = 'inputFileName8', $
        default = '', /auto)

        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call the function of Arable land preliminary fusion (sample accuracy)-four sets of products
    functionResult = funcCalCroplandSynergyWithFourByAccuracy(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Arable land preliminary fusion (sample accuracy)-four sets of products
function funcCalCroplandSynergyWithFourByAccuracy, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, $
    inputFileName5, inputFileName6, $
    inputFileName7, inputFileName8, $
    outputFileName1, outputFileName2
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read four sets of Arable land product data and classification accuracy data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;The first set of Arable land products
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;The first set of Arable land product accuracy
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;The second set of Arable land products
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;The second set of Arable land product accuracy
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;The third set of Arable land products
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6    ;;The third set of Arable land product accuracy
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;The fourth set of Arable land products
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;The fourth set of Arable land product accuracy
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6
    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7

    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8

    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 8
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns7
    nsArray[7] = ns8
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl7
    nlArray[7] = nl8
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1, 1, 1, 1], $
                        [1, 1, 1, 0], $
                        [1, 1, 0, 1], $
                        [1, 0, 1, 1], $
                        [0, 1, 1, 1], $
                        [1, 1, 0, 0], $
                        [1, 0, 1, 0], $
                        [0, 1, 1, 0], $
                        [1, 0, 0, 1], $
                        [0, 1, 0, 1], $
                        [0, 0, 1, 1], $
                        [1, 0, 0, 0], $
                        [0, 1, 0, 0], $
                        [0, 0, 1, 0], $
                        [0, 0, 0, 1], $
                        [0, 0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    
    OPENW, unit2, outputFileName2, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land synergy calculation'], title = 'Cultivated land synergy calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Combine Arable land data and Arable land precision data into two large arrays
            productCount = 4
            cropData = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            cropAccuracy = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData2 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData3 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain Arable land product data and its accuracy data
            ;;Get Arable land product data01
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            tileDataCopy1 = tileData1
            index = where(tileDataCopy1 gt 0, count)
            if count gt 0 then begin
                tileDataCopy1[index] = 1
            endif
            
            cropData[0, *, *] = tileDataCopy1[*, *]
            
            ;;Obtain accuracy data 01 of Arable land products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            cropAccuracy[0, *, *] = tileData2[*, *]

            ;;Get Arable land product data02
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            tileDataCopy3 = tileData3
            index = where(tileDataCopy3 gt 0, count)
            if count gt 0 then begin
                tileDataCopy3[index] = 1
            endif
            
            cropData[1, *, *] = tileDataCopy3[*, *]

            ;;Obtain accuracy data of Arable land products 02            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            cropAccuracy[1, *, *] = tileData4[*, *]
            
            ;;Get Arable land product data03
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            tileDataCopy5 = tileData5
            index = where(tileDataCopy5 gt 0, count)
            if count gt 0 then begin
                tileDataCopy5[index] = 1
            endif
            
            cropData[2, *, *] = tileDataCopy5[*, *]
            
            ;;Obtain accuracy data of Arable land products 03
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            cropAccuracy[2, *, *] = tileData6[*, *]
            
            ;;Get Arable land product data04
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            tileDataCopy7 = tileData7
            index = where(tileDataCopy7 gt 0, count)
            if count gt 0 then begin
                tileDataCopy7[index] = 1
            endif
            
            cropData[3, *, *] = tileDataCopy7[*, *]
            
            ;;Obtaining accuracy data of Arable land products 04
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            cropAccuracy[3, *, *] = tileData8[*, *]
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Sort the classification data according to the accuracy of each administrative division
            for m = 0LL, productCount - 1 do begin
                for n = 0LL, productCount - m - 2 do begin
                    tempData1[*, *] = cropAccuracy[n + 1, *, *] - cropAccuracy[n, *, *]
                    
                    index1 = where(tempData1 gt 0, count1)
                    if count1 gt 0 then begin
                        tempData2[index1] = cropData[n + 1, index1]
                        cropData[n + 1, index1] = cropData[n, index1]
                        cropData[n, index1] = tempData2[index1]
                    endif
                endfor
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value      
            resultData1 = INTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = tileData1
            
            for m = 0LL, synergyRankLine - 1 do begin
                tempData1 = abs(cropData[0, *, *] - synergyRankArray[0, m]) + abs(cropData[1, *, *] - synergyRankArray[1, m]) + $
                            abs(cropData[2, *, *] - synergyRankArray[2, m]) + abs(cropData[3, *, *] - synergyRankArray[3, m])
                            
                index1 = where(tempData1 eq 0, count1)
                if count1 gt 0 then begin
                    resultData1[index1] = m + 1
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1 + tileData3 + $
                        tileData5 + tileData7
                        
            tempDataCopy2 = tileDataCopy1 + tileDataCopy3 + $
                            tileDataCopy5 + tileDataCopy7
            
            resultData2 = tempDataCopy2
            
            index2 = where(tempDataCopy2 ne 0, count2)
            if count2 gt 0 then begin
                resultData2[index2] = tempData2[index2] / tempDataCopy2[index2]
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Free memory
    FREE_LUN, unit2
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 2, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Integration result', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy ratio', $
    map_info = map_info1, $
    /write, /open 
    
    return, 1
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Arable land preliminary fusion (sample accuracy)-five sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithFiveByAccuracy, event

    base = widget_auto_base(title = 'Arable land preliminary fusion (sample accuracy)-five sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Classification accuracy 01', uvalue = 'inputFileName2', $
        default = '', /auto)

    inputFileName3 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Classification accuracy 02', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName5 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Classification accuracy 03', uvalue = 'inputFileName6', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Classification accuracy 04', uvalue = 'inputFileName8', $
        default = '', /auto)

    inputFileName9 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName9', $
        default = '', /auto)
    inputFileName10 = widget_outf(base, prompt = 'Classification accuracy 05', uvalue = 'inputFileName10', $
        default = '', /auto)        
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    inputFileName10 = baseclass.inputFileName10    
    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call the function of Arable land preliminary fusion (sample accuracy)-five sets of products
    functionResult = funcCalCroplandSynergyWithFiveByAccuracy(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, $
        inputFileName9, inputFileName10, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Arable land preliminary fusion (sample accuracy)-five sets of products
function funcCalCroplandSynergyWithFiveByAccuracy, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, $
    inputFileName5, inputFileName6, $
    inputFileName7, inputFileName8, $
    inputFileName9, inputFileName10, $
    outputFileName1, outputFileName2
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read five sets of Arable land product data and classification accuracy data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;The first set of Arable land products
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;The first set of Arable land product accuracy
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;The second set of Arable land products
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;The second set of Arable land product accuracy
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;The third set of Arable land products
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6    ;;The third set of Arable land product accuracy
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;The fourth set of Arable land products
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;The fourth set of Arable land product accuracy
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;The fifth set of Arable land products
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    
    
    ENVI_OPEN_FILE, inputFileName10, r_fid = fid10    ;;The fifth set of Arable land product accuracy
    if fid10 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif        

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6
    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7

    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9
    
    ENVI_FILE_QUERY, fid10, dims = dims10, nb = nb10, ns = ns10, nl = nl10, data_type = data_type10
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 10
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns7
    nsArray[7] = ns8
    nsArray[8] = ns9
    nsArray[9] = ns10    
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl7
    nlArray[7] = nl8
    nlArray[8] = nl9
    nlArray[9] = nl10    
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 0], $
                        [1, 1, 1, 0, 1], $
                        [1, 1, 0, 1, 1], $
                        [1, 0, 1, 1, 1], $
                        [0, 1, 1, 1, 1], $
                        [1, 1, 1, 0, 0], $
                        [1, 1, 0, 1, 0], $
                        [1, 0, 1, 1, 0], $
                        [0, 1, 1, 1, 0], $
                        [1, 1, 0, 0, 1], $
                        [1, 0, 1, 0, 1], $
                        [0, 1, 1, 0, 1], $
                        [1, 0, 0, 1, 1], $
                        [0, 1, 0, 1, 1], $
                        [0, 0, 1, 1, 1], $
                        [1, 1, 0, 0, 0], $
                        [1, 0, 1, 0, 0], $
                        [0, 1, 1, 0, 0], $
                        [1, 0, 0, 1, 0], $
                        [0, 1, 0, 1, 0], $
                        [0, 0, 1, 1, 0], $
                        [1, 0, 0, 0, 1], $
                        [0, 1, 0, 0, 1], $
                        [0, 0, 1, 0, 1], $
                        [0, 0, 0, 1, 1], $
                        [1, 0, 0, 0, 0], $
                        [0, 1, 0, 0, 0], $
                        [0, 0, 1, 0, 0], $
                        [0, 0, 0, 1, 0], $
                        [0, 0, 0, 0, 1], $
                        [0, 0, 0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    
    OPENW, unit2, outputFileName2, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land synergy calculation'], title = 'Cultivated land synergy calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Combine Arable land data and Arable land precision data into two large arrays
            productCount = 5
            cropData = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            cropAccuracy = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData2 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData3 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain Arable land product data and its accuracy data
            ;;Get Arable land product data01
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            tileDataCopy1 = tileData1
            index = where(tileDataCopy1 gt 0, count)
            if count gt 0 then begin
                tileDataCopy1[index] = 1
            endif
            
            cropData[0, *, *] = tileDataCopy1[*, *]
            
            ;;Obtain accuracy data 01 of Arable land products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            cropAccuracy[0, *, *] = tileData2[*, *]

            ;;Get Arable land product data02
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            tileDataCopy3 = tileData3
            index = where(tileDataCopy3 gt 0, count)
            if count gt 0 then begin
                tileDataCopy3[index] = 1
            endif
            
            cropData[1, *, *] = tileDataCopy3[*, *]

            ;;Obtain accuracy data of Arable land products 02            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            cropAccuracy[1, *, *] = tileData4[*, *]
            
            ;;Get Arable land product data03
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            tileDataCopy5 = tileData5
            index = where(tileDataCopy5 gt 0, count)
            if count gt 0 then begin
                tileDataCopy5[index] = 1
            endif
            
            cropData[2, *, *] = tileDataCopy5[*, *]
            
            ;;Obtain accuracy data of Arable land products 03
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            cropAccuracy[2, *, *] = tileData6[*, *]
            
            ;;Get Arable land product data04
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            tileDataCopy7 = tileData7
            index = where(tileDataCopy7 gt 0, count)
            if count gt 0 then begin
                tileDataCopy7[index] = 1
            endif
            
            cropData[3, *, *] = tileDataCopy7[*, *]
            
            ;;Obtaining accuracy data of Arable land products 04
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            cropAccuracy[3, *, *] = tileData8[*, *]
            
            ;;Get Arable land product data05
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            
            tileDataCopy9 = tileData9
            index = where(tileDataCopy9 gt 0, count)
            if count gt 0 then begin
                tileDataCopy9[index] = 1
            endif
            
            cropData[4, *, *] = tileDataCopy9[*, *]
            
            ;;Obtain accuracy data of Arable land products 05
            dims10[1] = tileStartSample
            dims10[2] = tileEndSample
            dims10[3] = tileStartLine
            dims10[4] = tileEndLine
            
            tileData10 = ENVI_GET_DATA(fid = fid10, dims = dims10, pos = 0)
            
            cropAccuracy[4, *, *] = tileData10[*, *]
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Sort the classification data according to the accuracy of each administrative division
            for m = 0LL, productCount - 1 do begin
                for n = 0LL, productCount - m - 2 do begin
                    tempData1[*, *] = cropAccuracy[n + 1, *, *] - cropAccuracy[n, *, *]
                    
                    index1 = where(tempData1 gt 0, count1)
                    if count1 gt 0 then begin
                        tempData2[index1] = cropData[n + 1, index1]
                        cropData[n + 1, index1] = cropData[n, index1]
                        cropData[n, index1] = tempData2[index1]
                    endif
                endfor
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value      
            resultData1 = INTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = tileData9
            
            for m = 0LL, synergyRankLine - 1 do begin
                tempData1 = abs(cropData[0, *, *] - synergyRankArray[0, m]) + abs(cropData[1, *, *] - synergyRankArray[1, m]) + $
                            abs(cropData[2, *, *] - synergyRankArray[2, m]) + abs(cropData[3, *, *] - synergyRankArray[3, m]) + $
                            abs(cropData[4, *, *] - synergyRankArray[4, m])
                index1 = where(tempData1 eq 0, count1)
                if count1 gt 0 then begin
                    resultData1[index1] = m + 1
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1 + tileData3 + $
                        tileData5 + tileData7 + $
                        tileData9
                        
            tempDataCopy2 = tileDataCopy1 + tileDataCopy3 + $
                            tileDataCopy5 + tileDataCopy7 + $
                            tileDataCopy9
            
            resultData2 = tempDataCopy2
            
            index2 = where(tempDataCopy2 ne 0, count2)
            if count2 gt 0 then begin
                resultData2[index2] = tempData2[index2] / tempDataCopy2[index2]
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Free memory
    FREE_LUN, unit2
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 2, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Integration result', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy ratio', $
    map_info = map_info1, $
    /write, /open 
    
    return, 1
end


;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Arable land preliminary fusion (sample accuracy)-six sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithSixByAccuracy, event

    base = widget_auto_base(title = 'Arable land preliminary fusion (sample accuracy)-six sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Classification accuracy 01', uvalue = 'inputFileName2', $
        default = '', /auto)

    inputFileName3 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Classification accuracy 02', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName5 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Classification accuracy 03', uvalue = 'inputFileName6', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Classification accuracy 04', uvalue = 'inputFileName8', $
        default = '', /auto)

    inputFileName9 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName9', $
        default = '', /auto)
    inputFileName10 = widget_outf(base, prompt = 'Classification accuracy 05', uvalue = 'inputFileName10', $
        default = '', /auto)
        
    inputFileName11 = widget_outf(base, prompt = 'Class product 06', uvalue = 'inputFileName11', $
        default = '', /auto)
    inputFileName12 = widget_outf(base, prompt = 'Classification accuracy 06', uvalue = 'inputFileName12', $
        default = '', /auto)                
        
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    inputFileName10 = baseclass.inputFileName10    
    inputFileName11 = baseclass.inputFileName11
    inputFileName12 = baseclass.inputFileName12    

    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call the function of Arable land preliminary fusion (sample accuracy)-six sets of product
    functionResult = funcCalCroplandSynergyWithSixByAccuracy(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, $
        inputFileName9, inputFileName10, $
        inputFileName11, inputFileName12, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Arable land preliminary fusion (sample accuracy)-six sets of product
function funcCalCroplandSynergyWithSixByAccuracy, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, $
    inputFileName5, inputFileName6, $
    inputFileName7, inputFileName8, $
    inputFileName9, inputFileName10, $
    inputFileName11, inputFileName12, $    
    outputFileName1, outputFileName2
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read six sets of Arable land product data and classification accuracy data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;The first set of Arable land products
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;The first set of Arable land product accuracy
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;The second set of Arable land products
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;The second set of Arable land product accuracy
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;The third set of Arable land products
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6    ;;The third set of Arable land product accuracy
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;The fourth set of Arable land products
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;The fourth set of Arable land product accuracy
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;The fifth set of Arable land products
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    
    
    ENVI_OPEN_FILE, inputFileName10, r_fid = fid10    ;;The fifth set of Arable land product accuracy
    if fid10 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName11, r_fid = fid11    ;;The sixth set of Arable land products
    if fid11 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName12, r_fid = fid12    ;;The sixth set of Arable land product accuracy
    if fid12 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6
    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7

    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9
    
    ENVI_FILE_QUERY, fid10, dims = dims10, nb = nb10, ns = ns10, nl = nl10, data_type = data_type10
    
    ENVI_FILE_QUERY, fid11, dims = dims11, nb = nb11, ns = ns11, nl = nl11, data_type = data_type11
    
    ENVI_FILE_QUERY, fid12, dims = dims12, nb = nb12, ns = ns12, nl = nl12, data_type = data_type12
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 12
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns7
    nsArray[7] = ns8
    nsArray[8] = ns9
    nsArray[9] = ns10
    nsArray[10] = ns11
    nsArray[11] = ns12   
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl7
    nlArray[7] = nl8
    nlArray[8] = nl9
    nlArray[9] = nl10    
    nlArray[10] = nl11    
    nlArray[11] = nl12   
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1,1,1,1,1,1], $
                        [1,1,1,1,1,0], $
                        [1,1,1,1,0,1], $
                        [1,1,1,0,1,1], $
                        [1,1,0,1,1,1], $
                        [1,0,1,1,1,1], $
                        [0,1,1,1,1,1], $
                        [1,1,1,1,0,0], $
                        [1,1,1,0,1,0], $
                        [1,1,0,1,1,0], $
                        [1,0,1,1,1,0], $
                        [0,1,1,1,1,0], $
                        [1,1,1,0,0,1], $
                        [1,1,0,1,0,1], $
                        [1,0,1,1,0,1], $
                        [0,1,1,1,0,1], $
                        [1,1,0,0,1,1], $
                        [1,0,1,0,1,1], $
                        [0,1,1,0,1,1], $
                        [1,0,0,1,1,1], $
                        [0,1,0,1,1,1], $
                        [0,0,1,1,1,1], $
                        [1,1,1,0,0,0], $
                        [1,1,0,1,0,0], $
                        [1,1,0,0,1,0], $
                        [1,1,0,0,0,1], $
                        [1,0,1,1,0,0], $
                        [1,0,1,0,1,0], $
                        [1,0,1,0,0,1], $
                        [1,0,0,1,1,0], $
                        [1,0,0,1,0,1], $
                        [1,0,0,0,1,1], $
                        [0,1,1,1,0,0], $
                        [0,1,1,0,1,0], $
                        [0,1,1,0,0,1], $
                        [0,1,0,1,1,0], $
                        [0,1,0,1,0,1], $
                        [0,1,0,0,1,1], $
                        [0,0,1,1,1,0], $
                        [0,0,1,1,0,1], $
                        [0,0,1,0,1,1], $
                        [0,0,0,1,1,1], $
                        [1,1,0,0,0,0], $
                        [1,0,1,0,0,0], $
                        [1,0,0,1,0,0], $
                        [1,0,0,0,1,0], $
                        [1,0,0,0,0,1], $
                        [0,1,1,0,0,0], $
                        [0,1,0,1,0,0], $
                        [0,1,0,0,1,0], $
                        [0,1,0,0,0,1], $
                        [0,0,1,1,0,0], $
                        [0,0,1,0,1,0], $
                        [0,0,1,0,0,1], $
                        [0,0,0,1,1,0], $
                        [0,0,0,1,0,1], $
                        [0,0,0,0,1,1], $
                        [1,0,0,0,0,0], $
                        [0,1,0,0,0,0], $
                        [0,0,1,0,0,0], $
                        [0,0,0,1,0,0], $
                        [0,0,0,0,1,0], $
                        [0,0,0,0,0,1], $
                        [0,0,0,0,0,0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    
    OPENW, unit2, outputFileName2, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land synergy calculation'], title = 'Cultivated land synergy calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Combine Arable land data and Arable land precision data into two large arrays
            productCount = 6
            cropData = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            cropAccuracy = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData2 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData3 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain Arable land product data and its accuracy data
            ;;Get Arable land product data01
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            tileDataCopy1 = tileData1
            index = where(tileDataCopy1 gt 0, count)
            if count gt 0 then begin
                tileDataCopy1[index] = 1
            endif
            
            cropData[0, *, *] = tileDataCopy1[*, *]
            
            ;;Obtain accuracy data 01 of Arable land products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            cropAccuracy[0, *, *] = tileData2[*, *]

            ;;Get Arable land product data02
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            tileDataCopy3 = tileData3
            index = where(tileDataCopy3 gt 0, count)
            if count gt 0 then begin
                tileDataCopy3[index] = 1
            endif
            
            cropData[1, *, *] = tileDataCopy3[*, *]

            ;;Obtain accuracy data of Arable land products 02            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            cropAccuracy[1, *, *] = tileData4[*, *]
            
            ;;Get Arable land product data03
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            tileDataCopy5 = tileData5
            index = where(tileDataCopy5 gt 0, count)
            if count gt 0 then begin
                tileDataCopy5[index] = 1
            endif
            
            cropData[2, *, *] = tileDataCopy5[*, *]
            
            ;;Obtain accuracy data of Arable land products 03
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            cropAccuracy[2, *, *] = tileData6[*, *]
            
            ;;Get Arable land product data04
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            tileDataCopy7 = tileData7
            index = where(tileDataCopy7 gt 0, count)
            if count gt 0 then begin
                tileDataCopy7[index] = 1
            endif
            
            cropData[3, *, *] = tileDataCopy7[*, *]
            
            ;;Obtaining accuracy data of Arable land products 04
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            cropAccuracy[3, *, *] = tileData8[*, *]
            
            ;;Get Arable land product data05
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            
            tileDataCopy9 = tileData9
            index = where(tileDataCopy9 gt 0, count)
            if count gt 0 then begin
                tileDataCopy9[index] = 1
            endif
            
            cropData[4, *, *] = tileDataCopy9[*, *]
            
            ;;Obtain accuracy data of Arable land products 05
            dims10[1] = tileStartSample
            dims10[2] = tileEndSample
            dims10[3] = tileStartLine
            dims10[4] = tileEndLine
            
            tileData10 = ENVI_GET_DATA(fid = fid10, dims = dims10, pos = 0)
            
            cropAccuracy[4, *, *] = tileData10[*, *]
            
            ;;Get Arable land product data06
            dims11[1] = tileStartSample
            dims11[2] = tileEndSample
            dims11[3] = tileStartLine
            dims11[4] = tileEndLine
            
            tileData11 = ENVI_GET_DATA(fid = fid11, dims = dims11, pos = 0)
            
            tileDataCopy11 = tileData11
            index = where(tileDataCopy11 gt 0, count)
            if count gt 0 then begin
                tileDataCopy11[index] = 1
            endif
            
            cropData[5, *, *] = tileDataCopy11[*, *]
            
            ;;Obtain accuracy data of Arable land products 06
            dims12[1] = tileStartSample
            dims12[2] = tileEndSample
            dims12[3] = tileStartLine
            dims12[4] = tileEndLine
            
            tileData12 = ENVI_GET_DATA(fid = fid12, dims = dims12, pos = 0)
            
            cropAccuracy[5, *, *] = tileData12[*, *]            
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Sort the classification data according to the accuracy of each administrative division
            for m = 0LL, productCount - 1 do begin
                for n = 0LL, productCount - m - 2 do begin
                    tempData1[*, *] = cropAccuracy[n + 1, *, *] - cropAccuracy[n, *, *]
                    
                    index1 = where(tempData1 gt 0, count1)
                    if count1 gt 0 then begin
                        tempData2[index1] = cropData[n + 1, index1]
                        cropData[n + 1, index1] = cropData[n, index1]
                        cropData[n, index1] = tempData2[index1]
                    endif
                endfor
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value      
            resultData1 = INTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = tileData1
            
            for m = 0LL, synergyRankLine - 1 do begin
                tempData1 = abs(cropData[0, *, *] - synergyRankArray[0, m]) + abs(cropData[1, *, *] - synergyRankArray[1, m]) + $
                            abs(cropData[2, *, *] - synergyRankArray[2, m]) + abs(cropData[3, *, *] - synergyRankArray[3, m]) + $
                            abs(cropData[4, *, *] - synergyRankArray[4, m]) + abs(cropData[5, *, *] - synergyRankArray[5, m])
                index1 = where(tempData1 eq 0, count1)
                if count1 gt 0 then begin
                    resultData1[index1] = m + 1
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1 + tileData3 + $
                        tileData5 + tileData7 + $
                        tileData9 + tileData11
                        
            tempDataCopy2 = tileDataCopy1 + tileDataCopy3 + $
                            tileDataCopy5 + tileDataCopy7 + $
                            tileDataCopy9 + tileDataCopy11
            
            resultData2 = tempDataCopy2
            
            index2 = where(tempDataCopy2 ne 0, count2)
            if count2 gt 0 then begin
                resultData2[index2] = tempData2[index2] / tempDataCopy2[index2]
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Free memory
    FREE_LUN, unit2
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 2, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Integration result', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy ratio', $
    map_info = map_info1, $
    /write, /open 
    
    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Arable land preliminary fusion (sample accuracy)-seven sets of products
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
pro proCalCroplandSynergyWithSevenByAccuracy, event

    base = widget_auto_base(title = 'Arable land preliminary fusion (sample accuracy)-seven sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Classification accuracy 01', uvalue = 'inputFileName2', $
        default = '', /auto)

    inputFileName3 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Classification accuracy 02', uvalue = 'inputFileName4', $
        default = '', /auto)

    inputFileName5 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Classification accuracy 03', uvalue = 'inputFileName6', $
        default = '', /auto)

    inputFileName7 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName7', $
        default = '', /auto)
    inputFileName8 = widget_outf(base, prompt = 'Classification accuracy 04', uvalue = 'inputFileName8', $
        default = '', /auto)

    inputFileName9 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName9', $
        default = '', /auto)
    inputFileName10 = widget_outf(base, prompt = 'Classification accuracy 05', uvalue = 'inputFileName10', $
        default = '', /auto)
        
    inputFileName11 = widget_outf(base, prompt = 'Class product 06', uvalue = 'inputFileName11', $
        default = '', /auto)
    inputFileName12 = widget_outf(base, prompt = 'Classification accuracy 06', uvalue = 'inputFileName12', $
        default = '', /auto)

    inputFileName13 = widget_outf(base, prompt = 'Class product 07', uvalue = 'inputFileName13', $
        default = '', /auto)
    inputFileName14 = widget_outf(base, prompt = 'Classification accuracy 07', uvalue = 'inputFileName14', $
        default = '', /auto)

     
    outputFileName1 = widget_outf(base, prompt = 'Cultivated land preliminary synergy code', uvalue = 'outputFileName1', $
        default = '', /auto)
    outputFileName2 = widget_outf(base, prompt = 'Initial synergy ratio of cultivated land', uvalue = 'outputFileName2', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    inputFileName7 = baseclass.inputFileName7
    inputFileName8 = baseclass.inputFileName8
    inputFileName9 = baseclass.inputFileName9
    inputFileName10 = baseclass.inputFileName10    
    inputFileName11 = baseclass.inputFileName11
    inputFileName12 = baseclass.inputFileName12
    inputFileName13 = baseclass.inputFileName13
    inputFileName14 = baseclass.inputFileName14        

    
    outputFileName1 = baseclass.outputFileName1
    outputFileName2 = baseclass.outputFileName2
    
    ;;;;;Call the function of Arable land preliminary fusion (sample accuracy)-seven sets of products
    functionResult = funcCalCroplandSynergyWithSevenByAccuracy(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        inputFileName7, inputFileName8, $
        inputFileName9, inputFileName10, $
        inputFileName11, inputFileName12, $
        inputFileName13, inputFileName14, $
        outputFileName1, outputFileName2)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Arable land preliminary fusion (sample accuracy)-seven sets of products
function funcCalCroplandSynergyWithSevenByAccuracy, inputFileName1, inputFileName2, $
    inputFileName3, inputFileName4, $
    inputFileName5, inputFileName6, $
    inputFileName7, inputFileName8, $
    inputFileName9, inputFileName10, $
    inputFileName11, inputFileName12, $
    inputFileName13, inputFileName14, $   
    outputFileName1, outputFileName2
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1
    
    proDeleteFile, file_name = outputFileName2

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read seven sets of Arable land product data and classification accuracy data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1    ;;The first set of Arable land products
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2    ;;The first set of Arable land product accuracy
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3    ;;The second set of Arable land products
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4    ;;The second set of Arable land product accuracy
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5    ;;The third set of Arable land products
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6    ;;The third set of Arable land product accuracy
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7    ;;The fourth set of Arable land products
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName8, r_fid = fid8    ;;The fourth set of Arable land product accuracy
    if fid8 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName9, r_fid = fid9    ;;The fifth set of Arable land products
    if fid9 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    
    
    ENVI_OPEN_FILE, inputFileName10, r_fid = fid10    ;;The fifth set of Arable land product accuracy
    if fid10 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName11, r_fid = fid11    ;;The sixth set of Arable land products
    if fid11 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName12, r_fid = fid12    ;;The sixth set of Arable land product accuracy
    if fid12 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ENVI_OPEN_FILE, inputFileName13, r_fid = fid13    ;;Seventh set of cultivated land products
    if fid13 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName14, r_fid = fid14    ;;Seventh set of cultivated land products accuracy
    if fid14 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif


    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6
    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7

    ENVI_FILE_QUERY, fid8, dims = dims8, nb = nb8, ns = ns8, nl = nl8, data_type = data_type8
    
    ENVI_FILE_QUERY, fid9, dims = dims9, nb = nb9, ns = ns9, nl = nl9, data_type = data_type9
    
    ENVI_FILE_QUERY, fid10, dims = dims10, nb = nb10, ns = ns10, nl = nl10, data_type = data_type10
    
    ENVI_FILE_QUERY, fid11, dims = dims11, nb = nb11, ns = ns11, nl = nl11, data_type = data_type11
    
    ENVI_FILE_QUERY, fid12, dims = dims12, nb = nb12, ns = ns12, nl = nl12, data_type = data_type12
    
    ENVI_FILE_QUERY, fid13, dims = dims13, nb = nb13, ns = ns13, nl = nl13, data_type = data_type13

    ENVI_FILE_QUERY, fid14, dims = dims14, nb = nb14, ns = ns14, nl = nl14, data_type = data_type14    
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 14
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns7
    nsArray[7] = ns8
    nsArray[8] = ns9
    nsArray[9] = ns10
    nsArray[10] = ns11
    nsArray[11] = ns12
    nsArray[12] = ns13
    nsArray[13] = ns14    
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl7
    nlArray[7] = nl8
    nlArray[8] = nl9
    nlArray[9] = nl10    
    nlArray[10] = nl11    
    nlArray[11] = nl12   
    nlArray[12] = nl13    
    nlArray[13] = nl14       
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a synergy level matrix
    synergyRankArray = [[1, 1, 1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 1, 1, 0], $
                        [1, 1, 1, 1, 1, 0, 1], $
                        [1, 1, 1, 1, 0, 1, 1], $
                        [1, 1, 1, 0, 1, 1, 1], $
                        [1, 1, 0, 1, 1, 1, 1], $
                        [1, 0, 1, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 1, 0, 0], $
                        [1, 1, 1, 1, 0, 1, 0], $
                        [1, 1, 1, 0, 1, 1, 0], $
                        [1, 1, 0, 1, 1, 1, 0], $
                        [1, 0, 1, 1, 1, 1, 0], $
                        [1, 1, 1, 1, 0, 0, 1], $
                        [1, 1, 1, 0, 1, 0, 1], $
                        [1, 1, 0, 1, 1, 0, 1], $
                        [1, 0, 1, 1, 1, 0, 1], $
                        [1, 1, 1, 0, 0, 1, 1], $
                        [1, 1, 0, 1, 0, 1, 1], $
                        [1, 0, 1, 1, 0, 1, 1], $
                        [1, 1, 0, 0, 1, 1, 1], $
                        [1, 0, 1, 0, 1, 1, 1], $
                        [1, 0, 0, 1, 1, 1, 1], $
                        [1, 1, 1, 1, 0, 0, 0], $
                        [1, 1, 1, 0, 1, 0, 0], $
                        [1, 1, 1, 0, 0, 1, 0], $
                        [1, 1, 1, 0, 0, 0, 1], $
                        [1, 1, 0, 1, 1, 0, 0], $
                        [1, 1, 0, 1, 0, 1, 0], $
                        [1, 1, 0, 1, 0, 0, 1], $
                        [1, 1, 0, 0, 1, 1, 0], $
                        [1, 1, 0, 0, 1, 0, 1], $
                        [1, 1, 0, 0, 0, 1, 1], $
                        [1, 0, 1, 1, 1, 0, 0], $
                        [1, 0, 1, 1, 0, 1, 0], $
                        [1, 0, 1, 1, 0, 0, 1], $
                        [1, 0, 1, 0, 1, 1, 0], $
                        [1, 0, 1, 0, 1, 0, 1], $
                        [1, 0, 1, 0, 0, 1, 1], $
                        [1, 0, 0, 1, 1, 1, 0], $
                        [1, 0, 0, 1, 1, 0, 1], $
                        [1, 0, 0, 1, 0, 1, 1], $
                        [1, 0, 0, 0, 1, 1, 1], $
                        [1, 1, 1, 0, 0, 0, 0], $
                        [1, 1, 0, 1, 0, 0, 0], $
                        [1, 1, 0, 0, 1, 0, 0], $
                        [1, 1, 0, 0, 0, 1, 0], $
                        [1, 1, 0, 0, 0, 0, 1], $
                        [1, 0, 1, 1, 0, 0, 0], $
                        [1, 0, 1, 0, 1, 0, 0], $
                        [1, 0, 1, 0, 0, 1, 0], $
                        [1, 0, 1, 0, 0, 0, 1], $
                        [1, 0, 0, 1, 1, 0, 0], $
                        [1, 0, 0, 1, 0, 1, 0], $
                        [1, 0, 0, 1, 0, 0, 1], $
                        [1, 0, 0, 0, 1, 1, 0], $
                        [1, 0, 0, 0, 1, 0, 1], $
                        [1, 0, 0, 0, 0, 1, 1], $
                        [1, 1, 0, 0, 0, 0, 0], $
                        [1, 0, 1, 0, 0, 0, 0], $
                        [1, 0, 0, 1, 0, 0, 0], $
                        [1, 0, 0, 0, 1, 0, 0], $
                        [1, 0, 0, 0, 0, 1, 0], $
                        [1, 0, 0, 0, 0, 0, 1], $
                        [1, 0, 0, 0, 0, 0, 0], $
                        [0, 1, 1, 1, 1, 1, 1], $
                        [0, 1, 1, 1, 1, 1, 0], $
                        [0, 1, 1, 1, 1, 0, 1], $
                        [0, 1, 1, 1, 0, 1, 1], $
                        [0, 1, 1, 0, 1, 1, 1], $
                        [0, 1, 0, 1, 1, 1, 1], $
                        [0, 0, 1, 1, 1, 1, 1], $
                        [0, 1, 1, 1, 1, 0, 0], $
                        [0, 1, 1, 1, 0, 1, 0], $
                        [0, 1, 1, 0, 1, 1, 0], $
                        [0, 1, 0, 1, 1, 1, 0], $
                        [0, 0, 1, 1, 1, 1, 0], $
                        [0, 1, 1, 1, 0, 0, 1], $
                        [0, 1, 1, 0, 1, 0, 1], $
                        [0, 1, 0, 1, 1, 0, 1], $
                        [0, 0, 1, 1, 1, 0, 1], $
                        [0, 1, 1, 0, 0, 1, 1], $
                        [0, 1, 0, 1, 0, 1, 1], $
                        [0, 0, 1, 1, 0, 1, 1], $
                        [0, 1, 0, 0, 1, 1, 1], $
                        [0, 0, 1, 0, 1, 1, 1], $
                        [0, 0, 0, 1, 1, 1, 1], $
                        [0, 1, 1, 1, 0, 0, 0], $
                        [0, 1, 1, 0, 1, 0, 0], $
                        [0, 1, 1, 0, 0, 1, 0], $
                        [0, 1, 1, 0, 0, 0, 1], $
                        [0, 1, 0, 1, 1, 0, 0], $
                        [0, 1, 0, 1, 0, 1, 0], $
                        [0, 1, 0, 1, 0, 0, 1], $
                        [0, 1, 0, 0, 1, 1, 0], $
                        [0, 1, 0, 0, 1, 0, 1], $
                        [0, 1, 0, 0, 0, 1, 1], $
                        [0, 0, 1, 1, 1, 0, 0], $
                        [0, 0, 1, 1, 0, 1, 0], $
                        [0, 0, 1, 1, 0, 0, 1], $
                        [0, 0, 1, 0, 1, 1, 0], $
                        [0, 0, 1, 0, 1, 0, 1], $
                        [0, 0, 1, 0, 0, 1, 1], $
                        [0, 0, 0, 1, 1, 1, 0], $
                        [0, 0, 0, 1, 1, 0, 1], $
                        [0, 0, 0, 1, 0, 1, 1], $
                        [0, 0, 0, 0, 1, 1, 1], $
                        [0, 1, 1, 0, 0, 0, 0], $
                        [0, 1, 0, 1, 0, 0, 0], $
                        [0, 1, 0, 0, 1, 0, 0], $
                        [0, 1, 0, 0, 0, 1, 0], $
                        [0, 1, 0, 0, 0, 0, 1], $
                        [0, 0, 1, 1, 0, 0, 0], $
                        [0, 0, 1, 0, 1, 0, 0], $
                        [0, 0, 1, 0, 0, 1, 0], $
                        [0, 0, 1, 0, 0, 0, 1], $
                        [0, 0, 0, 1, 1, 0, 0], $
                        [0, 0, 0, 1, 0, 1, 0], $
                        [0, 0, 0, 1, 0, 0, 1], $
                        [0, 0, 0, 0, 1, 1, 0], $
                        [0, 0, 0, 0, 1, 0, 1], $
                        [0, 0, 0, 0, 0, 1, 1], $
                        [0, 1, 0, 0, 0, 0, 0], $
                        [0, 0, 1, 0, 0, 0, 0], $
                        [0, 0, 0, 1, 0, 0, 0], $
                        [0, 0, 0, 0, 1, 0, 0], $
                        [0, 0, 0, 0, 0, 1, 0], $
                        [0, 0, 0, 0, 0, 0, 1], $
                        [0, 0, 0, 0, 0, 0, 0]]
    
    synergyRankSize = size(synergyRankArray)
    synergyRankSample = synergyRankSize[1]
    synergyRankLine = synergyRankSize[2]
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun
    
    OPENW, unit2, outputFileName2, /get_lun
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Cultivated land synergy calculation'], title = 'Cultivated land synergy calculation', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Combine Arable land data and Arable land precision data into two large arrays
            productCount = 7
            cropData = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            cropAccuracy = DBLARR(productCount, tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData2 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData3 = DBLARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Obtain Arable land product data and its accuracy data
            ;;Get Arable land product data01
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            
            tileDataCopy1 = tileData1
            index = where(tileDataCopy1 gt 0, count)
            if count gt 0 then begin
                tileDataCopy1[index] = 1
            endif
            
            cropData[0, *, *] = tileDataCopy1[*, *]
            
            ;;Obtain accuracy data 01 of Arable land products
            dims2[1] = tileStartSample
            dims2[2] = tileEndSample
            dims2[3] = tileStartLine
            dims2[4] = tileEndLine
            
            tileData2 = ENVI_GET_DATA(fid = fid2, dims = dims2, pos = 0)
            
            cropAccuracy[0, *, *] = tileData2[*, *]

            ;;Get Arable land product data02
            dims3[1] = tileStartSample
            dims3[2] = tileEndSample
            dims3[3] = tileStartLine
            dims3[4] = tileEndLine
            
            tileData3 = ENVI_GET_DATA(fid = fid3, dims = dims3, pos = 0)
            
            tileDataCopy3 = tileData3
            index = where(tileDataCopy3 gt 0, count)
            if count gt 0 then begin
                tileDataCopy3[index] = 1
            endif
            
            cropData[1, *, *] = tileDataCopy3[*, *]

            ;;Obtain accuracy data of Arable land products 02            
            dims4[1] = tileStartSample
            dims4[2] = tileEndSample
            dims4[3] = tileStartLine
            dims4[4] = tileEndLine
            
            tileData4 = ENVI_GET_DATA(fid = fid4, dims = dims4, pos = 0)
            
            cropAccuracy[1, *, *] = tileData4[*, *]
            
            ;;Get Arable land product data03
            dims5[1] = tileStartSample
            dims5[2] = tileEndSample
            dims5[3] = tileStartLine
            dims5[4] = tileEndLine
            
            tileData5 = ENVI_GET_DATA(fid = fid5, dims = dims5, pos = 0)
            
            tileDataCopy5 = tileData5
            index = where(tileDataCopy5 gt 0, count)
            if count gt 0 then begin
                tileDataCopy5[index] = 1
            endif
            
            cropData[2, *, *] = tileDataCopy5[*, *]
            
            ;;Obtain accuracy data of Arable land products 03
            dims6[1] = tileStartSample
            dims6[2] = tileEndSample
            dims6[3] = tileStartLine
            dims6[4] = tileEndLine
            
            tileData6 = ENVI_GET_DATA(fid = fid6, dims = dims6, pos = 0)
            
            cropAccuracy[2, *, *] = tileData6[*, *]
            
            ;;Get Arable land product data04
            dims7[1] = tileStartSample
            dims7[2] = tileEndSample
            dims7[3] = tileStartLine
            dims7[4] = tileEndLine
            
            tileData7 = ENVI_GET_DATA(fid = fid7, dims = dims7, pos = 0)
            
            tileDataCopy7 = tileData7
            index = where(tileDataCopy7 gt 0, count)
            if count gt 0 then begin
                tileDataCopy7[index] = 1
            endif
            
            cropData[3, *, *] = tileDataCopy7[*, *]
            
            ;;Obtaining accuracy data of Arable land products 04
            dims8[1] = tileStartSample
            dims8[2] = tileEndSample
            dims8[3] = tileStartLine
            dims8[4] = tileEndLine
            
            tileData8 = ENVI_GET_DATA(fid = fid8, dims = dims8, pos = 0)
            
            cropAccuracy[3, *, *] = tileData8[*, *]
            
            ;;Get Arable land product data05
            dims9[1] = tileStartSample
            dims9[2] = tileEndSample
            dims9[3] = tileStartLine
            dims9[4] = tileEndLine
            
            tileData9 = ENVI_GET_DATA(fid = fid9, dims = dims9, pos = 0)
            
            tileDataCopy9 = tileData9
            index = where(tileDataCopy9 gt 0, count)
            if count gt 0 then begin
                tileDataCopy9[index] = 1
            endif
            
            cropData[4, *, *] = tileDataCopy9[*, *]
            
            ;;Obtain accuracy data of Arable land products 05
            dims10[1] = tileStartSample
            dims10[2] = tileEndSample
            dims10[3] = tileStartLine
            dims10[4] = tileEndLine
            
            tileData10 = ENVI_GET_DATA(fid = fid10, dims = dims10, pos = 0)
            
            cropAccuracy[4, *, *] = tileData10[*, *]
            
            ;;Get Arable land product data06
            dims11[1] = tileStartSample
            dims11[2] = tileEndSample
            dims11[3] = tileStartLine
            dims11[4] = tileEndLine
            
            tileData11 = ENVI_GET_DATA(fid = fid11, dims = dims11, pos = 0)
            
            tileDataCopy11 = tileData11
            index = where(tileDataCopy11 gt 0, count)
            if count gt 0 then begin
                tileDataCopy11[index] = 1
            endif
            
            cropData[5, *, *] = tileDataCopy11[*, *]
            
            ;;Obtain accuracy data of Arable land products 06
            dims12[1] = tileStartSample
            dims12[2] = tileEndSample
            dims12[3] = tileStartLine
            dims12[4] = tileEndLine
            
            tileData12 = ENVI_GET_DATA(fid = fid12, dims = dims12, pos = 0)
            
            cropAccuracy[5, *, *] = tileData12[*, *]
            
            ;;Get Arable land product data07
            dims13[1] = tileStartSample
            dims13[2] = tileEndSample
            dims13[3] = tileStartLine
            dims13[4] = tileEndLine
            
            tileData13 = ENVI_GET_DATA(fid = fid13, dims = dims13, pos = 0)
            
            tileDataCopy13 = tileData13
            index = where(tileDataCopy13 gt 0, count)
            if count gt 0 then begin
                tileDataCopy13[index] = 1
            endif
            
            cropData[6, *, *] = tileDataCopy13[*, *]
            
            ;;Obtain the accuracy data of Arable land products 07
            dims14[1] = tileStartSample
            dims14[2] = tileEndSample
            dims14[3] = tileStartLine
            dims14[4] = tileEndLine
            
            tileData14 = ENVI_GET_DATA(fid = fid14, dims = dims14, pos = 0)
            
            cropAccuracy[6, *, *] = tileData14[*, *]            
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Sort the classification data according to the accuracy of each administrative division
            for m = 0LL, productCount - 1 do begin
                for n = 0LL, productCount - m - 2 do begin
                    tempData1[*, *] = cropAccuracy[n + 1, *, *] - cropAccuracy[n, *, *]
                    
                    index1 = where(tempData1 gt 0, count1)
                    if count1 gt 0 then begin
                        tempData2[index1] = cropData[n + 1, index1]
                        cropData[n + 1, index1] = cropData[n, index1]
                        cropData[n, index1] = tempData2[index1]
                    endif
                endfor
            endfor
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate synergy value      
            resultData1 = INTARR(tileEndSample - tileStartSample + 1, tileEndLine - tileStartLine + 1)
            tempData1 = tileData1
            
            for m = 0LL, synergyRankLine - 1 do begin
                tempData1 = abs(cropData[0, *, *] - synergyRankArray[0, m]) + abs(cropData[1, *, *] - synergyRankArray[1, m]) + $
                            abs(cropData[2, *, *] - synergyRankArray[2, m]) + abs(cropData[3, *, *] - synergyRankArray[3, m]) + $
                            abs(cropData[4, *, *] - synergyRankArray[4, m]) + abs(cropData[5, *, *] - synergyRankArray[5, m]) + $
                            abs(cropData[6, *, *] - synergyRankArray[6, m])
                index1 = where(tempData1 eq 0, count1)
                if count1 gt 0 then begin
                    resultData1[index1] = m + 1
                endif
            endfor

            ;Write the calculation result of the current block data to the unit memory
            writeu, unit1, resultData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Calculate the average cultivated land ratio
            tempData2 = tileData1 + tileData3 + $
                        tileData5 + tileData7 + $
                        tileData9 + tileData11 + $
                        tileData13
                        
            tempDataCopy2 = tileDataCopy1 + tileDataCopy3 + $
                            tileDataCopy5 + tileDataCopy7 + $
                            tileDataCopy9 + tileDataCopy11 + $
                            tileDataCopy13
            
            resultData2 = tempDataCopy2
            
            index2 = where(tempDataCopy2 ne 0, count2)
            if count2 gt 0 then begin
                resultData2[index2] = tempData2[index2] / tempDataCopy2[index2]
            endif
            
            ;Write the calculation result of the current block data to the unit memory
            writeu, unit2, resultData2
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Free memory
    FREE_LUN, unit2
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish    
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = 2, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Integration result', $
    map_info = map_info1, $
    /write, /open
    
    ENVI_SETUP_HEAD, fname = outputFileName2, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Synergy ratio', $
    map_info = map_info1, $
    /write, /open 
    
    return, 1
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Exception handling
pro proNaNValueKiller, event
    base = widget_auto_base(title = 'Exception handling')
    inputFileName = widget_outf(base, prompt = 'Input data', uvalue = 'inputFileName', $
        default = '', /auto)
    outputFileName = widget_outf(base, prompt = 'Output data', uvalue = 'outputFileName', $
        default = '', /auto)
    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName = baseclass.inputFileName
    outputFileName = baseclass.outputFileName
    
    ;;;;;Exception processing function
    functionResult = FuncNaNValueKiller(inputFileName, outputFileName)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Exception processing function
function FuncNaNValueKiller, inputFileName, outputFileName

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName

    ;;Get input data
    ENVI_OPEN_FILE, inputFileName, r_fid = fid
    if fid eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid, dims = dims, nb = nb, ns = ns, nl = nl, data_type = data_type

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels for statistical analysis
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(ns / double(tileSample))
    tileLineCount = ceil(nl / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;Create a new file for output
    OPENW, unit, outputFileName, /get_lun
    
    ;;Progress Bar
    ENVI_REPORT_INIT, ['Exception handling'], title = 'Exception handling', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;Iterate each block
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt ns then begin
                tileEndSample = ns - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nl then begin
                tileEndLine = nl - 1
            endif
            
            ;;Get the data of the current block
            dims[1] = tileStartSample
            dims[2] = tileEndSample
            dims[3] = tileStartLine
            dims[4] = tileEndLine

            tileData = ENVI_GET_DATA(fid = fid, dims = dims, pos = 0)
            resultData = tileData
            
;            ;;Get the unique value of the current data
;            tileData = tileData[sort(tileData)]
;            curUniqData = tileData[uniq(tileData)]
;            
;            if i eq 0 and j eq 0 then begin
;               uniqData = curUniqData
;               lastUniqData = uniqData
;            endif else begin
;               uniqData = [curUniqData, lastUniqData]
;               lastUniqData = uniqData
;            endelse
            
            ;;;;;;;;;;Remove Nan Value
            index = where(finite(tileData, /NAN), count)
            if count gt 0 then begin
                resultData[index] = 0
            endif
            
            ;;;;;;;;;;Remove negative values
            index = where(tileData lt 0, count)
            if count gt 0 then begin
                resultData[index] = 0
            endif

            ;;Write the calculation result of the current block data to the unit memory
            writeu, unit, resultData
            
            ;;Progress bar, showing calculation progress
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
;    ;;Get unique value
;    uniqData = uniqData[sort(uniqData)]
;    uniqData = uniqData[uniq(uniqData)]
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish
    
    ;;Free memory
    FREE_LUN, unit    
    
    ;;Write output file infomation
    map_info = ENVI_GET_MAP_INFO(fid = fid)
    
    ENVI_SETUP_HEAD, fname = outputFileName, ns = ns, nl = nl, nb = nb, $
        data_type = data_type, offset = 0, interleave = 0, $
        xstart = 0, ystart = 0, $
        descrip = 'Data after NaN is cleared', $
        map_info = map_info, $
        /write, /open

    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName, r_fid = resultFID
    if resultFID eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Multiple sets of Arable land data maximum output_three sets of products
pro proCalCroplandMaximumValueWithThree, event

    base = widget_auto_base(title = 'Multiple sets of Arable land data maximum output_three sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01', uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02', uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
        
    outputFileName1 = widget_outf(base, prompt = 'Arable land maximum data', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the function of Multiple sets of Arable land data maximum output_three sets of products
    functionResult = funcCalCroplandMaximumValueWithThree(inputFileName1, inputFileName2, $
        inputFileName3, outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Multiple sets of Arable land data maximum output_three sets of products
function funcCalCroplandMaximumValueWithThree, inputFileName1, inputFileName2, $
        inputFileName3, outputFileName1
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read three sets of Arable land product data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 3
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Multiple sets of Arable land data maximum output'], title = 'Multiple sets of Arable land data maximum output', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block, To sort
    fidArray = LONARR(fileCount)
    fidArray[0] = fid1
    fidArray[1] = fid2
    fidArray[2] = fid3
    
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;Get the first Arable land data
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            resultData1 = tileData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Find the maximum value by comparison
            for m = 0LL, fileCount - 2 do begin
                if m eq 0 then begin
                    curFid1 = fidArray[m]
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid1, dims = curDims1
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims1[1] = tileStartSample
                    curDims1[2] = tileEndSample
                    curDims1[3] = tileStartLine
                    curDims1[4] = tileEndLine
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine
                    
                    curTileData1 = ENVI_GET_DATA(fid = curFid1, dims = curDims1, pos = 0)
                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0) 
                                   
                    resultData1 = curTileData1
                    curData = curTileData2
                endif else begin
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine

                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0)                 
                
                    curData = curTileData2
                endelse

                tempDataFlag = resultData1 - curData
                
                index = where(tempDataFlag lt 0.0, count)
                if count gt 0 then begin
                    resultData1[index] = curData[index]
                endif
            endfor
            
            writeu, unit1, resultData1
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Multiple sets of Arable land data maximum output', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Multiple sets of Arable land data maximum output_Four sets of products
pro proCalCroplandMaximumValueWithFour, event

    base = widget_auto_base(title = 'Multiple sets of Arable land data maximum output_Four sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
        
    outputFileName1 = widget_outf(base, prompt = 'Arable land maximum data', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the function of Multiple sets of Arable land data maximum output_Four sets of products
    functionResult = funcCalCroplandMaximumValueWithFour(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Multiple sets of Arable land data maximum output_Four sets of products
function funcCalCroplandMaximumValueWithFive, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        outputFileName1
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read four sets of Arable land product data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
   
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 4
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Multiple sets of Arable land data maximum output'], title = 'Multiple sets of Arable land data maximum output', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block, To sort
    fidArray = LONARR(fileCount)
    fidArray[0] = fid1
    fidArray[1] = fid2
    fidArray[2] = fid3
    fidArray[3] = fid4
    
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;Get the first Arable land data
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            resultData1 = tileData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Find the maximum value by comparison
            for m = 0LL, fileCount - 2 do begin
                if m eq 0 then begin
                    curFid1 = fidArray[m]
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid1, dims = curDims1
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims1[1] = tileStartSample
                    curDims1[2] = tileEndSample
                    curDims1[3] = tileStartLine
                    curDims1[4] = tileEndLine
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine
                    
                    curTileData1 = ENVI_GET_DATA(fid = curFid1, dims = curDims1, pos = 0)
                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0) 
                                   
                    resultData1 = curTileData1
                    curData = curTileData2
                endif else begin
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine

                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0)                 
                
                    curData = curTileData2
                endelse

                tempDataFlag = resultData1 - curData
                
                index = where(tempDataFlag lt 0.0, count)
                if count gt 0 then begin
                    resultData1[index] = curData[index]
                endif
            endfor
            
            writeu, unit1, resultData1
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Multiple sets of Arable land data maximum output', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Multiple sets of Arable land data maximum output_Five sets of products
pro proCalCroplandMaximumValueWithFive, event

    base = widget_auto_base(title = 'Multiple sets of Arable land data maximum output_Five sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)
        
    outputFileName1 = widget_outf(base, prompt = 'Arable land maximum data', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the function of Multiple sets of Arable land data maximum output_Five sets of products
    functionResult = funcCalCroplandMaximumValueWithFive(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Multiple sets of Arable land data maximum output_Five sets of products
function funcCalCroplandMaximumValueWithFive, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, outputFileName1
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read five sets of Arable land product data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
   
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 5
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Multiple sets of Arable land data maximum output'], title = 'Multiple sets of Arable land data maximum output', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block, To sort
    fidArray = LONARR(fileCount)
    fidArray[0] = fid1
    fidArray[1] = fid2
    fidArray[2] = fid3
    fidArray[3] = fid4
    fidArray[4] = fid5
    
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;Get the first Arable land data
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            resultData1 = tileData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Find the maximum value by comparison
            for m = 0LL, fileCount - 2 do begin
                if m eq 0 then begin
                    curFid1 = fidArray[m]
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid1, dims = curDims1
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims1[1] = tileStartSample
                    curDims1[2] = tileEndSample
                    curDims1[3] = tileStartLine
                    curDims1[4] = tileEndLine
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine
                    
                    curTileData1 = ENVI_GET_DATA(fid = curFid1, dims = curDims1, pos = 0)
                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0) 
                                   
                    resultData1 = curTileData1
                    curData = curTileData2
                endif else begin
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine

                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0)                 
                
                    curData = curTileData2
                endelse

                tempDataFlag = resultData1 - curData
                
                index = where(tempDataFlag lt 0.0, count)
                if count gt 0 then begin
                    resultData1[index] = curData[index]
                endif
            endfor
            
            writeu, unit1, resultData1
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Multiple sets of Arable land data maximum output', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Multiple sets of Arable land data maximum output_Six sets of products
pro proCalCroplandMaximumValueWithSix, event

    base = widget_auto_base(title = 'Multiple sets of Arable land data maximum output_Six sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Class product 06', uvalue = 'inputFileName6', $
        default = '', /auto)        
        
    outputFileName1 = widget_outf(base, prompt = 'Arable land maximum data', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the function of Multiple sets of Arable land data maximum output_Six sets of products
    functionResult = funcCalCroplandMaximumValueWithSix(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Multiple sets of Arable land data maximum output_Six sets of products
function funcCalCroplandMaximumValueWithSix, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        outputFileName1
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read six sets of Arable land product data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
   
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 6
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6    
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6    
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Multiple sets of Arable land data maximum output'], title = 'Multiple sets of Arable land data maximum output', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block, To sort
    fidArray = LONARR(fileCount)
    fidArray[0] = fid1
    fidArray[1] = fid2
    fidArray[2] = fid3
    fidArray[3] = fid4
    fidArray[4] = fid5
    fidArray[5] = fid6
    
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;Get the first Arable land data
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            resultData1 = tileData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Find the maximum value by comparison
            for m = 0LL, fileCount - 2 do begin
                if m eq 0 then begin
                    curFid1 = fidArray[m]
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid1, dims = curDims1
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims1[1] = tileStartSample
                    curDims1[2] = tileEndSample
                    curDims1[3] = tileStartLine
                    curDims1[4] = tileEndLine
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine
                    
                    curTileData1 = ENVI_GET_DATA(fid = curFid1, dims = curDims1, pos = 0)
                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0) 
                                   
                    resultData1 = curTileData1
                    curData = curTileData2
                endif else begin
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine

                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0)                 
                
                    curData = curTileData2
                endelse

                tempDataFlag = resultData1 - curData
                
                index = where(tempDataFlag lt 0.0, count)
                if count gt 0 then begin
                    resultData1[index] = curData[index]
                endif
            endfor
            
            writeu, unit1, resultData1
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Multiple sets of Arable land data maximum output', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Multiple sets of Arable land data maximum output_Seven sets of products
pro proCalCroplandMaximumValueWithSeven, event

    base = widget_auto_base(title = 'Multiple sets of Arable land data maximum output_Seven sets of products')
        
    inputFileName1 = widget_outf(base, prompt = 'Class product 01',uvalue = 'inputFileName1', $
        default = '', /auto)
    inputFileName2 = widget_outf(base, prompt = 'Class product 02',uvalue = 'inputFileName2', $
        default = '', /auto)
    inputFileName3 = widget_outf(base, prompt = 'Class product 03', uvalue = 'inputFileName3', $
        default = '', /auto)
    inputFileName4 = widget_outf(base, prompt = 'Class product 04', uvalue = 'inputFileName4', $
        default = '', /auto)
    inputFileName5 = widget_outf(base, prompt = 'Class product 05', uvalue = 'inputFileName5', $
        default = '', /auto)
    inputFileName6 = widget_outf(base, prompt = 'Class product 06', uvalue = 'inputFileName6', $
        default = '', /auto)
    inputFileName7 = widget_outf(base, prompt = 'Class product 07', uvalue = 'inputFileName7', $
        default = '', /auto)        
        
    outputFileName1 = widget_outf(base, prompt = 'Arable land maximum data', uvalue = 'outputFileName1', $
        default = '', /auto)

    
    ;Display Dialog
    baseclass = auto_wid_mng(base)
    If baseclass.accept ne 1 Then Begin
        return
    EndIf

    ;Get input data
    inputFileName1 = baseclass.inputFileName1
    inputFileName2 = baseclass.inputFileName2
    inputFileName3 = baseclass.inputFileName3
    inputFileName4 = baseclass.inputFileName4
    inputFileName5 = baseclass.inputFileName5
    inputFileName6 = baseclass.inputFileName6
    inputFileName7 = baseclass.inputFileName7    
    
    outputFileName1 = baseclass.outputFileName1
    
    ;;;;;Call the function of Multiple sets of Arable land data maximum output_Seven sets of products
    functionResult = funcCalCroplandMaximumValueWithSeven(inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        inputFileName7, outputFileName1)
    if functionResult eq 0 then begin
        result = dialog_message('Error', /ERROR)
        return
    end

    p = DIALOG_MESSAGE('Done', /INFORMATION)

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Call the function of Multiple sets of Arable land data maximum output_Seven sets of products
function funcCalCroplandMaximumValueWithSeven, inputFileName1, inputFileName2, $
        inputFileName3, inputFileName4, $
        inputFileName5, inputFileName6, $
        inputFileName7, outputFileName1
        
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Delete the file with outputFileName
    proDeleteFile, file_name = outputFileName1

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Read seven sets of Arable land product data
    ENVI_OPEN_FILE, inputFileName1, r_fid = fid1
    if fid1 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR) 
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName2, r_fid = fid2
    if fid2 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName3, r_fid = fid3
    if fid3 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName4, r_fid = fid4
    if fid4 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif

    ENVI_OPEN_FILE, inputFileName5, r_fid = fid5
    if fid5 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName6, r_fid = fid6
    if fid6 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif
    
    ENVI_OPEN_FILE, inputFileName7, r_fid = fid7
    if fid7 eq -1 then begin
        result = DIALOG_MESSAGE('Error', /ERROR)
        return, 0
    endif    

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Get information such as the number of data rows and columns
    ENVI_FILE_QUERY, fid1, dims = dims1, nb = nb1, ns = ns1, nl = nl1, data_type = data_type1
    
    ENVI_FILE_QUERY, fid2, dims = dims2, nb = nb2, ns = ns2, nl = nl2, data_type = data_type2
    
    ENVI_FILE_QUERY, fid3, dims = dims3, nb = nb3, ns = ns3, nl = nl3, data_type = data_type3
   
    ENVI_FILE_QUERY, fid4, dims = dims4, nb = nb4, ns = ns4, nl = nl4, data_type = data_type4

    ENVI_FILE_QUERY, fid5, dims = dims5, nb = nb5, ns = ns5, nl = nl5, data_type = data_type5
    
    ENVI_FILE_QUERY, fid6, dims = dims6, nb = nb6, ns = ns6, nl = nl6, data_type = data_type6
    
    ENVI_FILE_QUERY, fid7, dims = dims7, nb = nb7, ns = ns7, nl = nl7, data_type = data_type7    
    
    ;;Is the minimum value of the rows and columns of all products
    fileCount = 7
    nsArray = LONARR(fileCount)
    nsArray[0] = ns1
    nsArray[1] = ns2
    nsArray[2] = ns3
    nsArray[3] = ns4
    nsArray[4] = ns5
    nsArray[5] = ns6
    nsArray[6] = ns7
    
    nsStd = min(nsArray, max = maxValue)
    
    nlArray = LONARR(fileCount)
    nlArray[0] = nl1
    nlArray[1] = nl2
    nlArray[2] = nl3
    nlArray[3] = nl4
    nlArray[4] = nl5
    nlArray[5] = nl6
    nlArray[6] = nl7
    
    nlStd = min(nlArray, max = maxValue)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Create a new file for output
    OPENW, unit1, outputFileName1, /get_lun

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Traverse all pixels, calculate the unique value of Administrative division code and synergy category
    tileSample = 500000LL
    tileLine = 1LL
    
    tileSampleCount = ceil(nsStd / double(tileSample))
    tileLineCount = ceil(nlStd / double(tileLine))
    tileCount = tileSampleCount * tileLineCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Progress Bar
    ENVI_REPORT_INIT, ['Multiple sets of Arable land data maximum output'], title = 'Multiple sets of Arable land data maximum output', base = base
    ENVI_REPORT_INC, base, tileCount
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Iterate each block, To sort
    fidArray = LONARR(fileCount)
    fidArray[0] = fid1
    fidArray[1] = fid2
    fidArray[2] = fid3
    fidArray[3] = fid4
    fidArray[4] = fid5
    fidArray[5] = fid6
    fidArray[6] = fid7
    
    for i = 0LL, tileSampleCount - 1 do begin
        for j = 0LL, tileLineCount - 1 do begin
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Determine the current block range
            tileStartSample = i * tileSample
            tileEndSample = tileStartSample + tileSample - 1
            if tileEndSample gt nsStd then begin
                tileEndSample = nsStd - 1
            endif
            
            tileStartLine = j * tileLine
            tileEndLine = tileStartLine + tileLine - 1
            if tileEndLine gt nlStd then begin
                tileEndLine = nlStd - 1
            endif
            
            ;;Get the first Arable land data
            dims1[1] = tileStartSample
            dims1[2] = tileEndSample
            dims1[3] = tileStartLine
            dims1[4] = tileEndLine

            tileData1 = ENVI_GET_DATA(fid = fid1, dims = dims1, pos = 0)
            resultData1 = tileData1
            
            ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Find the maximum value by comparison
            for m = 0LL, fileCount - 2 do begin
                if m eq 0 then begin
                    curFid1 = fidArray[m]
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid1, dims = curDims1
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims1[1] = tileStartSample
                    curDims1[2] = tileEndSample
                    curDims1[3] = tileStartLine
                    curDims1[4] = tileEndLine
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine
                    
                    curTileData1 = ENVI_GET_DATA(fid = curFid1, dims = curDims1, pos = 0)
                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0) 
                                   
                    resultData1 = curTileData1
                    curData = curTileData2
                endif else begin
                    curFid2 = fidArray[m+1]
                    
                    ENVI_FILE_QUERY, curFid2, dims = curDims2
                    
                    curDims2[1] = tileStartSample
                    curDims2[2] = tileEndSample
                    curDims2[3] = tileStartLine
                    curDims2[4] = tileEndLine

                    curTileData2 = ENVI_GET_DATA(fid = curFid2, dims = curDims2, pos = 0)                 
                
                    curData = curTileData2
                endelse

                tempDataFlag = resultData1 - curData
                
                index = where(tempDataFlag lt 0.0, count)
                if count gt 0 then begin
                    resultData1[index] = curData[index]
                endif
            endfor
            
            writeu, unit1, resultData1
            
            ;Progress bar, showing the calculation progress of change intensity
            ENVI_REPORT_STAT, base, i * tileSampleCount + j, tileCount
        endfor
    endfor
    
    ;;Free memory
    FREE_LUN, unit1
    
    ;;Write output file infomation
    map_info1 = ENVI_GET_MAP_INFO(fid = fid1)
    
    ENVI_SETUP_HEAD, fname = outputFileName1, ns = nsStd, nl = nlStd, nb = nb1, $
    data_type = data_type1, offset = 0, interleave = 0, $
    xstart = 0, ystart = 0, $
    descrip = 'Multiple sets of Arable land data maximum output', $
    map_info = map_info1, $
    /write, /open
    
    ;Read the output file into memory and return r_FID
    ENVI_OPEN_FILE, outputFileName1, r_fid = r_fid1
    if r_fid1 eq -1 then begin
        result = dialog_message('Error', /ERROR)
        return, 0
    end
    
    ;End progress bar
    ENVI_REPORT_INIT, base = base, /finish

    return, 1
end

