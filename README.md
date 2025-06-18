 Dette er en komplett Infrastructure as Code (IaC) løsning for å sette opp Azure DevTest Labs for
 undervisningsformål. Løsningen støtter opptil 30 elever med individuell tilgangskontroll og
 kostnadsbegrensninger.
 
 Hovedfunksjoner
 
 Kostnadskontroll
 Daglig budsjett: 50 NOK per elev (konfigurerbart)
 VM-begrensninger: Maksimalt 2 VM-er per elev
 Automatisk shutdown: VM-er slås av kl. 22:00 hver dag
 Kostnadsvarsler: Ved 50%, 80% og 100% av budsjett
 
 Sikkerhet og Tilgangskontroll
 Custom roller: Begrensede rettigheter for elever
 Individuell tilgang: Hver elev ser kun sine egne ressurser
 Godkjente VM-images: Kun Windows 11 og Windows Server 2022
 Størrelsebegrensninger: Standard_B1s, B2s, B1ms, B2ms
 
 Automatisering
 
 Auto-start: Mandag-fredag kl. 08:00
 Auto-shutdown: Hver dag kl. 22:00 med 30 min varsel
 Policyhåndhevelse: Automatisk kontroll av ressursbruk
 Brukerhåndtering: Automatisk opprettelse av studentkontoer
 Implementasjonsalternativer
 Alternativ 1: Bicep (Anbefalt)
 bash
 # 1. Last ned filene
 # 2. Kjør PowerShell-scriptet
 .\deploy-devtest-labs.ps1 -SubscriptionId "din-subscription-id" -SchoolName "DinSkole" -CohortI
 
 Alternativ 2: Azure CLI
 
bash
 # 1. Gjør scriptet kjørbart
 chmod +x deploy-devtest-labs.sh
 # 2. Kjør deployment
 ./deploy-devtest-labs.sh
 Alternativ 3: Terraform
 bash
 # 1. Initialiser Terraform
 terraform init
 # 2. Plan deployment
 terraform plan -var="school_name=DinSkole" -var="cohort_id=H2025"
 # 3. Deploy
 terraform apply
 📁
 Filstruktur
 azure-devtest-labs/
 ├── main.bicep                    
├── modules/
 │   └── student-user.bicep        
├── parameters.json               
├── deploy-devtest-labs.ps1       
├── deploy-devtest-labs.sh        
├── main.tf                       
└── README.md                     
⚙
 Konfigurasjon
 Parametere (parameters.json)
 # Hovedtemplat (Bicep)
 # Student bruker modul
 # Parameterfile
 # PowerShell deployment
 # Bash deployment
 # Terraform hovedfil
 # Denne filen
json
 {
 }
 "schoolName": "TechSkole",        
"cohortId": "V2025",              
"numberOfStudents": 26,           
"location": "norwayeast",         
// Navn på skolen
 // Kull/semester
 // Antall elever
 // Azure region
 "dailyCostLimitPerStudent": 50,   // Daglig kostnad per elev (NOK)
 "maxVmsPerStudent": 2,            
// Maks VM-er per elev
 "autoShutdownHours": 2            
Miljøvariabler
 bash
 // Timer før auto-shutdown
 export AZURE_SUBSCRIPTION_ID="din-subscription-id"
 export SCHOOL_NAME="DinSkole"
 export COHORT_ID="H2025"
 
 Brukerhåndtering
 Studentkontoer
 Systemet oppretter automatisk brukerkontoer:
 Format: 
elev01@dindomene.onmicrosoft.com til 
Midlertidig passord: 
TempPass123!
 Tvungen passordendring: Ved første innlogging
 Tilgangsnivå: Kun egne VM-er og lab-ressurser
 Lærerkontoer
 Lærere får administratortilgang til:
 Lab-administrasjon
 Kostnadsoversikt
 Brukerhåndtering
 VM-overvåkning
 
 Kostnadskontroll
 Budsjettstruktur
 Per elev per dag: 50 NOK (default)
 elev30@dindomene.onmicrosoft.com
