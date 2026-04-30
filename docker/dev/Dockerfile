FROM rust:1.82-slim-bookworm

# === 1. Dépendances système ===
# cmake + build-essential : requis par rdkafka (binding C de librdkafka)
# libssl-dev : requis par tonic (TLS) et reqwest (Stripe)
# librdkafka-dev : client Kafka natif
# protobuf-compiler : pour prost-build si on compile les .proto localement
# pkg-config : détection des libs système par les crates Rust
# libpq-dev : client PostgreSQL natif (optionnel, sqlx peut utiliser rustls)
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    cmake \
    build-essential \
    librdkafka-dev \
    protobuf-compiler \
    libpq-dev \
    curl \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# === 2. Outils de développement ===
# cargo-watch : recompile automatiquement quand un fichier .rs change
# cargo-nextest : test runner plus rapide et lisible que cargo test
# sqlx-cli : gestion des migrations depuis le terminal
RUN rustup component add rustfmt clippy rust-analyzer

RUN cargo install cargo-watch sqlx-cli --locked && \
    curl -LsSf https://get.nexte.st/latest/linux | tar zxf - -C /usr/local/cargo/bin

# === Buf CLI (pour régénérer le code proto depuis BSR) ===
RUN curl -sSL https://github.com/bufbuild/buf/releases/latest/download/buf-Linux-x86_64 \
    -o /usr/local/bin/buf && \
    chmod +x /usr/local/bin/buf

# === 3. Workspace ===
WORKDIR /app

# === 4. Pré-compilation des dépendances (layer cachée) ===
# On copie UNIQUEMENT les Cargo.toml pour compiler les dépendances.
# Tant que les dépendances ne changent pas, cette layer est cachée
# par Docker → le rebuild est quasi instantané.
COPY Cargo.toml ./
COPY crates/shared-kernel/Cargo.toml crates/shared-kernel/
COPY crates/identity/Cargo.toml crates/identity/
COPY crates/catalog/Cargo.toml crates/catalog/
COPY crates/inventory/Cargo.toml crates/inventory/
COPY crates/cart/Cargo.toml crates/cart/
COPY crates/order/Cargo.toml crates/order/
COPY crates/payment/Cargo.toml crates/payment/
COPY crates/notification/Cargo.toml crates/notification/
COPY crates/server/Cargo.toml crates/server/

# Créer des fichiers source vides pour satisfaire cargo
# (cargo refuse de compiler un crate sans src/lib.rs ou src/main.rs)
RUN for dir in crates/*/; do \
    mkdir -p "$dir/src" && \
    echo "// placeholder" > "$dir/src/lib.rs"; \
    done && \
    mkdir -p crates/server/src && \
    echo "fn main() {}" > crates/server/src/main.rs

# Compiler les dépendances en mode dev (avec debug symbols)
# Le "|| true" ignore l'erreur de compilation (le code est vide)
# mais les dépendances sont bien compilées et cachées.
RUN cargo build 2>/dev/null || true

# Nettoyer les artéfacts des placeholders pour éviter les conflits
# quand le vrai code source sera monté en volume.
RUN rm -rf crates/*/src

# === 5. Le vrai code arrive par volume mount ===
# En dev, on ne COPY pas le code source ici.
# Il est monté via docker-compose :
#   volumes:
#     - ../../:/app
#
# Avantage : modifier un .rs sur l'hôte → cargo-watch le détecte
# instantanément → recompilation → serveur redémarré.
# Pas besoin de rebuilder l'image Docker.

# === 6. Ports ===
# gRPC
EXPOSE 50051
# HTTP (webhooks Stripe + health-check)
EXPOSE 3000

# === 7. Commande de lancement ===
# cargo-watch surveille les fichiers et relance la compilation + exécution.
# -x run : exécute `cargo run` à chaque changement
# -w crates/ : surveille uniquement le dossier crates/ (pas target/, pas .git)
# -w migrations/ : surveille aussi les migrations SQL
# --why : affiche quel fichier a déclenché la recompilation (utile pour debug)
# --poll : utilise le polling au lieu de inotify (plus fiable avec Docker volumes)
CMD ["cargo", "watch", \
    "-x", "run --bin server", \
    "-w", "crates/", \
    "-w", "migrations/", \
    "--why", \
    "--poll"]