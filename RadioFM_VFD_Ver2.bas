'(
      Radio FM cu afisaj VFD - Copyright YO6PIR(2020)

      Data Procesor  - Atmega88
      VFD Controller - PT6302
      Oscilator intern 8Mhz
      Radio Processor = TEA5767 (verificati codul IC-ului montat)
      Radio Data System emulate in software
      RTC activ in cod = ISL1208 cu baterie backup 3V
      Volume Control cu IC-TPL0401A-10 din taste <UP><DWN>
      Cautare automata cu tastele <LEFT><RIGHT> soft "MUTE"
      Cautare manuala cu tastele <LEFT><RIGHT> apasate din nou
      Ceas afisat in mod StandBy pe digiti central
      Buton SatndBy cu LED bi-color <verde-rosu>

*******************************************************
')
$Regfile = "m88adef.dat"
$Crystal = 8000000
'Necesita RC intern 8MHz cu fuse CKDIV8 neprogramat; PB6/PB7 sunt folositi ca I/O.
$hwstack = 40
$swstack = 16
$framesize = 32
Config Submode = NEW

Const On = 1
Const OFF = 0
Const Tea5767w = &HC0                                       'Protocol/adresa activa: TEA5767; verificati piesa montata
Const Tea5767r = &HC1
'(
'Adrese DS1307 doar ca referinta; rutinele active sunt specifice ISL1208.
Ceas RTC DS1307
      Const I2Cwrite = &HD0                                 'Adresa DS1307 Write
      Const I2Cread = &HD1                                  'Adresa DS1307 Read
')
'Ceas RTC ISL1208 (implementarea activa)
Const I2Cwrite = &HDE                                       'Adresa ISL1208 Write
Const I2Cread = &HDF                                        'Adresa ISL1208 Read

Const I2Cvolumew = &B01011100                               'Adresa TPL0401 write
Const I2Cvolumer = &B01011101                               'Adresa TPL0401 read

DDRB.0 = 1 : Strobe alias PORTB.0
DDRB.6 = 1 : DataPin alias PORTB.7
DDRB.7 = 1 : ClockPin alias PORTB.6
DDRC.4 = 1 : LedV Alias PORTC.4 : Reset LedV
DDRC.5 = 1 : LedR Alias PORTC.5 : Reset LedR
DDRB.2 = 1 : SW ALIAS PORTB.2

Config Scl = PortD.1                                        'Config Serial Clock
Config Sda = PortD.0                                        'Config Serial Data
I2Cinit

'Configurare matrice taste
ddrd.5 = 1 : Row1 alias portd.5
ddrd.6 = 1 : Row2 alias portd.6
ddrd.7 = 1 : Row3 alias portd.7
DDRB.1 = 0 : Colon1 alias pinb.1
DDRC.0 = 0 : Colon2 alias pinc.0
DDRC.1 = 0 : Colon3 alias pinc.1

'EEPROM: adresa 0 ramane rezervata; sirurile fixe ocupa 1..325.
'EepromText: 1..18 RDS, 19..20 MEMORY, 21 gol, 22..25 meniu.
Dim EepromText(25) As Eram String * 12 At 1
Dim Efrecventa As Eram Word At &H146                       'Frecventa memorata
Dim DP(2) As Byte                                           'Var.puncte clipitoare
Dim a As Byte , b As Byte , j As Byte , k As Byte           'Var.de lucru
Dim Text As String * 12                                     'Textul afisat pe display
Dim C(12)As Byte                                            'Var.de conversie pentru VFD controller
Dim CifraCeas(4) As Byte                                    'Cifrele ceasului afisat
Dim Cifra As Byte
Dim RFMF As Boolean                                         'Radio FM Flag
Dim Semnal As Byte
Dim Index As Integer , Index1 As Byte
Dim Isearch As Integer
Dim RdsScrollBuffer As String * 36
Dim RdsScrollPosition As Byte
Dim RdsScrollTimer As Byte
Dim Watchdog_timer As Byte

