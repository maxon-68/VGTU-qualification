::By Zhupikov Maxim (c)

@echo off
rem ==========================================
rem ==========================================
SetLocal EnableExtensions EnableDelayedExpansion

set log_file=
set cmd_command=
set Descript_lang=
set find_module=
set jsonmibtxtdir=
set net_snmp_dir=
set dev_base_txtdir=
set mibdir=
set pred_device=
set "ARK_ON=0"
set "ARKFold="
set "ARKVer="
set strver=0
set "NO_MIB_ARK_SOFT=0"
set "COMMUNITY=public"
set "HOSTCONTROLLER=localhost"

:cmd_priem_par_while
:: принял первый параметр
set "cmd_priem_par=%1"
set "cmd_priem_par1=%2"
:: передал парсеру параметров
call :cmd_priem_par_func !cmd_priem_par!
:: если есть следующий параметр, то сделать его первым и повторить парсинг параметра
if NOT "!cmd_priem_par1!"=="" (
	rem сдвинул на 1 параметр
	shift /1
	goto cmd_priem_par_while
)
rem Если лог файл не задан - задать по умолчанию
if "!log_file!"=="" (
	set "log_file=C:\log_file.log"
)
rem Если один из параметров /ARKSelf /ARKFold /ARKVer задан - выполнять проверку наличия ARK-SOFT (с SNMP) и задать папку
if "!ARK_ON!"=="1" (
	call :ARKSNMP
)

