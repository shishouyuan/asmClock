.386
.model flat, stdcall
option casemap:none
option proc:private

include windows.inc
include user32.inc
includelib user32.lib
include kernel32.inc
includelib kernel32.lib
include gdi32.inc
includelib gdi32.lib

TIMER_ID = 1
ICON_MAIN = 0001h

MINIRADIUS = 50
PARTSNUM = 4
HOURHANDW = MINIRADIUS / 16 * 3
MINUTEHANDW = MINIRADIUS / 16 * 2
SECONDHANDW = MINIRADIUS / 16
HOURHANDCOLOR = 00ffff00h
MINUTEHANDCOLOR = 0000ffffh
SECONDHANDCOLOR = 00ff00ffh
TAILBI = 3
KEDUW = 2
FORMWIDTH = MINIRADIUS * 2 + 100
FORMHEIGHT = MINIRADIUS * 2 + 100

.const
	PerDegree dword 6
	Per5Degree dword 30
	ct180 dword 180
	HandBiArg label dword
	HourHandBi dword 10
	MinuteHandBi dword 14
	SecondHandBi dword 15
	HANDBIARGINDEX = ($ - HandBiArg) / type HandBiArg - 1
	HANDBIARGGROUPITEMC = 1
	ctdwCircleRadiusBi dword 1
	ctdwKeDuBi dword 1

	WinClassName db 'Clock', 0

.data?
	CenterPoint POINT <>
	dwRadius dword ?
	btTooSmall byte ?

	HANDARGGROUPITEMC = 2
	HandLArg label dword
	dwHourHandL dword ?	;HourHandLength
	dwHourTailL dword ?
	dwMinuteHandL dword ?
	dwMinuteTailL dword ?
	dwSecondHandL dword ?
	dwSecondTailL dword ?
	HANDLARGINDEX = ($ - HandLArg) / type HandLArg / HANDARGGROUPITEMC - 1
.erre HANDLARGINDEX EQ HANDBIARGINDEX;表针长数与比例数不等 

	dwCircleRadius dword ?
	dwKeDuL dword ?

	hInstance dword ?
	hWnd dword ?
	struWinClass WNDCLASSEX <>

	hdcCurrent HDC ?
	hHourPen dword ?
	hMinutePen dword ?
	hSecondPen dword ?

	struPaintStruct PAINTSTRUCT <>
	struLocalTime SYSTEMTIME <>

.code

CreateHandPens proc
	invoke CreatePen, PS_SOLID, HOURHANDW, HOURHANDCOLOR
	mov hHourPen, eax
	invoke CreatePen, PS_SOLID, MINUTEHANDW, MINUTEHANDCOLOR
	mov hMinutePen, eax
	invoke CreatePen, PS_SOLID, SECONDHANDW, SECONDHANDCOLOR
	mov hSecondPen, eax

	ret
CreateHandPens endp

RefreshLayout proc public uses ebx edx ecx
	local _Rect:RECT

	invoke GetClientRect, hWnd, addr _Rect
	and eax, eax
	jz $ret
	mov ebx, _Rect.right
	mov eax, _Rect.bottom
	shr ebx, 1
	shr eax, 1
	mov CenterPoint.x, ebx
	mov CenterPoint.y, eax
	cmp ebx, eax
	jbe @F
	mov ebx, eax
@@:
	cmp ebx, MINIRADIUS
	jae @F
	mov btTooSmall, 1
	jmp $ret
@@:
	mov dwRadius, ebx
	mov btTooSmall, 0
	shr ebx, PARTSNUM
	mov ecx, HANDLARGINDEX

@@:
		mov eax, ebx
		mul HandBiArg[ecx * (type HandBiArg * HANDBIARGGROUPITEMC)]
		mov HandLArg[ecx * (type HandLArg * HANDARGGROUPITEMC)], eax
		shr eax, TAILBI
		mov HandLArg[ecx * (type HandLArg * HANDARGGROUPITEMC) + type HandLArg], eax
		sub ecx, 1
	jnc @B

	mov eax, ebx
	mul ctdwKeDuBi
	mov dwKeDuL, eax
	mov eax, ebx
	mul ctdwCircleRadiusBi
	mov dwCircleRadius, eax

$ret:
 	ret
RefreshLayout endp

