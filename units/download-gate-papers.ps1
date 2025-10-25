<#
Download helper for GATE CS papers (2021-2025).

How it works:
- The script downloads the official download pages we found (IIT Guwahati year-wise page and IIT Roorkee pages) and scans them for PDF links that look like Computer / CS papers.
- It will try to fetch any PDF whose link text or URL contains 'CS' or 'Computer' (case-insensitive).
- Some official organizers host PDFs on remote servers or Google Drive; the script will attempt to download any direct .pdf links it finds.

Run this script from PowerShell (Windows) inside the repository, e.g.:
  cd "c:\Users\sande\OneDrive\Desktop\bhumi\units"
  .\download-gate-papers.ps1

Notes:
- The script is conservative: it only downloads links that end with .pdf and include 'CS' or 'Computer' in the URL or link text.
- If an organizer uses a Google Drive folder (no direct pdf links rendered), you'll need to either download manually from the Drive UI or update the script with direct file IDs.
- Review downloaded files in `gate-papers` and remove any unwanted files.
#>

Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$outDir = Join-Path $scriptRoot 'gate-papers'
if(-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$officialPages = @(
    'https://gate2026.iitg.ac.in/download.html',   # IIT Guwahati (year-wise listing + bulk drive link)
    'https://gate2025.iitr.ac.in/download.html',   # IIT Roorkee (2025 downloads)
    'https://gate2025.iitr.ac.in/question-papers.html'
)

Write-Host "Will scan the following pages for .pdf links that mention 'CS' or 'Computer':" -ForegroundColor Cyan
$officialPages | ForEach-Object { Write-Host " - $_" }

$allPdfUrls = @()
foreach($page in $officialPages){
    try{
        Write-Host "Fetching: $page" -ForegroundColor Yellow
        $resp = Invoke-WebRequest -Uri $page -UseBasicParsing -ErrorAction Stop
        $links = @()
        # Use the parsed Links collection if available
        if($resp.Links){
            $links = $resp.Links | Where-Object { $_.href -and ($_.href -match '\.pdf$') } | ForEach-Object {
                [pscustomobject]@{ href = $_.href; text = ($_.innerText -join ' ').Trim() }
            }
        } else {
            # Fallback: regex search for .pdf URLs in raw HTML
            $matches = [regex]::Matches($resp.Content, 'href\s*=\s*"([^"]+?\.pdf)"', 'IgnoreCase')
            foreach($m in $matches){ $links += [pscustomobject]@{ href = $m.Groups[1].Value; text = '' } }
        }

        foreach($l in $links){
            $href = $l.href
            $text = $l.text
            if( ($href -match 'CS' -or $href -match 'Computer' -or $text -match 'CS' -or $text -match 'Computer') -and ($href -match '\.pdf$') ){
                # Resolve relative URLs
                if($href -notmatch '^https?://'){
                    $base = (New-Object System.Uri($page))
                    $abs = (New-Object System.Uri($base, $href)).AbsoluteUri
                } else { $abs = $href }
                $allPdfUrls += $abs
            }
        }

    }catch{
        Write-Warning "Failed to fetch or parse $page : $_"
    }
}

$allPdfUrls = $allPdfUrls | Sort-Object -Unique
if(-not $allPdfUrls -or $allPdfUrls.Count -eq 0){
    Write-Warning "No direct PDF links matching filter were found. \n- If the site provides a Google Drive folder, open it in a browser and download manually.\n- You can also edit this script and add direct PDF URLs to the `\$manualUrls` array." -ForegroundColor Red
}

# Optional manual URLs you can paste here if you have direct pdf links
$manualUrls = @(
    # Example: 'https://example.org/gate-cs-2025.pdf'
)

$allPdfUrls += $manualUrls

foreach($u in $allPdfUrls){
    try{
        $uri = [System.Uri]$u
        $fileName = [System.IO.Path]::GetFileName($uri.LocalPath)
        $outPath = Join-Path $outDir $fileName
        if(Test-Path $outPath){ Write-Host "Skipping (exists): $fileName" -ForegroundColor Gray; continue }
        Write-Host "Downloading: $u -> $fileName" -ForegroundColor Green
        Invoke-WebRequest -Uri $u -OutFile $outPath -UseBasicParsing -ErrorAction Stop
    }catch{
        Write-Warning "Failed to download $u : $_"
    }
}

Write-Host "Done. Check the folder: $outDir" -ForegroundColor Cyan
Write-Host "If you want me to attempt to add direct file URLs into this script, reply and I will try to extract direct links for each year (may need manual Drive file-ids)." -ForegroundColor Yellow