:: команды:
:: 1 - чтение JSONMIB в одну строку по модулям Иркоса
:: 2 - генерация JSONMIB
:: 911 - helper чтения
:: 912 - helper генерации
:: 91 - общий helper
:: 33 - отсутствие ARK-SOFT с SNMP
:: 331 - отсутствие созданной агентом базы данных
:: 332 - отсутствие запущенной службы SNMP
if "!cmd_command!"=="1" (
	set json.Section.Dates=
	rem если параметр /JSMD не использовался - расположение файла JSONMIB.txt в директории скрипта
	if "!jsonmibtxtdir!"=="" (
		set "jsonmibtxtdir=%~dp0"
	)
	rem проверка, что параметр /M поиска модуля непустой
	if NOT "!find_module!"=="" (
		REM :: проверка, что файл JSONMIB сгенерирован
		if EXIST "!jsonmibtxtdir!JSONMIB.txt" (
			call :json.ReadJSONPath "!jsonmibtxtdir!JSONMIB.txt" !find_module!
		) else (
			echo NoJSONMIBFile!
		)
	) else if "!find_module!"=="" (
		echo NoModule!
	)
) else if "!cmd_command!"=="2" (
	call :json.GenerateJSONPath
) else if "!cmd_command!"=="3" (
	call :json.DiscoveryIrcosTranslate
) else if "!cmd_command!"=="911" (
	call :helper1
) else if "!cmd_command!"=="912" (
	call :helper2
) else if "!cmd_command!"=="913" (
	call :helper3
) else if "!cmd_command!"=="91" (
	call :helper
) else if "!cmd_command!"=="33" (
	call :Log-Message "No SNMP ARKSOFT" 4
) else if "!cmd_command!"=="331" (
	call :Log-Message "No SNMP ARKSOFT BDSQL" 4
) else if "!cmd_command!"=="332" (
	call :Log-Message "No SNMP SERVICE RUNNING" 4
) else (
	call :helper
)
EndLocal
Exit /B 0
 
 
:json.ReadJSONPath
::%1 - путь к файлу
::%2 - имя модуля
set json.Section.Date=
:: Считываем построчно JSONMIB
For /F "usebackq tokens=* delims=" %%a In ("%~1") do (
	rem Если считанная строка непустая
	IF NOT "X%%a"=="X" (
		rem Сюда бы добавить или
		rem Если считанная строка [, то это первая строка, начать сбор строки с неё, без запятой (,[)
		if "%%a"=="[" (
			set json.Section.Date=%%a
			:Begin_Trim_Left1
			if "!json.Section.Date:~0,1!"==" " (set "json.Section.Date=!json.Section.Date:~1!"& Goto Begin_Trim_Left1)		
			set json.Section.Dates=!json.Section.Dates!!json.Section.Date!
		) else if "%%a"=="]" (
			rem Если считанная строка ], то она последняя, перед ней был последний параметр, он тоже записывается без запятой
			set json.Section.Date=%%a
			:Begin_Trim_Left2
			if "!json.Section.Date:~0,1!"==" " (set "json.Section.Date=!json.Section.Date:~1!"& Goto Begin_Trim_Left2)		
			set json.Section.Dates=!json.Section.Dates!!json.Section.Date!
		) else (
			REM :: Считываем значимую строку, ищем в ней параметр, отвечающий за модуль Иркоса, сравниваем с запрашиваемым
			REM :: Если модуль совпадает, добавляем к строке вывода JSON-а\
			REM :: Если нет, то отбрасываем
			For /F "usebackq tokens=8 delims=," %%b In ('"%%a"') do (
				For /F "usebackq tokens=2 delims=:}" %%c In ('"%%b"') do (
					set module_find="%~2"
					if "!module_find!"=="%%c" (
						set json.Section.Date=%%a
						:Begin_Trim_Left
						if "!json.Section.Date:~0,1!"==" " (set "json.Section.Date=!json.Section.Date:~1!"& Goto Begin_Trim_Left)

						if "!json.Section.Dates!"=="[" (
							set json.Section.Dates=!json.Section.Dates!!json.Section.Date!
						) else (
							set json.Section.Dates=!json.Section.Dates!,!json.Section.Date!
						)
					)
				)
			)
		)
	)
)
echo !json.Section.Dates!
Exit /B 0

:json.GenerateJSONPath
rem ==========================================
:: Начало генерирования JSONMIB, задаем параметры
rem ==========================================
rem если параметр /NSD не использовался - расположение файла Net-SNMP в директории C:\usr
if "!net_snmp_dir!"=="" (
	set "net_snmp_dir=C:\usr"
) else if NOT "!net_snmp_dir!"=="" (
	if NOT EXIST "!net_snmp_dir!" (
		set "net_snmp_dir=C:\usr"
	)
)
rem если параметр /MIBD не использовался - расположение MIB-файлов в директории скрипта генерации
if "!mibdir!"=="" (
	set "mibdir=%~dp0mibs"
) else if NOT "!mibdir!"=="" (
	if NOT EXIST "!mibdir!" (
		set "mibdir=%~dp0mibs"
	)
)

if exist "!net_snmp_dir!\bin" (
	rem расположение бинарников Net-SNMP для разыменования mib файла
	set "snmpdir=!net_snmp_dir!\bin"
) else (
	call :Log-Message "No find Net-SNMP" 4
	exit /b 0
)

rem временные файлы процедуры разыменования
set "tmpwalkmain=%~dp0tmpwalkmain.txt"
set "tmpwalk=%~dp0tmpwalk.txt"
set "tmptrans=%~dp0tmptrans.txt"
set "tmpoid=%~dp0tmpoid.txt"

rem если параметр /DBD не использовался - расположение базы данных девайсов Иркоса в директории скрипта
if "!dev_base_txtdir!"=="" (
	set "dev_base_txtdir=%~dp0"
) else if NOT "!dev_base_txtdir!"=="" (
	if NOT EXIST "!dev_base_txtdir!" (
		set "dev_base_txtdir=%~dp0"
	)
)
set "dev_base=!dev_base_txtdir!Device_BASE.txt"
rem если параметр /JSMD не использовался - расположение файла JSONMIB.txt в директории скрипта
if "!jsonmibtxtdir!"=="" (
	set "jsonmibtxtdir=%~dp0"
) else if NOT "!jsonmibtxtdir!"=="" (
	if NOT EXIST "!jsonmibtxtdir!" (
		set "jsonmibtxtdir=%~dp0"
	)
)
set "JSONMIB=!jsonmibtxtdir!JSONMIB.txt"
set "UNKNOWNDEVICE=!jsonmibtxtdir!UNKNOWNDEVICE.txt"
rem если параметр /LNGD не использовался - язык дескрипторов элементов Zabbix-а по умолчанию английский
if "!Descript_lang!"=="" (
	set "Descript_lang=en"
) else if NOT "!Descript_lang!"=="" (
	if "!Descript_lang!"=="EN" (
		set "Descript_lang=en"
	) else if "!Descript_lang!"=="en" (
		set "Descript_lang=en"
	) else if "!Descript_lang!"=="RU" (
		set "Descript_lang=ru"
	) else if "!Descript_lang!"=="ru" (
		set "Descript_lang=ru"
	) else (
		set "Descript_lang=en"
	)
)
rem если параметр /TMPSave не использовался - по умолчанию не сохранять логи
if "!TMPSave!"=="" (
	set "TMPSave=0"
)
rem ==========================================
rem Если временный файл существует - удалить
if exist "!tmpwalkmain!" (
	del /f /Q "!tmpwalkmain!"
)
if exist "!tmpwalk!" (
	del /f /Q "!tmpwalk!"
)
if EXIST "!tmptrans!" (
	del /f /Q "!tmptrans!"
)
if EXIST "!tmpoid!" (
	del /f /Q "!tmpoid!"
)
rem Если Net-SNMP существует (обязательное условие), копирование требуемых mib-файлов, начало разыменования указанных в OID.txt веток
if EXIST "!net_snmp_dir!" (
rem Проверка наличия папки mibs
	if EXIST "!mibdir!" (
		set "check_snmp_service=0"
		call :mib_copy
		For /F "usebackq tokens=2,3,* delims=: " %%a In (`SC queryex snmp`) do (
			if "%%b"=="RUNNING" (
				if "%%a"=="4" (
					set "check_snmp_service=1"
				)
			)
		)
		if "!check_snmp_service!"=="0" (
			call :Log-Message "No service snmp running" 4
			set "cmd_command=332"
			exit /b 0
		)
		if EXIST "!mibdir!\OID.txt" (
			For /F "usebackq delims=" %%a In ("!mibdir!\OID.txt") do (
				IF NOT "X%%a"=="X" (
					rem получение списка устройств из веток
					"!snmpdir!\snmpwalk.exe" -v 2c -c !COMMUNITY! !HOSTCONTROLLER! %%a >> !tmpwalkmain!	
				)
			)
		) else (
			call :Log-Message "No find OID.txt" 4
			exit /b 0
		)
	) else (
		call :Log-Message "I can't find the directory with mibs file !mibdir!" 4
		exit /b 0
	)
) else (
	call :Log-Message "No find Net-SNMP" 4
	exit /b 0
)
rem Если файл !tmpwalkmain! сгенерирован программой snmpwalk
if EXIST "!tmpwalkmain!" (
	set tmpwalk.Section.Dates=
	set tmpwalk.Section.Date=
	rem переменная для хранения длины строки, которая будет ограничивать длину запроса
	set _STRLENVAR=0
	rem счётчик для количества устройств
	set device.count=0
	rem получение одной строки со списком устройств для дальнейшего массового запроса на разыменование с указанием mib-файла источника
	For /F "usebackq tokens=1,2,3,* delims=:= " %%a In ("!tmpwalkmain!") do (
		IF NOT "X%%b"=="X" (
			REM echo %%a::%%b >> !tmptrans!
			set tmpwalk.Section.Date=%%b
			:Begin_Trim_Left3
			if "!tmpwalk.Section.Date:~0,1!"==" " (set "tmpwalk.Section.Date=!tmpwalk.Section.Date:~1!"& Goto Begin_Trim_Left3)
			rem функция оценки длины очередной строки, хранится в _SL
			call :STRLEN "!tmpwalk.Section.Date!" _SL
			rem если длина текущей строки больще 1024 - отбросить строку
			rem (эту строку генерируем мы, поэтому это на случай ошибки) 
			if !_SL! LEQ 1024 (
				rem складываем суммарную длину строки и текущую
				set /A _STRLENVAR=!_SL!+!_STRLENVAR!
				rem если суммарная строка больше 2047, делать разыменование во временные файлы
				if !_STRLENVAR! GTR 2047 (
					call :ircos_device_translate_path
					rem так как считанную строку мы не добавили к общей, то с неё начинается новая
					set _STRLENVAR=!_SL!
					set tmpwalk.Section.Dates=!tmpwalk.Section.Date!
				) else (
					set tmpwalk.Section.Dates=!tmpwalk.Section.Dates! !tmpwalk.Section.Date!
				)
			)
		)
	)
	rem при любом варианте есть остаточная суммарная строка (была меньше 2047 в цикле), с которой нужно выполнить разыменование
	call :ircos_device_translate_path
	del /f /Q "!tmpwalkmain!"
) else (
	rem Отсутствие сгенерированного файла !tmpwalkmain!
	call :Log-Message "Tmpwalkmain File failed" 4
	exit /b 0
)
rem Если все промежуточные файлы присутствуют (список устройст и oid-ов)
if EXIST "!tmpwalk!" (
	if EXIST "!tmpoid!" (
		rem Узнаём количество строк в файле tmpwalk
		for /f %%n in ( 'more ^< "!tmpwalk!" ^| find /c /v ""' ) do (
			set tail.count=%%n
		)
		rem Узнаём количество строк в файле tmpoid
		for /f %%n in ( 'more ^< "!tmpoid!" ^| find /c /v ""' ) do (
			set tail1.count=%%n
		)
		rem Сравнием количество устройств и oid-ов
		if "!tail.count!"=="!tail1.count!" (
			rem Если список устройств состоит хотя бы из одного устройства
			if !tail.count! GTR 0 (
				rem Удаление предыдущего JSONMIB файла
				if EXIST "!JSONMIB!" (
					del /f /Q "!JSONMIB!"
				)
				rem Запуск генерации JSONMIB
				call :ircos_device_translate
			)
		)
		if "!TMPSave!"=="0" (
			del /f /Q "!tmpoid!"
		)
	) else (
		rem Отсутствие файла с OID-ами
		call :Log-Message "There is no temporary file with OIDs" 4
	)
	if "!TMPSave!"=="0" (
		rem Отсутствие файла с устройствами
		del /f /Q "!tmpwalk!"
	)
) else (
	call :Log-Message "There is no temporary file with a short list of devices" 4
)
endlocal
exit /b 0
	
:ircos_device_translate_path
REM set $Process_1=
REM For /F "tokens=1,2,* delims==_" %%a In ('Set $Process') Do (
	REM set $Process_%%b=;
REM )
Set /A i=0 
Set /A device.counts=!device.count!
rem создаёт переменные окружения Process и записывает построчно строку tmpwalk.Section.Dates
For %%A In (!tmpwalk.Section.Dates!) Do (Set /A i+=1&Set $Process_!i!==!i!;%%~A)
rem считывает подстрочку, разбивает на 3 столбца
For /F "tokens=1,2,3,* delims==;" %%a In ('Set $Process') Do (
	for /f "delims=" %%v in ('echo.%%b^| findstr "[^0-9]"') do set "nv=%%~v"
	if not defined nv if "%%b" neq "" (
		if %%b LEQ !i! (
			Set /A device.count+=1
			rem получение краткого списка устройств
			echo !device.count!:%%c>> !tmpwalk!
		)	
	)	
)
Set /A device.count=!device.counts!
rem получение списка устройств из веток с указанием mib-а
"!snmpdir!\snmptranslate.exe" -IR !tmpwalk.Section.Dates! > !tmptrans!
set tmpwalk.Section.Dates=
set tmpwalk.Section.Date=
For /F "usebackq delims=" %%a In ("!tmptrans!") do (
	IF NOT "X%%a"=="X" (
		set tmpwalk.Section.Date=%%a
		:Begin_Trim_Left4
		if "!tmpwalk.Section.Date:~0,1!"==" " (set "tmpwalk.Section.Date=!tmpwalk.Section.Date:~1!"& Goto Begin_Trim_Left4)		
		set tmpwalk.Section.Dates=!tmpwalk.Section.Dates! !tmpwalk.Section.Date!
	)
)
del /f /Q "!tmptrans!"
rem получение oid-ов списка устройств
"!snmpdir!\snmptranslate.exe" -On !tmpwalk.Section.Dates! >> !tmptrans!
set tmpwalk.Section.Dates=
set tmpwalk.Section.Date=
For /F "usebackq delims=" %%a In ("!tmptrans!") do (
	IF NOT "X%%a"=="X" (
		set tmpwalk.Section.Date=%%a
		:Begin_Trim_Left5
		if "!tmpwalk.Section.Date:~0,1!"==" " (set "tmpwalk.Section.Date=!tmpwalk.Section.Date:~1!"& Goto Begin_Trim_Left5)		
		set tmpwalk.Section.Dates=!tmpwalk.Section.Dates! !tmpwalk.Section.Date!
	)
)
del /f /Q "!tmptrans!"
Set /A i=0
rem создаёт переменные окружения Process и записывает построчно строку
For %%B In (!tmpwalk.Section.Dates!) Do (Set /A i+=1&Set $Process_!i!==!i!;%%~B)
For /F "tokens=1,2,3,* delims==;" %%a In ('Set $Process') Do (
	for /f "delims=" %%v in ('echo.%%b^| findstr "[^0-9]"') do set "nv=%%~v"
	if not defined nv if "%%b" neq "" (
		if %%b LEQ !i! (
			Set /A device.count+=1
			rem получение краткого списка устройств
			echo !device.count!:%%c>> !tmpoid!
		)	
	)	
)
exit /b 0

:ircos_device_translate
if exist "!UNKNOWNDEVICE!" (
	del /f /Q "!UNKNOWNDEVICE!" > nul
)
rem Если присутствует база данных модулей Иркоса
if exist "!dev_base!" (
	For /F "usebackq tokens=1,2,3,* delims=:." %%a In ("!tmpwalk!") do (
		rem флаг, что модуль Иркоса является ircosdevice или ircosroot (для избавление от неизвестной шины для базы модулей Иркоса)
		set idt_flag=0
		set "par_var_tmpwalk=%%b"
		rem проверка на ircosRoot
		set "par_var_tmpwalk_ircosdevice=!par_var_tmpwalk:~0,9!"
		if "!par_var_tmpwalk_ircosdevice!"=="ircosRoot" (
			set idt_flag=1
			rem вычисление, что за модуль и что за параметр, удаление информации о шине
			set "par_var_tmpwalk_ircosdevice=!par_var_tmpwalk:~9!"
			For /F "usebackq tokens=1,2,3,4,* delims=xS" %%d In ('!par_var_tmpwalk_ircosdevice!') do (
				rem устройство может иметь параметр State, который при парсинге будет tate, пробуем дописать букву S перед tate ("State")
				set idt_pvti_pars_1=S%%g
				rem если %%g был пуст, значит этого параметра не существует, значит элемент не является "State"
				if "!idt_pvti_pars_1!"=="S" (
					set idt_pvti_pars_1=
				)				
				set par_var_tmpwalk=ircosRoot%%dx%%e!idt_pvti_pars_1!
			)
		)
		rem Если в текущем поиске еще не найдено модуля Иркоса, начать проверку на ircosDevice
		if NOT idt_flag==1 (
			set "par_var_tmpwalk_ircosdevice=!par_var_tmpwalk:~0,11!"
			if "!par_var_tmpwalk_ircosdevice!"=="ircosDevice" (
				set idt_flag=1
				set "par_var_tmpwalk_ircosdevice=!par_var_tmpwalk:~11!"
				For /F "usebackq tokens=1,2,3,4,* delims=xS" %%d In ('!par_var_tmpwalk_ircosdevice!') do (
					set idt_pvti_pars_1=S%%g
					if "!idt_pvti_pars_1!"=="S" (
						set idt_pvti_pars_1=
					)				
					set par_var_tmpwalk=ircosDevice%%dx%%e!idt_pvti_pars_1!
				)
			)
		)
		if NOT EXIST "!JSONMIB!" (
			echo [>>!JSONMIB!
		)
		if NOT "%%b.%%c"=="!pred_device!" (
			set "str_translate_flag=0"
			rem Сравнение с базой данных устройств
			For /F "usebackq tokens=1,2,3,4,5,6,7,8,9,* delims=;" %%i In ("!dev_base!") do (
				if "!par_var_tmpwalk!"=="%%j" (
					set "str_translate_flag=1"
					if "!Descript_lang!"=="ru" (
						set "ircosdesc_lang=%%l"
						set "ircosdesc_razm_lang=%%m"
					) else if "!Descript_lang!"=="en" (
						set "ircosdesc_lang=%%n"
						set "ircosdesc_razm_lang=%%o"
					)
					set "ircos_armada_notification_code=%%p"
					set "ircos_armada_notification_code_restore=%%q"
					rem если найденное устройство совпадает с информацией из базы данных устройств					
					For /F "usebackq tokens=1,2,* delims=:" %%v In ("!tmpoid!") do (
						if "%%v"=="%%a" (
							set oid_sens=%%w
						)
					)
					echo {"ircosdevice":"%%b.%%c","ircoskey":"%%i: %%k","ircosoid":"!oid_sens!","ircosdesc":"!ircosdesc_lang!","ircosdesc_r":"!ircosdesc_razm_lang!","ircos_tag1":"!ircos_armada_notification_code!","ircos_tag2":"!ircos_armada_notification_code_restore!","ircosmodule":"%%i"}>>!JSONMIB!
					set pred_device=%%b.%%c
				)
			)
			if "!str_translate_flag!"=="0" (		
				echo !par_var_tmpwalk! >> !UNKNOWNDEVICE!								
			)
		) 		
	)
)
echo ]>>!JSONMIB!
exit /b 0

:ARKSNMP
REM "C:\Program Files\Zabbix Agent\ircos_translate\ircos_translate.cmd" /C:"2" /LNGD:"ru" /TMPSave:"0" /ARKVer:290.11.1745
REM "C:\Program Files\Zabbix Agent\ircos_translate\ircos_translate.cmd" /C:"2" /LNGD:"ru" /TMPSave:"0" /ARKSelf
REM "C:\Program Files\Zabbix Agent\ircos_translate\ircos_translate.cmd" /C:"2" /LNGD:"ru" /TMPSave:"0" /ARKFold:"C:\USER\ARK-SOFT-290.11.1745"
rem Работает только на версиях XXX.XX.*
if "!ARKFold!"=="" (
	if "!ARKVer!"=="" (
		for /f "tokens=4 delims=\ " %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node"') do (	
			if "%%a"=="IRCOS" (
				for /f "tokens=6 delims=\ " %%b in ('"reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS" | findstr /I ARK-SOFT"') do (
					if NOT "%%b"=="" (
						For /F "usebackq tokens=2,3 delims=." %%c In ('%%b') do (
							if %%c%%d GTR !strver! (
								set strver=%%c%%d
								for /f "tokens=1,3 delims= " %%e in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS\ARK-SOFT %%b\Settings" /v "Path"') do (
									if exist "%%f\SNMP" (
										set "ARKFold=%%f\SNMP"
									)
								)
							)
						)						

					)
				)
			)
		)
	) else if NOT "!ARKVer!"=="" (
		for /f "tokens=4 delims=\ " %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node"') do (	
			if "%%a"=="IRCOS" (
				for /f "tokens=5 delims=\" %%b in ('"reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS" | findstr /I /C:"ARK-SOFT""') do (
					if "%%b"=="ARK-SOFT" (
						for /f "tokens=1,3 delims= " %%c in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS\ARK-SOFT"') do (
							if "!ARKVer!"=="%%c" (
								if exist "%%d\SNMP" (
									set "ARKFold=%%d\SNMP"
								)
							)
						)
					)
				)
			)
		)
	)
) else if NOT "!ARKFold!"=="" (
	if exist "!ARKFold!\SNMP" (
		set "ARKFold=!ARKFold!\SNMP"
	) else (
		set "ARKFold="
	)
)
if "!ARKFold!"=="" (
	for /f "tokens=4 delims=\ " %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node"') do (	
			if "%%a"=="IRCOS" (
				for /f "tokens=5 delims=\" %%b in ('"reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS" | findstr /I /C:"ARK-SOFT""') do (
					if "%%b"=="ARK-SOFT" (
						for /f "tokens=1,3 delims= " %%c in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS\ARK-SOFT"') do (
							For /F "usebackq tokens=1,2,3 delims=." %%e In ('%%c') do (
								set/p="%%e%%f%%g"<nul|>nul findstr [^^0-9a-f]&& (
									echo. >nul 
								) || (
									if %%e%%f%%g GTR !strver! (
										if exist "%%d\SNMP" (
											set strver=%%e%%f%%g
											set "ARKFold=%%d\SNMP"
										)
									)
								)								
							)
						)
					)
				)
			)
		)
	)
)
if "!ARKFold!"=="" (
	set "cmd_command=33"
	exit /b 0
)

