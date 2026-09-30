"""Testes executados pela pipeline antes do build da imagem."""

import app as application


def test_health_responde_ok():
    client = application.app.test_client()
    resposta = client.get("/health")
    assert resposta.status_code == 200
    assert resposta.get_json()["status"] == "ok"


def test_pagina_inicial_mostra_disciplina():
    client = application.app.test_client()
    resposta = client.get("/")
    assert resposta.status_code == 200
    assert application.DISCIPLINA in resposta.get_data(as_text=True)


def test_pagina_inicial_mostra_todos_os_integrantes():
    client = application.app.test_client()
    html = client.get("/").get_data(as_text=True)
    assert len(application.INTEGRANTES) >= 1
    for nome in application.INTEGRANTES:
        assert nome in html
