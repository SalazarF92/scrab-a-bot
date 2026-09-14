param([ValidateSet('Verify','Capture','Video','All')][string]$Mode = 'All')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.Replace('\','/')
$godot = 'F:/GODOT/Godot_v4.7.2-stable_win64_console.exe'
$ffmpeg = 'F:/video_test/node_modules/@remotion/compositor-win32-x64-msvc/ffmpeg.exe'
$visual = "$projectRoot/docs/visual"
function Invoke-GodotVFX([string]$Scene,[string]$Name,[string]$Extra = '',[string]$UserArgs = '') {
    $log = "$visual/$Name.log"
    $arguments = "--path $projectRoot --log-file $log --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 60 $Extra res://scenes/$Scene.tscn"
    if ($UserArgs) { $arguments += " -- $UserArgs" }
    Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -Wait
    if (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) {
        throw "Godot reported an error in $log"
    }
}
if ($Mode -in @('Verify','All')) {
    Invoke-GodotVFX 'creature_vfx_review' 'vfx-integration' '' '--verify-vfx'
    if (-not (Select-String -LiteralPath "$visual/vfx-integration.log" -SimpleMatch 'VFX integration:' -Quiet)) {
        throw 'VFX integration checks did not complete'
    }
    Write-Output 'VFX pause, replay and action switching verified.'
}
if ($Mode -in @('Capture','All')) {
    foreach ($sample in @(@('carga','0.45'),@('pico','1.6'),@('cauda','2.65'),@('fim','3.15'))) {
        Invoke-GodotVFX 'creature_vfx_review' "vfx-$($sample[0])" '' "--capture-vfx --time=$($sample[1])"
        Copy-Item -LiteralPath "$visual/vfx-revisao.png" -Destination "$visual/vfx-$($sample[0]).png" -Force
    }
    Copy-Item -LiteralPath "$visual/vfx-pico.png" -Destination "$visual/vfx-revisao.png" -Force
    Write-Output 'VFX charge, peak, decay and final frames captured.'
}
if ($Mode -in @('Video','All')) {
    foreach ($job in @(@('creature_vfx_review','poderes-criaturas'),@('parafuseta_anim_showcase','parafuseta'),@('rato_morto_anim_showcase','rato_morto'))) {
        $name = $job[1]
        $avi = "$visual/$name-vfx.avi"
        Invoke-GodotVFX $job[0] "$name-video" "--write-movie $avi --quit-after 420"
        & $ffmpeg -y -loglevel error -i $avi -an -c:v libx264 -preset fast -crf 19 -pix_fmt yuv420p -movflags +faststart "$visual/$name-preview.mp4"
        if ($LASTEXITCODE -ne 0) { throw "Encoding failed: $name" }
        Remove-Item -LiteralPath $avi
        & $ffmpeg -y -loglevel error -ss 1.6 -i "$visual/$name-preview.mp4" -frames:v 1 "$visual/$name-preview.png"
        if ($LASTEXITCODE -ne 0) { throw "Frame extraction failed: $name" }
        Write-Output "Exported $name-preview.mp4"
    }
}
