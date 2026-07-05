# CODEX_IMPLEMENTATION: LiteRT-Bilderkennung und In-App-Modellvergleich

Ziel dieses Branches ist ein technischer Vergleich von drei Bildklassifikationsvarianten fuer die CueLens-App:

1. **ML Kit Image Labeling Baseline**
2. **MobileNetV3Small, transfer learned**
3. **EfficientNet-Lite0, transfer learned**

Von Anfang an wird mit genau sechs Klassen gearbeitet:

```text
c in {ashtray, cigarette, cigarette pack, people smoking, smoke, negative}
```

Die Modelle sollen in der Android-App einfach gegeneinander austauschbar sein und in einem Benchmark-Modus direkt auf einem realen Android-Geraet hinsichtlich Sensitivitaet, Spezifitaet, Laufzeit und Fehlklassifikationen getestet werden.

---

## 1. Entscheidung: Transfer Learning nicht in der App, sondern in Python

Das Transfer Learning soll **nicht** in Android Studio und **nicht** direkt in der App erfolgen, sondern in einer separaten Python-Umgebung. Die Android-App fuehrt ausschliesslich Inferenz und Benchmarking aus.

Begruendung:

- Das Training ist rechenintensiv und auf mobilen Endgeraeten fuer diesen Prototyp nicht notwendig.
- Python/TensorFlow erlaubt reproduzierbare Splits, Augmentationen, Quantisierung und Metrikberechnung.
- Die App bleibt schlank, stabil und alltagstauglich.
- Die Studienversion muss keine Trainingsdaten oder Trainingslogik enthalten.
- Die trainierten Modelle koennen als `.tflite`/LiteRT-Dateien mit identischer Ein-/Ausgabeschnittstelle exportiert werden.

Die App enthaelt also nur:

- Modelladapter,
- Vorverarbeitung,
- Inferenz,
- Benchmark-Auswertung,
- CSV-Export der Ergebnisse.

---

## 2. Datenstruktur

Die Bilddateien liegen klassenweise in Ordnern. Fuer die Trainingsumgebung wird folgende Struktur erwartet:

```text
data/cuelens_images/
  ashtray/
    *.jpg|*.jpeg|*.png|*.webp
  cigarette/
    *.jpg|*.jpeg|*.png|*.webp
  cigarette pack/
    *.jpg|*.jpeg|*.png|*.webp
  people smoking/
    *.jpg|*.jpeg|*.png|*.webp
  smoke/
    *.jpg|*.jpeg|*.png|*.webp
  negative/
    *.jpg|*.jpeg|*.png|*.webp
```

Falls Ordnernamen ohne Leerzeichen bevorzugt werden, duerfen fuer Dateisystem und Skripte auch diese technischen Namen verwendet werden:

```text
ashtray
cigarette
cigarette_pack
people_smoking
smoke
negative
```

Die fachlichen Labels bleiben trotzdem:

```text
ashtray
cigarette
cigarette pack
people smoking
smoke
negative
```

### Label-Reihenfolge

Die Label-Reihenfolge ist fest und muss in Training, Modell-Metadaten, Android-Code und Auswertung identisch sein:

```text
0 ashtray
1 cigarette
2 cigarette pack
3 people smoking
4 smoke
5 negative
```

Die Datei `labels.txt` soll exakt diese Reihenfolge enthalten:

```text
ashtray
cigarette
cigarette pack
people smoking
smoke
negative
```

---

## 3. Datenaufteilung

Es darf nicht mit demselben Bildmaterial trainiert und in der App evaluiert werden.

Empfohlene Aufteilung:

```text
70 % Training
15 % Validation
15 % Test
```

Vorgehen:

1. Ein Python-Skript erzeugt einmalig einen stratifizierten Split pro Klasse.
2. Der Split wird als `dataset_split.json` persistiert.
3. Der Testsplit wird fuer den In-App-Benchmark exportiert.
4. Der Trainings- und Validierungssplit wird nicht in die App eingebunden.

