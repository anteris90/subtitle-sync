param([switch]$NoBrowser)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:SelectedMkv = $null
$script:MkvMerge = $null
$script:MkvExtract = $null
$script:Ffsubsync = $null
$script:Ffmpeg = $null
$script:Python = $null
$script:TextModelReady = $false
$script:ConfigPath = Join-Path $env:LOCALAPPDATA 'SubtitleSync\settings.json'

function Send-Json($Context, $Data, [int]$Code = 200) {
  $bytes = [Text.Encoding]::UTF8.GetBytes(($Data | ConvertTo-Json -Depth 6 -Compress))
  $Context.Response.StatusCode = $Code
  $Context.Response.ContentType = 'application/json; charset=utf-8'
  $Context.Response.ContentLength64 = $bytes.Length
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.Close()
}

function Send-File($Context, $Path) {
  $bytes = [IO.File]::ReadAllBytes($Path)
  $Context.Response.ContentType = if ($Path.EndsWith('.html')) {'text/html; charset=utf-8'} else {'text/plain; charset=utf-8'}
  $Context.Response.ContentLength64 = $bytes.Length
  $Context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $Context.Response.Close()
}

function Set-ToolPaths($ToolPath) {
  $folder = Split-Path -Parent $ToolPath
  $script:MkvMerge = Join-Path $folder 'mkvmerge.exe'
  $script:MkvExtract = Join-Path $folder 'mkvextract.exe'
  if (!(Test-Path -LiteralPath $script:MkvMerge) -or !(Test-Path -LiteralPath $script:MkvExtract)) { throw 'The selected folder must contain both mkvmerge.exe and mkvextract.exe.' }
}

function Save-ToolPaths {
  $folder = Split-Path -Parent $script:ConfigPath
  New-Item -ItemType Directory -Force -Path $folder | Out-Null
  @{ mkvMerge=$script:MkvMerge; mkvExtract=$script:MkvExtract; ffsubsync=$script:Ffsubsync; ffmpeg=$script:Ffmpeg; python=$script:Python; textModelReady=$script:TextModelReady } | ConvertTo-Json | Set-Content -LiteralPath $script:ConfigPath -Encoding UTF8
}

function Load-SavedTools {
  if (!(Test-Path -LiteralPath $script:ConfigPath)) { return }
  try {
    $saved = Get-Content -LiteralPath $script:ConfigPath -Raw | ConvertFrom-Json
    if ($saved.mkvMerge -and $saved.mkvExtract) { $script:MkvMerge = $saved.mkvMerge; $script:MkvExtract = $saved.mkvExtract }
    if ($saved.ffsubsync) { $script:Ffsubsync = $saved.ffsubsync }
    if ($saved.ffmpeg) { $script:Ffmpeg = $saved.ffmpeg }
    if ($saved.python -and (Test-Path -LiteralPath $saved.python)) { $script:Python = $saved.python }
    $script:TextModelReady = [bool]$saved.textModelReady
  } catch { $script:MkvMerge = $null; $script:MkvExtract = $null; $script:Ffsubsync = $null; $script:Ffmpeg = $null }
}

function Get-ToolStatus {
  if (!$script:MkvMerge -or !$script:MkvExtract) { return @{ configured=$false; message='MKVToolNix has not been configured. Select mkvmerge.exe first.' } }
  $mergeOk = Test-Path -LiteralPath $script:MkvMerge
  $extractOk = Test-Path -LiteralPath $script:MkvExtract
  if (!$mergeOk -or !$extractOk) { return @{ configured=$false; message='The saved MKVToolNix location is no longer valid. The files may have been moved or removed.'; mkvMerge=$script:MkvMerge; mkvExtract=$script:MkvExtract } }
  return @{ configured=$true; message='MKVToolNix is ready.'; folder=(Split-Path -Parent $script:MkvMerge) }
}

# The server process is started behind the browser. Give OpenFileDialog a tiny
# topmost owner so the picker is always visible instead of opening behind it.
function Show-OpenDialog($Dialog) {
  $owner = New-Object System.Windows.Forms.Form
  $owner.Text = 'Subtitle Sync'
  $owner.Size = New-Object Drawing.Size(1, 1)
  $owner.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
  $owner.ShowInTaskbar = $false
  $owner.Opacity = 0
  $owner.TopMost = $true
  try { $owner.Show(); return $Dialog.ShowDialog($owner) } finally { $owner.Close(); $owner.Dispose() }
}

