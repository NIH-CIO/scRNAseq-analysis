FROM rocker/r-ver:4.5

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8


# Copy the company CA certificate into the image
COPY trusted_certs.crt /usr/local/share/ca-certificates/company-cert.crt

# Update the CA certificates
RUN update-ca-certificates

WORKDIR /app



RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    cmake gdal-bin libcairo2-dev libfontconfig1-dev libfreetype6-dev libgdal-dev \
    libglpk-dev libgsl0-dev libhdf5-dev libnode-dev libpng-dev libx11-dev pandoc \
    patch libharfbuzz-dev libfribidi-dev libjpeg-dev libtiff-dev libwebp-dev \
    libxml2-dev libbz2-dev liblzma-dev libcurl4-openssl-dev libssl-dev libgit2-dev \
    libsqlite3-dev libreadline-dev libzmq3-dev zlib1g-dev libncurses5-dev libpcre2-dev \
    libgl1-mesa-dev xorg-dev libxext-dev wget gdebi-core \
    libdbus-1-3 libnss3 libasound2 libcups2 libgtk-3-0 libglib2.0-0 libxi6 libxrandr2 \
    libxcomposite1 libxcursor1 libxdamage1 libxfixes3 libsm6 libice6 libxss1 libatk1.0-0 \
    libatk-bridge2.0-0 libatspi2.0-0 libpango-1.0-0 libpangocairo-1.0-0 libharfbuzz0b \
    libxkbcommon0 libxkbcommon-x11-0 libgbm1 libdrm2 libglu1-mesa libxinerama1 xauth dbus-x11 \
    libudunits2-dev libgeos-dev libproj-dev libmagick++-dev libpoppler-cpp-dev libv8-dev libhts-dev \
    default-jdk default-jre python3 python3-pip python3-venv libpam0g psmisc build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*


#### This is the only change made ####
# Install RStudio Server
RUN wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2023.09.0-421-amd64.deb \
    && gdebi -n rstudio-server-2023.09.0-421-amd64.deb \
    && rm rstudio-server-2023.09.0-421-amd64.deb
### =============================  ####

# Verify all runtime libs are present (fails build if any missing)
RUN ldd /usr/bin/rstudio | awk '/not found/ {print; missing=1} END{exit missing?1:0}'

# Smoke test (no GUI needed)
RUN rstudio --version


RUN echo 'options(repos = c(CRAN = "https://cran.rstudio.com"))' >> /usr/local/lib/R/etc/Rprofile.site


# Install remotes package with verbose output
RUN R -e "install.packages('remotes', repos = 'https://cloud.r-project.org', verbose = TRUE)"

# Install renv using remotes and verify installation
RUN R -e "remotes::install_github('rstudio/renv')"
RUN R -e "if (!requireNamespace('renv', quietly = TRUE)) { stop('renv package not installed') }"


# Copy the lockfile and activate script
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R

# Restore the project dependencies
RUN R -e "renv::restore()"

# Copy the rest of your project files.
COPY . .

# Verify installed packages
RUN R -e "print('Installed packages:'); print(installed.packages()[, 'Package'])"

