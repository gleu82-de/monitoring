Monitoring mit Cuma einrichten
# Debmatic
## Service
 -Serviceverfügbarkeit prüfen
 -Alle nativen Services, also auch rfd service usw. sind damit gemeint
## Interne Verfügbarkeiten
 - Prüfen, ob die ETH Antenne verbunden ist
 - Prüfen, ob darüber Kommunikation läuft
 - prüfen, ob das Wired Gateway verbunden ist
 - prüfen, ob das kommunikation drüber läuft
 ## Auswertung von logs
 Es soll geprüft werden, welche Logfiles angefertigt werden und ob darin aktuell auffälligkeiten zu sehen sind
 ## Duty cycle
 Es woll alarmiert werden, wenn der duty cycle einen Schwellwert x überschreitet.

 # ccu-jack
 - Prüfung, ob der Service online ist
 - Prüfung, ob innerhalb von einer Minute mindestens einen Nachricht publiziert wird
 - Prüfung, ob es im Log auffälligkeiten gibt

# Node-Red
 - Prüfung, ob der Dienst online ist oder das debug.sh läuft. Wenn debug.sh läuft, soll für den Node-Red ein Mainenance Window von 1h (bei jedem Start von debug.sh) eingestellt werden.
 - Prüfung des logs auf Auffälligkeiten
 - Prüfung, ob flows mit Fehler beendet werden. Wir brauchen hier möglicherweise eine Blacklist.