function Ensure-Tools {
  if ((Get-ToolStatus).configured) { return }
  throw 'MKVToolNix is not available. Use the separate MKVToolNix location button in the app, then try again.'
}

function Choose-Tools {
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = 'Select the MKVToolNix mkvmerge.exe file'
  $dialog.Filter = 'mkvmerge.exe|mkvmerge.exe|Programok (*.exe)|*.exe'
  $dialog.RestoreDirectory = $true
  if ((Show-OpenDialog $dialog) -ne [System.Windows.Forms.DialogResult]::OK) { throw 'MKVToolNix selection was cancelled.' }
  Set-ToolPaths $dialog.FileName
  Save-ToolPaths
  return (Get-ToolStatus)
}

function Install-MkvToolNix {
  $installer = Join-Path ([IO.Path]::GetTempPath()) ('mkvtoolnix-' + [guid]::NewGuid().ToString() + '-setup.exe')
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $downloadPage = Invoke-WebRequest -UseBasicParsing 'https://mkvtoolnix.download/downloads.html'
    $match = [regex]::Match($downloadPage.Content, 'href="(?<url>[^"]*mkvtoolnix-64-bit-[^"]*-setup\.exe)"', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (!$match.Success) { throw 'Could not find the current official MKVToolNix Windows installer.' }
    $downloadUrl = $match.Groups['url'].Value -replace '&amp;', '&'
    if (!$downloadUrl.StartsWith('http')) { $downloadUrl = 'https://mkvtoolnix.download/' + $downloadUrl.TrimStart('/') }
    Invoke-WebRequest -UseBasicParsing -Uri $downloadUrl -OutFile $installer
    if (!(Test-Path -LiteralPath $installer) -or (Get-Item -LiteralPath $installer).Length -lt 1000000) { throw 'The MKVToolNix installer download was incomplete.' }
    $process = Start-Process -FilePath $installer -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'MKVToolNix installation was cancelled or did not complete.' }
    $standard = 'C:\Program Files\MKVToolNix\mkvmerge.exe'
    if (!(Test-Path -LiteralPath $standard)) { throw 'MKVToolNix was installed, but mkvmerge.exe was not found in its standard location. Use Set MKVToolNix location to select it.' }
    Set-ToolPaths $standard
    Save-ToolPaths
    return (Get-ToolStatus)
  } finally {
    if (Test-Path -LiteralPath $installer) { Remove-Item -LiteralPath $installer -Force }
  }
}

function Get-AutoSyncStatus {
  if (!$script:Ffsubsync) { return @{ configured=$false; message='ffsubsync has not been configured. Select its local executable first.' } }
  if (!(Test-Path -LiteralPath $script:Ffsubsync)) { return @{ configured=$false; message='The saved ffsubsync location is no longer valid. The file may have been moved or removed.'; path=$script:Ffsubsync } }
  if (!$script:Ffmpeg -or !(Test-Path -LiteralPath $script:Ffmpeg)) { return @{ configured=$false; message='ffmpeg is missing. Use the automatic installer to add the local audio engine.'; path=$script:Ffsubsync } }
  return @{ configured=$true; message='ffsubsync and ffmpeg are ready.'; path=$script:Ffsubsync }
}

function Get-TextSyncStatus {
  if (!$script:Python -or !(Test-Path -LiteralPath $script:Python)) {
    $python = Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1
    if ($python) { $script:Python = $python.Source; Save-ToolPaths }
  }
  if (!$script:Python) { return @{ configured=$false; message='Python is not available. Install the sync engine first, then install the local text model.' } }
  if (!$script:TextModelReady) { return @{ configured=$false; message='The local multilingual text model has not been installed.'; path=$script:Python } }
  return @{ configured=$true; message='The local multilingual text model is ready.'; path=$script:Python; model='paraphrase-multilingual-MiniLM-L12-v2' }
}

function Enable-Ffmpeg {
  if ($script:Ffmpeg -and (Test-Path -LiteralPath $script:Ffmpeg)) {
    $folder = Split-Path -Parent $script:Ffmpeg
    if (($env:PATH -split ';') -notcontains $folder) { $env:PATH = $folder + ';' + $env:PATH }
  }
}

