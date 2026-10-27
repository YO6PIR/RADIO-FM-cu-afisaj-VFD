$nocompile

Sub Tea5768
'*********************************
'Rutina de comunicare cu TEA5768
'*********************************
   Dim PllCalc As Long
   Dim Fset As Word

 '  Const Tea5767w = &HC0                                    'Address TEA5767
 '  Const Tea5767r = &HC1
   If Action = ON Then                                      'verifica steag schimbare frecventa FM Radio
      'Frecventa este in unitati de 100 kHz.
      'PLL = 4 * (Frecventa * 100 + 225) / 32.768
      'Forma intreaga echivalenta: (Frecventa * 12500 + 28125) / 1024.
      PllCalc = Frecventa
      PllCalc = PllCalc * 12500
      PllCalc = PllCalc + 28125
      Shift PllCalc , Right , 10
      Fset = PllCalc
      Control(1) = High(fset)
      'Reset Control(1).7                                    'not mute
      Control(1).7 = MUTE
      Reset Control(1).6                                    'not search
      Control(2) = Low(fset)
      Control(3) = &B00010000
      Control(4) = &B00110010
      Control(5) = &B00000000
      I2csend Tea5767w , Control(1) , 5
      Waitms 100
      I2creceive Tea5767r , Control(1) , 0 , 5
'      Semnal = Control(4)                                   ' : Shift Semnal , Right , 1        'SEMNAL / 2
'      STEREO_ind = Control(3).7
      Action = OFF
   End If

End Sub