if NOT exist "!ARKFold!\SnmpBD.db" (
	set "cmd_command=331"
	exit /b 0
)
exit /b 0

:mib_copy
if exist "!mibdir!\miblist.txt" (
	For /F "usebackq delims=" %%a In ("!mibdir!\miblist.txt") do (
		set "mib_copy_flag_1=0"
		IF NOT "X%%a"=="X" (
			if NOT "!ARKFold!"=="" (
				if "!NO_MIB_ARK_SOFT!"=="0" (
					if exist "!ARKFold!\user_mibs" (
						if exist "!ARKFold!\user_mibs\%%a" (
							xcopy /Y/h "!ARKFold!\user_mibs\%%a" "!net_snmp_dir!\share\snmp\mibs" > nul
							set "mib_copy_flag_1=1"
						)
					)
					if "!mib_copy_flag_1!"=="0" (
						if exist "!ARKFold!\%%a" (
							xcopy /Y/h "!ARKFold!\%%a" "!net_snmp_dir!\share\snmp\mibs" > nul
							set "mib_copy_flag_1=1"
						)
					)
				)
			)
			if "!mib_copy_flag_1!"=="0" (
				if exist "!mibdir!\%%a" (
					xcopy /Y/h "!mibdir!\%%a" "!net_snmp_dir!\share\snmp\mibs" > nul
					set "mib_copy_flag_1=1"
				)
			)
			if "!mib_copy_flag_1!"=="0" (
				call :Log-Message "I can't find a mib file - %%a" 4
			)
		)
	)
)
exit /b 0

