# ---------- Base with RStudio Server ----------
FROM rocker/rstudio:4.5 AS base

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive
# Limit threads & reduce heap fragmentation to avoid memory spikes
ENV OMP_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    BLIS_NUM_THREADS=1 \
    VECLIB_MAXIMUM_THREADS=1 \
    MALLOC_ARENA_MAX=2


# Optional enterprise CA
COPY trusted_certs.crt /usr/local/share/ca-certificates/company-cert.crt
RUN update-ca-certificates || true

# Your required system dependencies
RUN set -eux; \
  apt-get update; \
  # ALSA name differs on noble
  ASOUND=libasound2; apt-cache show libasound2t64 >/dev/null 2>&1 && ASOUND=libasound2t64; \
  # libhts-dev on noble pulls gnutls; fall back to openssl elsewhere
  CURLDEV=libcurl4-gnutls-dev; \
  apt-cache show libcurl4-gnutls-dev >/dev/null 2>&1 || CURLDEV=libcurl4-openssl-dev; \
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    cmake curl gdal-bin libcairo2-dev libfontconfig1-dev libfreetype6-dev libgdal-dev \
    libglpk-dev libgsl0-dev libhdf5-dev libnode-dev libpng-dev libx11-dev pandoc \
    patch libharfbuzz-dev libfribidi-dev libjpeg-dev libtiff-dev libwebp-dev \
    libxml2-dev libbz2-dev liblzma-dev "$CURLDEV" libssl-dev libgit2-dev \
    libsqlite3-dev libreadline-dev libzmq3-dev zlib1g-dev libncurses5-dev libpcre2-dev \
    libgl1-mesa-dev xorg-dev libxext-dev wget gdebi-core gdebi \
    libdbus-1-3 libnss3 "$ASOUND" libcups2 libgtk-3-0 libglib2.0-0 libxi6 libxrandr2 \
    libxcomposite1 libxcursor1 libxdamage1 libxfixes3 libsm6 libice6 libxss1 libatk1.0-0 \
    libatk-bridge2.0-0 libatspi2.0-0 libpango-1.0-0 libpangocairo-1.0-0 libharfbuzz0b \
    libxkbcommon0 libxkbcommon-x11-0 libgbm1 libdrm2 libglu1-mesa libxinerama1 xauth dbus-x11 \
    libudunits2-dev libgeos-dev libproj-dev libmagick++-dev libpoppler-cpp-dev libv8-dev libhts-dev \
    default-jdk default-jre python3 python3-pip python3-venv libpam0g psmisc build-essential pkg-config \
  && rm -rf /var/lib/apt/lists/*

# Ensure the curl dev headers needed by many R pkgs
RUN apt-get update && apt-get install -y "$CURLDEV" && rm -rf /var/lib/apt/lists/*
  

# Make sure RStudio’s Pandoc is discoverable by rmarkdown/knitr
ENV PATH="/usr/lib/rstudio/bin:/usr/lib/rstudio-server/bin:${PATH}"
ENV RSTUDIO_PANDOC=/usr/lib/rstudio/bin

# ---------- Quarto builder (multi-arch) ----------
FROM base AS quarto_builder
ARG TARGETARCH
RUN set -eux; \
    cd /tmp; \
    QUARTO_URL="https://quarto.org/download/latest/quarto-linux-${TARGETARCH}.deb"; \
    wget -O /tmp/quarto.deb "$QUARTO_URL"

# ---------- Final image ----------
FROM base
ARG TARGETARCH

# Install Quarto from builder
COPY --from=quarto_builder /tmp/quarto.deb /tmp/quarto.deb
RUN dpkg -i /tmp/quarto.deb || (apt-get update && apt-get -f install -y && dpkg -i /tmp/quarto.deb) \
  && rm -f /tmp/quarto.deb

# ---------- RStudio Desktop (Electron) — arch-aware ----------
# Map TARGETARCH -> Posit DEB URL; supports amd64 and arm64 on Ubuntu 22.04 (Jammy)
# You can pin/override with --build-arg RSTUDIO_DESKTOP_VERSION=2024.09.1-394
ARG RSTUDIO_DESKTOP_VERSION=2025.09.2-418
ARG UBUNTU_CODENAME=jammy
RUN set -eux; \
    arch="$TARGETARCH"; \
    for base in \
      "https://download1.rstudio.org/electron/${UBUNTU_CODENAME}/${arch}" \
      "https://s3.amazonaws.com/rstudio-ide-build/electron/${UBUNTU_CODENAME}/${arch}"; do \
        url="${base}/rstudio-${RSTUDIO_DESKTOP_VERSION}-${arch}.deb"; \
        echo "Trying $url"; \
        if wget -q -O /tmp/rstudio-desktop.deb "$url"; then break; fi; \
    done; \
    test -s /tmp/rstudio-desktop.deb; \
    apt-get update; \
    gdebi -n /tmp/rstudio-desktop.deb; \
    rm -f /tmp/rstudio-desktop.deb




######### == Bundle references == ########
# Copy references (note the trailing slashes to copy directories)
COPY celldex_cache/      /opt/refs/celldex/
COPY pbmcref.SeuratData/ /opt/refs/pbmcref.SeuratData/

# Make files readable and directories traversable
RUN chmod -R a+rX /opt/refs/pbmcref.SeuratData /opt/refs/celldex

# Verify Azimuth reference bundle exists right at this path
RUN set -e; \
  echo "Checking Azimuth reference bundle..."; \
  test -f /opt/refs/pbmcref.SeuratData/azimuth/ref.Rds && \
  test -e /opt/refs/pbmcref.SeuratData/azimuth/idx.annoy && \
  echo "✓ Found ref.Rds and idx.annoy under /opt/refs/pbmcref.SeuratData/azimuth"

# Keep the stable path for R
ENV AZIMUTH_REF="/opt/refs/pbmcref.SeuratData/azimuth"





###### ===== Bake project library with renv ===== #####
ENV RENV_PATHS_LIBRARY=/opt/renv/library
RUN mkdir -p /opt/renv/library && chmod -R a+rX /opt/renv
RUN install -d -m 0777 /opt/renv/library

# Set a CRAN mirror globally so renv/activate can fetch BiocManager
RUN printf '%s\n' 'options(repos = c(CRAN="https://cloud.r-project.org"))' >> /etc/R/Rprofile.site

# Preinstall BiocManager to satisfy renv’s Bioconductor init (into renv lib)
RUN R -e 'lib <- Sys.getenv("RENV_PATHS_LIBRARY"); dir.create(lib, recursive=TRUE, showWarnings=FALSE); install.packages("BiocManager", lib=lib, repos="https://cloud.r-project.org", quiet=TRUE)'

# Install renv tooling for build
RUN R -e "install.packages('remotes', repos='https://cloud.r-project.org', quiet=TRUE)" && \
    R -e "remotes::install_github('rstudio/renv', quiet=TRUE)"

# Copy only what's needed for restore
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R

# Ensure renv present (CRAN, stable)
RUN R -e "install.packages('renv', repos='https://cloud.r-project.org', quiet=TRUE)"

# Make sure BiocManager is installed in this layer before using it
RUN R -e "install.packages('BiocManager', repos='https://cloud.r-project.org', quiet=TRUE)"

# Restore
RUN R -e "options(renv.consent=TRUE, renv.download.method='curl', renv.download.timeout=600, \
                  repos=BiocManager::repositories(), renv.config.repos.override='https://cloud.r-project.org'); \
          Sys.setenv(RENV_DOWNLOAD_TRIES=5, RENV_DOWNLOAD_TIMEOUT=600); \
          renv::restore(prompt=FALSE, clean=TRUE); \
          miss <- setdiff(c('knitr','rmarkdown'), rownames(installed.packages())); \
          if (length(miss)) renv::install(miss)"





# (moved) Do NOT lock perms yet; a second restore happens after COPY

# ---------- Project files & working dir ----------
WORKDIR /app
COPY . /app

# Sync baked site library with the project that was just copied
RUN R -e "options(renv.consent=TRUE); renv::restore(prompt=FALSE)"

# Sanity check: fail build if library didn’t populate (use actual renv path)
RUN R -q -e 'lp <- renv::paths$library(); ip <- installed.packages(lib.loc=lp); stopifnot(nrow(ip) > 50)'

# Make runtime use the baked renv library path
RUN R -q -e 'lp <- renv::paths$library(); write(paste0("R_LIBS_SITE=", lp, "\n"), file="/etc/R/Renviron.site", append=TRUE)'

# NOW lock perms for runtime (moved down)
RUN chmod -R a+rX /opt/renv/library

# Use baked site library at runtime (no renv activation required)
ENV R_LIBS_SITE=/opt/renv/library

# Optional diagnostics
RUN R -e "cat('Library paths:\\n'); print(.libPaths()); \
          ip <- installed.packages(); cat('Installed packages:', nrow(ip), '\\n'); \
          cat('Has knitr? ', 'knitr' %in% rownames(ip), '\\n'); \
          cat('Has rmarkdown? ', 'rmarkdown' %in% rownames(ip), '\\n')"
            

