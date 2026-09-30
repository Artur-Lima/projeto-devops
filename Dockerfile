# ---------- Estágio 1: build das dependências ----------
FROM python:3.12-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---------- Estágio 2: imagem final ----------
FROM python:3.12-slim

# Argumentos preenchidos pela pipeline (viram o rodapé da página)
ARG COMMIT_SHA=dev
ARG BUILD_TIME=local
ENV COMMIT_SHA=$COMMIT_SHA \
    BUILD_TIME=$BUILD_TIME \
    PYTHONUNBUFFERED=1

# Usuário sem privilégios: o container não roda como root
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app.py .
COPY templates/ ./templates/

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app:app"]