Dim Rozeta As Word
Dim ConfigTasteFlags As Word                                'cuvantul care tine FLAGS taste
Dim MenuByte As Byte                                        'variabla meniuri
Dim Minute As Byte , Ore As Byte
Dim Volume As Byte
Dim VolumeTemp As Byte
Dim Evolume As Eram Byte At &H148
Dim EfrecuentaSOL As Eram Word At &H149
Dim EfrecuentaBK As Eram Word At &H14B
Dim EepromLayout As Eram Word At &H14D                    'semnatura pentru noua harta EEPROM
Dim PresetHold As Byte
Dim PresetLong As Boolean
Dim TunerReady As Boolean
Dim TunerUpdated As Boolean
Dim TunerMute As Boolean
Dim TunerFrequency As Word
Dim RTCstatus As Byte
Dim Hour12 As Byte
Dim HourPM As Byte
Dim RawHour As Byte
Dim RawSeconds As Byte
Dim RawMinutes As Byte

Dim Frecventa As Word , Frecventa_old As Word               'Frecventa radioului format [1029=102,9MHz]
PresetReturn Alias Frecventa_old.15                         'Bit liber: marcheaza previzualizarea unui preset
Dim Frecventa_Str As String * 4
Dim Ar(7) As Byte
Dim Control(5) As Byte
Dim Radio As Boolean                                        'Flag care porneste sau opreste radioul
Dim Action As Boolean                                       'Bit care indica schimbarea frecventei de acord
Dim MUTE As Boolean                                         'Bit MUTE radio
Dim Search As Byte
Search_stg Alias Search.0
Search_dr Alias Search.1
'VolUP Alias Search.3
'VolDWN Alias Search.4

'Configurare comenzi
Dim ConfigCMD As Byte
PrintF alias ConfigCMD.0                                    'Print On Display Actionive
Roz Alias ConfigCMD.1                                       'Rozetta Actionive
UDvF Alias ConfigCMD.2                                      'Change Volume Actionive
LRmF Alias ConfigCMD.3                                      'Change Menu Actionive
UDmF Alias ConfigCMD.4                                      'Change Minute
UDoF Alias ConfigCMD.5                                      'Change Ore
MANF Alias ConfigCMD.6                                      'MANUAL Mode Seek
SRCF Alias ConfigCMD.7                                      'AUTO Mode seek

'Configurare Flags taste
SOLF alias ConfigTasteFlags.0
STGF alias ConfigTasteFlags.1
DRF alias ConfigTasteFlags.2
ONF Alias ConfigTasteFlags.8
OKF Alias ConfigTasteFlags.4
MENUF Alias ConfigTasteFlags.5
BKF Alias ConfigTasteFlags.6
DWNF Alias ConfigTasteFlags.7
UPF Alias ConfigTasteFlags.3

'Formateaza cifrele
Dim L(11) As Byte
L(1) = &B00111111
L(2) = &B00000110
L(3) = &B01011011
L(4) = &B01001111
L(5) = &B01100110
L(6) = &B01101101
L(7) = &B01111101
L(8) = &B00000111
L(9) = &B01111111
L(10) = &B01101111
L(11) = &B00111111

'Variabile folosite la citirea/scrierea RTC-ului I2C
Dim Secunde As Byte
Dim Takt As Byte

Sub Read_RTC
        I2cstart                                            'Generate start code
        I2cwbyte I2cwrite                                   'send address
        I2cwbyte 0                                          'start address in RTC
        I2cstart                                            'Generate start code
        I2cwbyte I2cread                                    'send address
        I2crbyte RawSeconds , Ack                           'Secunde
        I2crbyte RawMinutes , Ack                           'Minute
        I2crbyte RawHour , Nack                             'Ore
        I2cstop
  Secunde = Makedec(RawSeconds)
  Minute = Makedec(RawMinutes)
  If RawHour >= 128 Then RawHour = RawHour - 128
  Ore = Makedec(RawHour)