PaintBackground proc
	local P1:POINT, P2:POINT, d:dword, i:dword

	;画钟面圆
	mov eax, CenterPoint.x
	sub eax, dwRadius
	mov P1.x, eax
	mov P2.x, eax
	mov eax, dwRadius
	shl eax, 1
	add P2.x, eax
	mov eax, CenterPoint.y
	sub eax, dwRadius
	mov P1.y, eax
	mov P2.y, eax
	mov eax, dwRadius
	shl eax, 1
	add P2.y, eax
	invoke GetStockObject, 	LTGRAY_BRUSH
	invoke SelectObject, hdcCurrent, eax
	invoke Ellipse, hdcCurrent, P1.x, P1.y, P2.x, P2.y

	;画刻度
	mov i, 60	;60格
	mov ebx, 5	;每5格加长
	finit
	fldpi	;加载Pi
	fild ct180	;加载180
$loop:
	mov eax, i
	mul PerDegree	;得到角度数
	mov d, eax
	fild d
	fdiv st(0), st(1)
	fmul st(0), st(2)	;转为弧度
	fsincos
	fld st(1)	;复制Sin到st(0)
	fimul dwRadius
	fistp P1.x	;横坐标
	fld st(0)
	fimul dwRadius
	fistp P1.y
	fimul dwKeDuL
	fistp P2.y
	fimul dwKeDuL
	fistp P2.x
	cmp ebx, 5
	jne @F
	shl P2.x, 1
	shl P2.y, 1
	xor ebx, ebx
@@:
	mov eax, CenterPoint.x
	add eax, P1.x
	mov P1.x, eax
	sub eax, P2.x
	mov P2.x, eax
	mov eax, CenterPoint.y
	sub eax, P1.y
	mov P1.y, eax
	add eax, P2.y
	mov P2.y, eax

	invoke MoveToEx, hdcCurrent, P1.x, P1.y, 0
	invoke LineTo, hdcCurrent, P2.x, P2.y
	
	inc ebx
	sub i, 1
	jnz $loop

 	ret
PaintBackground endp

PaintHands proc
	local P1:POINT, P2:POINT, d:dword

	invoke GetLocalTime, addr struLocalTime
	movzx eax, struLocalTime.wHour
	cmp eax, 12
	jbe @F
	sub eax, 12
@@:

	finit
	fldpi	;加载Pi
	fild ct180	;加载180

	mul Per5Degree
	mov d, eax
	fild d
	movzx eax, struLocalTime.wMinute
	mul PerDegree
	mov d, eax
	fild d
	mov d, 60 / 5
	fidiv d
	fadd
	fdiv st(0), st(1)	
	fmul st(0), st(2)	;转为弧度
	fsincos
	fld st(1)	;复制Sin到st(0)
	fimul dwHourHandL
	fistp P1.x	;横坐标
	fld st(0)
	fimul dwHourHandL
	fistp P1.y
	fimul dwHourTailL
	fistp P2.y
	fimul dwHourTailL
	fistp P2.x
	mov eax, CenterPoint.x
	add P1.x, eax
	sub eax, P2.x
	mov P2.x, eax
	mov eax, CenterPoint.y
	neg P1.y
	add P1.y, eax
	add eax, P2.y
	mov P2.y, eax
	invoke SelectObject, hdcCurrent, hHourPen
	invoke MoveToEx, hdcCurrent, P1.x, P1.y, 0
	invoke LineTo, hdcCurrent, P2.x, P2.y

	movzx eax, struLocalTime.wMinute
	mul PerDegree
	mov d, eax
	fild d
	movzx eax, struLocalTime.wSecond
	mul PerDegree
	mov d, eax
	fild d
	mov d, 60
	fidiv d
	fadd
	fdiv st(0), st(1)	
	fmul st(0), st(2)	;转为弧度
	fsincos
	fld st(1)	;复制Sin到st(0)
	fimul dwMinuteHandL
	fistp P1.x	;横坐标
	fld st(0)
	fimul dwMinuteHandL
	fistp P1.y
	fimul dwMinuteTailL
	fistp P2.y
	fimul dwMinuteTailL
	fistp P2.x
	mov eax, CenterPoint.x
	add P1.x, eax
	sub eax, P2.x
	mov P2.x, eax
	mov eax, CenterPoint.y
	neg P1.y
	add P1.y, eax
	add eax, P2.y
	mov P2.y, eax
	invoke SelectObject, hdcCurrent, hMinutePen
	invoke MoveToEx, hdcCurrent, P1.x, P1.y, 0
	invoke LineTo, hdcCurrent, P2.x, P2.y
	movzx eax, struLocalTime.wSecond
	mul PerDegree
	mov d, eax
	fild d
	fdiv st(0), st(1)	
	fmul st(0), st(2)	;转为弧度
	fsincos
	fld st(1)	;复制Sin到st(0)
	fimul dwSecondHandL
	fistp P1.x	;横坐标
	fld st(0)
	fimul dwSecondHandL
	fistp P1.y
	fimul dwSecondTailL
	fistp P2.y
	fimul dwSecondTailL
	fistp P2.x
	mov eax, CenterPoint.x
	add P1.x, eax
	sub eax, P2.x
	mov P2.x, eax
	mov eax, CenterPoint.y
	neg P1.y
	add P1.y, eax
	add eax, P2.y
	mov P2.y, eax
	invoke SelectObject, hdcCurrent, hSecondPen
	invoke MoveToEx, hdcCurrent, P1.x, P1.y, 0
	invoke LineTo, hdcCurrent, P2.x, P2.y
	
	mov eax, CenterPoint.x
	sub eax, dwCircleRadius
	mov P1.x, eax
	mov P2.x, eax
	mov eax, dwCircleRadius
	shl eax, 1
	add P2.x, eax
	mov eax, CenterPoint.y
	sub eax, dwCircleRadius
	mov P1.y, eax
	mov P2.y, eax
	mov eax, dwCircleRadius
	shl eax, 1
	add P2.y, eax
	invoke Ellipse, hdcCurrent, P1.x, P1.y, P2.x, P2.y
	ret
