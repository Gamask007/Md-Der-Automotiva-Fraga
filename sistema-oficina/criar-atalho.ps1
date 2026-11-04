# Cria o atalho "Sistema Oficina Fraga" na Área de Trabalho (rodar uma vez só).
# Uso: clique com o botão direito neste arquivo > "Executar com o PowerShell"
$app = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktop = [Environment]::GetFolderPath('Desktop')
$atalho = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'Sistema Oficina Fraga.lnk'))
$atalho.TargetPath = Join-Path $app 'abrir-sistema.bat'
$atalho.WorkingDirectory = $app
$atalho.IconLocation = "$env:SystemRoot\System32\imageres.dll,109"
$atalho.Description = 'Abre o sistema da Oficina Fraga'
$atalho.Save()
Write-Host "Atalho criado em $desktop"
