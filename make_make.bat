@echo off
move bin\make.exe bin\make2.exe
bin\make2 -m
del bin\make2.exe
