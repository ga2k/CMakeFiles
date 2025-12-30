call setup
call run
goto EOF

:setup
cmd.exe /k "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -startdir=none -arch=x64 -host_arch=x64
goto EOF

:run
"C:\Program Files\Git\git-bash.exe"
goto EOF
