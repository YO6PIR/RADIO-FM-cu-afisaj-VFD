# Radio FM cu afișaj VFD
Visit: https://qsl.net/yo6pir/PT6302.html

Firmware BASCOM-AVR pentru un radio FM construit în jurul unui **ATmega88**, al unui tuner TEA5767, al unui afișaj VFD controlat de PT6302 și al unui ceas RTC ISL1208. Proiectul oferă afișarea frecvenței și a ceasului, reglarea volumului, două memorii de posturi și nume de posturi afișate ca RDS.

> Mesajele RDS sunt etichete salvate local și asociate cu frecvențe presetate. Firmware-ul nu decodează date RDS transmise de posturile radio.

Firmware-ul și funcțiile descrise au fost validate de autor pe placa radio.

## Funcții

- Acord FM în banda 88,0–108,0 MHz și căutare cu tastele stânga/dreapta.
- Afișarea frecvenței, ceasului, volumului și a numelui presetat al postului.
- Derularea mesajului postului: staționare de aproximativ 5 secunde, apoi un pas la circa 250 ms în medie.
- Volum reglat din taste pe intervalul 0–42 și memorat în EEPROM. TPL0401A-10 are 128 de poziții liniare; firmware-ul folosește o mapare pe segmente cu pași crescători pentru un răspuns aproximativ logaritmic.
- Ceas ISL1208 cu baterie de rezervă și meniu de reglare a orelor și minutelor.
- Mod Stand-by cu afișarea ceasului.
- Două memorii de frecvență: apăsarea scurtă pe SOL/BK recheamă postul, iar apăsarea lungă îl salvează. În timpul salvării apare mesajul `MEMORY-1` sau `MEMORY-2`.
- Rozeta VFD se mișcă la schimbarea volumului și la pașii de derulare RDS.

## Hardware

| Componentă | Rol |
| --- | --- |
| ATmega88, oscilator RC intern la 8 MHz | Controlul principal |
| PT6302 și afișaj VFD | Afișarea textelor, cifrelor și indicatorilor |
| TEA5767 | Tuner FM comandat prin I²C |
| ISL1208 | Ceas RTC cu baterie de rezervă |
| [TPL0401A-10](https://www.ti.com/product/TPL0401A-10) | Potențiometru digital cu 128 de poziții pentru reglarea volumului |
| Tastatură matricială 3×3 | Comenzile radio și reglajele |

### Conexiuni definite în firmware

| Semnal | Pin ATmega88 |
| --- | --- |
| Date PT6302 | PB7 |
| Clock PT6302 | PB6 |
| Strobe PT6302 | PB0 |
| SCL / SDA software | PD1 / PD0 |
| Rânduri tastatură | PD5, PD6, PD7 |
| Coloane tastatură | PB1, PC0, PC1 |
| LED verde / roșu | PC4 / PC5 |
| Comandă alimentare tuner | PB2 |

Sursele includ schemele disponibile: [controller VFD](VFD_controller_schema.JPG) și [sursa VFD](VFD_supply.JPG).

## Comenzi

| Tastă | Acțiune |
| --- | --- |
| ON | Comută între radio și Stand-by |
| MENU | Intră în reglarea ceasului |
| LEFT / RIGHT | Selectează ora/minutele în meniu; controlează acordul sau căutarea în modul radio |
| UP / DOWN | Reglează volumul sau valoarea selectată în meniul ceasului |
| OK | Închide meniul de reglare |
| SOL / BK — scurt | Recheamă memoria 1 / 2 |
| SOL / BK — lung | Salvează frecvența curentă în memoria 1 / 2 |

## Codul sursă

- `RadioFM_VFD_Ver2.bas` — inițializare, bucla principală, ceas, meniuri, memorie și compunerea afișajului.
- `TEA5768.bas` — programarea tunerului prin I²C.
- `PT6302driver.inc` — driverul VFD și maparea segmentelor/indicatorilor.
- `4x4_emulate.bas` — scanarea tastaturii și detectarea apăsărilor lungi.

Textele pentru posturi și meniuri sunt stocate în EEPROM. Frecvența curentă, volumul și cele două frecvențe memorate sunt păstrate tot în EEPROM.

La inițializarea unei hărți EEPROM noi, valorile implicite sunt 100,0 MHz și volumul 5, iar cele două memorii sunt goale. Etichetele locale RDS sunt definite pentru 17 frecvențe; pentru celelalte apare `NO-RDS`.

## Compilare

Deschide `RadioFM_VFD_Ver2.bas` în BASCOM-AVR și compilează pentru **ATmega88** (`m88adef.dat`) la **8 MHz**. Firmware-ul folosește oscilatorul RC intern; fuse-ul CKDIV8 trebuie să fie neprogramat, iar PB6/PB7 sunt folosiți ca pini I/O pentru PT6302.

## Licență

MIT LICENSE