Beispiel:

```json
{
  "version": 1,
  "labels": ["ashtray", "cigarette", "cigarette pack", "people smoking", "smoke", "negative"],
  "split_seed": 20260705,
  "train": [
    {"file": "ashtray/img_0001.jpg", "label": "ashtray"}
  ],
  "validation": [],
  "test": []
}
```

Fuer die App wird daraus ein kleineres Manifest erzeugt:

```json
[
  {"asset_path": "evalset/ashtray/img_0001.jpg", "label": "ashtray"},
  {"asset_path": "evalset/negative/img_0002.jpg", "label": "negative"}
]
```

---

## 4. Trainingsartefakte

Empfohlene Repository-Struktur:

```text
AI_PoC/
  app/
    src/
      main/
        assets/
          models/
            mobilenetv3small_cuelens_int8.tflite
            efficientnet_lite0_cuelens_int8.tflite
          labels.txt
      benchmark/
        assets/
          eval_manifest.json
          evalset/
            ashtray/
            cigarette/
            cigarette pack/
            people smoking/
            smoke/
            negative/
training/
  image_models/
    train_mobilenetv3small.py
    train_efficientnet_lite0.py
    split_dataset.py
    export_eval_assets.py
    requirements.txt
    README.md
```

`benchmark` sollte als eigener Source Set oder Build Variant genutzt werden, damit die Testbilder nicht versehentlich in die produktive App gelangen.

---

## 5. Modellvarianten

### 5.1 ML Kit Image Labeling Baseline

Zweck: technische Baseline ohne eigenes Training.

Eigenschaften:

- nutzt das allgemeine ML-Kit-Image-Labeling-Modell,
- liefert keine CueLens-spezifischen sechs Klassen,
- muss deshalb ueber eine Mapping-Funktion auf die sechs Zielklassen abgebildet werden,
- dient nur als Vergleich, nicht als bevorzugtes Studienmodell.

Vorgeschlagenes Mapping:

```kotlin
private val mlKitKeywordMap = mapOf(
    "ashtray" to "ashtray",
    "cigarette" to "cigarette",
    "cigar" to "cigarette",
    "tobacco" to "cigarette pack",
    "smoking" to "people smoking",
    "smoke" to "smoke"
)
```

Entscheidungsregel:

- alle ML-Kit-Labels werden normalisiert (`lowercase`, trim),
- das erste passende Label oberhalb `threshold` bestimmt die CueLens-Klasse,
- wenn kein Mapping greift, wird `negative` vorhergesagt.

Damit wird die ML-Kit-Baseline bewusst konservativ ausgewertet. Ihre geringe Spezifitaet oder Sensitivitaet ist als erwartbares Ergebnis dokumentierbar, weil das Basismodell nicht fuer Rauchreize trainiert wurde.

### 5.2 MobileNetV3Small, transfer learned

Zweck: leichtgewichtiges On-Device-Modell fuer Android-Geraete mit begrenzten Ressourcen.

Empfohlene Architektur:

```text
Input: 224 x 224 x 3 RGB
Backbone: MobileNetV3Small, ImageNet-Initialisierung, include_top=false
Pooling: GlobalAveragePooling2D
Dropout: 0.2
Dense: 6 Klassen, Softmax
Export: int8 oder float16 TFLite/LiteRT
```

Training:

1. Backbone zunaechst einfrieren.
2. Klassifikationskopf trainieren.
3. Optional letzte Backbone-Bloecke mit kleiner Lernrate feinjustieren.
4. Validation Loss fuer Early Stopping verwenden.
5. Modell auf Testsplit evaluieren.
6. Nach Export nochmals das `.tflite`-Modell evaluieren, nicht nur das Keras-Modell.

### 5.3 EfficientNet-Lite0, transfer learned

