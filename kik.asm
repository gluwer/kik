; Aplikacja: Kó³ko i krzy¿yk dla systemu Windows
; Autor: Rafa³ Joñca
; 

.386                   ; wersja procesora
.model flat, stdcall   ; korzystanie z modelu FLAT & wywo³añ STDCALL
option casemap :none   ; w³¹czenie uwzglêdniania wielkoœci liter

; do³¹czane pliki nag³ówkowe
      include c:\MASM32\INCLUDE\windows.inc
      include c:\MASM32\INCLUDE\gdi32.inc
      include c:\MASM32\INCLUDE\user32.inc
      include c:\MASM32\INCLUDE\kernel32.inc

; do³¹czane biblioteki
      includelib c:\MASM32\LIB\gdi32.lib
      includelib c:\MASM32\LIB\user32.lib
      includelib c:\MASM32\LIB\kernel32.lib

; ------------------------------------------------------------------------
; przydatne MAKRA

; makro u³atwiajace tworzenie tekstów w dowolnym miejscu
szText MACRO Name, Text:VARARG
    LOCAL lbl
    jmp lbl
    Name db Text,0
lbl:
    ENDM

; makro kopiowania jednej wartoœci do drugiej (kopiowanie pamiêæ-pamiêæ)
m2m MACRO M1, M2
    push M2
    pop  M1
    ENDM

; makro powrotu z podprogramu       
return MACRO arg
    mov eax, arg
    ret
    ENDM

; makro czyszczenia tablicy z polami
zerujTab MACRO
    LOCAL etyk
    mov ecx,8           ; inicjalizacja licznika
etyk:
    mov tablica[ecx],0  ; ustawienie elementu tablicy na zero
    loop etyk           ; jeœli jeszcze nie zero, nastêpny etap
    mov tablica,0       ; wyzerowanie tak¿e elementu zerowego
    ENDM

; prototypy
    WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
    WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
    TopXY PROTO   :DWORD,:DWORD
    Paint_Proc   PROTO :DWORD,:DWORD
    Analiza_Klikniecia PROTO
    Analiza_Konca PROTO
    Ruch_Komputera PROTO

; inicjalizowane dane

.data
    szDisplayName db "Kó³ko i krzy¿yk",0   ; nazwa wyœwietlanego okna
    CommandLine   dd 0                     ; wiersz poleceñ (pusty)
    hWnd          dd 0                     ; uchwyt okna
    hInstance     dd 0                     ; uchwyt kopii
    tablica       db 9 dup (0)             ; tablica z elementami planszy
    ktoGra        db 0                     ; 1 - gra kó³ko, 2 - gra krzy¿yk lub komputer
    rodzajGry     db 0                     ; 0 - brak gry, 1 - gra dla dwóch, 2 - gra z komputerem
    bmpPlansza    dd 0                     ; uchwyt bitmapy planszy
    bmpKolko      dd 0                     ; uchwyt bitmapy kó³ka
    bmpKrzyzyk    dd 0                     ; uchwyt bitmapy krzy¿yka
    kliknieto     db 0                     ; przechowuje numer kliknietego pola
    ruch          db 0                     ; zawiera liczbe ruchów wykonanych od pocz¹tkugry

.data?
    punkt POINT <>                         ; struktora przechowuj¹ca wspó³rzêdne myszy

; ------------------------------------------------------------------------

        
    .code


start:
    invoke GetModuleHandle, NULL ; pobiera uchwyt kopii
    mov hInstance, eax           ; zapamiêtuje go

    invoke LoadBitmap,hInstance,700 ; wczytanie i pobranie uchwytów dla bitmap
    mov bmpPlansza, eax
    invoke LoadBitmap,hInstance,702
    mov bmpKrzyzyk, eax
    invoke LoadBitmap,hInstance,703
    mov bmpKolko, eax

    invoke GetCommandLine        ; pobiera adres wiersza poleceñ

    invoke WinMain,hInstance,NULL,CommandLine,SW_SHOWDEFAULT
    
    invoke ExitProcess,eax       ; powrót do systemu operacyjnego