:json.DiscoveryIrcosTranslate
rem если параметр /JSMD не использовался - расположение файла JSONMIB.txt в директории скрипта
if "!jsonmibtxtdir!"=="" (
	set "jsonmibtxtdir=%~dp0"
) else if NOT "!jsonmibtxtdir!"=="" (
	if NOT EXIST "!jsonmibtxtdir!" (
		set "jsonmibtxtdir=%~dp0"
	)
)
set "JSONMIB=!jsonmibtxtdir!JSONMIB.txt"
set "UNKNOWNDEVICE=!jsonmibtxtdir!UNKNOWNDEVICE.txt"

set "mi_dit_key_jsonmib=0"
set "mi_dit_key_snmp=0"
set "mi_dit_key_driverdev=0"


if EXIST "!JSONMIB!" (
	set "mi_dit_key_jsonmib=1"
)

call :service_check "SNMP"
if "!service_check_flag_1!"=="1" (
	set "mi_dit_key_snmp=1"
)
For /F "usebackq tokens=1 delims= " %%a In (`tasklist`) do (
	if "%%a"=="Disp.exe" (
		set "mi_dit_key_driverdev=1"
	) else if "%%a"=="rc2hwcl.exe" (
		set "mi_dit_key_driverdev=1"
	)
)
set /a mi_dit_key_discovery=!mi_dit_key_jsonmib!*!mi_dit_key_snmp!*!mi_dit_key_driverdev!
echo !mi_dit_key_discovery!

