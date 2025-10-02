# 🐳 Multi-stage Dockerfile para Controlador Autônomo
FROM golang:1.21-alpine AS builder

# 📦 Instalar dependências de build
RUN apk add --no-cache git ca-certificates tzdata

# 📁 Configurar diretório de trabalho
WORKDIR /app

# 📋 Copiar arquivos de dependências
COPY go.mod go.sum ./

# 📥 Download de dependências
RUN go mod download && go mod verify

# 📄 Copiar código fonte
COPY . .

# 🔨 Build da aplicação
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o autonomous-controller .

# 🏃‍♂️ Imagem final - distroless para segurança máxima
FROM gcr.io/distroless/static:nonroot

# 📋 Labels para metadados
LABEL maintainer="Service Mesh Expert" \
      version="1.0.0" \
      description="Autonomous Deployment Controller for Istio AKS" \
      org.opencontainers.image.title="Autonomous Deployment Controller" \
      org.opencontainers.image.description="Intelligent controller for autonomous deployments with rollback" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.created="2024-01-01T00:00:00Z" \
      org.opencontainers.image.source="https://github.com/ricardo2009/istio-aks-templates" \
      org.opencontainers.image.licenses="MIT"

# 📁 Copiar certificados CA
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 🕐 Copiar timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# 📦 Copiar binário
COPY --from=builder /app/autonomous-controller /autonomous-controller

# 👤 Usar usuário não-root (distroless nonroot = uid 65532)
USER 65532:65532

# 🚪 Expor portas
EXPOSE 8080 8081

# 🏥 Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/autonomous-controller", "--health-check"]

# 🚀 Comando de entrada
ENTRYPOINT ["/autonomous-controller"]