Zweck: Vergleichsmodell mit voraussichtlich hoeherer Klassifikationsguete bei weiterhin mobiler Modellgroesse.

Empfohlene Architektur:

```text
Input: 224 x 224 x 3 RGB
Backbone: EfficientNet-Lite0 Feature Vector
Pooling: im Feature Vector enthalten oder GlobalAveragePooling2D
Dropout: 0.2
Dense: 6 Klassen, Softmax
Export: int8 oder float16 TFLite/LiteRT
```

Training:

- bevorzugt in derselben Python-Pipeline wie MobileNetV3Small,
- gleiche Splits,
- gleiche Augmentationen,
- gleiche Metriken,
- gleiche Label-Reihenfolge,
- gleicher Android-Inferenzadapter.

---

## 6. Android-Modellabstraktion

Die App soll alle Modelle ueber dieselbe Schnittstelle ansprechen. Dadurch kann das aktive Modell durch eine einzige Konfiguration gewechselt werden.

### 6.1 Gemeinsames Ergebnisformat

```kotlin
data class ModelPrediction(
    val modelId: String,
    val predictedLabel: String,
    val scores: Map<String, Float>,
    val latencyMs: Long
)
```

### 6.2 Gemeinsames Backend-Interface

```kotlin
interface ImageModelBackend : AutoCloseable {
    val modelId: String
    suspend fun classify(bitmap: Bitmap): ModelPrediction
}
```

### 6.3 Modellkonfiguration

Eine zentrale Datei `AiModelConfig.kt` soll den Modellaustausch so einfach wie moeglich machen:

```kotlin
object AiModelConfig {
    val activeModel: ModelSpec = Models.MOBILE_NET_V3_SMALL
    // val activeModel: ModelSpec = Models.EFFICIENT_NET_LITE0
    // val activeModel: ModelSpec = Models.ML_KIT_IMAGE_LABELING_BASELINE

    val benchmarkModels: List<ModelSpec> = listOf(
        Models.ML_KIT_IMAGE_LABELING_BASELINE,
        Models.MOBILE_NET_V3_SMALL,
        Models.EFFICIENT_NET_LITE0
    )
}
```

`activeModel` wird fuer die normale UI verwendet. `benchmarkModels` wird fuer den Benchmark-Modus verwendet, wenn alle Modelle nacheinander auf demselben Testset laufen sollen.

### 6.4 ModelSpec

```kotlin
data class ModelSpec(
    val id: String,
    val backend: BackendType,
    val assetModelPath: String? = null,
    val inputWidth: Int = 224,
    val inputHeight: Int = 224,
    val labelsAssetPath: String = "labels.txt",
    val threshold: Float = 0.5f
)

enum class BackendType {
    ML_KIT_BASELINE,
    LITERT_CLASSIFIER
}

object Models {
    val ML_KIT_IMAGE_LABELING_BASELINE = ModelSpec(
        id = "mlkit_image_labeling_baseline",
        backend = BackendType.ML_KIT_BASELINE,
        threshold = 0.5f
    )

    val MOBILE_NET_V3_SMALL = ModelSpec(
        id = "mobilenetv3small_transfer_int8",
        backend = BackendType.LITERT_CLASSIFIER,
        assetModelPath = "models/mobilenetv3small_cuelens_int8.tflite",
        inputWidth = 224,
        inputHeight = 224,
        threshold = 0.5f
    )

    val EFFICIENT_NET_LITE0 = ModelSpec(
        id = "efficientnet_lite0_transfer_int8",
        backend = BackendType.LITERT_CLASSIFIER,
        assetModelPath = "models/efficientnet_lite0_cuelens_int8.tflite",
        inputWidth = 224,
        inputHeight = 224,
        threshold = 0.5f
    )
}
```

### 6.5 Factory