exit /b 0

:cmd_priem_par_func
set "cmd_priem_par_var=%1"
set "cmd_priem_par_var=!cmd_priem_par_var:"=*!"
For /F "usebackq tokens=1,* delims=:" %%a In ('!cmd_priem_par_var!') do (
	set "cmd_priem_par_var1=%%a"
	set "cmd_priem_par_var2=%%b"
	:Begin_Trim_Left6
	if "!cmd_priem_par_var2:~0,1!"=="*" (set "cmd_priem_par_var2=!cmd_priem_par_var2:~1!"& Goto Begin_Trim_Left6)
	:Begin_Trim_Left7
	if "!cmd_priem_par_var2:~-1!"=="*" (set "cmd_priem_par_var2=!cmd_priem_par_var2:~0,-1!"& Goto Begin_Trim_Left7) 
	if /I "!cmd_priem_par_var1!"=="/READ" (
		rem команда на чтение JSONMIB
		set "cmd_command=1"
	) else if /I "!cmd_priem_par_var1!"=="/R" (
		rem команда на генерацию JSONMIB
		set "cmd_command=1"
	) else if /I "!cmd_priem_par_var1!"=="/GENERATE" (
		rem команда на генерацию JSONMIB
		set "cmd_command=2"
	) else if /I "!cmd_priem_par_var1!"=="/G" (
		rem команда на генерацию JSONMIB
		set "cmd_command=2"
	) else if /I "!cmd_priem_par_var1!"=="/DISCOVERY" (
		rem команда на генерацию JSONMIB
		set "cmd_command=3"
	) else if /I "!cmd_priem_par_var1!"=="/DIS" (
		rem команда на генерацию JSONMIB
		set "cmd_command=3"
	) else if /I "!cmd_priem_par_var1!"=="/LANGUAGE-DESCRIPTION" (
		rem Выбор языка дескрипта для элемента Zabbix-а
		set "Descript_lang=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/LNGD" (
		rem Выбор языка дескрипта для элемента Zabbix-а
		set "Descript_lang=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/MODULE" (
		rem Модуль, который ищет модуль низкоуровневого обнаружения Zabbix-а
		set "find_module=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/M" (
		rem Модуль, который ищет модуль низкоуровневого обнаружения Zabbix-а
		set "find_module=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/JSONMIB-DIR" (
		rem Параметр, указывающий, где искать (или куда писать) файл JSONMIB
		set "jsonmibtxtdir=!cmd_priem_par_var2!\"
	) else if /I "!cmd_priem_par_var1!"=="/JSMD" (
		rem Параметр, указывающий, где искать (или куда писать) файл JSONMIB
		set "jsonmibtxtdir=!cmd_priem_par_var2!\"
	) else if /I "!cmd_priem_par_var1!"=="/NET-SNMP-DIR" (
		rem Параметр, указывающий путь до Net-SNMP
		set "net_snmp_dir=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/NSD" (
		rem Параметр, указывающий путь до Net-SNMP
		set "net_snmp_dir=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/DEVICEBASE-DIR" (
		rem Параметр, указывющй расположение базы данных устройств Иркоса
		set "dev_base_txtdir=!cmd_priem_par_var2!\"
	) else if /I "!cmd_priem_par_var1!"=="/DBD" (
		rem Параметр, указывющй расположение базы данных устройств Иркоса
		set "dev_base_txtdir=!cmd_priem_par_var2!\"
	) else if /I "!cmd_priem_par_var1!"=="/MIB-DIR" (
		rem Параметр, указывающий, где искать MIB, которые необходимо откопировать в Net-SNMP
		set "mibdir=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/MIBD" (
		rem Параметр, указывающий, где искать MIB, которые необходимо откопировать в Net-SNMP
		set "mibdir=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/LOGFILE" (
		rem Параметр, указывающий полный путь до лог файла и его полное имя
		set "log_file=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/LGFile" (
		rem Параметр, указывающий полный путь до лог файла и его полное имя
		set "log_file=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/TMPSave" (
		rem Параметр, указывающий, что необходимо сохранить файлы списка устройств и OID-ов
		set "TMPSave=1"
	) else if /I "!cmd_priem_par_var1!"=="/ARKVer" (
		rem Параметр, указывающий версию ARK-софта для проверки наличия службы SNMP и MIB-файлов
		set "ARKVer=!cmd_priem_par_var2!"
		set "ARK_ON=1"
	) else if /I "!cmd_priem_par_var1!"=="/ARKFold" (
		rem Параметр, указывающий папку с ARK-софтов для проверки наличия службы SNMP и MIB-файлов (приоритетней указания версии)
		set "ARKFold=!cmd_priem_par_var2!"
		set "ARK_ON=1"
	) else if /I "!cmd_priem_par_var1!"=="/ARKSelf" (
		rem Параметр, указывающий на проверку наличия службы SNMP и MIB-файлов в любой версии ARK-софта, начиная с последней установленной
		set "ARK_ON=1"
	) else if /I "!cmd_priem_par_var1!"=="/NOMIBARKSOFT" (
		rem Параметр, указывающий, что при наличии ARK-софта с MIB-ами, приоритет отдавать файлам в папке mibs (параметр !mibdir!)
		if "!ARK_ON!"=="1" (
			set "NO_MIB_ARK_SOFT=1"
		)
	) else if /I "!cmd_priem_par_var1!"=="/COMMUNITY" (
		rem Параметр, указывающий сообщество для SNMP
		set "COMMUNITY=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/CO" (
		rem Параметр, указывающий сообщество для SNMP
		set "COMMUNITY=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/HOSTCONTROLLER" (
		set "HOSTCONTROLLER=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/HC" (
		set "HOSTCONTROLLER=!cmd_priem_par_var2!"
	) else if /I "!cmd_priem_par_var1!"=="/help" (
		if "!cmd_command!"=="1" (
			set "helpS=0"
			set "cmd_command=911"
		) else if "!cmd_command!"=="2" (
			set "helpS=0"
			set "cmd_command=912"
		) else if "!cmd_command!"=="3" (
			set "helpS=0"
			set "cmd_command=913"
		) else (
			set "cmd_command=91"
		)
	) else if /I "!cmd_priem_par_var1!"=="/helpS" (
		if "!cmd_command!"=="1" (
			set "helpS=1"
			set "cmd_command=911"
		) else if "!cmd_command!"=="2" (
			set "helpS=1"
			set "cmd_command=912"
		) else if "!cmd_command!"=="3" (
			set "helpS=1"
			set "cmd_command=913"
		) else (
			set "cmd_command=91"
		)
	) else if /I "!cmd_priem_par_var1!"=="/REGQUESTION" (
		call :reg_check_trace_func "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS\SNMP\IRCOS_TRANSLATE"
		if "!reg_check_trace_flag!"=="1" (
			call :reg_ircostranslate
		) else (
			call :Log-Message "Missing registry branch IRCOS_TRANSLATE" 4
		)
		REM call :cmd_priem_par_func 
	) else if /I "!cmd_priem_par_var1!"=="/REGQ" (
		call :reg_check_trace_func "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS\SNMP\IRCOS_TRANSLATE"
		if "!reg_check_trace_flag!"=="1" (
			call :reg_ircostranslate
		) else (
			call :Log-Message "Missing registry branch IRCOS_TRANSLATE" 4
		)
		REM call :cmd_priem_par_func 
)
exit /b 0

:helper
echo ==============================
echo ::By Zhupikov Maxim (c)
echo ------------------------------
echo ircos_translate.cmd /READ /help
echo ircos_translate.cmd /GENERATE /help
echo ircos_translate.cmd /G /helpS
echo ------------------------------
echo /READ - ReadJSONPath
echo /GENERATE - GenerateJSONPath
echo /DISCOVERY - Discovery IrcosDevices
echo ------------------------------
echo ==============================
exit /b 0

:helper1
echo ==============================
echo ::By Zhupikov Maxim (c)
echo ------------------------------
echo ircos_translate.cmd /READ /MODULE:"*" /JSONMIB-DIR:"*"
echo ------------------------------
echo /MODULE:"T5" - Search for the "T5" module in JSONMIB (Read)
echo /MODULE:"T5.State" - Search for the "T5.State" module in JSONMIB (Read)
echo ------------------------------
echo /JSONMIB-DIR:"C:\Program Files\Zabbix Agent\ircos_translate" - Location of the JSONMIB file
echo by default: Location file ircos_translate.cmd
echo ------------------------------
echo ==============================
exit /b 0

:helper2
set "HD_TMPSave=TMPSave"
set "HD_ARKVer=ARKVer"
set "HD_ARKFold=ARKFold"
set "HD_ARKSelf=ARKSelf"
set "HD_NOMIBARKSOFT=NOMIBARKSOFT"
if "!helpS!"=="0" (
	set "HD_GENERATE=GENERATE"
	set "HD_LNGD=LANGUAGE-DESCRIPTION"
	set "HD_JSMD=JSONMIB-DIR"
	set "HD_NSD=NET-SNMP-DIR"
	set "HD_DBD=DEVICEBASE-DIR"
	set "HD_MIBD=MIB-DIR"
	set "HD_LGFile=LOGFILE"
	set "HD_CO=COMMUNITY"
	set "HD_REGQ=REGQUESTION"
	set "HD_HC=HOSTCONTROLLER"
) else if "!helpS!"=="1" (
	set "HD_GENERATE=G"
	set "HD_LNGD=LNGD"
	set "HD_JSMD=JSMD"
	set "HD_NSD=NSD"
	set "HD_DBD=DBD"
	set "HD_MIBD=MIBD"
	set "HD_LGFile=LGFile"
	set "HD_CO=CO"
	set "HD_REGQ=REGQ"
	set "HD_HC=HC"
)
echo ==============================
echo ::By Zhupikov Maxim (c)
echo ------------------------------
echo ircos_translate.cmd /!HD_GENERATE! /!HD_LNGD!:"*" /!HD_CO!:"*" /!HD_JSMD!:"*" /!HD_NSD!:"*" /!HD_DBD!:"*" /!HD_MIBD!:"*" /!HD_LGFile!:"*" /!HD_TMPSave! /!HD_ARKVer!:"*" /!HD_ARKFold!:"*" /!HD_ARKSelf! /!HD_NOMIBARKSOFT! /!HD_REGQ! /!HD_HC!:"*"
echo ------------------------------
echo /!HD_LNGD!:"en"
echo /!HD_LNGD!:"ru" - Zabbix data element descriptor language
echo by default: Language:"en"
echo ------------------------------
echo /!HD_CO!:"public"
echo by default: Community:"public"
echo ------------------------------
echo /!HD_JSMD!:"C:\Program Files\Zabbix Agent\ircos_translate" - Location of the JSONMIB file
echo by default: Location file ircos_translate.cmd
echo ------------------------------
echo /!HD_NSD!:"C:\Program Files\Net-SNMP" - Location of the Net-SNMP file
echo by default: Location: C:\usr
echo ------------------------------
echo /!HD_DBD!:"C:\Program Files\Zabbix Agent\ircos_translate" - Location of the DataBase IRCOS-Device
echo by default: Location file ircos_translate.cmd
echo ------------------------------
echo /!HD_MIBD!:"C:\Program Files\Net-SNMP\share\snmp\mibs" - Location of the MIB and OID.txt file
echo by default: Location file ircos_translate.cmd
echo ------------------------------
echo /!HD_LGFile!:"C:\log_file.log" - Location of the log_file.log
echo by default: Location C:\log_file.log
echo ------------------------------
echo /!HD_TMPSave! - Save temp file
echo by default: No save temp file
echo ------------------------------
echo /!HD_ARKVer!:"290.11.1745" - Priory version ARK-SOFT
echo by default: if not exist /ARKFold - the latest version ARK-SOFT with SNMP
echo by default: if exist /ARKFold - this version
echo ------------------------------
echo /!HD_ARKFold!:"C:\USER\ARK-SOFT-290.11.1745" - Priory folder ARK-SOFT
echo by default: if not exist /ARKFold - the latest version ARK-SOFT with SNMP
echo by default: if exist /ARKFold - this folder
echo ------------------------------
echo /!HD_ARKSelf! - Check availability ARK-SOFT + Copy the mib files
echo by default: No check availability ARK-SOFT
echo ------------------------------
echo /!HD_NOMIBARKSOFT! - If check availability ARK-SOFT - NO copy the mib files
echo ------------------------------
echo /!HD_REGQ! - Read keys from the registry
echo ------------------------------
echo /!HD_HC! - Address of the host being polled
echo ------------------------------
echo ==============================
exit /b 0

:helper3
echo ==============================
echo ::By Zhupikov Maxim (c)
echo ------------------------------
echo ircos_translate.cmd /DISCOVERY /JSONMIB-DIR:"*"
echo ------------------------------
echo /JSONMIB-DIR:"C:\Program Files\Zabbix Agent\ircos_translate" - Location of the JSONMIB file
echo by default: Location file ircos_translate.cmd
echo ------------------------------
echo ==============================
exit /b 0

:STRLEN

  Setlocal EnableDelayedExpansion
  Set "s=#%~1"
  Set "len=0"
  For %%N in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
    if "!s:~%%N,1!" neq "" (
      set /a "len+=%%N"
      set "s=!s:~%%N!"
    )
  )
  Endlocal&if "%~2" neq "" (set %~2=%len%) else echo %len%

  goto :EOF

:reg_ircostranslate
for /f "tokens=1,2,* delims=\ " %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\IRCOS\SNMP\IRCOS_TRANSLATE"') do (
	set "cmd_priem_par=/%%a:""
	set "cmd_priem_par=!cmd_priem_par!%%c^""
	call :cmd_priem_par_func !cmd_priem_par!
)
exit /b 0

:reg_check_trace_func
set "reg_check_trace_flag=0"
set "reg_check_trace_typ_2=%~1"
set "reg_check_trace_typ_1=!reg_check_trace_typ_2:\= /!"
set "reg_check_trace_count_tokens=0"

:reg_check_trace_func_1
for /F "tokens=1* delims=/" %%A in ( "!reg_check_trace_typ_1!" ) do (
  set /A reg_check_trace_count_tokens+=1
  set "reg_check_trace_typ_1=%%B"
  goto reg_check_trace_func_1 
)
set "reg_check_trace_count_tokens_1=0"
set reg_check_trace_line=
:reg_check_trace_func_2
set /A reg_check_trace_count_tokens_1+=1
if !reg_check_trace_count_tokens_1! LEQ !reg_check_trace_count_tokens! (
	for /F "tokens=%reg_check_trace_count_tokens_1% delims=\" %%G in ( "%reg_check_trace_typ_2%" ) do (
		if NOT "%%G"=="" (
			if "!reg_check_trace_count_tokens_1!"=="1" (
				set "reg_check_trace_line=%%G"
				set "reg_check_trace_flag=1"
			) else if NOT "!reg_check_trace_count_tokens_1!"=="1" (
				call :reg_check_trace_func_3 "!reg_check_trace_line!" "%%G" reg_check_trace_line reg_check_trace_flag
			)
		)
	)
	if NOT "!reg_check_trace_flag!"=="0" (
		goto reg_check_trace_func_2
	)
)
exit /b 0

:reg_check_trace_func_3
set "reg_check_trace_flag_func3=0"
if NOT "%~1"=="" (
	for /f "tokens=* delims=" %%a in ('reg query "%~1"') do (
		if /I "%%a"=="%~1\%~2" (
			set "reg_check_trace_flag_func3=1"
		)
	)
	if "!reg_check_trace_flag_func3!"=="0" (
		set "%~3=%~1"
		set "%~4=0"
	) else if "!reg_check_trace_flag_func3!"=="1" (
		set "%~3=%~1\%~2"
		set "%~4=1"
	)
)
exit /b 0

:service_check
set service_check=
set "service_check_flag_1=0"
for /f "tokens=5 delims=\" %%a in ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services"') do (
	rem если всё ещё не нашли, продолжаем поиск
	if "!service_check!"=="" (
		if "%~1"=="%%a" (
		REM set/p="%%a"<nul|>nul findstr /C:"%~1" && (
			REM echo %%a is Zabbix.
			rem нашли Zabbix Agent-а, задали имя для проверки службы
			set "service_check=%%a"
		)
	)
)
if NOT "!service_check!"=="" (
	For /F "usebackq tokens=2,3,* delims=: " %%a In (`SC queryex "!service_check!"`) do (
		if "%%b"=="RUNNING" (
			set "service_check_flag_1=1"
		) else if "%%b"=="STOPPED" (
			set "service_check_flag_1=1"
		) else if "%%b"=="STOP_PENDING" (
			set "service_check_flag_1=1"
		)
	)
)
exit /b 0

:Log-Message
rem comm 4 - писать в лог (информация)
set "LogMessage=%~1"
set "comm=%~2"
set mess9=%date% %time% Information: !LogMessage!

if "!comm!"=="4" (
	echo !mess9! >> "!log_file!"
)
Exit /B