End Sub

Sub Change_min
          RawMinutes = Makebcd(Minute)                      'formateaza minutele
          I2cstart
          I2cwbyte I2cwrite
          I2cwbyte &H0                                      'Porneste de la registrul secundelor
          I2cwbyte 0                                        'Reseteaza secundele
          I2cwbyte RawMinutes                               'Scrie minutele in registrul urmator
          I2cstop
End Sub

Sub Change_hour
         RawHour = Makebcd(ore)                             'formateaza orele
         I2cstart
         I2cwbyte I2cwrite
         I2cwbyte &H2                                       'Modifica orele
         RawHour = RawHour + 128                            '24h Clock
         I2cwbyte RawHour                                    'la valoarea setata
         I2cstop
End Sub

Sub Change_volume
    'Aproximare logaritmica: pasii cresc, fara salturi la praguri.
    If Volume >= 20 Then
       VolumeTemp = Volume * 4
       VolumeTemp = VolumeTemp - 48
    ElseIf Volume >= 10 Then
       VolumeTemp = Volume * 2
       VolumeTemp = VolumeTemp - 9
    Else
       VolumeTemp = Volume
    End If
    'Send to IC-TPC4010A-10K
    I2Cstart
    I2Cwbyte I2Cvolumew
    I2Cwbyte 0
    I2Cwbyte VolumeTemp                                     ' VolumeTemp
    I2Cstop
End Sub

Sub ResetRdsScroll
   RdsScrollPosition = 13
   RdsScrollTimer = 255
End Sub

'Rutina de citire RDS data
Sub Radiodatasistem
   Isearch = Frecventa                                      'Search
   'Citeste indexul din tabelul de frecvente presetate
   Index = LookDown(Isearch , Rds_index , 18)
   Index1 = Index                                          'configurare index in baza(0)
   Decr Index1
   If Index = -1 Then Index1 = 17                           'NO-RDS
   Text = EepromText(index1 + 1)
   RdsScrollBuffer = Space(36)
   Mid(RdsScrollBuffer , 13 , 12) = Text
   Call ResetRdsScroll
End Sub

$include PT6302driver.Inc     '//PT6302 driver routines

Sub SavePreset(ByVal PresetSlot As Byte)
   If PresetSlot = 1 Then
      EfrecuentaSOL = Frecventa
      Text = EepromText(19)
   Else
      EfrecuentaBK = Frecventa
      Text = EepromText(20)
   End If
   Call Sent2Display(Text)
End Sub

Sub RecallPreset(ByVal PresetSlot As Byte)
   Dim PresetFrequency As Word
      'Daca slotul de presetare este 1, citeste frecventa memorata in EfrecuentaSOL, altfel citeste EfrecuentaBK.
   If PresetSlot = 1 Then
      PresetFrequency = EfrecuentaSOL
   Else
      PresetFrequency = EfrecuentaBK
   End If
   'Daca frecventa memorata este valida, seteaza-o ca frecventa curenta si dezactiveaza MUTE.
   If PresetFrequency >= 880 And PresetFrequency <= 1080 Then
      Frecventa = PresetFrequency
      PresetReturn = ON
      MUTE = OFF
      Search = OFF
      Watchdog_timer = 0
   End If
End Sub

$include 4x4_emulate.bas
$include TEA5768.bas

'************************[Init Program]*********************
VFD_init                                                    'init. VFD
VFD_clear                                                   'clear VFD
Waitms 500                                                  'Bitwait
Radio = OFF                                                 'Porneste radio

If EepromLayout <> &H5646 Then
   Efrecventa = 1000
   Evolume = 5
   EfrecuentaSOL = 0
   EfrecuentaBK = 0
   EepromLayout = &H5646
