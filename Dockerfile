FROM ubuntu:latest

# Install prerequisites
RUN apt update -y && \
    apt install curl xz-utils -y

# Install Nix using Determinate Systems installer
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
  --extra-conf "sandbox = false" \
  --init none \
  --no-confirm

# Set up environment for Nix
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"

# Create directory for nixcfg
WORKDIR /nixcfg

# Copy your nixcfg directory with flake.nix into the container
COPY . /nixcfg/

# Enable flakes and install the profile
RUN mkdir -p ~/.config/nix && \
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf && \
    nix profile install

# Verify installation
RUN nix flake show


# docker run -v ~/:/root -it --gpus=8  ubuntu-with-nix --name nixdev
# docker start nixdev && docker exec -it nixdev fish