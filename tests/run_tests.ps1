# Executor dos testes headless do SCRAP-A-BOT. Serve direto como passo de CI.
#
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
#   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 -Godot C:\caminho\godot_console.exe
#
# Passo zero: importar. A pasta .godot esta no .gitignore, entao um clone limpo
# nao tem o cache de classes globais e nenhum script com class_name compila.
#
# Um teste so passa com as tres condicoes juntas: codigo de saida 0, a linha
# "=== TUDO OK ===" impressa, e nenhum "SCRIPT ERROR" na saida. So o codigo de
# saida nao basta: se o proprio script de teste nao compila, o Godot abre a cena
# sem script, nunca chama quit, e o --quit-after encerra com codigo 0.
param(
    [string]$Godot = "F:\GODOT\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Only = "",
    [switch]$VerboseGodot
)

$ErrorActionPreference = "Continue"
$project = Split-Path -Parent $PSScriptRoot

# Gameplay e percurso completo usam --fixed-fps: desacopla o tempo de jogo do
# relogio e simula minutos de partida em segundos. O teste de fumaca roda em
# tempo real de proposito. Com a flag, o laco principal atropela a thread de
# audio e o benchmark de fisica mostra picos falsos de 8 a 10 ms.
$scenes = @(
    @{ Path = "res://tests/compile_check.tscn"; Extra = @() },
    @{ Path = "res://tests/integration_additions.tscn"; Extra = @() },
    @{ Path = "res://tests/boss_combat.tscn"; Extra = @() },
    @{ Path = "res://tests/mob_expansion.tscn"; Extra = @() },
    @{ Path = "res://tests/rig_integration.tscn"; Extra = @() },
    @{ Path = "res://tests/audio_cleanup.tscn"; Extra = @() },
    @{ Path = "res://tests/smoke.tscn"; Extra = @() },
    @{ Path = "res://tests/gameplay.tscn"; Extra = @("--fixed-fps", "120") },
    @{ Path = "res://tests/run_completion.tscn"; Extra = @("--fixed-fps", "120") }
)

# Testes de rig e arte: scripts standalone (extends SceneTree), rodados com
# --script. Mesma regra de aprovacao: codigo 0, "=== TUDO OK ===" e sem erro.
$scripts = @(
    "res://tests/mini_prensa_motion.gd",
    "res://tests/frostbyte_motion.gd",
    "res://tests/parafuseta_motion.gd",
    "res://tests/rato_morto_motion.gd",
    "res://tests/olhudo_motion.gd",
    "res://tests/creature_mouths.gd",
    "res://tests/creature_joint_contacts.gd",
    "res://tests/boss_revision.gd"
)

$known = ($scenes | ForEach-Object { $_.Path }) + $scripts
if ($Only -and -not ($known | Where-Object { $_ -like "*/$Only.tscn" -or $_ -like "*/$Only.gd" })) {
    Write-Host "Teste desconhecido: $Only"
    exit 2
}

Write-Host ">>> importando o projeto (cache de classes e .uid)"
& $Godot --headless --path $project --editor --import --quit 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "FALHOU: a importacao saiu com codigo $LASTEXITCODE"
    exit 1
}

$failed = @()
foreach ($scene in $scenes) {
    if ($Only -and $scene.Path -notlike "*/$Only.tscn") { continue }
    Write-Host ""
    Write-Host ">>> $($scene.Path)"
    # --quit-after e so a rede de seguranca contra teste que nunca termina.
    $godotArgs = @("--headless", "--path", $project) + $scene.Extra + @("--quit-after", "120000", $scene.Path)
    if ($VerboseGodot) { $godotArgs += "--verbose" }
    $lines = & $Godot @godotArgs 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $text = $lines -join "`n"
    $lines | Where-Object { $_ -notmatch "^Godot Engine" } | ForEach-Object { Write-Host $_ }

    $ok = ($code -eq 0) -and ($text -match "=== TUDO OK ===") -and ($text -notmatch "SCRIPT ERROR|ObjectDB.*leaked|Leaked instance:")
    if (-not $ok) {
        $failed += "$($scene.Path) (saida $code)"
    }
}

foreach ($script in $scripts) {
    if ($Only -and $script -notlike "*/$Only.gd") { continue }
    Write-Host ""
    Write-Host ">>> $script"
    $lines = & $Godot --headless --path $project --quit-after 120000 --script $script 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    $text = $lines -join "`n"
    $lines | Where-Object { $_ -notmatch "^Godot Engine" } | ForEach-Object { Write-Host $_ }
    $ok = ($code -eq 0) -and ($text -match "=== TUDO OK ===") -and ($text -notmatch "SCRIPT ERROR|ObjectDB.*leaked|Leaked instance:")
    if (-not $ok) { $failed += "$script (saida $code)" }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "TODOS OS TESTES PASSARAM"
    exit 0
}
Write-Host "FALHARAM:"
$failed | ForEach-Object { Write-Host "  - $_" }
exit 1