; #########################################################################

; g³ówna procedura programu, jej format jest narzucony przez system

WinMain proc hInst     :DWORD,
             hPrevInst :DWORD,
             CmdLine   :DWORD,
             CmdShow   :DWORD

        ; umieszczenie zmiennych LOCAL na stosie
        
        LOCAL wc   :WNDCLASSEX   ; struktora klasy okna
        LOCAL msg  :MSG          ; struktura komunikatu

        LOCAL Wwd  :DWORD        ; zmienne lokalne wykorzystywane do centrowania okna na ekranie
        LOCAL Wht  :DWORD
        LOCAL Wtx  :DWORD
        LOCAL Wty  :DWORD

        szText szClassName,"KIK_Class"

        ; wype³nianie struktury WNDCLASSEX zmiennymi, aby uzyskaæ na ekranie odpowiednie okno

        mov wc.cbSize,         sizeof WNDCLASSEX
        mov wc.style,          CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW
        mov wc.lpfnWndProc,    offset WndProc      ; adres WndProc
        mov wc.cbClsExtra,     NULL
        mov wc.cbWndExtra,     NULL
        m2m wc.hInstance,      hInst               ; uchwyt kopii
        mov wc.hbrBackground,  COLOR_WINDOW+1      ; kolor systemowy
        mov wc.lpszMenuName,   NULL
        mov wc.lpszClassName,  offset szClassName  ; nazwa klasy okna
          invoke LoadIcon,hInst,500                ; zasob ikony
        mov wc.hIcon,          eax
          invoke LoadCursor,NULL,IDC_ARROW         ; kursor systemowy
        mov wc.hCursor,        eax
        mov wc.hIconSm,        0

        invoke RegisterClassEx, ADDR wc     ; rejestracja klasy okna

        ; centrowanie okna o podanych wymiarach

        mov Wwd, 160  ; wymiary okna, szerokoœæ
        mov Wht, 225  ; wymiary okna, wysokoœæ

        invoke GetSystemMetrics,SM_CXSCREEN ; pobranie szerokoœci ekranu
        invoke TopXY,Wwd,eax
        mov Wtx, eax

        invoke GetSystemMetrics,SM_CYSCREEN ; pobranie wysokoœci ekranu
        invoke TopXY,Wht,eax
        mov Wty, eax


        ; Wyœwietlanie g³ównego okna programu
        ; bez mo¿liwoœci zmiany rozmiaru, z menu i tytu³em

        invoke CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,
                              ADDR szClassName,
                              ADDR szDisplayName,
                              WS_OVERLAPPED or WS_SYSMENU or WS_MINIMIZEBOX,
                              Wtx,Wty,Wwd,Wht,
                              NULL,NULL,
                              hInst,NULL

        mov   hWnd,eax  ; skopiowanie zwróconej wartoœci do zmiennej uchwytu DWORD

        invoke LoadMenu,hInst,600                 ; wczytanie menu z zasobów
        invoke SetMenu,hWnd,eax                   ; ustawienie go dla okna

        invoke ShowWindow,hWnd,SW_SHOWNORMAL      ; wyœwietlenie okna
        invoke UpdateWindow,hWnd                  ; aktualizacja okna

      ; zapêtlenie a¿ do otrzymania komunikatu PostQuitMessage 

    petlag:
        invoke GetMessage,ADDR msg,NULL,0,0         ; pobranie komunikatu
        cmp eax, 0                                  ; wyjœcie jeœli GetMessage() 
        je pkoniec                                  ; zwróæ zero
        invoke TranslateMessage, ADDR msg           ; przekszta³cenie komunikatu
        invoke DispatchMessage,  ADDR msg           ; wys³anie do procedury rozdzialania komunikatów
        jmp petlag
    pkoniec:

      return msg.wParam                             ; zwrócenie wartoœci wyjœcia programu do systemu