Total månedlig: 1,300 NOK for 26 elever × 30 dager = 39,000 NOK
 Semester (6 måneder): Ca. 234,000 NOK
 Kostnadsvarsler
 50% av budsjett: E-postvarsel til administrator
 80% av budsjett: Prognosert kostnad varsling
 100% av budsjett: Kritisk varsling
 Kostnadsoptimalisering
 VM-størrelser: Kun små instanser tillatt (B-serien)
 Auto-shutdown: Forhindrer glemt VM-er som kjører hele natten
 Weekend shutdown: Automatisk stopp i helger
 Snapshot-policyer: Automatisk opprydding av gamle disker
 🛡
 Sikkerhetsfunksjoner
 Rollebasert tilgangskontroll (RBAC)
 Nettverkssikkerhet
 Isolerte subnett: Hver elev får sitt eget nettverkssegment
 NSG-regler: Kun nødvendig trafikk tillatt
 Bastion Host: Sikker tilgang uten offentlige IP-er (valgfritt)
 json
 {
  "studentRettigheter": [
    "Opprette VM fra godkjente images",
    "Starte/stoppe egne VM-er",
    "Koble til VM via RDP/SSH",
    "Se kostnadsrapporter",
    "Installere godkjente artifacts"
  ],
  "forbudte_handlinger": [
    "Endre lab-policyer",
    "Se andre elevers VM-er",
    "Opprette custom images",
    "Endre sikkerhetspolicyer",
    "Administrere andre brukere"
  ]
 }
