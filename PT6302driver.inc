$nocompile
'(
------------------------------------------------------------
CONFIGURARE AFISAJ STANGA
--------------------------
               36       54        31
             TITLE      CH       TRACK

              26        44             52       21
              --        --             --       --
     46|   16|45|55  34|14|24  13   42|22|32 11|40|50
              --        --      *      --       --
     46|   35|  |25  53|  |43   *   12|  |51 30|  |20
              --        --     23      --       --
              15        33             41       10
------------------------------------------------------------
CONFIGURARE AFISAJ MIJLOC
--------------------------
 36-AM
 56-FM        26        44             52       21
              --        --             --       --
     46|   16|45|55  34|14|24  13   42|22|32 11|40|50
              --        --      *      --       --
     46|   35|  |25  53|  |43   *   12|  |51 30|  |20
              --        --     23      --       --
              15        33             41       10
------------------------------------------------------------
CONFIGURARE AFISAJ DREAPTA
---------------------------
            35       45        36
          STERE0    REC       CEAS

                   21       52
                   --       --        46
           13   11|40|50 42|22|32    ANT
            *      --       --
            *   30|  |20 12|  |51
           23      --       --
                   10       41

ROZETA: 0 , 1 , 2 , 3 , 4 , 5 , 6 , 7 , 8 , 9
Pini:  33  43  53  14  24  34  44  54  15   25
------------------------------------------------------------
')
Dim G(5) as Byte                                            'Grile coloane cu puncte afisaj VFD (5x7)
Dim Bcount As Byte                                          'variabila interna
Dim DataArray(13) As string * 1                             'bytes care tin informatia text descompusa
Dim MyDataOut as Byte                                       'byte send to VFD

FM_ind Alias G(5).6
STEREO_ind alias C(2).4
ANT_ind Alias C(1).1
Title_AM_CEAS_ind Alias G(3).6
REC_ind Alias C(2).6
CH_R7_ind Alias G(5).4
TRACK_ind Alias G(3).1

Sub DigitsGroup(byval GridPosition as byte)
'Configurare Grile:
G(4).6 = C(1).1
G(2).6 = C(2).0 : G(5).5 = C(2).1 : G(2).5 = C(2).2 : G(1).5 = C(2).3 : G(3).5 = C(2).4 : G(1).6 = C(2).5 : G(4).5 = C(2).6
G(4).4 = C(3).0 : G(2).4 = C(3).1 : G(4).3 = C(3).2 : G(3).3 = C(3).3 : G(5).3 = C(3).4 : G(3).4 = C(3).5 : G(1).4 = C(3).6
G(1).3 = DP(1) : G(2).3 = DP(2)
G(5).2 = C(4).0 : G(3).2 = C(4).1 : G(5).1 = C(4).2 : G(4).1 = C(4).3 : G(1).2 = C(4).4 : G(4).2 = C(4).5 : G(2).2 = C(4).6
G(2).1 = C(5).0 : G(5).0 = C(5).1 : G(2).0 = C(5).2 : G(1).0 = C(5).3 : G(3).0 = C(5).4 : G(1).1 = C(5).5 : G(4).0 = C(5).6
'Configurare Rozeta:
    If roz = 1 then                                         'bit Rozeta ACTIVE
        G(3).3 = Rozeta.0
        G(4).3 = Rozeta.1
        G(5).3 = Rozeta.2
        G(1).4 = Rozeta.3
        G(2).4 = Rozeta.4
        G(3).4 = Rozeta.5
        G(4).4 = Rozeta.6
        G(5).4 = Rozeta.7
        G(1).5 = Rozeta.8
        G(2).5 = Rozeta.9
    end if
'-----------------------------------------------------------
   Select case GridPosition                                 'Grid position
   case 1:                                                  'Select Grid(1)
       reset strobe                                         'start Tx
       myDataOut = &b0010_0001 : Send                       'command grid[1]
       gosub grile                                          'format Grids
       myDataOut = &b0001_0000 : Send                       'charge characters
       myDataOut = 1 : Send                                 'select Grid(1)
       Set strobe                                           'Stop Tx
   Case 2:
       reset strobe
       myDataOut = &b0010_0010 : Send
       gosub grile
       myDataOut = &b0001_0001 : Send
       myDataOut = 2 : Send
       Set strobe
   Case 3:
       reset strobe
       myDataOut = &b0010_0011 : Send
       gosub grile
       myDataOut = &b0001_0010 : Send
       myDataOut = 3 : Send
       Set strobe
   End select
exit sub

  Grile:
    myDataOut = G(1) : Send
    myDataOut = G(2) : Send
    myDataOut = G(3) : Send
    myDataOut = G(4) : Send
    myDataOut = G(5) : Send
    Set strobe
    Reset strobe
  Return
End sub
'------------------Sterge afisajul VFD----------------------
Sub VFD_clear
       Reset strobe
       myDataOut = &B00010000 : Send
           for j = 0 to 15
               myDataOut = &B00100000 : Send
           next
       Set strobe

       Waitms 10

       Reset strobe
       myDataOut = &B00110000 : Send
        for j = 0 to 15
           myDataOut = &B00100000 : Send
        next
       Set strobe
End sub
'------------Initializare afisajul VFD----------------------
Sub VFD_init
     'set FULL screen
       reset strobe
       myDataOut = &B0111_0010 : Send
       set strobe

       Waitms 500
     'set NORMAL MODE
       reset strobe
       myDataOut = &B0111_0000 : Send
       set strobe

End sub
'Rutina de afisare caractere grafice pe VFD display---------
Sub Sent2Display(byref Text12 as string * 12)
       for j = 0 to 11                                      'transmite separat 12 litere (0...11)
         Reset strobe
         myDataOut = 30 - j                                 ''íncepe de la locatia &B001_1110 (15)
         Call Send                                          'si termina de afisat la locatia (4)

         bcount = split(Text12 , dataArray(1) , "")         'descompune textul in litere

         myDataOut = dataArray(12 - j)
          Call Send
         Set strobe
       next
End Sub
'------------Transmisie reriala to VFD----------------------
Sub Send
    Shiftout DataPin , ClockPin , myDataOut , 3
    waitus 10
End Sub