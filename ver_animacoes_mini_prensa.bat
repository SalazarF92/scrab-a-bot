@echo off
title SCRAP-A-BOT - Showcase de Animacoes (Mini-Prensa 500)
cd /d "%~dp0"
echo ============================================================
echo   SCRAP-A-BOT :: SHOWCASE DE ANIMACOES EM LOOP
echo   Chefe: Mini-Prensa 500 (Setor 1)
echo ============================================================
echo.
echo   Ciclos reproduzidos em loop:
echo     1. ANDAR  - Caminhada pesada com pistoes hidraulicos
echo     2. ATAQUE - Carimbo Hidraulico com impacto e tremor
echo     3. PODER  - Nucleo Exposto jorrando vapor e chamas
echo.
echo   Controles na janela:
echo     [Espaco] Pausar / Retomar a animacao
echo     [1] Travar no ciclo de Andar
echo     [2] Travar no ciclo de Ataque
echo     [3] Travar no ciclo de Poder Especial
echo     [4] Exibir os tres movimentos lado a lado
echo     [ESC] Fechar visualizador
echo.
echo Abrindo janela do Godot...

if exist "%~dp0..\Godot_v4.7.2-stable_win64.exe" (
    "%~dp0..\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://scenes/mini_prensa_anim_showcase.tscn
) else if exist "F:\GODOT\Godot_v4.7.2-stable_win64.exe" (
    "F:\GODOT\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://scenes/mini_prensa_anim_showcase.tscn
) else if exist "F:\GODOT\Godot_v4.7.2-stable_win64_console.exe" (
    "F:\GODOT\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0." res://scenes/mini_prensa_anim_showcase.tscn
) else (
    echo [ERRO] Executavel do Godot nao foi encontrado na pasta pai.
    pause
)
