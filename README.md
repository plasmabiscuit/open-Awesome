# open-Awesome
All the context and documentation a dumbass LLM might need to not fuckup my docker containers

!important ALWAYS CHECK THE DOCUMENTATION BEFORE MAKING OR SUGGESTING MAJOR CHANGES

# Codespace quickstart

- **Base image & resources:** Start from the CUDA-enabled image `ghcr.io/open-webui/open-webui:cuda` so GPU workflows  work. Allocate at least 4 vCPUs, 16 GB RAM, and a GPU with ~8 GB VRAM for smoother model loads and RAG indexing.
- **First pull & run:**
  - `docker pull ghcr.io/open-webui/open-webui:cuda`
  - `docker run -d --gpus all -p 3000:8080 -v open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui:cuda`
- **Apply overlays after pulls:**
  - `openwebui-custom/static/` replaces the container’s `/app/backend/static/` contents so icons, CSS, and loader assets stay customized between updates.
  - `Replace/` is for one-off file overrides outside the normal static path (for example, a patched `index.html`). Copy its contents over the container filesystem after each pull or rebuild.
- **Read next:**
  - [Manual Docker quick start](Documentation/Essential/Docker/ManualDocker.md)
  - [Compose layout](Documentation/Essential/Docker/DockerCompose.md)
  - [Update flow](Documentation/Essential/Docker/DockerUpdating.md)
  - [Data & backup notes](Documentation/Essential/Data%20and%20Backups/backups.md)

### Windows notes (keep separate from cloud/codespace defaults)

- Docker Desktop runs inside WSL; use `\\wsl$\docker-desktop-data` for volume inspection and keep model paths on `F:\.ollama\models` as configured below.
- When copying overlays, translate Windows paths (e.g., `C:\workspace\openwebui-custom\static`) to the container with `docker cp` instead of relying on bind mounts that expect Linux-style paths.
- For a step-by-step localhost setup on Windows with WSL and Docker Desktop, see [Windows Localhost Quickstart](Documentation/Essential/Docker/WindowsLocalhost.md).

# Host System Info

## Device Specs

Device Name	llamadesk 

Processor	Intel(R) Core(TM) i9-10900K CPU @ 3.70GHz   3.70 GHz

Installed RAM	32.0 GB

Storage	477 GB SSD ADATA SX6000LNP, 1.82 TB SSD WDS200T1X0E-00AFY0, 1.82 TB HDD ST2000DM008-2FR102

Graphics Card	NVIDIA GeForce RTX 3080 (10 GB)

Device ID	73229887-15CB-4457-B581-C0EEC56A0C67

Product ID	00325-82110-89953-AAOEM

System Type	64-bit operating system, x64-based processor

## Windows Info

Edition	Windows 10 Home
Version	22H2
OS Build	19045.6466
> Windows System Vars: OLLAMA_HOST = 0.0.0.0:11434 ; OLLAMA_MODELS F:\.ollama\models
##Configuration

> llamadisk (F:) is where the models are stored, specifically at F:\.ollama\models\manifests\registry.ollama.ai\library. For openwebui, use F:\.ollama\models\

> Docker-Desktop (UI) is installed on windows from the WSL ("\\wsl.localhost\docker-desktop") 

> Docker will pull the latest image best suited for windows host running ollama FIRST, then apply any modifications in /openwebui_custom. The /static folder should go to the expected location in the backend of the container image, replacing any defalut contents from the pulled docker container. Data in this dir will be used for migration of backend files between undates when necessary, and also store any memories to be imported. /Replace/ will be used for any persistant modifications to the stock image, and the contents should be applied over container defaults (eg- a modified index.html or something else outside of the typical backend static)