PaintHands endp

TimerProc proc
	invoke InvalidateRect, hWnd, 0, TRUE
	ret 16
TimerProc endp

WindowProc proc uses ebx edi esi , _hWnd, _uMsg, _wParam, _lParam

	.if _uMsg == WM_PAINT
		or btTooSmall,0
		jnz @F
		invoke BeginPaint, hWnd, addr struPaintStruct
		mov hdcCurrent, eax
		invoke PaintBackground
		invoke PaintHands
		invoke EndPaint, hWnd, addr struPaintStruct
	@@:
		xor eax,eax
		ret
	.elseif _uMsg == WM_SIZE
		invoke RefreshLayout
		invoke DefWindowProc, _hWnd, _uMsg, _wParam, _lParam
		ret
	.elseif _uMsg == WM_DESTROY
		invoke PostQuitMessage,0
		xor eax,eax
		ret
	.else
		invoke DefWindowProc, _hWnd, _uMsg, _wParam, _lParam
		ret
	.endif

WindowProc endp

WinMain proc public
	local _msg:MSG

	invoke CreateHandPens
 	invoke GetModuleHandle, NULL
	mov hInstance, eax
	mov struWinClass.hInstance, eax
	mov struWinClass.cbSize, sizeof struWinClass
	mov struWinClass.style, CS_HREDRAW or CS_VREDRAW
	mov struWinClass.lpfnWndProc, offset WindowProc
	mov struWinClass.lpszClassName, offset WinClassName
	Mov struWinClass.hbrBackground, (COLOR_BTNFACE + 1)
	invoke LoadIcon, hInstance, ICON_MAIN
	mov struWinClass.hIcon , eax
	mov struWinClass.hIconSm, eax
	invoke LoadCursor,NULL,IDC_ARROW
    mov struWinClass.hCursor,eax
	invoke RegisterClassEx, addr struWinClass
	Invoke CreateWindowEx, WS_EX_APPWINDOW or WS_EX_TOPMOST, addr WinClassName, addr WinClassName, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, FORMWIDTH, FORMHEIGHT, \
		NULL, NULL, hInstance, NULL
	mov hWnd, eax
	invoke ShowWindow, hWnd, SW_SHOWNORMAL
	invoke UpdateWindow, hWnd
	invoke SetTimer, hWnd, TIMER_ID, 1000, addr TimerProc
L:
	invoke GetMessage, addr _msg, NULL, 0, 0
	and eax, eax
	jz exit
	

	invoke TranslateMessage, addr _msg
	invoke DispatchMessage, addr _msg
	jmp L
exit:
	invoke ExitProcess, 0

	ret
WinMain endp

end WinMain