```kotlin
object ImageModelBackendFactory {
    fun create(context: Context, spec: ModelSpec): ImageModelBackend {
        return when (spec.backend) {
            BackendType.ML_KIT_BASELINE -> MlKitBaselineBackend(spec)
            BackendType.LITERT_CLASSIFIER -> LiteRtClassifierBackend(context, spec)
        }
    }
}
```

---

## 7. LiteRT-/TFLite-Inferenzadapter

Der bestehende Proof of Concept nutzt bereits den TensorFlow-Lite-Interpreter und `.tflite`-Assets. Fuer diesen Branch soll daraus ein generischer Klassifikationsadapter entstehen.

### 7.1 Eingabeformat

Fuer beide trainierten Modelle soll gelten:

```text
Input tensor: [1, 224, 224, 3]
Datentyp: float32 oder int8, je nach Export
Farbraum: RGB
Normalisierung: modellabhaengig, aber fuer beide Modelle explizit dokumentiert
Output tensor: [1, 6]
Aktivierung: Softmax
Label-Reihenfolge: labels.txt
```

Die Vorverarbeitung muss zentral implementiert werden:

1. EXIF-Orientierung beruecksichtigen, soweit Bilder aus Datei/URI geladen werden.
2. Bild zentriert quadratisch zuschneiden oder mit Letterboxing skalieren. Fuer den Vergleich muss die Methode fest sein.
3. Resize auf 224 x 224.
4. RGB extrahieren.
5. Normalisierung passend zum Modell anwenden.
6. Tensor befuellen.

Empfehlung fuer den ersten Vergleich: **Center Crop + Resize**. Dadurch ist die Pipeline reproduzierbar und leichter zu dokumentieren als kameraabhaengige Freiform-Crops.

### 7.2 Output-Auswertung

```kotlin
val topIndex = scores.indices.maxBy { scores[it] }
val predictedLabel = labels[topIndex]
```

Fuer Sensitivitaet/Spezifitaet wird zunaechst die Top-1-Klasse verwendet. Optional kann spaeter zusaetzlich eine Schwellenwertlogik eingefuehrt werden:

```kotlin
if (scores[topIndex] < spec.threshold) predictedLabel = "negative"
```

Diese Schwellenwertlogik sollte im Benchmark separat ausgewiesen werden, weil sie Sensitivitaet und Spezifitaet stark beeinflussen kann.

---

## 8. Benchmark-Modus in der App

### 8.1 Ziel

Die App soll auf einem realen Android-Geraet alle Testbilder aus dem Benchmark-Asset-Satz laden, jedes Modell ausfuehren und eine CSV-Datei mit Einzelvorhersagen und aggregierten Metriken erzeugen.

### 8.2 Eingabe

```text
app/src/benchmark/assets/eval_manifest.json
app/src/benchmark/assets/evalset/<class>/*
```

Beispiel `eval_manifest.json`:

```json
[
  {"asset_path": "evalset/ashtray/a_0001.jpg", "label": "ashtray"},
  {"asset_path": "evalset/cigarette/c_0001.jpg", "label": "cigarette"},
  {"asset_path": "evalset/cigarette pack/p_0001.jpg", "label": "cigarette pack"},
  {"asset_path": "evalset/people smoking/ps_0001.jpg", "label": "people smoking"},
  {"asset_path": "evalset/smoke/s_0001.jpg", "label": "smoke"},
  {"asset_path": "evalset/negative/n_0001.jpg", "label": "negative"}
]
```

### 8.3 Einzelresultate

CSV-Spalten fuer Einzelvorhersagen:

```text
run_id,device_manufacturer,device_model,android_version,model_id,image_path,true_label,predicted_label,score_ashtray,score_cigarette,score_cigarette_pack,score_people_smoking,score_smoke,score_negative,latency_ms,correct
```

### 8.4 Aggregierte Metriken

Fuer jede Klasse wird eine One-vs-Rest-Konfusionsmatrix berechnet:

