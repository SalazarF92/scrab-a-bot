param([ValidateSet('Capture','Video','All')][string]$Mode = 'All')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.Replace('\','/')
$visual = "$projectRoot/docs/visual"
$godot = 'F:/GODOT/Godot_v4.7.2-stable_win64_console.exe'
$ffmpeg = 'F:/video_test/node_modules/@remotion/compositor-win32-x64-msvc/ffmpeg.exe'
function Invoke-Olhudo([string]$Name,[string]$Extra,[string]$Arguments) {
    Start-Process -FilePath $godot -ArgumentList "--path $projectRoot --log-file $visual/olhudo-$Name.log --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 $Extra res://scenes/olhudo_showcase.tscn -- $Arguments" -WindowStyle Hidden -Wait
    if (Select-String -LiteralPath "$visual/olhudo-$Name.log" -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) { throw "Godot failed: $Name" }
}
if ($Mode -in @('All','Capture')) {
    Invoke-Olhudo 'verify' '' '--verify-olhudo'
    if (-not (Select-String -LiteralPath "$visual/olhudo-verify.log" -SimpleMatch 'Olhudo native integration:' -Quiet)) { throw 'Integration verification incomplete' }
    Invoke-Olhudo 'construction' '' '--capture-olhudo --construction --time=0'
    foreach ($sample in @(@('piscar','3.0'),@('junta-extremo','0.85'),@('carga','1.2'),@('laser','1.65'))) {
        Invoke-Olhudo $sample[0] '' "--capture-olhudo --time=$($sample[1])"
        Copy-Item -LiteralPath "$visual/olhudo-preview.png" -Destination "$visual/olhudo-$($sample[0]).png" -Force
    }
    Write-Output 'Olhudo: native integration and construction/pose captures complete.'
}
if ($Mode -in @('All','Video')) {
    $avi = "$visual/olhudo-preview.avi"
    Invoke-Olhudo 'video' "--write-movie $avi --quit-after 432" ''
    & $ffmpeg -y -loglevel error -i $avi -an -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p -movflags +faststart "$visual/olhudo-preview.mp4"
    if ($LASTEXITCODE -ne 0) { throw 'Video encoding failed' }
    Remove-Item -LiteralPath $avi
    Write-Output 'Olhudo: exported 7.2 seconds at 60 fps.'

    $attackAvi = "$visual/olhudo-ataque-preview.avi"
    Start-Process -FilePath $godot -ArgumentList "--path $projectRoot --log-file $visual/olhudo-ataque-video.log --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 --write-movie $attackAvi --quit-after 432 res://scenes/olhudo_attack_review.tscn" -WindowStyle Hidden -Wait
    if (Select-String -LiteralPath "$visual/olhudo-ataque-video.log" -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) { throw 'Attack recording failed' }
    & $ffmpeg -y -loglevel error -i $attackAvi -an -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p -movflags +faststart "$visual/olhudo-ataque-preview.mp4"
    if ($LASTEXITCODE -ne 0) { throw 'Attack encoding failed' }
    Remove-Item -LiteralPath $attackAvi
    Write-Output 'Olhudo: attack preview exported at normal speed and 25% slow motion.'
}
