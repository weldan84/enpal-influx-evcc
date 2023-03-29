# Enpal-InfluxDB-Anbindung für evcc
Workaround für die evcc-Integration einer gemieteten PV-Anlage "Huawei SUN2000 with SDongle &amp; Power Sensor" von Enpal.

Am 20. März 2023 hatte ich bei **evcc-io/evcc** auf GitHub eine [Diskussion](https://github.com/evcc-io/evcc/discussions/6965) bezüglich der Einbindung einer gemieteten PV-Anlage inkl. Speicher von Enpal gestellt. Allerdings stellte sich heraus, dass wohl niemand so recht etwas mit der Frage anzufangen wusste. Dazu muss man wissen, dass man bei einer gemieteten PV-Anlage von Enpal keinen Zugriff auf die Modbus-Schnittstelle erhält, man kann das System also nicht so einfach mittels [template](https://docs.evcc.io/docs/devices/meters#sun2000-with-sdongle--power-sensor) in die **evcc.yaml** einbinden.   

Was man auf Anfrage vom technischen Support bei Enpal aber bekommt, ist ein lesender Zugang zur InfluxDB. Diese Datenbank befindet sich auf einem lokalen Server in der Enpal-Box. Laut E-Mail des technischen Beraters nutzt auch Enpal diese Datenbank für die hauseigene Enpal-App um Informationen aus der Anlage weiterzuverarbeiten. Ich bin jedoch der Meinung, dass nicht alle Daten in der InfluxDB zu finden sind, denn bis dato habe ich es z. B. noch nicht geschafft den Ladezustand des Speichers zu errechnen. Vielleicht bin ich aber auch einfach noch nicht tief genug in dem Thema drinn. Für Lösungsvorschläge diesbezüglich bin ich deshalb immer dankbar.

Wichtig vorab zu wissen ist, dass meine Lösung für eine **InfluxDB in der Version 2.0.0** entwickelt wurde. Meines Wissens ist diese Version zumindest nicht mit den Vorgängern kompatibel. Laut den Informationen des technischen Mitarbeiters werden unter anderem an der Struktur der Datenbanken in diesem Jahr auch nochmal Änderungen vorgenommen, die dazu führen, dass Scripte evtl. angepasst werden müssen. Ich werde mich jedoch bemühen die Lösung hier stets auf den aktuellen Stand zu halten. Zudem läuft das Ganze bei mir auf einem kleinen **Server mit Ubuntu 20.04**.

Was ihr also machen müsst, bevor ihr eure gemietete PV-Anlage in **evcc** einbinden könnt, ist eine freundliche E-Mail an den Enpal-Support zu schreiben und um lesenden Zugang für die InfluxDB zu bitten. In der Regel sollte eurer Bitte dann innerhalb von 1 bis 2 Werktagen Folge geleistet werden, meiner Erfahrung nach dauert es nicht länger bis man hier eine Antwort erhält.

In der Antwort-Mail sollte euch dann der lokale Host der InfluxDB sowie euer Benutzername und das Passwort mitgeteilt werden.
1. Ruft nun die Weboberfläche der InfluxDB auf, indem ihr die **Host-Adresse zzgl. Port** (z.B. http://192.168.0.180:8086) im Browser eingebt. Meldet euch hier mit den entsprechenden Zugangsdaten an.
2. Als erstes besorgt ihr euch die **Organization Id**. Klickt dazu in der linken Navigationsleiste unter dem Influx-Logo auf euer Profilbild. Es öffnet sich ein DropDown-Menü. Klickt dort nun auf "About".
3. Nun sollten auf der rechten Seite der Webseite sogenannte "Common Ids" angezeigt werden, notiert euch hiervon die "Organization Id".
4. Als nächstes benötigt ihr den **Token** zur Authentifizierung. Klickt dazu in der linken Navigationsleiste auf das Icon unter eurem Profilbild mit dem Subtitel "Data". Auf der darauffolgenden Seite solltet ihr im oberen Drittel mehrere Tabs sehen und ganz rechts einen mit der Aufschrift "Tokens". 
5. Mit einem Klick auf den Tab gelangt ihr nun zur Übersicht eurer Tokens. Für gewöhnlich findet ihr hier lediglich einen Token, den ihr wiederum anklickt und im Anschluss den Schlüssel zu kopieren.
6. Ich bin mir aktuell nicht sicher ob die Buckets der InfluxDB nicht eigens für mich erstellt wurden oder ob der Name immer einheitlich ist. Zur Sicherheit würde ich nun nochmal auf den Tab "Buckets" klicken, der sich links vom Tab "Tokens" befindet und mir einen Überblick der angelegten Buckets verschaffen.
7. Bei mir trägt der Bucket die Bezeichnung "my-new-bucket". Wenn ihr euch aber nicht sicher seid, dann klickt einfach auf den entsprechenen Bucket-Titel und prüft ob folgende Elemente angezeigt werden: "Gesamtleistung, LeistungDc, aggregated, consumtionEnergy, deviceStatus, fromGridEnergy, gridFrequency, intoGridEnergy, inverterTemperature, phaseCurrentAc, phasePowerAc, phaseVoltageAc, productionCurrentDc und productionVoltageDc"
8. Werden diese Elemente angezeigt, dann notiert euch den entsprechenden **Bucket-Namen**.

Um die PV-Anlage nun mittels evcc einzubinden geht wiefolgt vor:

Ladet euch das Script herunter
````shell
wget https://raw.githubusercontent.com/weldan84/enpal-influx-evcc/main/enpal.sh
````

Öffnet das Script und setzt eure Zugansdaten ein
````shell
nano enpal.sh
````

````shell
#!/bin/sh

# Zugangsdaten
INFLUX_HOST="YOUR_INFLUX_HOST"
INFLUX_ORG_ID="YOUR_INFLUX_ORG_ID"
INFLUX_BUCKET="YOUR_INFLUX_BUCKET"
INFLUX_TOKEN="YOUR_INFLUX_TOKEN"
...

````

Speichert die Änderungen mit der Tastenkombination "Strg+O" ab und schliesst die Bearbeitung mit der Tastenkombination "Strg+X"

Ihr könnt das Script nun mit folgendem Befehl testen
````shell
sh enpal.sh pv
````
Als Ergebnis sollte euch die aktuelle DC-Erzeugungsleistung angezeigt werden, im Fehlerfall scheut euch bitte nicht hier unter [Issues](https://github.com/weldan84/enpal-influx-evcc/issues) einen neuen Vorgang aufzumachen.

Natürlich könnt ihr auch noch alle anderen Abfragen testen bevor ihr mit der Einbindung startet. Eine Liste aller möglichen Argumente erhaltet ihr mit dem Befehl
````shell
sh enpal.sh help
````

Um die Datei nun global bekannt zu machen, verschieben wir es in das bin-Verzeichnis und machen das Script ausführbar 
````shell
sudo mv enpal.sh /usr/bin/enpal
sudo chmod +x /usr/bin/enpal
````

Nun solltet ihr in der Lage sein das Script auch ohne "sh" und Pfadangabe aufzurufen
````shell
enpal grid
````

Mit diesem Befehl sollte euch nun der aktuelle Netzbezug bzw. Einspeisung (mit einem negativen Wert) angezeigt werden

Nun könnte ihr das [evcc-Plugin "script"](https://docs.evcc.io/docs/reference/plugins#shell-script-lesenschreiben) nutzen um eure Werte für grid, pv und battery weiterzuverarbeiten. Eine entsprechende Beispielkonfiguration der [evcc.yaml](https://github.com/weldan84/enpal-influx-evcc/blob/main/evcc.yaml) findet ihr ebenfalls [hier](https://github.com/weldan84/enpal-influx-evcc/blob/main/evcc.yaml) im Projektordner.

Zu Schluss möchte ich noch anmerken, dass ich mich noch nicht so lange mit dem Projekt evcc beschäftige. Es kann somit durchaus sein, dass hier oder da noch ein paar Denkfehler auftauchen. In diesem Fall freue ich mich über euren Rat. Im Gegenzug freue ich mich natürlich auch über positives Feedback oder konstruktive Kritik und Verbesserungsvorschläge :)