```text
TP_k: true_label == k und predicted_label == k
FN_k: true_label == k und predicted_label != k
FP_k: true_label != k und predicted_label == k
TN_k: true_label != k und predicted_label != k
```

Daraus:

```text
Sensitivity_k = TP_k / (TP_k + FN_k)
Specificity_k = TN_k / (TN_k + FP_k)
Precision_k   = TP_k / (TP_k + FP_k)
F1_k          = 2 * Precision_k * Sensitivity_k / (Precision_k + Sensitivity_k)
```

Zusaetzlich wird eine binaere Rauchreiz-Auswertung berechnet:

```text
positive = {ashtray, cigarette, cigarette pack, people smoking, smoke}
negative = {negative}
```

Damit lassen sich zwei fachlich unterschiedliche Fragen beantworten:

1. Erkennt das Modell irgendeinen Rauchreiz?  
   → binaere Sensitivitaet/Spezifitaet.
2. Erkennt das Modell die konkrete Cue-Klasse?  
   → sechs Klassen, One-vs-Rest-Metriken und Gesamtgenauigkeit.

### 8.5 Aggregierte CSV

```text
run_id,model_id,metric_scope,label,tp,fp,tn,fn,sensitivity,specificity,precision,f1,accuracy,mean_latency_ms,p95_latency_ms,n
```

`metric_scope` ist entweder:

```text
multiclass_one_vs_rest
binary_smoking_cue
```

---

## 9. UI fuer den Benchmark

Im Debug-/Benchmark-Build reicht eine einfache Compose-Oberflaeche:

```text
CueLens AI Benchmark
[Run active model]
[Run all benchmark models]
[Export CSV]

Status:
Model: efficientnet_lite0_transfer_int8
Image: 123 / 750
Mean latency: 18.4 ms
Accuracy: 0.86
Binary sensitivity: 0.91
Binary specificity: 0.94
```

Der Benchmark darf nicht automatisch beim App-Start laufen. Er soll explizit gestartet werden, damit keine langen Rechenlaeufe versehentlich auf Studiengeraeten ausgefuehrt werden.

---

## 10. Gradle-Abhaengigkeiten

Der aktuelle Proof of Concept verwendet bereits TensorFlow Lite. Fuer die Weiterentwicklung sind zwei Wege moeglich:

### Variante A: vorhandenen Interpreter-Ansatz fortfuehren

Minimal-invasiv fuer das bestehende Projekt:

```toml
tensorflow-lite = { group = "org.tensorflow", name = "tensorflow-lite", version = "2.17.0" }
```

### Variante B: auf LiteRT-Paket umstellen

Fuer die eigentliche LiteRT-Nomenklatur und kuenftige Weiterentwicklung:

```toml
litert = { group = "com.google.ai.edge.litert", name = "litert", version = "2.1.0" }
```

Empfehlung fuer diesen Branch:

- Die Modellartefakte werden als `.tflite`/LiteRT exportiert.
- Die Android-Abstraktion wird so geschrieben, dass der Backend-Adapter austauschbar bleibt.
- Falls die neue LiteRT-Dependency im lokalen Projekt sofort stabil baut, wird `LiteRtClassifierBackend` mit dem LiteRT-API umgesetzt.
- Falls nicht, wird zunaechst der vorhandene Interpreter-Ansatz als `LiteRtClassifierBackend` gekapselt, damit die Evaluation nicht blockiert wird.

Fuer ML Kit Baseline:

```toml
mlkit-image-labeling = { group = "com.google.mlkit", name = "image-labeling", version = "17.0.9" }
```

Bei Bedarf fuer ML Kit Custom Models, nicht fuer die Baseline:

```toml
mlkit-image-labeling-custom = { group = "com.google.mlkit", name = "image-labeling-custom", version = "17.0.3" }
```

---

## 11. Python-Training: empfohlener Ablauf

### 11.1 `requirements.txt`

