# Pinging Project - Una pipeline CI/CD per deploy su cluster Kubernetes

Questo progetto implementa una semplice applicazione di microservizi composta da due "pinger" che vengono eseguiti su un cluster Kubernetes locale gestito da Kind. Le applicazioni sono containerizzate utilizzando Docker e il progetto include anche workflow di CI/CD di base con GitHub Actions per la compilazione e il push delle immagini, oltre a un self-hosted runner per il deploy.

## Architettura

L'architettura è composta dai seguenti elementi:

- **Pinger A & Pinger B**: Due applicazioni Python containerizzate che si pingano a vicenda a intervalli regolari.
- **Kubernetes (Kind)**: Le applicazioni vengono eseguite all'interno di un cluster Kubernetes locale creato con Kind.
- **ConfigMap**: Una ConfigMap di Kubernetes viene utilizzata per configurare l'intervallo e il timeout dei ping.
- **Namespace**: Il progetto utilizza namespace separati (`ping-app` e `github-runner`) per isolare le risorse dell'applicazione e del runner.
- **GitHub Actions**: I workflow sono configurati per automatizzare la compilazione delle immagini Docker dei pinger e il deploy su un self-hosted runner.

## Prerequisiti

Prima di iniziare, assicurati di avere installato i seguenti strumenti:

- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [jq](https://stedolan.github.io/jq/download/)

## Compatibilità

Questo progetto è stato progettato per funzionare su sistemi operativi e architetture specifiche.

- **Sistema Operativo**: Lo script di setup `run.sh` è uno script Bash e utilizza comandi standard Unix. È quindi compatibile con:
    - **Linux** (qualsiasi distribuzione moderna)
    - **macOS**
    - **Windows** tramite WSL (Windows Subsystem for Linux) (NON testato) . Non è compatibile con l'ambiente a riga di comando standard di Windows (CMD o PowerShell).

- **Architettura della CPU**: Le immagini Docker per le applicazioni vengono costruite per più architetture (`linux/amd64` e `linux/arm64`). Questo garantisce la compatibilità con:
    - Processori **Intel/AMD (x86_64)**, comuni sulla maggior parte dei PC.
    - Processori **ARM64 (aarch64)**, come quelli dei Mac con Apple Silicon (M1/M2/M3) e di altri dispositivi basati su ARM.

## Guida all'Installazione

Questa guida ti mostrerà come eseguire il deploy dell'intera applicazione da zero. Il flusso di lavoro principale consiste nel preparare le immagini Docker, caricarle sul tuo registry e solo dopo avviare il cluster.

### 1. Fork del Repository

**Questo è il passo più importante.** Per poter utilizzare la pipeline CI/CD e configurare il progetto correttamente, devi prima creare una tua copia (fork) di questo repository.

Clicca sul pulsante **Fork** in alto a destra in questa pagina di GitHub.

Lavorerai sulla tua versione del repository d'ora in poi.

### 2. Clona il Tuo Fork

Una volta creato il fork, clona il **tuo** repository sulla macchina locale. Sostituisci `<IL_TUO_UTENTE_GITHUB>` con il tuo username.

```bash
git clone https://github.com/<IL_TUO_UTENTE_GITHUB>/pinging_project.git
cd pinging_project
```

### 3. Configurazione dei Segreti di GitHub

Nel tuo repository **forkato**, vai su **Settings > Secrets and variables > Actions** e aggiungi i seguenti segreti. Questi sono necessari per permettere alla pipeline CI/CD di caricare le immagini Docker nel tuo container registry in futuro.

- `DOCKER_USERNAME`: Il tuo username di Docker Hub.
- `DOCKER_PASSWORD`: La tua password di Docker Hub o un token di accesso.

### 4. Creazione del File `.env`

Lo script di avvio richiede un file `.env` nella root del progetto per configurare il self-hosted runner di GitHub Actions. Crea un file chiamato `.env` e aggiungi le seguenti variabili:

```
GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"
REPO_OWNER="<IL_TUO_UTENTE_GITHUB>"
REPO_NAME="pinging_project"
MACHINE_ID="<IL_TUO_ID_MACCHINA>"
```

- `GITHUB_PAT`: Un Personal Access Token di GitHub con i permessi `repo`.
- `REPO_OWNER`: **Importante:** Inserisci qui il tuo username di GitHub.
- `REPO_NAME`: Il nome del repository (dovrebbe essere `pinging_project`).
- `MACHINE_ID`: Un identificatore univoco per la tua macchina (es. `tuo-nome-laptop`).

### 5. Preparazione e Push delle Immagini Docker

Prima di avviare il cluster, le immagini Docker delle applicazioni devono essere disponibili su Docker Hub. Questo garantirà che Kubernetes possa scaricarle e avviare le applicazioni senza errori.

**Passo 5.1: Login su Docker Hub**
Esegui il login al tuo account Docker Hub dal terminale:
```bash
docker login
```

**Passo 5.2: Modifica dei Manifest Kubernetes**
Apri i file `k8s/app/pinger-a.yaml` e `k8s/app/pinger-b.yaml`. In entrambi i file, sostituisci `matteoclz` con il tuo username di Docker Hub nel campo `image`.

*Esempio per `pinger-a.yaml`:*
```yaml
      - name: pinger-a
        image: <IL_TUO_UTENTE_DOCKERHUB>/pinger-a:latest
```

**Passo 5.3: Build e Push delle Immagini**
Ora costruisci le immagini e caricale sul tuo Docker Hub. Sostituisci `<IL_TUO_UTENTE_DOCKERHUB>` con il tuo username.
```bash
# Costruisci e carica pinger-a
docker build -t <IL_TUO_UTENTE_DOCKERHUB>/pinger-a:latest ./app/pinger-a
docker push <IL_TUO_UTENTE_DOCKERHUB>/pinger-a:latest

# Costruisci e carica pinger-b
docker build -t <IL_TUO_UTENTE_DOCKERHUB>/pinger-b:latest ./app/pinger-b
docker push <IL_TUO_UTENTE_DOCKERHUB>/pinger-b:latest
```

### 6. Esegui lo Script di Avvio

Ora che le immagini sono su Docker Hub e i manifest sono corretti, puoi eseguire lo script `run.sh` per creare il cluster e fare il deploy delle applicazioni.

Lo script richiede privilegi elevati. Hai due opzioni:

1.  **Eseguire con `sudo` (Opzione più semplice):**
    ```bash
    sudo ./run.sh
    ```
2.  **Aggiungere il tuo utente al gruppo `docker`:**
    ```bash
    sudo usermod -aG docker $USER
    # Richiede un logout/login per applicare la modifica
    ```
    **Attenzione:** Aggiungere un utente al gruppo `docker` concede privilegi equivalenti a quelli di root e può comportare gravi problemi di sicurezza in caso di compromissione. Utilizza questo approccio solo se ne comprendi a pieno le implicazioni!

### 7. Verifica il Deploy

Una volta che lo script ha terminato, puoi verificare che tutto sia in esecuzione correttamente.

```bash
kubectl get pods -n ping-app
```

Dovresti vedere i pod in stato `Running`.

### 8. Visualizza i Log

Per vedere l'output delle applicazioni, usa `kubectl logs`.

```bash
# Ottieni il nome di un pod di pinger-a
PINGER_A_POD=$(kubectl get pods -n ping-app -l app=pinger-a -o jsonpath='{.items[0].metadata.name}')

# Visualizza i log
kubectl logs -f $PINGER_A_POD -n ping-app
```

### 9. Pulizia

Per eliminare il cluster Kubernetes locale, esegui:

```bash
kind delete cluster
```

## CI/CD

Dopo aver completato questa configurazione iniziale manuale, ogni successivo `push` sul branch `main` del tuo fork attiverà la pipeline di GitHub Actions. Il workflow si occuperà di ricostruire e caricare automaticamente le immagini Docker aggiornate sul tuo Docker Hub e successivamente ridistribuirle al tuo cluster.