WinMain endp

; #########################################################################

; procedura wywo³ywana po otrzymaniu komunikatu od systemu
; zajmuje siê wykonaniem odpowiednich zadañ w zale¿noœci od uzyskanego komunikatu

WndProc proc hWin   :DWORD,
             uMsg   :DWORD,
             wParam :DWORD,
             lParam :DWORD

    LOCAL hDC    :DWORD
    LOCAL Ps     :PAINTSTRUCT

    .if uMsg == WM_COMMAND ; komunikat poleceñ menu

        ; polecenia menu
        .if wParam == 1000 ; polecenie gry dwuosobowej
            mov ktoGra,1   ; ustawienie zmiennych na grê dwuosobow¹
            mov rodzajGry,1
            mov ruch,0
            zerujTab       ; zerowanie tablicy
            invoke InvalidateRect, hWnd, NULL, TRUE ; wymuszenie odrysowania okna
        .elseif wParam == 1001 ; polecenie gry z komputerem
            invoke GetTickCount ; proste wygenerowanie, czy pierwszy ruch nale¿y do gracza, czy do komp.
            shr eax,2
            and eax, 1
            inc eax
            mov ktoGra,al       ; przypisanie wygenerowanej wartoœci - 1 lub 2
            mov rodzajGry,2
            mov ruch,0
            zerujTab       ; zerowanie tablicy
            .if ktoGra == 2 ; jeœli to ruch komputera, wykonujemy go i zmieniamy ktoGra na gracza
                call Ruch_Komputera
                mov ktoGra,1
            .endif
            invoke InvalidateRect, hWnd, NULL, TRUE ; wymuszenie odrysowania okna
        .elseif wParam == 1002  ; polecenie wyjœcia
            invoke SendMessage,hWin,WM_SYSCOMMAND,SC_CLOSE,NULL ; wys³anie komunikatu wyjœcia
        .elseif wParam == 1900 ; wyœwietlenie informacji o programie
            szText infoProg,"Gra kó³ko i krzy¿yk",13,10,"Autor: Rafa³ Joñca  Rok:2003"
            invoke MessageBox,hWin,ADDR infoProg,ADDR szDisplayName,MB_OK
        .endif

    ; koniec poleceñ menu

    .elseif uMsg == WM_CLOSE  ; wys³ano kumunikat zamkniêcie okna
        szText pytanieWyj,"Czy na pewno chcesz zakoñczyæ grê w toku?"
        .if rodzajGry != 0    ; jeœli odbywa siê gra, wyœwietlamy zapytanie, czy j¹ zakoñczyæ
          invoke MessageBox,hWin,ADDR pytanieWyj,ADDR szDisplayName,MB_YESNO
          .if eax == IDNO ; jeœli nie, wracamy
            return 0
          .endif
        .endif

    .elseif uMsg == WM_PAINT  ; komunikat odrysowania okna
        invoke BeginPaint,hWin,ADDR Ps ; rozpoczêcie rysowania
        mov hDC, eax
        invoke Paint_Proc,hWin,hDC     ; wywo³anie procedury rysowania
        invoke EndPaint,hWin,ADDR Ps   ; zakoñczenie rysowania
        return 0

    .elseif uMsg==WM_LBUTTONDOWN       ; klikniêto lewym przyciskiem myszy
      .if rodzajGry != 0
		mov eax,lParam           ; wydobycie wspó³rzêdnych kursora myszy do struktury punkt
		and eax,0ffffh
		mov punkt.x,eax
		mov eax,lParam
		shr eax,16
		mov punkt.y,eax
        call Analiza_Klikniecia  ; w al zwraca numer klikniêtego pola lub 0, jeœli poza polem
        ; mov kliknieto,al
        .if al==0                ; jeœli zwrócono zero, wyœwietl komunikat
            szText pozaObszarem,"Klikniêto poza obszarem gry!"
            invoke MessageBox,hWin,ADDR pozaObszarem,ADDR szDisplayName,MB_OK
        .else                    ; jeœli to pole, odejmij 1, aby uzyskaæ indeks dla tablicy
            mov ebx,eax
            dec ebx
            .if tablica[ebx] != 0 ; jeœli klikniête pole jest zajête, wyœwietl komunikat
                szText poleZajete,"To pole jest zajête!"
                invoke MessageBox,hWin,ADDR poleZajete,ADDR szDisplayName,MB_OK
            .else
                inc ruch         ; inkrementacja liczby ogólnie wykonanych ruchów
                mov  al, ktoGra
                mov  tablica[bx],al ; umieszczenie ruchu w tablicy
                invoke InvalidateRect, hWnd, NULL, TRUE ; spowodowanie odrysowania tablicy
                mov al, ktoGra      ; ponowne umieszczenie ktoGra w al, poniewa¿ 
                call Analiza_Konca  ; wymaga tego Analiza_Konca (przekazywanie param przez rejestr)
                .if eax == 1        ; analiza wykaza³a, ¿e koniec gry
                  .if rodzajGry == 2 ; gdy gra z komputerem, wygra³ gracz
                    szText wygranaGracza,"Wygra³ gracz!"
                    invoke MessageBox,hWin,ADDR wygranaGracza,ADDR szDisplayName,MB_OK
                  .elseif ktoGra == 1 ; gdy ruch wykonywa³o kó³ko, to one wygra³o
                    szText wygranaKolka,"Wygra³o kó³ko!"
                    invoke MessageBox,hWin,ADDR wygranaKolka,ADDR szDisplayName,MB_OK
                  .else               ; gdy ruch wykonywa³ krzy¿yk, to on wygra³
                    szText wygranaKrzyzyka,"Wygra³ krzy¿yk!"
                    invoke MessageBox,hWin,ADDR wygranaKrzyzyka,ADDR szDisplayName,MB_OK
                  .endif
                  mov ktoGra,0       ; skoro wygrana, reset ustawieñ i tablicy
                  mov rodzajGry,0
                  mov ruch,0
                  zerujTab
                  jmp aktualizuj
                .endif
                .if ruch == 9 ; skoro nie by³o wygranej i wykonano ostatni mo¿liwy ruch, jest remis
                  szText remis,"Jest remis!"
                  invoke MessageBox,hWin,ADDR remis,ADDR szDisplayName,MB_OK
                  mov ktoGra,0  ; skoro remis, reset ustawieñ i tablicy
                  mov rodzajGry,0
                  mov ruch,0
                  zerujTab
                  jmp aktualizuj
                .endif
                .if rodzajGry == 2 ; skoro gra z komputerem, niech wykona swój ruch
                    call Ruch_Komputera
                    invoke InvalidateRect, hWnd, NULL, TRUE  ; po wykonaniu ruchu, aktualizacja okna
                    mov al,2
                    call Analiza_Konca ; sprawdzenie warunków koñca po ruchu komputera
                    .if eax == 1       ; skoro 1, komputer wykona³ wyrywaj¹ce posuniêcie
                        szText wygranaKomp,"Wygra³ komputer!"
                        invoke MessageBox,hWin,ADDR wygranaKomp,ADDR szDisplayName,MB_OK
                        mov ktoGra,0   ; skoro wygrana, reset ustawieñ i tablicy
                        mov rodzajGry,0
                        mov ruch,0
                        zerujTab
                        jmp aktualizuj
                    .elseif ruch == 9  ; jeœli nie by³o wygranej i zajêto ostatnie wolne miejsce, jest remis
                        invoke MessageBox,hWin,ADDR remis,ADDR szDisplayName,MB_OK
                        mov ktoGra,0   ; skoro remis, reset ustawieñ i tablicy
                        mov rodzajGry,0
                        mov ruch,0
                        zerujTab
                        jmp aktualizuj
                    .endif
                .elseif ktoGra == 1 ; skoro gra dla dwóch graczy, zamiana gracza
                    mov ktoGra, 2
                .else
                    mov ktoGra, 1
                .endif