function Choose-AutoSyncTool {
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = 'Select the local ffsubsync executable'
  $dialog.Filter = 'ffsubsync executable|ffsubsync.exe;ffs.exe|Programs (*.exe)|*.exe|All files|*.*'
  $dialog.RestoreDirectory = $true
  if ((Show-OpenDialog $dialog) -ne [System.Windows.Forms.DialogResult]::OK) { throw 'ffsubsync selection was cancelled.' }
  $script:Ffsubsync = $dialog.FileName
  Save-ToolPaths
  return (Get-AutoSyncStatus)
}

function Install-AutoSyncTool {
  $python = @(Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1)
  if (!$python) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (!$winget) { throw 'Python is not installed and Windows Package Manager (winget) is unavailable. Install Python 3.11 or newer, then try again.' }
    try { [void](Run-Tool $winget.Source '--version'); [void](Run-Tool $winget.Source 'install --id Python.Python.3.11 -e --accept-package-agreements --accept-source-agreements') }
    catch { throw 'Windows Package Manager is not available on this PC. Install Python 3.11 or newer manually, then use this button again.' }
    $python = @(Get-Command python.exe -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1)
    if (!$python) { throw 'Python was installed, but its executable is not available yet. Close the app, open it again, and retry.' }
  }
  $script:Python = $python[0].Source
  [void](Run-Tool $python.Source '-m pip install --user --upgrade ffsubsync imageio-ffmpeg')
  $scriptsFolder = (Run-Tool $python.Source '-c "import sysconfig; print(sysconfig.get_path(\"scripts\", scheme=\"nt_user\"))"').Trim()
  $candidate = Join-Path $scriptsFolder 'ffsubsync.exe'
  if (!(Test-Path -LiteralPath $candidate)) { throw 'ffsubsync was installed, but its executable could not be found. Use Set ffsubsync location to select it manually.' }
  $ffmpegCandidate = (Run-Tool $python.Source '-c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"').Trim()
  if (!(Test-Path -LiteralPath $ffmpegCandidate)) { throw 'ffmpeg could not be installed. Retry the automatic installer.' }
  $ffmpegFolder = Join-Path (Split-Path -Parent $script:ConfigPath) 'bin'
  New-Item -ItemType Directory -Force -Path $ffmpegFolder | Out-Null
  $ffmpegShim = Join-Path $ffmpegFolder 'ffmpeg.exe'
  Copy-Item -LiteralPath $ffmpegCandidate -Destination $ffmpegShim -Force
  $script:Ffsubsync = $candidate
  $script:Ffmpeg = $ffmpegShim
  Enable-Ffmpeg
  Save-ToolPaths
  return (Get-AutoSyncStatus)
}

function Install-TextSyncModel {
  $status = Get-TextSyncStatus
  if (!$script:Python) { throw $status.message }
  $script:TextModelReady = $false
  [void](Run-Tool $script:Python '-m pip install --user --upgrade sentence-transformers')
  $modelScript = Join-Path $root 'text_alignment.py'
  [void](Run-Tool $script:Python ((Quote-Arg $modelScript) + ' install'))
  $script:TextModelReady = $true
  Save-ToolPaths
  return (Get-TextSyncStatus)
}

function Run-Tool($Exe, [string]$Arguments) {
  $p = New-Object Diagnostics.Process
  $p.StartInfo.FileName = $Exe; $p.StartInfo.Arguments = $Arguments
  $p.StartInfo.UseShellExecute = $false; $p.StartInfo.RedirectStandardOutput = $true; $p.StartInfo.RedirectStandardError = $true; $p.StartInfo.CreateNoWindow = $true
  [void]$p.Start(); $stdoutTask = $p.StandardOutput.ReadToEndAsync(); $stderrTask = $p.StandardError.ReadToEndAsync(); $p.WaitForExit(); $stdout = $stdoutTask.Result; $stderr = $stderrTask.Result
  if ($p.ExitCode -ne 0) { throw ($stderr.Trim()) }
  return $stdout
}

function Quote-Arg([string]$Value) { '"' + $Value.Replace('"','\"') + '"' }

function Pick-Mkv {
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = 'Select MKV file'; $dialog.Filter = 'Matroska video (*.mkv)|*.mkv|All files|*.*'
  $dialog.RestoreDirectory = $true
  if ((Show-OpenDialog $dialog) -ne [System.Windows.Forms.DialogResult]::OK) { throw 'MKV selection was cancelled.' }
  $script:SelectedMkv = $dialog.FileName
  Ensure-Tools
  $info = (Run-Tool $script:MkvMerge ('-J ' + (Quote-Arg $script:SelectedMkv))) | ConvertFrom-Json
  $tracks = @($info.tracks | Where-Object { $_.type -eq 'subtitles' } | ForEach-Object { @{ id=$_.id; language=$_.properties.language; name=$_.properties.track_name; codec=$_.codec } })
  if (!$tracks.Count) { throw 'No subtitle tracks were found in this MKV.' }
  return @{ name=(Split-Path -Leaf $script:SelectedMkv); tracks=$tracks }
}

