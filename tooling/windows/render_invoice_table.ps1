param(
  [Parameter(Mandatory = $true)][string]$TemplatePath,
  [Parameter(Mandatory = $true)][string]$PayloadPath,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [string]$RenderMode = 'table'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$xlEdgeLeft = 7
$xlEdgeTop = 8
$xlEdgeBottom = 9
$xlEdgeRight = 10
$xlInsideVertical = 11
$xlInsideHorizontal = 12
$xlCenter = -4108
$xlRight = -4152
$xlNone = -4142
$xlContinuous = 1
$xlDouble = -4119
$xlThin = 2
$xlThick = 4
$xlPasteFormats = -4122
$xlPasteColumnWidths = 8

$excel = $null
$workbook = $null
$worksheet = $null
function Release-ComObject($value) {
  if ($null -ne $value) {
    try {
      [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($value)
    } catch {
    }
  }
}

function Set-CellText($cell, [string]$text) {
  $cell.NumberFormat = "@"
  if ([string]::IsNullOrEmpty($text)) {
    $cell.Value2 = ''
  } else {
    $cell.Value2 = "'$text"
  }
}

try {
  $payload = Get-Content -Raw -LiteralPath $PayloadPath | ConvertFrom-Json
  $rows = @($payload.rows)
  $summaryValues = $null
  if ($payload.PSObject.Properties.Name -contains 'summaryValues') {
    $summaryValues = $payload.summaryValues
  }
  $rowCount = [Math]::Max(1, [int]$payload.rowCount)
  $firstDataRow = 6
  $summaryStartRow = 21
  $baseTemplateRows = $summaryStartRow - $firstDataRow
  $extraRows = 0

  $excel = New-Object -ComObject Excel.Application
  $excel.Visible = $false
  $excel.DisplayAlerts = $false
  $excel.ScreenUpdating = $false
  try {
    $excel.ErrorCheckingOptions.BackgroundChecking = $false
  } catch {
  }

  $workbook = $excel.Workbooks.Open($TemplatePath)
  $worksheet = $workbook.Worksheets.Item(1)

  if ($rowCount -gt $baseTemplateRows) {
    $extraRows = $rowCount - $baseTemplateRows
    for ($extraIndex = 0; $extraIndex -lt $extraRows; $extraIndex++) {
      $insertRow = $summaryStartRow + $extraIndex
      $worksheet.Rows.Item($insertRow).Insert()
      $worksheet.Range('A20:I20').Copy() | Out-Null
      $worksheet.Range("A$insertRow:I$insertRow").PasteSpecial($xlPasteFormats) | Out-Null
      $worksheet.Range("A$insertRow:I$insertRow").PasteSpecial($xlPasteColumnWidths) | Out-Null
      $worksheet.Rows.Item($insertRow).RowHeight = $worksheet.Rows.Item(20).RowHeight
    }
  }

  $lastDataRow = $firstDataRow + $rowCount - 1
  $actualSummaryRow = $summaryStartRow + $extraRows
  $worksheet.Range("A${firstDataRow}:I$lastDataRow").ClearContents()
  $worksheet.Range("A${firstDataRow}:I$lastDataRow").NumberFormat = "@"

  $headerRange = $worksheet.Range("A5:I5")
  $headerRange.Interior.Pattern = $xlNone
  $headerRange.Font.Bold = $true
  $headerRange.Font.Color = 0
  $headerRange.HorizontalAlignment = $xlCenter
  $headerRange.VerticalAlignment = $xlCenter
  foreach ($borderIndex in @($xlEdgeLeft, $xlEdgeRight, $xlInsideVertical)) {
    $border = $headerRange.Borders.Item($borderIndex)
    $border.LineStyle = $xlContinuous
    $border.Weight = $xlThin
    $border.Color = 0
  }
  foreach ($borderIndex in @($xlEdgeTop, $xlEdgeBottom)) {
    $border = $headerRange.Borders.Item($borderIndex)
    $border.LineStyle = $xlDouble
    $border.Weight = $xlThick
    $border.Color = 0
  }

  $tableRange = $worksheet.Range("A5:I$lastDataRow")
  foreach ($borderIndex in @($xlEdgeLeft, $xlEdgeRight)) {
    $border = $tableRange.Borders.Item($borderIndex)
    $border.LineStyle = $xlContinuous
    $border.Weight = $xlThin
    $border.Color = 0
  }

  $bodyRange = $worksheet.Range("A${firstDataRow}:I$lastDataRow")
  foreach ($borderIndex in @($xlEdgeLeft, $xlEdgeRight, $xlEdgeBottom, $xlInsideVertical, $xlInsideHorizontal)) {
    $border = $bodyRange.Borders.Item($borderIndex)
    $border.LineStyle = $xlContinuous
    $border.Weight = $xlThin
    $border.Color = 0
  }

  for ($index = 0; $index -lt $rowCount; $index++) {
    $rowNumber = $firstDataRow + $index
    $source = if ($index -lt $rows.Count) { $rows[$index] } else { $null }

    $noValue = if ($null -ne $source) { [string]$source.no } else { '' }
    $tanggalValue = if ($null -ne $source) { [string]$source.tanggal } else { '' }
    $platValue = if ($null -ne $source) { [string]$source.plat } else { '' }
    $muatanValue = if ($null -ne $source) { [string]$source.muatan } else { '' }
    $muatValue = if ($null -ne $source) { [string]$source.muat } else { '' }
    $bongkarValue = if ($null -ne $source) { [string]$source.bongkar } else { '' }
    $tonaseValue = if ($null -ne $source) { [string]$source.tonase } else { '' }
    $hargaValue = if ($null -ne $source) { [string]$source.harga } else { '' }
    $totalValue = if ($null -ne $source) { [string]$source.total } else { '' }

    Set-CellText $worksheet.Cells.Item($rowNumber, 1) $noValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 2) $tanggalValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 3) $platValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 4) $muatanValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 5) $muatValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 6) $bongkarValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 7) $tonaseValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 8) $hargaValue
    Set-CellText $worksheet.Cells.Item($rowNumber, 9) $totalValue
  }

  $bodyRange.Interior.Pattern = $xlNone
  $bodyRange.Font.Color = 0
  $bodyRange.VerticalAlignment = $xlCenter
  $worksheet.Range("A${firstDataRow}:G$lastDataRow").HorizontalAlignment = $xlCenter
  $worksheet.Range("H${firstDataRow}:I$lastDataRow").HorizontalAlignment = $xlRight

  if ($null -ne $summaryValues) {
    if ($RenderMode -eq 'table_with_total') {
      Set-CellText $worksheet.Cells.Item($actualSummaryRow, 8) 'TOTAL BAYAR Rp.'
      Set-CellText $worksheet.Cells.Item($actualSummaryRow, 9) ([string]$summaryValues.total)
      $summaryLabelRange = $worksheet.Range("H$actualSummaryRow:H$actualSummaryRow")
      $summaryValueRange = $worksheet.Range("I$actualSummaryRow:I$actualSummaryRow")
      $summaryCombinedRange = $worksheet.Range("H$actualSummaryRow:I$actualSummaryRow")
    } else {
      Set-CellText $worksheet.Cells.Item($actualSummaryRow, 2) 'Hormat kami,'
      Set-CellText $worksheet.Cells.Item($actualSummaryRow, 8) 'SUBTOTAL Rp.'
      Set-CellText $worksheet.Cells.Item($actualSummaryRow + 1, 8) 'PPH 2% Rp.'
      Set-CellText $worksheet.Cells.Item($actualSummaryRow + 2, 8) 'TOTAL BAYAR Rp.'
      Set-CellText $worksheet.Cells.Item($actualSummaryRow, 9) ([string]$summaryValues.subtotal)
      Set-CellText $worksheet.Cells.Item($actualSummaryRow + 1, 9) ([string]$summaryValues.pph)
      Set-CellText $worksheet.Cells.Item($actualSummaryRow + 2, 9) ([string]$summaryValues.total)
      $summaryLabelRange = $worksheet.Range("H$actualSummaryRow:H$($actualSummaryRow + 2)")
      $summaryValueRange = $worksheet.Range("I$actualSummaryRow:I$($actualSummaryRow + 2)")
      $summaryCombinedRange = $worksheet.Range("H$actualSummaryRow:I$($actualSummaryRow + 2)")
    }

    $summaryLabelRange.HorizontalAlignment = $xlRight
    $summaryValueRange.HorizontalAlignment = $xlRight
    $summaryCombinedRange.VerticalAlignment = $xlCenter
    $summaryValueRange.WrapText = $false
    $summaryValueRange.ShrinkToFit = $false
    $summaryValueRange.AddIndent = $false
    $summaryValueRange.IndentLevel = 0
    $summaryValueRange.Font.Color = 0
    foreach ($offset in 0..2) {
      $valueCell = $worksheet.Cells.Item($actualSummaryRow + $offset, 9)
      $valueCell.HorizontalAlignment = $xlRight
      $valueCell.VerticalAlignment = $xlCenter
      $valueCell.WrapText = $false
      $valueCell.ShrinkToFit = $false
      $valueCell.AddIndent = $false
      $valueCell.IndentLevel = 0
    }
  }

  if ($RenderMode -eq 'summary') {
    $worksheet.PageSetup.PrintArea = "I$actualSummaryRow:I$($actualSummaryRow + 2)"
  } elseif ($RenderMode -eq 'table_with_total') {
    $worksheet.PageSetup.PrintArea = "A5:I$actualSummaryRow"
  } elseif ($RenderMode -eq 'table_with_summary') {
    $worksheet.PageSetup.PrintArea = "A5:I$($actualSummaryRow + 2)"
  } else {
    $worksheet.PageSetup.PrintArea = "A5:I$lastDataRow"
  }
  $worksheet.PageSetup.Orientation = 1
  $worksheet.PageSetup.Zoom = $false
  $worksheet.PageSetup.FitToPagesWide = 1
  $worksheet.PageSetup.FitToPagesTall = 1
  $worksheet.PageSetup.LeftMargin = $excel.InchesToPoints(0.05)
  $worksheet.PageSetup.RightMargin = $excel.InchesToPoints(0.05)
  $worksheet.PageSetup.TopMargin = $excel.InchesToPoints(0.05)
  $worksheet.PageSetup.BottomMargin = $excel.InchesToPoints(0.05)
  [void]$worksheet.ExportAsFixedFormat(0, $OutputPath)

  $workbook.Close($false)
  $excel.Quit()
} finally {
  Release-ComObject $worksheet
  if ($null -ne $workbook) {
    Release-ComObject $workbook
  }
  if ($null -ne $excel) {
    Release-ComObject $excel
  }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