aktualizuj:     invoke InvalidateRect, hWnd, NULL, TRUE ; odrysowanie okna
            .endif
        .endif
      .endif  

    .elseif uMsg == WM_DESTROY       ; komunikat usuwania okna
        invoke PostQuitMessage,NULL  ; wys³anie komunikatu zamkniêcia
        return 0 
    .endif

    invoke DefWindowProc,hWin,uMsg,wParam,lParam

    ret

WndProc endp

; ########################################################################

; obliczanie lewego lub górnego naro¿nika okna, aby znalaz³o siê ono na œrodku
; przyjmuje: wymiar ekranu i wymiar okna
; zwraca: w eax miejce umieszczenia pocz¹tku okna
; niszczy: eax
TopXY proc wDim:DWORD, sDim:DWORD
    shr sDim, 1      ; podzielenie wymiaru ekranu przez 2
    shr wDim, 1      ; podzielenie wymiaru okna przez  2
    mov eax, wDim
    sub sDim, eax    ; obliczenie, gdzie umieœciæ pocz¹tek okna
    return sDim
TopXY endp

; rysowanie zawartoœci okna (plansza, kó³ka, krzy¿yki i napis)
; przyjmuje: uchwyt okna i uchwyt kontekstu
; zwraca: 0 w eax
; niszczy: eax
Paint_Proc proc hWin:DWORD, hDC:DWORD
    LOCAL hOld:DWORD     ; stary uchwyt
    LOCAL memDC :DWORD   ; uchwyt na kontekst pamiêci
    LOCAL rect: RECT     ; strukura prostopad³oœcianu

    szText graczKolko, "Ruch kó³ka..."
    szText graczKrzyzyk, "Ruch krzy¿yka..."
    szText graczGracz, "Ruch gracza..."
    invoke GetClientRect,hWnd, ADDR rect

    cmp rodzajGry,0      ; pomiñ napis, jeœli jeszcze nie rozpoczêto gry
    je dalejRys
    .if rodzajGry == 2   ; wyœwietlanie odpowiedniego napisu
        invoke DrawText, hDC,ADDR graczGracz,-1, ADDR rect, DT_SINGLELINE or DT_BOTTOM or DT_LEFT
    .elseif ktoGra == 1
        invoke DrawText, hDC,ADDR graczKolko,-1, ADDR rect, DT_SINGLELINE or DT_BOTTOM or DT_LEFT
    .else
        invoke DrawText, hDC,ADDR graczKrzyzyk,-1, ADDR rect, DT_SINGLELINE or DT_BOTTOM or DT_LEFT
    .endif