VPN-integrasjon: Kobling til skolens nettverk (valgfritt)
 
 Overvåkning og Rapportering
 Kostnadsoversikt
 bash
 # Daglig kostnadsrapport
 az consumption usage list --start-date $(date -d '1 day ago' +%Y-%m-%d) --end-date $(date +%Y-%
 # Månedlig rapport per student
 az devtestlab vm list --resource-group $RG_NAME --lab-name $LAB_NAME --query "[].{Name:name,Own
 
 Bruksstatistikk
 VM-opprettelse: Hvilke elever som oppretter flest VM-er
 Brukstid: Hvor lenge VM-er kjører
 Ressurstyper: Mest populære VM-størrelser og images
 Kostnadsfordeling: Per elev og per måned
 
 Daglig drift
 For lærere - Daglige oppgaver
 Morgenrutine (08:00)
 bash
 # Kjør management script
 ./manage-lab-TechSkole-V2025.sh
 # Velg alternativ 3: "Start all VMs" (hvis auto-start ikke virker)
 # Kontroller at alle elever har tilgang
 I løpet av dagen
 Overvåk ressursbruk via Azure Portal
 Hjelp elever med tekniske problemer
 Kontroller kostnader i Cost Management
 Kveldrutine (21:30)
 
bash
 # Varsle elevene 30 min før shutdown
 # VM-er slås av automatisk kl. 22:00
 # Kontroller at shutdown har fungert
 For elever - Daglig bruk
 Komme i gang
 1. Logg inn på Azure Portal med skolebruker
 2. Naviger til DevTest Labs
 3. Opprett VM fra "Windows11-Student" formula
 4. Vent på provisioning (5-10 minutter)
 5. Koble til via RDP
 Best practices for elever
 Lagre arbeid: Alltid lagre filer på C: eller nettverksdisk
 Installer software: Kun via godkjente artifacts
 Slå av VM: Når ikke i bruk for å spare kostnader
 Rapporter problemer: Til lærer hvis noe ikke fungerer
 
 Feilsøking
 Vanlige problemer
 "Kan ikke opprette VM"
 bash
 # Sjekk policyer
 az lab policy list --resource-group $RG_NAME --lab-name $LAB_NAME
 # Kontroller kvoter
 az vm list-usage --location $LOCATION --output table
 # Løsning: Øk kvote eller vent til andre VM-er slettes
 "Kan ikke koble til VM"
 Kontroller NSG-regler: Tillat RDP (port 3389)
 Sjekk VM-status: Må være "Running"
 Firewall: Kontroller skolens nettverkspolicyer
Credentials: Bruk riktig brukernavn/passord
 "Kostnadene er for høye"
 bash
 # Identifiser dyre ressurser
 az consumption usage list --top 10
 # Stopp unødvendige VM-er
 az lab vm stop --resource-group $RG_NAME --lab-name $LAB_NAME --name $VM_NAME
 # Juster policyer
 # Reduser VM-størrelser eller antall tillatte VM-er
 Avansert feilsøking
 Lab-policyer virker ikke
 1. Kontroller JSON-syntax i policy-definisjoner
 2. Verifiser scope - gjelder policyen riktig nivå?
 3. Restart lab service (sjeldent nødvendig)
 Brukere kan ikke se lab-et
 1. Kontroller rolle-assignments
 2. Verifiser Azure AD-tilgang
 3. Sjekk subscription-tilganger
 
 Skalering og optimalisering
 Øke antall elever
 bash
 # Oppdater parameter file
 sed -i 's/"numberOfStudents": 26/"numberOfStudents": 30/' parameters.json
 # Redeploy
 az deployment group create --resource-group $RG_NAME --template-file main.bicep --parameters @p
 
 Ytelsesoptimalisering
 SSD-disker: Velg Premium storage for bedre ytelse
 Større VM-er: Tillat Standard_B4ms for krevende oppgaver
 
Regional deployment: Velg nærmeste Azure region
 Semesteroppgradering
 1. Eksporter konfigurasjon fra forrige semester
 2. Oppdater cohort_id i parameter file
 3. Deploy ny lab med samme innstillinger
 4. Migrer VM-formulas og artifacts
 
 Sjekkliste før produksjon
 Pre-deployment
 Azure subscription klar med tilstrekkelige kvoter
 Azure AD domain konfigurert
 Budsjett og kostnadskontroll planlagt
 Nettverk og sikkerhetspolicyer definert
 Backup og disaster recovery planlagt
 Under deployment
 Template validering passert
 Alle ressurser opprettet uten feil
 Policyer aktivert og testet
 Brukere opprettet og tildelt roller
 Test VM opprettet og funksjonell
 Post-deployment
 Kostnadsvarsler konfigurert og testet
 Studentkontoer distribuert sikkert
 Lærer-dashboard konfigurert
 Overvåkning og alerting aktivert
 Dokumentasjon oppdatert og distribuert
 
 Backup og gjenoppretting
 Automatisk backup
bash
 # VM snapshots (daglig)
 az vm snapshot create --resource-group $RG_NAME --name $VM_NAME-snapshot-$(date +%Y%m%d)
 # Lab konfigurasjon backup
 az lab export --resource-group $RG_NAME --name $LAB_NAME --output-blob-container-uri $BACKUP_UR
 
 Disaster recovery
 1. Dokumenter alle innstillinger i versjonskontroll
 2. Eksporter VM-formulas regelmessig
 3. Backup kritiske student-data til annen region
 4. Test gjenopprettingsprosedyrer hver måned
 
 Support og vedlikehold
 Vanlige supportoppgaver
 Passord reset: Hjelpe elever med glemt passord
 VM-problemer: Restart eller recreate problematiske VM-er
 Kostnadsstyring: Justere policyer ved behov
 Brukerhåndtering: Legge til/fjerne studenter
 Vedlikeholdsplan
 Ukentlig: Kostnadsoversikt og cleanup
 Månedlig: Policy-review og optimalisering
 Semestervis: Fullstendig gjennomgang og oppdatering
 Årlig: Sikkerhetsgennomgang og compliance-sjekk
 
 Ressurser og lenker
 Microsoft dokumentasjon
 Azure DevTest Labs dokumentasjon
 Azure Cost Management
 Azure RBAC
 Utvidede muligheter
 Azure Lab Services: Alternativ for større klassemiljøer
 Windows Virtual Desktop: For remote desktop opplevelser
 
Azure Education: Gratis credits for skoler
 
 Lisens og bidrag
 Dette prosjektet er open source og kan fritt brukes av utdanningsinstitusjoner. Bidrag og forbedringer
 mottas gjerne!
 Hvordan bidra
 1. Fork repository
 2. Opprett feature branch
 3. Test endringene grundig
 4. Submit pull request med beskrivelse
 Sist oppdatert: Juni 2025
 Versjon: 1.0
 Kompatibilitet: Azure DevTest Labs, Bicep 0.4+, Terraform 1.0+
