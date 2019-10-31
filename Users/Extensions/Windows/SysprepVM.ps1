Start-Process -FilePath "$Env:windir\System32\Sysprep\Sysprep.exe" -ArgumentList "/generalize /oobe /shutdown /quiet"