dalejRys:
    ; rysowanie planszy
    invoke CreateCompatibleDC,hDC      ; pobranie kontekstu
    mov memDC, eax
    invoke SelectObject,memDC,bmpPlansza  ; wybór obiektu
    mov hOld, eax                         ; zapamiêtanie starego obiektu, zwróconego przez SelectObject
    invoke BitBlt,hDC,0,0,150,150,memDC,0,0,SRCCOPY ; skopiowanie bitmapy na ekran
    invoke SelectObject,hDC,hOld
    invoke DeleteDC,memDC    ; usuniêcie kontekstu

    ; rysowanie kó³ek w ten sam sposób, co planszy
    invoke CreateCompatibleDC,hDC
    mov memDC, eax
    invoke SelectObject,memDC,bmpKolko
    mov hOld, eax

; krótkie makro skracaj¹ce zapis kopiowania bitmapy
BitBltaa MACRO x1, y1, x2, y2
    invoke BitBlt,hDC,x1,y1,x2,y2,memDC,0,0,SRCCOPY
ENDM

    ; umieszczanie 
    .if tablica[0] == 1 ; rysowanie bitmapy kó³ka, jeœli jeden w odpowiednim miejscu tablicy
        BitBltaa 5,5,40,40 ; nie mo¿na zwin¹æ if-ów w ³atwy sposób, poniewa¿ miejsca wstawiania
    .endif                 ; na ekranie s¹ w ró¿nych miejscach, któych nie mo¿na obliczyæ zbyt
    .if tablica[1] == 1    ; ³atwo a przynajmniej zaje³oby to podobn¹ iloœæ miejsca
        BitBltaa 55,5,40,40
    .endif
    .if tablica[2] == 1
        BitBltaa 105,5,40,40
    .endif
    .if tablica[3] == 1
        BitBltaa 5,55,40,40
    .endif
    .if tablica[4] == 1
        BitBltaa 55,55,40,40
    .endif
    .if tablica[5] == 1
        BitBltaa 105,55,40,40
    .endif
    .if tablica[6] == 1
        BitBltaa 5,105,40,40
    .endif 
    .if tablica[7] == 1
        BitBltaa 55,105,40,40
    .endif
    .if tablica[8] == 1
        BitBltaa 105,105,40,40
    .endif
    invoke SelectObject,hDC,hOld
    invoke DeleteDC,memDC

    ; rysowanie krzy¿yków
    invoke CreateCompatibleDC,hDC
    mov memDC, eax
    invoke SelectObject,memDC,bmpKrzyzyk
    mov hOld, eax

    .if tablica[0] == 2 ; podobnie jak dla kó³ek, ale rysowanie, gdy w tablicy jest 2
        BitBltaa 5,5,40,40
    .endif
    .if tablica[1] == 2
        BitBltaa 55,5,40,40
    .endif
    .if tablica[2] == 2
        BitBltaa 105,5,40,40
    .endif
    .if tablica[3] == 2
        BitBltaa 5,55,40,40
    .endif
    .if tablica[4] == 2
        BitBltaa 55,55,40,40
    .endif
    .if tablica[5] == 2
        BitBltaa 105,55,40,40
    .endif
    .if tablica[6] == 2
        BitBltaa 5,105,40,40
    .endif 
    .if tablica[7] == 2
        BitBltaa 55,105,40,40
    .endif
    .if tablica[8] == 2
        BitBltaa 105,105,40,40
    .endif
    invoke SelectObject,hDC,hOld
    invoke DeleteDC,memDC
    return 0 ; zwrócenie w eax 0