function Read-SubtitleText($Path) {
  $reader = New-Object IO.StreamReader($Path, $true)
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Run-AutoSync($Request) {
  if (!$script:SelectedMkv) { throw 'Select the MKV video first.' }
  if (!(Get-AutoSyncStatus).configured) { throw 'ffsubsync is not available. Set its location in the app first.' }
  if (!$Request.srtText) { throw 'Load a subtitle to correct first.' }
  $input = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-sync-input-' + [guid]::NewGuid().ToString() + '.srt')
  $output = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-sync-output-' + [guid]::NewGuid().ToString() + '.srt')
  try {
    # Preserve Hungarian characters: make the temporary file unambiguously UTF-8
    # and keep ffsubsync from guessing a legacy Windows code page.
    [IO.File]::WriteAllText($input, [string]$Request.srtText, [Text.UTF8Encoding]::new($true))
    [void](Run-Tool $script:Ffsubsync ((Quote-Arg $script:SelectedMkv) + ' -i ' + (Quote-Arg $input) + ' -o ' + (Quote-Arg $output) + ' --encoding utf-8 --output-encoding utf-8'))
    if (!(Test-Path -LiteralPath $output)) { throw 'ffsubsync finished without creating an output SRT.' }
    return @{ name='auto-synced-subtitle.srt'; text=(Read-SubtitleText $output) }
  } finally {
    if (Test-Path -LiteralPath $input) { Remove-Item -LiteralPath $input -Force }
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }
  }
}

function Run-ReferenceSync($Request) {
  if (!(Get-AutoSyncStatus).configured) { throw 'ffsubsync is not available. Set its location in the app first.' }
  if (!$Request.referenceText) { throw 'Load a reference subtitle first.' }
  if (!$Request.srtText) { throw 'Load a subtitle to correct first.' }
  $referencePath = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-sync-reference-' + [guid]::NewGuid().ToString() + '.srt')
  $targetPath = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-sync-target-' + [guid]::NewGuid().ToString() + '.srt')
  $outputPath = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-sync-reference-output-' + [guid]::NewGuid().ToString() + '.srt')
  try {
    $utf8 = [Text.UTF8Encoding]::new($true)
    [IO.File]::WriteAllText($referencePath, [string]$Request.referenceText, $utf8)
    [IO.File]::WriteAllText($targetPath, [string]$Request.srtText, $utf8)
    $arguments = (Quote-Arg $referencePath) + ' -i ' + (Quote-Arg $targetPath) + ' -o ' + (Quote-Arg $outputPath) + ' --encoding utf-8 --reference-encoding utf-8 --output-encoding utf-8 --split-penalty 3'
    [void](Run-Tool $script:Ffsubsync $arguments)
    if (!(Test-Path -LiteralPath $outputPath)) { throw 'ffsubsync finished without creating an output SRT.' }
    return @{ name='reference-synced-subtitle.srt'; text=(Read-SubtitleText $outputPath) }
  } finally {
    foreach ($path in @($referencePath, $targetPath, $outputPath)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
  }
}

function Run-TextSync($Request) {
  if (!(Get-TextSyncStatus).configured) { throw 'Install the local multilingual text model first.' }
  if (!$Request.referenceText) { throw 'Load a reference subtitle first.' }
  if (!$Request.srtText) { throw 'Load a subtitle to correct first.' }
  $referencePath = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-text-reference-' + [guid]::NewGuid().ToString() + '.srt')
  $targetPath = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-text-target-' + [guid]::NewGuid().ToString() + '.srt')
  $outputPath = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-text-output-' + [guid]::NewGuid().ToString() + '.srt')
  try {
    $utf8 = [Text.UTF8Encoding]::new($true)
    [IO.File]::WriteAllText($referencePath, [string]$Request.referenceText, $utf8)
    [IO.File]::WriteAllText($targetPath, [string]$Request.srtText, $utf8)
    $modelScript = Join-Path $root 'text_alignment.py'
    $arguments = (Quote-Arg $modelScript) + ' align ' + (Quote-Arg $referencePath) + ' ' + (Quote-Arg $targetPath) + ' ' + (Quote-Arg $outputPath)
    $summary = (Run-Tool $script:Python $arguments) | ConvertFrom-Json
    if (!(Test-Path -LiteralPath $outputPath)) { throw 'The local text model did not create an output SRT.' }
    return @{ name='text-synced-subtitle.srt'; text=(Read-SubtitleText $outputPath); matchedGroups=$summary.matchedGroups; anchors=$summary.anchors; averageSimilarity=$summary.averageSimilarity }
  } finally {
    foreach ($path in @($referencePath, $targetPath, $outputPath)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force } }
  }
}

