import os

from flask import Flask, jsonify, render_template

app = Flask(__name__)

# TODO: coloque aqui o nome completo de TODOS os integrantes do grupo.
INTEGRANTES = [
    "Super Choque (Artur Lima da Silva)",
]

DISCIPLINA = "Cloud Computing e DevOps"
INSTITUICAO = "Afya"

COMMIT_SHA = os.getenv("COMMIT_SHA", "dev")
BUILD_TIME = os.getenv("BUILD_TIME", "local")


@app.route("/")
def index():
    return render_template(
        "index.html",
        disciplina=DISCIPLINA,
        instituicao=INSTITUICAO,
        integrantes=INTEGRANTES,
        commit=COMMIT_SHA[:7],
        build_time=BUILD_TIME,
    )


@app.route("/health")
def health():
    """Usado pelo HEALTHCHECK do Docker, pelo teste da pipeline e pelo Uptime Kuma."""
    return jsonify(status="ok", commit=COMMIT_SHA[:7], build=BUILD_TIME), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