```text
tensorflow==2.17.*
tensorflow-hub
numpy
pandas
scikit-learn
pillow
matplotlib
```

Falls `tflite-model-maker` lokal stabil laeuft, kann es fuer EfficientNet-Lite0 verwendet werden. Fuer reproduzierbare lokale Entwicklung ist aber eine klare Keras/TensorFlow-Pipeline vorzuziehen.

### 11.2 Gemeinsame Trainingsparameter

```text
image_size = 224
batch_size = 32
classes = ["ashtray", "cigarette", "cigarette pack", "people smoking", "smoke", "negative"]
loss = categorical_crossentropy
optimizer = Adam
metrics = accuracy, precision, recall
callbacks = EarlyStopping, ModelCheckpoint
augmentation = random_flip, random_rotation, random_zoom, random_contrast
```

### 11.3 Export

Beide trainierten Modelle muessen folgende Dateien erzeugen:

```text
mobilenetv3small_cuelens_float32.tflite
mobilenetv3small_cuelens_int8.tflite
efficientnet_lite0_cuelens_float32.tflite
efficientnet_lite0_cuelens_int8.tflite
labels.txt
training_report.json
```

`training_report.json` soll enthalten:

```json
{
  "model_id": "mobilenetv3small_transfer_int8",
  "labels": ["ashtray", "cigarette", "cigarette pack", "people smoking", "smoke", "negative"],
  "input_size": [224, 224, 3],
  "split_seed": 20260705,
  "train_count": 0,
  "validation_count": 0,
  "test_count": 0,
  "keras_test_accuracy": null,
  "tflite_test_accuracy": null,
  "notes": "fill during training"
}
```

---

## 12. Android-Implementierungsschritte fuer Codex

### Schritt 1: Klassen und Konfiguration anlegen

Neue Dateien unter:

```text
AI_PoC/app/src/main/java/me/stefanberger/ai_poc/ml/
```

Anlegen:

```text
AiLabels.kt
AiModelConfig.kt
ImageModelBackend.kt
ImageModelBackendFactory.kt
LiteRtClassifierBackend.kt
MlKitBaselineBackend.kt
ModelPrediction.kt
ImagePreprocessor.kt
```

### Schritt 2: bestehende MainActivity entkoppeln

Die aktuelle `MainActivity.kt` enthaelt noch Modelllogik direkt in der Activity. Diese Logik soll in die Backend-Klassen verschoben werden.

Die Activity soll nur noch:

- Bildauswahl,
- Anzeige,
- Aufruf des aktiven Backends,
- Darstellung der Scores,
- Benchmark-Start im Debug-/Benchmark-Build

uebernehmen.

### Schritt 3: Benchmark-Paket anlegen

Neue Dateien:

```text
AI_PoC/app/src/main/java/me/stefanberger/ai_poc/benchmark/
  BenchmarkManifest.kt
  BenchmarkRunner.kt
  ConfusionMatrix.kt
  Metrics.kt
  CsvExporter.kt
```

### Schritt 4: Assets einbinden

Anlegen:

```text
AI_PoC/app/src/main/assets/models/.gitkeep
AI_PoC/app/src/main/assets/labels.txt
AI_PoC/app/src/benchmark/assets/eval_manifest.json
AI_PoC/app/src/benchmark/assets/evalset/.gitkeep
```

Grosse Bilddateien und Modellartefakte sollen nur dann committet werden, wenn Dateigroesse und Lizenzlage geklaert sind. Andernfalls `.gitignore` verwenden und eine lokale Pfadanweisung dokumentieren.

### Schritt 5: Build Variant absichern

Der Benchmark-Code und die Benchmark-Assets duerfen nicht unbeabsichtigt in die Studienversion gelangen. Wenn kein separater Flavor eingerichtet wird, muss zumindest eine klare Debug-Pruefung eingebaut werden:

```kotlin
if (!BuildConfig.DEBUG) {
    error("Benchmark is only available in debug builds.")
}
```

