# Windows Localhost Quickstart (Docker Desktop + WSL)

Use this guide to stand up Open WebUI on Windows for local feature and integration testing. It assumes Docker Desktop is driving containers through WSL 2 and that Ollama is installed on the host.

## Prerequisites

- Windows 10/11 with WSL 2 enabled.
- Docker Desktop installed with the **WSL 2** backend and integration enabled for your distro.
- GPU driver installed (NVIDIA recommended if you plan to use the CUDA image).
- Ollama for Windows installed and running so it exposes `http://localhost:11434`.
- Environment variables on Windows (set once via System Properties > Environment Variables):
  - `OLLAMA_HOST=0.0.0.0:11434`
  - `OLLAMA_MODELS=F:\\.ollama\\models` (adjust if your models live elsewhere). In WSL this path will appear as `/mnt/f/.ollama/models`.

## 1) Verify Docker inside WSL

Open your WSL terminal (e.g., Ubuntu) and confirm Docker is available:

```bash
docker info
```

If this fails, open Docker Desktop and enable **Settings > Resources > WSL Integration** for your distro.

## 2) Pull the Open WebUI image

From WSL, pull the CUDA-enabled image (recommended for GPU testing). Use `:main` if you do not need GPU acceleration.

```bash
docker pull ghcr.io/open-webui/open-webui:cuda
```

For a smaller footprint, you can pull the slim variant instead:

```bash
docker pull ghcr.io/open-webui/open-webui:cuda-slim
```

## 3) Run Open WebUI pointing at host Ollama

This starts the container, binds it to `http://localhost:3000`, and forwards requests to the Ollama service running on Windows.

```bash
docker run -d --name openwebui --restart unless-stopped \
  --gpus all \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -v open-webui:/app/backend/data \
  ghcr.io/open-webui/open-webui:cuda
```

- Remove `--gpus all` and switch the image tag to `:main` if you are CPU-only.
- For slim images, use `ghcr.io/open-webui/open-webui:cuda-slim` (or `:main-slim`).

## 4) Apply local customizations

From your checked-out repository inside WSL (e.g., `/mnt/c/Users/<you>/open-Awesome`), overlay the customized assets into the running container:

```bash
docker cp openwebui-custom/static/. openwebui:/app/backend/static/
docker cp openwebui-custom/Replace/. openwebui:/app/backend/
docker restart openwebui
```

These commands translate Windows paths automatically through WSL; no bind mounts are required.

## 5) Validate the localhost setup

- Confirm the container is running: `docker ps --filter name=openwebui`
- Open your browser to [http://localhost:3000](http://localhost:3000).
- Log in or register the first admin account. Verify model calls reach Ollama (the **Settings > Connections** page should show the Ollama endpoint at `http://host.docker.internal:11434`).

## 6) Troubleshooting tips

- **Port in use:** If port 3000 is taken, change the `-p` flag (e.g., `-p 3300:8080`) and browse to the new port.
- **Ollama unreachable:** Confirm the Ollama tray app is running on Windows and that `curl http://host.docker.internal:11434/api/tags` works from WSL.
- **Volume location:** Docker-managed data is stored in `\\wsl$\\docker-desktop-data`. Model files live on `F:` (or your chosen drive); keep them off the WSL ext4 disk for space and speed.
- **Resetting the stack:** `docker stop openwebui && docker rm openwebui` removes the container while preserving the `open-webui` volume.