Paint_Proc endp

; makro pomocniczne upraszczaj¹ce zapis procedury analizy klikniêcia
AnalizaKlik MACRO x1,y1,x2,y2,co
    LOCAL dalejjj
    cmp eax, x1 ; sprawdzanie kratki - lewy górny naro¿nik
    jb dalejjj
    cmp eax, y1
    ja dalejjj
    cmp edx, x2 ; prawy dolny naro¿nik
    jb dalejjj
    cmp edx, y2
    ja dalejjj
    mov eax,co ; jest to kratka co, skoro tutaj dotarliœmy
    jmp koniec ; skok na koniec procedury analizy
dalejjj: ; kontynuacja sprawdzania (po rozwiniêciu makra)
ENDM


; procedura sprawdza, któr¹ kratkê planszy klikniêto
; procedura nie przyjmuje parametrów, ale wykorzystuje informacje zawarte w globalnej zmiennej punkt
; procedura zwraca w eax numer kratki 1 do 9 lub 0, jeœli klikniêto poza obszarem kratek
; niszczy: eax (edx jest zapamiêtywane na stosie)
Analiza_Klikniecia proc
    push edx
    mov eax,punkt.x    ; umieszczenie wspó³rzêdnych w eax i edx
    mov edx,punkt.y
    AnalizaKlik 5,45,5,45,1        ; sprawdzanie, czy klikniêto w pierwszym kwadracie 
    AnalizaKlik 55,95,5,35,2       ; sprawdzenia dla kolejnych kwadratów
    AnalizaKlik 105,145,5,45,3
    AnalizaKlik 5,45,55,95,4
    AnalizaKlik 55,95,55,95,5
    AnalizaKlik 105,145,55,95,6
    AnalizaKlik 5,45,105,145,7
    AnalizaKlik 55,95,105,145,8
    AnalizaKlik 105,145,105,145,9
    mov eax,0                       ; klikniêto obszar poza kratkami