End If
Volume = Evolume                                            'Preset volume level
If Volume = &HFF Or Volume > 42 Then
   Volume = 5
   Evolume = Volume
End If
Change_volume                                               'seteaza volumul
Rozeta = &B01_0101_0101                                     'Preset rozeta dots

'Citeste frecventa memorata; daca valoarea este invalida, seteaza 100,00 MHz.
Frecventa = Efrecventa
If Frecventa = &HFFFF Or Frecventa < 880 Or Frecventa > 1080 Then
 Frecventa = 1000
 Efrecventa = Frecventa
End If

Watchdog_timer = 0                                          'Reset Watchdog timer
ConfigCMD = &b1000_0100
'             |     |_Volume Flag Actionivat
'             |__Scan MODE ON

 'Activeaza RTC-ul ISL1208 si normalizeaza ora in format 24h.
Init_ceas:
         I2cstart
         I2cwbyte I2cwrite
         I2cwbyte &H07
         I2cwbyte &B10010000
'                   |  |_Auto Reset BAT+ALM flags
'                   |____Enable RTC
         I2Cstop

         I2cstart
         I2cwbyte I2cwrite
         I2cwbyte &H07
         I2cstart
         I2cwbyte I2cread
         I2crbyte RTCstatus , Nack
         I2cstop

         If RTCstatus.0 = On Then
            'Pierderea alimentarii principale si a bateriei a resetat ora.
            'Porneste RTC-ul de la 00:00:00, in format 24h.
            I2cstart
            I2cwbyte I2cwrite
            I2cwbyte &H00
            I2cwbyte 0
            I2cwbyte 0
            I2cwbyte &H80
            I2cstop
         Else
            'Converteste ora existenta din 12h in 24h fara sa o schimbe.
            I2cstart
            I2cwbyte I2cwrite
            I2cwbyte &H02
            I2cstart
            I2cwbyte I2cread
            I2crbyte RawHour , Nack
            I2cstop

            If RawHour < &H80 Then
               If RawHour >= 64 Then RawHour = 0
               HourPM = OFF
               Hour12 = RawHour
               If RawHour >= 32 Then
                  Hour12 = RawHour - 32
                  HourPM = On
               End If
               Hour12 = Makedec(Hour12)
               If Hour12 > 12 Then Hour12 = 0
               If Hour12 = 12 Then
                  If HourPM = OFF Then Hour12 = 0
               ElseIf HourPM = On Then
                  Hour12 = Hour12 + 12
               End If
               RawHour = Makebcd(Hour12) + 128
               I2cstart
               I2cwbyte I2cwrite
               I2cwbyte &H02
               I2cwbyte RawHour
               I2cstop
            End If
         End If
'***********************************************************
'*                   MAIN PROGRAM                          *
'***********************************************************
Do
                                                        'Contor pentru timeout-ul de volum
Incr Watchdog_timer
  Call Read_4x4                                             'Citeste Tastatura
  Index = ConfigTasteFlags
  Decr Index
  Index = Index And ConfigTasteFlags
  If Index <> 0 Then ConfigTasteFlags = 0                    'Ignora combinatiile de taste neacceptate
KeysValid:
  Call Read_RTC                                             'Citeste Ceasul RTC

  If Search_stg = On Then
     Decr Frecventa
     MUTE = On
     If Frecventa < 880 Then Frecventa = 1080
  End If

  If Search_dr = On Then
     Incr Frecventa
     MUTE = On
     If Frecventa > 1080 Then Frecventa = 880
  End If

  SW = NOT Radio                                            'Porneste alimentarea tunerului inainte de configurare
  TunerUpdated = OFF
  If Radio = On Then                                        'verifica daca a fost pornit RadioFM
        If TunerReady = OFF Or TunerFrequency <> Frecventa Or TunerMute <> MUTE Then
           If TunerReady = OFF Then
              Waitms 100                                     'Asteapta stabilizarea alimentarii la pornire
           End If
           Action = On
           Call TEA5768                                     'Programeaza tunerul doar la schimbare
           If TunerReady = OFF Or TunerFrequency <> Frecventa Then
              Call Radiodatasistem                          'actualizeaza RDS numai la schimbarea postului
              PrintF = On
           End If
           TunerFrequency = Frecventa
           TunerMute = MUTE
           TunerReady = On
           TunerUpdated = On
        End If
  End If