Besser ist ein eigener Flavor:

```kotlin
flavorDimensions += "mode"
productFlavors {
    create("study") {
        dimension = "mode"
    }
    create("benchmark") {
        dimension = "mode"
        applicationIdSuffix = ".benchmark"
        versionNameSuffix = "-benchmark"
    }
}
```

---

## 13. Fehlerquellen und Gegenmassnahmen

| Risiko | Gegenmassnahme |
|---|---|
| Label-Reihenfolge unterscheidet sich zwischen Training und App | `labels.txt` aus Trainingspipeline exportieren und in Android laden |
| Testbilder waren im Training enthalten | persistierter `dataset_split.json`, Hash-basierte Kontrolle |
| Generierte Bilder sind zu homogen | harte Negativbeispiele und separater Smartphone-Praxistest |
| ML Kit Baseline liefert andere Label-Taxonomie | explizite Mapping-Tabelle und konservative Negative-Regel |
| INT8-Modell verliert stark an Genauigkeit | float32 und int8 beide exportieren und vergleichen |
| App-Benchmark verfaelscht Laufzeit durch erstes Laden | Warm-up-Inferenz pro Modell nicht in Latenzstatistik aufnehmen |
| Unterschiedliche Vorverarbeitung pro Modell | zentrale `ImagePreprocessor`-Klasse und dokumentierte Normalisierung |
| Bilder/Modelle landen in Studienversion | eigener `benchmark` Flavor oder Debug-Gate |

---

## 14. Mindestkriterien fuer den Branch

Der Branch gilt als technisch ausreichend, wenn:

1. alle drei Backends ueber dieselbe Schnittstelle aufgerufen werden koennen,
2. `activeModel` durch eine einzelne Konfigurationszeile gewechselt werden kann,
3. MobileNetV3Small und EfficientNet-Lite0 dieselbe Label-Reihenfolge und denselben Output-Typ verwenden,
4. ein Benchmark-Lauf pro Bild Modell-ID, wahres Label, vorhergesagtes Label, Scores und Latenz speichert,
5. Sensitivitaet und Spezifitaet sowohl pro Klasse als auch binaer `Rauchreiz vs. negative` berechnet werden,
6. die Benchmark-Ergebnisse als CSV exportiert werden koennen,
7. der Benchmark nicht in der Release-/Studienversion aktiv ist.

---

## 15. Wissenschaftliche Dokumentation fuer Kapitel 3

Fuer die Masterarbeit sollen aus dem Branch folgende Tabellen/Abbildungen ableitbar sein:

1. Tabelle der Modellvarianten:
   - Modell,
   - Eingabegroesse,
   - Parametrisierung,
   - Quantisierung,
   - Modellgroesse,
   - mittlere Latenz,
   - p95-Latenz.

2. Konfusionsmatrix je Modell.

3. Tabelle mit Sensitivitaet/Spezifitaet:
   - pro Klasse,
   - binaer Rauchreiz vs. negativ.

4. Fehleranalyse:
   - typische False Positives,
   - typische False Negatives,
   - besondere Probleme bei Rauch, Aschenbechern und Gruppenbildern.

5. begruendete Modellentscheidung:
   - nicht nur hoechste Accuracy,
   - sondern Abwaegung aus Sensitivitaet, Spezifitaet, Latenz, Modellgroesse, Stabilitaet und Android-Integrationsaufwand.

---

## 16. Quellenhinweise fuer die Implementierung

- LiteRT Android: https://developers.google.com/edge/litert/android
- ML Kit Image Labeling Baseline: https://developers.google.com/ml-kit/vision/image-labeling/android
- ML Kit Custom Image Labeling: https://developers.google.com/ml-kit/vision/image-labeling/custom-models/android
- LiteRT/Model Maker Image Classification: https://developers.google.com/edge/litert/libraries/modify/image_classification
