@echo off
move bin\make.exe bin\make.tmp.exe
bin\make.tmp.exe -m
del bin\make.tmp.exe
