$nocompile

'Detecteaza apasarea lunga si afiseaza mesajul la pragul de o secunda.
Sub WaitPresetRelease(byval PresetSlot as Byte)
   PresetHold = 0
   Do
      If Colon1 = 1 AND Colon2 = 1 AND Colon3 = 1 Then
         Exit Do
      End If
      Waitms 10
      If PresetHold < 100 Then
         Incr PresetHold
         If PresetHold = 100 Then
            PresetLong = ON
            Call SavePreset(PresetSlot)
         End If
      End If
   Loop
End Sub
'   Rutine de executie pentru functia de scanare Matrice 4x4 emulata
Sub Read_4x4
   PresetLong = OFF

   set row1 : reset row2 : set row3
   waitms 1
   If Colon1 = 0 Then ONF = ON
   if Radio = OFF then
    bwku
    exit sub
   end if
   If Colon2 = 0 Then
      OKF = ON
      If MenuByte = 0 Then
         If PresetReturn = ON Then
            Frecventa = Efrecventa
            PresetReturn = OFF
         End If
      End If
   End If
   If Colon3 = 0 Then MENUF = ON
     bwku
'-----------------------------------
   set Row1 : set ROW2 : reset ROW3
   waitms 1
   If Colon1 = 0 Then BKF = ON
   'bwku
   If Colon2 = 0 Then DWNF = ON
   If Colon3 = 0 Then UPF = ON
   If Colon1 = 0 Then
      Call WaitPresetRelease(2)
   Elseif MenuByte = 2 OR MenuByte = 3 Then
      bwku
   End If
'-------------------------------------
   Reset Row1 : set row2 : set row3
   waitms 1
   If Colon1 = 0 Then SOLF = ON
   If Colon2 = 0 Then STGF = ON
   If Colon3 = 0 Then DRF = ON
   If Colon1 = 0 Then
      Call WaitPresetRelease(1)
   Else
      bwku
   End If
'------------------------------------
End sub

'Rutina de eliberare a tastei
Sub BWKU
    bitwait colon1 , set
    bitwait colon2 , set
    bitwait colon3 , set
End Sub