'------------------[ TASTE ]--------------------------------
Tasta_SOL:
  If ConfigTasteFlags <> 1 Then GoTo Tasta_STG
  If PresetLong = OFF Then
     Call RecallPreset(1)
  Else
     Text = EepromText(Index1 + 1)                         'revine la textul postului dupa eliberare
     Call ResetRdsScroll
     PrintF = On
  End If
  SOLF = OFF

Tasta_STG:
  If ConfigTasteFlags <> 2 Then GoTo Tasta_DR
        If LRmF = OFF Then PresetReturn = OFF
        If Search <> 0 Then
           MANF = On
           SRCF = OFF
        End If

        If MANF = On Then
         Search = OFF                                       'anuleaza Searchrea automata
         MUTE = OFF
         If Frecventa > 880 Then Decr Frecventa
        End If

        If SRCF = On Then
           Search_stg = On
        End If

        If LRmF = On Then
          MenuByte = 3                                   'But_Left selecteaza ajustarea orelor
        End If

        Watchdog_timer = 0
        STGF = OFF

Tasta_DR:

        If ConfigTasteFlags <> 4 Then GoTo Tasta_UP
        If LRmF = OFF Then PresetReturn = OFF

        If Search <> 0 Then
           MANF = On
           SRCF = OFF
        End If

       If MANF = On Then
          Search = OFF
          MUTE = OFF                                        'Anuleaza Searchrea automata
          If Frecventa < 1080 Then Incr Frecventa
       End If

        If SRCF = On Then Search_dr = On

        If LRmF = On Then
          MenuByte = 2                                   'But_DR selecteaza ajustarea minutelor
        End If

        Watchdog_timer = 0
        DRF = OFF

Tasta_UP:
  If ConfigTasteFlags <> 8 Then GoTo Tasta_DWN

    If MenuByte = 2 Or MenuByte = 3 Then GoTo Label1
       MenuByte = 4
       Watchdog_timer = 0
       If Volume < 42 Then incr Volume
       Change_volume
       Rozeta = NOT Rozeta
       waitms 50
Label1:
       If UDmF = On Then                                    'reglaj minute Actionivat
          incr Minute
          If Minute > 59 Then Minute = 0
          Change_min                                        'regleaza minute
       End If

       If UDoF = On Then
          incr Ore
          If Ore > 23 Then Ore = 0
          Change_hour
       End If
        Watchdog_timer = 0
       UPF = OFF

Tasta_DWN:
  If ConfigTasteFlags <> 128 Then GoTo Tasta_OK
       If MenuByte = 2 Or MenuByte = 3 Then GoTo Label2
          MenuByte = 4
          Watchdog_timer = 0
          If Volume > 0 Then decr Volume
          Change_volume
          Toggle Rozeta
          waitms 50
Label2:
       If UDmF = On Then                                    'Reglaj Minute
          decr Minute
          If Minute = 255 Then Minute = 59
          Change_min
       End If

       If UDoF = On Then
          Decr Ore
          If Ore = 255 Then ore = 23
          Change_hour
       End If
        Watchdog_timer = 0
        DWNF = OFF

Tasta_OK:
  If ConfigTasteFlags = 16 Then
      MenuByte = 0
      ConfigCMD = &B1000_0100
'                   |     |_Volume Flag Active
'                   |_Auto Search Flag Active
      VFD_clear
      Search = OFF
      OKF = OFF
      If Radio = On Then
         Text = EepromText(Index1 + 1)                       'restaureaza mesajul postului dupa meniu
         Call ResetRdsScroll
         PrintF = On
      End If
  End If

