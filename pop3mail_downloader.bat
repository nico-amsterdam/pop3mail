@echo off
set params=%*
set t=%params%
set loopargs=
set argsmin1=
set lastarg=
:loop
for /f "tokens=1*" %%a in ("%t%") do (
   SET argsmin1=%loopargs%
   SET lastarg=""%%a""
   SET loopargs=%loopargs%""%%a"", 
   set t=%%b
   )
if defined t goto :loop
set mixargs=Pop3mail.CLI.main([%argsmin1%%lastarg%])
echo mix run -e "%mixargs%"
mix run -e "%mixargs%"
