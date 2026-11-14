#!/bin/zsh
# The diagrams under docs/: writes docs/ablauf.puml anew from the process
# definition in SourdoughKit (`BakeProcess.plantUML()`, through the test that
# checks it), then draws every docs/*.puml as an SVG next to it. The SVGs are
# checked in, because GitHub does not draw PlantUML.
#
#   tools/diagrams.sh
#
# Needs Java and the PlantUML jar, whose path is read from PLANTUML_JAR only;
# the jar lies outside the repository. Activity diagrams need no Graphviz.
cd "${0:A:h}/.."

if [[ -z "$PLANTUML_JAR" ]]; then
  print -u2 "PLANTUML_JAR ist nicht gesetzt: Pfad zur PlantUML-Jar angeben, etwa"
  print -u2 "  export PLANTUML_JAR=\"/Library/Application Support/PlantUML/plantuml-mit-1.2026.10.jar\""
  exit 1
fi
if [[ ! -f "$PLANTUML_JAR" ]]; then
  print -u2 "PLANTUML_JAR zeigt auf keine Datei: $PLANTUML_JAR"
  exit 1
fi

# The generated source first, so that the SVG shows the current process.
if ! (cd SourdoughKit && UPDATE_DIAGRAMS=1 swift test --filter theDiagramInTheDocsIsUpToDate >/dev/null 2>&1); then
  print -u2 "docs/ablauf.puml ließ sich nicht erzeugen: tools/tests.sh zeigt den Fehler."
  exit 1
fi

java -jar "$PLANTUML_JAR" -tsvg docs/*.puml || exit 1
print -l -- docs/*.svg