Tasta_MENU:
  If ConfigTasteFlags <> 32 Then GoTo Tasta_BK
       MenuByte = 1  ' Afiseaza meniul principal
       Watchdog_timer = 0
       MENUF = OFF
       UDvF = OFF

Tasta_BK:
  If ConfigTasteFlags <> 64 Then GoTo Tasta_ON
       If PresetLong = OFF Then
          Call RecallPreset(2)
       Else
          Text = EepromText(Index1 + 1)                    'revine la textul postului dupa eliberare
          Call ResetRdsScroll
          PrintF = On
       End If
       BKF = OFF

Tasta_ON:
  If ConfigTasteFlags <> 256 Then GoTo Afisare
       Toggle Radio                                         'Porneste sau Opreste Radio
        TunerReady = OFF                                     'Reinitializeaza tunerul la urmatoarea pornire
       MenuByte = 0
       ConfigCMD = &B1100_0000
'                    ||_MANUAL Search Flag  Active
'                    |_AUTO Search Flag Active
       Watchdog_timer = 0
       ONF = OFF
        If Radio = OFF Then
           Text = EepromText(21)                             'Goleste doar randul de caractere RDS
           PrintF = On                                       'Afiseaza imediat randul gol in standby
           C(1) = 0 : C(2) = 0 : C(3) = 0 : C(4) = 0 : C(5) = 0
           DP(1) = OFF : DP(2) = OFF
           FM_ind = OFF : Title_AM_CEAS_ind = OFF : CH_R7_ind = OFF
           Call DigitsGroup(1)                              'Sterge cifrele ramase in stanga
           Call DigitsGroup(3)                              'Sterge indicatorii/cifrele din dreapta
        End If

'------------[ Afisare text pe display ]--------------------
Afisare:

    Select Case MenuByte
       Case 1: '//Afiseaza meniul principal
         Text = EepromText(22)
         ConfigCMD = 0 Or &B0000_1001
'                                |  |_Print Flag Active
'                                |_LRmF (menu left/right) Active
       Case 2: '//Afiseaza meniul secundar
         Text = EepromText(23)
         ConfigCMD = 0 Or &B0001_1001
'                              | |  |_Print Flag Active
'                              | |_LRmF (menu left/right) Active
'                              |_Change Minute Flag Active
       Case 3: '//Afiseaza meniul tertiar
         Text = EepromText(24)
         ConfigCMD = 0 Or &B0010_1001
'                             |  |  |_Print Flag Active
'                             |  |_LRmF (menu left/right)
'                             |____Change Hours Flag Actionive
       Case 4:
        Text = EepromText(25)
        ConfigCMD = 0 Or &B0000_0101
'                                | |_Print Flag Active
'                                |_UDvF=ON (up/down volume flag)
    End Select

Print_on_VFD:
    If PrintF = On Then
       Call Sent2Display(Text)                              'print Text on Display
       PrintF = OFF
    End If
'***********************************************************
     CifraCeas(4) = Minute Mod 10                           'Minute
     If CifraCeas(4) = 0 Then CifraCeas(4) = 10
     CifraCeas(3) = Minute / 10                             'Zeci de minute
     If CifraCeas(3) = 0 Then CifraCeas(3) = 10
     CifraCeas(2) = Ore Mod 10                              'Ore
     If CifraCeas(2) = 0 Then CifraCeas(2) = 10
     CifraCeas(1) = Ore / 10                                'Zeci de ore