koniec:
    pop edx
    ret
Analiza_Klikniecia endp

; makro pomagaj¹ce przy sprawdzaniu, czy istnieje warunek koñca gry
sprawdz MACRO a,b,c,kogo
    LOCAL niema
    cmp tablica[a],kogo  ; sprawdzanie, czy indeksy a,b i c tablicy zawieraj¹ tê sam¹ wartoœæ
    jne niema            ; równ¹ kogo
    cmp tablica[b],kogo
    jne niema
    cmp tablica[c],kogo
    jne niema
    mov eax, 1           ; wszystkie trzy zawieraj¹ to samo, wiêc ustaw eax na 1
    jmp koniecspr        ; i skoñcz sprawdzanie ca³oœci, bo znaleziono warunek wygranej
niema:                   ; skoro tu jesteœmy, któraœ z wartoœci by³a inna
ENDM

; procedura analizuj¹ca, czy istnieje jakaœ trójka dla gracza okreœlonego w al
; przyjmuje jako parametr wartoœæ numeru gracza w al
; wynik zwracany jest w eax
; niszczone jest tylko eax
Analiza_Konca proc
    sprawdz 0,1,2,al   ; sprawdzanie kolejnych trójek
    sprawdz 0,4,8,al
    sprawdz 0,3,6,al
    sprawdz 1,4,7,al
    sprawdz 2,4,6,al
    sprawdz 2,5,8,al
    sprawdz 3,4,5,al
    sprawdz 6,7,8,al
    mov eax,0          ; skoro ¿adnej nie znaleziono, zwracamy 0
koniecspr:
    ret
Analiza_Konca endp


; procedura wykonuj¹ca ruch komputera, gdy jest to odpowiednie
; dla podanej trójki zmiennych
; procedura sprawdza, czy istnieja dwa pola "kogo" w jedej linii a trzecie jest puste
; jeœli tak, wstawia ruch komputera w pustym miejscu
; przyjmowane s¹ cztery parametry: elementy tablicy (a, b i cc), oraz "kogo"
; czyli wzglêdem kogo jest wykonywane sprawdzanie
; procedura zwraca w eax 0, jesli ruchu nie wykonano lub 1, jeœli wykonano
; niszczone s¹ wszystkie cztery podstawowe rejestry, czyli eax, ebx, ecx i edx
sprawdzKomp proc STDCALL a:DWORD,b:DWORD,cc:DWORD,kogo:DWORD
    mov dx, 0                ; inicjalizacja
    mov ecx,kogo
    mov ebx,0
    mov eax, a
    .if  tablica[eax] == cl  ; czy jest tu "kogo"?
        inc dx
    .elseif tablica[eax] == 0 ; czy jest to puste miejsce?
        mov ebx,a
    .else                   ; zajmujemy to miejsce?
        mov dx, 5
        jmp koniecKo
    .endif
    mov eax, b
    .if  tablica[eax] == cl
        inc dx
    .elseif tablica[eax] == 0
        mov ebx,b
    .else
        mov dx, 5
        jmp koniecKo
    .endif
    mov eax, cc
    .if tablica[eax] == cl
        inc dx
    .elseif tablica[eax] == 0
        mov ebx,cc
    .else
        mov dx, 5
    .endif
