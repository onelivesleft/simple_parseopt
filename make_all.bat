@echo off
move bin\make.exe bin\make.tmp.exe
bin\make.tmp.exe -a README.md
del bin\make.tmp.exe