'Conversie cifre in carActionere pe VFD(1) --------------------
'                  _DP(1)=ON; DP(2)=ON
'                 |
'           1 8 8 : 8 8
'           | | |   | |_C(5)= Minute
'           | | |   |___C(4)= Zeci de Minute
'           | | |_______C(3)= Ore
'           | |_________C(2)= Zeci de Ore
'           |___________C(1)=0 (stinge cifra)
C(1) = 0
 Cifra = CifraCeas(1) + 1
 C(2) = L(Cifra)
 If Ore < 10 Then C(2) = 0
 Cifra = CifraCeas(2) + 1
 C(3) = L(Cifra)
 Cifra = CifraCeas(3) + 1
 C(4) = L(Cifra)
 Cifra = CifraCeas(4) + 1
 C(5) = L(Cifra)
Takt = Secunde MOD 2
DP(1) = Takt : DP(2) = Takt

If Radio = OFF Then  '//daca Radio=Off nu afisa informatii inutile
   FM_ind = OFF
   Call DigitsGroup(2)                                      'Trimite informatia spre Grup Digits Stg (1)
Else
   Call DigitsGroup(1)                                    'Trimite informatia spre Grup Digits Stg (1)
End If
'-----------------------
LedV = Radio
LedR = NOT LedV
If Radio = OFF Then GoTo Fine                               'daca Radio=Off nu afisa informatii inutile
'Debuging
Frecventa_Str = Str(Frecventa)                              'Converteste frecventa in String
str2digits Frecventa_Str , Ar(1)                            'Descompune frecventa in cifre separate
     CifraCeas(4) = Ar(5)                                   'Frecventa Mii
     If CifraCeas(4) = 0 Then CifraCeas(4) = 10

     CifraCeas(3) = Ar(4)                                   'Frecventa Sute
     If CifraCeas(3) = 0 Then CifraCeas(3) = 10

     CifraCeas(2) = Ar(3)                                   'Frecventa Unitati
     If CifraCeas(2) = 0 Then CifraCeas(2) = 10

     CifraCeas(1) = Ar(2)                                   'Frecventa Zecimala
     If CifraCeas(1) = 0 Then CifraCeas(1) = 10

'Conversie cifre in carActionere pe VFD(2) --------------------
'                  _DP(1)=OFF; DP(2)=ON
'                 |
'           1 8 8 : 8 8
'           | | |   | |_C(5)=0
'           | | |   |___C(4)= L(CifraCeas(1))
'           | | |_______C(3)= L(CifraCeas(2))
'           | |_________C(2)= L(CifraCeas(3))
'           |___________C(1)= L(CifraCeas(4))

Cifra = CifraCeas(4) + 1
C(1) = L(Cifra)
If Frecventa < 1000 Then C(1) = 0                           'stinge cifra C(1) daca frecventa este sub 1000
Cifra = CifraCeas(3) + 1
C(2) = L(Cifra)
Cifra = CifraCeas(2) + 1
C(3) = L(Cifra)
Cifra = CifraCeas(1) + 1
C(4) = L(Cifra)
C(5) = L(11)
DP(1) = OFF                                                 'Stinge pct de sus
DP(2) = On                                                  'Aprinde pct in loc de virgula
FM_ind = On                                                 'Arata indicator FM pe VFD
Call DigitsGroup(2)                                         'Trimite info la VFD Grup Afisaj mijloc (2)

'Sterge carActionerele inutile din Grup VFD (3)----------------
C(1) = 0                                                    'Stinge informatii inutile de pe afisaj
C(2) = 0                                                    'Stinge informatii inutile de pe afisaj
C(3) = 0                                                    'Stinge informatii inutile de pe afisaj

CifraCeas(1) = Volume Mod 10
If CifraCeas(1) = 0 Then CifraCeas(1) = 10

CifraCeas(2) = Volume / 10
If CifraCeas(2) = 0 Then CifraCeas(2) = 10

Cifra = CifraCeas(1) + 1
C(4) = L(Cifra)
Cifra = CifraCeas(2) + 1
C(5) = L(Cifra)

