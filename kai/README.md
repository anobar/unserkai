# Kai — unsere private KI

Kai ist ein gemeinsamer KI-Chat für vier Freunde. Er besteht aus zwei gemieteten Maschinen in Amazons Rechenzentrum Frankfurt, die wir selbst kontrollieren: einer **kleinen Maschine, die immer läuft** und Konten, Chat-Verlauf und Werkzeuge hält, und einer **Grafikkarten-Maschine**, auf der das Sprachmodell rechnet und die nur eingeschaltet wird, wenn wir sie brauchen. Niemand außer uns liest die Gespräche mit.

![Kai im Überblick](docs/bilder/kai_ueberblick.svg)

## So funktioniert es, in vier Sätzen

1. Du öffnest im Browser (PC oder Telefon) die **Chat-Oberfläche** auf der kleinen Maschine und meldest dich mit deinem Konto an.
2. Deine Frage geht über den **Verteiler** an das **Sprachmodell** auf der Grafikkarten-Maschine. Es antwortet und merkt sich nichts; dein Chat-Verlauf liegt in deinem Konto auf der kleinen Maschine.
3. Wenn es sinnvoll ist, benutzt das Modell ein **Werkzeug**, zunächst die Websuche von Brave, um aktuelle Informationen zu holen.
4. Ist die Grafikkarten-Maschine aus, bleibt die Oberfläche mit allen Verläufen erreichbar; das Modell meldet sich dann als „nicht erreichbar“, bis jemand die Maschine einschaltet.

## Was wo steht

| Für wen | Dokument |
|---|---|
| Alle | Dieses Blatt und die Bilder in [docs/bilder/](docs/bilder/) |
| Technisch Interessierte | [Architektur und Entscheidungen](docs/01_architektur.md) |
| Uwe (Infrastruktur) | [Anforderungen an Maschinen, Platten, Netz, Zugang](docs/02_anforderungen-infrastruktur.md) und die [Bestandsaufnahme der beiden Maschinen](docs/instance_specs.md) |
| Modellwahl | [Modellvorschlag für die T4-Grafikkarte](docs/03_modellvorschlag.md) |
| Vorgehen | [Plan: Phasen, Aufgaben, Prüfungen](docs/04_plan.md) |
| Admins | [compose/entry/.env.example](compose/entry/.env.example): welche Zugangsdaten gebraucht werden (ab Phase 2) |

## Bausteine

| Maschine | Baustein | Was er tut | Software |
|---|---|---|---|
| kai-entry (läuft immer) | Chat-Oberfläche | Konten, Gespräche, Dokumente, Werkzeuge | [Open WebUI](https://github.com/open-webui/open-webui) |
| kai-entry | Verteiler | Ein Anschluss für Oberfläche und Programme; leitet jede Anfrage an die richtige Maschine und zählt den Verbrauch | [LiteLLM](https://github.com/BerriAI/litellm) |
| kai-entry | Websuche | Sucht im Internet, wenn das Modell es anfordert | [Brave Search MCP](https://github.com/brave/brave-search-mcp-server) |
| kai-gpu (bei Bedarf) | Modell-Weiche | Lädt das gewählte Modell auf die Grafikkarte, tauscht bei Bedarf | [llama-swap](https://github.com/mostlygeek/llama-swap) |
| kai-gpu | Modellserver | Rechnet die Antworten | [llama.cpp](https://github.com/ggml-org/llama.cpp) |
| kai-gpu | Erstes Modell | Allrounder, 21 Mrd. Parameter, passt in 16 GB | [gpt-oss-20b](https://huggingface.co/ggml-org/gpt-oss-20b-GGUF) |

Alles läuft in Docker-Containern und wird mit Ansible aus diesem Repository eingerichtet ([ansible/](../ansible/)). Beide Maschinen sind austauschbar: alles, was bleiben muss, liegt auf eigenen Platten, der Rest wird aus diesem Repository neu aufgebaut ([Architektur §3](docs/01_architektur.md#3-austauschbarkeit-die-maschine-ist-wegwerfware)).

## Was später dazukommt

Der Verteiler kann weitere Rechenknoten aufnehmen, ohne dass sich für die Nutzer etwas ändert: eine größere Grafikkarten-Maschine, Rechner zu Hause, externe KI-Dienste (nur mit Schutz der Daten) sowie Programme wie OpenCode, die den Verteiler direkt ansprechen. Automatisches Ein- und Ausschalten der Grafikkarten-Maschine gehört ebenfalls dazu. Siehe [Architektur §5](docs/01_architektur.md#5-ausblick-was-der-endpunkt-später-aufnimmt).

## Stand

Phase 1 (Design) in Abstimmung · Uwe hat die kleine Maschine angelegt, Befund in der Bestandsaufnahme · Phase 2 (Skripte) und Phase 3 (Umsetzung) folgen · Aufgaben in ClickUp, Sprint 01.
