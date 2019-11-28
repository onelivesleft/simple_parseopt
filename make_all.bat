@echo off
move bin\make.exe bin\make2.exe
bin\make2 -a README.md -open
del bin\make2.exe