If LRmF = On Then Title_AM_CEAS_ind = On  'Arata indicatorul de meniu pe VFD

    If Index1 <> 17 Then   '//Daca nu e NO-RDS, arata indicatorul de antena pe VFD
      ANT_ind = On
      MUTE = OFF
      If Watchdog_timer > 0 Then Search = OFF               'Anuleaza cautarea automata daca s-a actionat o tasta
    End If

Roz = On                                                    'Actionare Efect Rozeta
DP(2) = OFF                                                 'Stinge pct

Call DigitsGroup(3)                                         'Trimite info la VFD Display3
'-----------------------
Title_AM_CEAS_ind = OFF                                     'Stinge indicatorul AM/CEAS pe VFD
ANT_ind = OFF                                               'Stinge indicatorul antena pe VFD
Reset Roz                                                   'anuleaza afisarea rozetei pt.Display1,Display2
CH_R7_ind = OFF                                             'Stinge informatii inutile de pe afisaj
'memoreaza noile situatii create
   If Watchdog_timer = 20 Then                              'Timeout dupa 20 de cicluri fara actiune
      If MenuByte = 4 Then OKF = On                          'Expira mesajul de volum la pragul existent
   End If
Random_save:
    If PresetReturn = OFF Then                              'Nu suprascrie postul curent in timpul previzualizarii
     If Frecventa_old <> Frecventa Then                     'Daca frecventa e modificata
      Frecventa_old = Frecventa                             'Salveaza frecventa temporar
      Efrecventa = Frecventa                                'Memoreaza frecventa in EEprom
     End If
    End If
    Evolume = Volume                                        'Memoreaza volumul
    PrintF = On   '                                           'Afiseaza mesajul de salvare pe VFD

   'Bucla principala este aproximativ 100 ms: 50 cicluri = 5 s, apoi media este 250 ms/pas.
   If MenuByte = 0 And Index1 <> 17 Then
      Incr RdsScrollTimer
      If RdsScrollPosition = 13 Then
         If RdsScrollTimer >= 50 Then
            RdsScrollTimer = 0
            RdsScrollPosition = 14
         End If
      Else
         If RdsScrollTimer >= 2 Then
            If RdsScrollPosition.0 = 0 Or RdsScrollTimer >= 3 Then
               RdsScrollTimer = 0
               If RdsScrollPosition = 25 Then
                  RdsScrollPosition = 2
               Else
                  Incr RdsScrollPosition
               End If
            End If
         End If
      End If
      If RdsScrollTimer = 0 Then
         Text = Mid(RdsScrollBuffer , RdsScrollPosition , 12)
      End If
   End If
Fine:
    If MenuByte = 0 Then
       If MANF = On Then
          OKF = On                                          'timeout-ul nu inchide meniul de ajustare
       End If
    End If

   If Radio = On And TunerUpdated = OFF Then Waitms 100     'Pastreaza ritmul buclei si cautarii

Loop
End


$EEPROM
Data &HFF
Data " RADIO GAGA " , "  ROCK-FM   " , "   DIGI-FM  " , "   KISS-FM  " , " EUROPA-FM  " , "  RADIO SON "
Data "  RADIO-21  " , "R.R.ACTUALIT" , "  DANCE-FM  " , "  RADIO-ZU  " , "REINTREGIREA" , "  ATLAS-FM  "
Data "NATIONAL FM " , "  MAGIC-FM  " , "   PRO-FM   " , " TARGU-MURES" , "R.R.CULTURAL" , "   NO-RDS   "
Data "MEMORY-1    " , "MEMORY-2    " , "            "
Data "Clock <Adj> " , "Minut Up/Dwn" , "Hours Up/Dwn" , "VOLUM Up/Dwn"
$DATA
'Radio Data Sistem info frecvente
Rds_index:
Data 880% , 884% , 891% , 903% , 907% , 1056%
Data 927% , 936% , 1000% , 980% , 986% , 1064%
Data 1006% , 1012% , 1016% , 1029% , 1049% , 0%
