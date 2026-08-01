FROM fedora:44

RUN dnf install -y \
    neovim \
    git \
    fish \
    ripgrep \
    nodejs24 \
    && dnf clean all

RUN npm install -g opencode-ai

COPY nvim_minimal /opt/nvim_config

RUN mkdir -p /root/.config \
    && ln -s /opt/nvim_config /root/.config/nvim

WORKDIR /workspace
CMD ["fish"]