koniecKo:
    cmp dx,5              ; jeœli któreœ z miejsc by³o zajête przez przeciwnika, zwróc 0
    je @F
    cmp dx,2              ; jeœli pól zajêtych przez kogo nie bylo 2, zwróc 0
    jne @F
    mov tablica[ebx],2    ; w pozosta³ych przypadkach wstaw w puste miejsce tablicy krzy¿yk (2)
    inc ruch              ; zwiêksz liczbê wykonanych ruchów o 1
    return 1              ; i zwróæ 1, aby zaznaczyæ, ¿e ruch wykonano
@@:
    return 0
sprawdzKomp endp

; wykonuje ruch komputera
; najpierw sprawdzana jest mo¿liwoœæ wygranej przez komputer
; nastêpnie sprawdzane jest, czy nale¿y siê broniæ przed wygran¹ gracza
; jeœli nie nast¹pi ¿adna z powy¿szych sytuacji a œrodek jest pusty, wstawiamy tam krzy¿yk
; jeœli wszystkie poprzednie sytuacje zawiod³y, wstawiamy krzy¿yk w pierwsze wolne miejsce
; procedura nie przyjmuje parametrów
; procedura nic nie zwraca
; zachowywane s¹ wszystkie rejestry bior¹ce udzia³ w obliczeniach
Ruch_Komputera proc uses eax ebx ecx edx
    LOCAL licznik:DWORD ; najpierw sprawdzanie warunku wygranej dla siebie (licznik==2)
                        ; nastêpnie sprawdzanie warunku dla przeciwnika (licznik==1)
    mov licznik,2
petelka:
    invoke sprawdzKomp,0,1,2,licznik    ; sprawdzanie warunku wygranej dla pierwszej kombinacji
    cmp eax,1                           ; jeœli ruch wykonany, skok na wyjœcia z funkcji
    je koniecKomp
    invoke sprawdzKomp,0,4,8,licznik
    cmp eax,1
    je koniecKomp
    invoke sprawdzKomp,0,3,6,licznik
    cmp eax,1
    je koniecKomp
    invoke sprawdzKomp,1,4,7,licznik
    cmp eax,1
    je koniecKomp
    invoke sprawdzKomp,2,4,6,licznik
    cmp eax,1
    je koniecKomp
    invoke sprawdzKomp,2,5,8,licznik
    cmp eax,1
    je koniecKomp
    invoke sprawdzKomp,3,4,5,licznik
    cmp eax,1
    je koniecKomp
    invoke sprawdzKomp,6,7,8,licznik
    cmp eax,1
    je koniecKomp
    dec licznik         
    cmp licznik,0       ; jeœli licznik==0, sprawdziliœmy ju¿ siebie i przeciwnika
    jne petelka         ; wiêc wyjœcie
    invoke sprawdzKomp,2,4,8,1 ;zabezpieczenie przed pewn¹ sztuczk¹ powoduj¹c¹ wygran¹ gracza
    cmp eax,1
    je koniecKomp
    mov ebx,0
    cmp tablica[4],0    ; jeœli œrodek wolny, wstawiamy tam krzy¿yk
    jne juzjest
    mov tablica[4],2
    inc ruch
    ret
juzjest:                 ; wyszukanie pierwszego pustego miejsca i wstawienie tam krzy¿yka (2)
    inc bx
    cmp tablica[bx-1],0 ; czy to puste miejsce?
    jne juzjest         ; jeœli nie, szukamy dalej
    dec bx              ; przejœcie z numeru kratki na numer w³asciowy tablicy
    mov tablica[bx],2   ; wstawienie krzy¿yka (2) w puste miejsce
    inc ruch            ; zwiêkszenie liczby ruchów
koniecKomp:
    ret
Ruch_Komputera endp


; ########################################################################

end start