Load-SavedTools
Enable-Ffmpeg

$listener = New-Object Net.HttpListener
$listener.Prefixes.Add('http://127.0.0.1:8765/')
try { $listener.Start() } catch { throw 'Local port 8765 is already in use. Close an earlier Subtitle Sync window and try again.' }
if (!$NoBrowser) { Start-Process "http://127.0.0.1:8765/" }
Write-Host 'Subtitle Sync local server: http://127.0.0.1:8765/'
while ($listener.IsListening) {
  $ctx = $listener.GetContext(); $path = $ctx.Request.Url.AbsolutePath
  try {
    if ($path -eq '/' -or $path -eq '/index.html') { Send-File $ctx (Join-Path $root 'index.html') }
    elseif ($path -eq '/api/tool-status') { Send-Json $ctx (Get-ToolStatus) }
    elseif ($path -eq '/api/select-tools') { Send-Json $ctx (Choose-Tools) }
    elseif ($path -eq '/api/install-mkvtoolnix') { Send-Json $ctx (Install-MkvToolNix) }
    elseif ($path -eq '/api/autosync-status') { Send-Json $ctx (Get-AutoSyncStatus) }
    elseif ($path -eq '/api/textsync-status') { Send-Json $ctx (Get-TextSyncStatus) }
    elseif ($path -eq '/api/install-textsync') { Send-Json $ctx (Install-TextSyncModel) }
    elseif ($path -eq '/api/select-autosync') { Send-Json $ctx (Choose-AutoSyncTool) }
    elseif ($path -eq '/api/install-autosync') { Send-Json $ctx (Install-AutoSyncTool) }
    elseif ($path -eq '/api/select-mkv') { Send-Json $ctx (Pick-Mkv) }
    elseif ($path -eq '/api/autosync') {
      # Browser requests are UTF-8 JSON. Do not use Windows' legacy default code page.
      $body = [IO.StreamReader]::new($ctx.Request.InputStream, [Text.Encoding]::UTF8, $true); $request = ($body.ReadToEnd() | ConvertFrom-Json); $body.Dispose()
      Send-Json $ctx (Run-AutoSync $request)
    }
    elseif ($path -eq '/api/autosync-reference') {
      $body = [IO.StreamReader]::new($ctx.Request.InputStream, [Text.Encoding]::UTF8, $true); $request = ($body.ReadToEnd() | ConvertFrom-Json); $body.Dispose()
      Send-Json $ctx (Run-ReferenceSync $request)
    }
    elseif ($path -eq '/api/textsync') {
      $body = [IO.StreamReader]::new($ctx.Request.InputStream, [Text.Encoding]::UTF8, $true); $request = ($body.ReadToEnd() | ConvertFrom-Json); $body.Dispose()
      Send-Json $ctx (Run-TextSync $request)
    }
    elseif ($path -eq '/api/extract') {
      if (!$script:SelectedMkv) { throw 'Select an MKV file first.' }
      $body = New-Object IO.StreamReader($ctx.Request.InputStream, $ctx.Request.ContentEncoding); $request = ($body.ReadToEnd() | ConvertFrom-Json); $body.Dispose()
      $temp = Join-Path ([IO.Path]::GetTempPath()) ('subtitle-sync-' + [guid]::NewGuid().ToString() + '.srt')
      try { [void](Run-Tool $script:MkvExtract ('tracks ' + (Quote-Arg $script:SelectedMkv) + ' ' + $request.trackId + ':' + (Quote-Arg $temp))); Send-Json $ctx @{ name=((Split-Path -Leaf $script:SelectedMkv) + '.track' + $request.trackId + '.srt'); text=(Read-SubtitleText $temp) } } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
    } else { Send-Json $ctx @{error='Unknown local endpoint.'} 404 }
  } catch { Send-Json $ctx @{error=$_.Exception.Message} 400 }
}
