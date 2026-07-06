# CueLens image model pipeline

This directory contains the reproducible preparation, split, training and export
steps for the CueLens image-classification branch.

## Fixed data contract

The classifier uses exactly six target labels in this order:

```text
0 ashtray
1 cigarette
2 cigarette pack
3 people smoking
4 smoke
5 negative
```

Technical directory names avoid spaces:

```text
ashtray -> ashtray
cigarette -> cigarette
cigarette_pack -> cigarette pack
people_smoking -> people smoking
smoke -> smoke
negative -> negative
```

`smoke` is restricted to images where smoke is visible without further smoking
key cues such as cigarettes, cigarette packs, ashtrays or smoking people. Images
with multiple visible smoking cues must be assigned to the dominant concrete cue
class, not to `smoke`.

## Operational assumptions

- Source images remain in `images/` at 512 x 512 px.
- Training images are generated in `data/cuelens_images_224/` at 224 x 224 px.
- Each class contributes 500 images to the prepared training dataset.
- `people_smoking` contains 2000 source images; only one persisted random sample
  of 500 files is used for model development.
- `negative` initially contained 159 files and is augmented to 500 files using
  deterministic variants such as horizontal mirroring, zoom/crop, mild rotation
  and brightness/contrast changes.
- The split is stratified per class as 70 % train, 15 % validation and 15 % test.
- The test split is exported only to the Android `benchmark` source set.
- Android inference latency is measured after bitmap decoding and includes model
  preprocessing plus inference. A warm-up inference per model is excluded from
  benchmark statistics.
- The default prediction rule is Top-1 over the six classes. Threshold-based
  remapping to `negative` is kept separate because it changes sensitivity and
  specificity materially.

## EfficientNet-Lite0 source decision

EfficientNet-Lite0 is implemented as a TensorFlow Hub feature-vector backbone:

```text
https://tfhub.dev/tensorflow/efficientnet/lite0/feature-vector/2
```

Rationale:

- It is the current EfficientNet-Lite0 feature-vector URI exposed by the Google
  AI Edge/MediaPipe image-classifier model specification.
- It provides the intended Edge-oriented EfficientNet-Lite architecture rather
  than substituting Keras EfficientNetB0, which is related but not the same model.
- It expects 224 x 224 RGB input and is aligned with later TensorFlow Lite/LiteRT
  export.
- The training code can keep the same CueLens classifier head and output contract
  as the MobileNetV3Small variant.

For both custom models, the exported graph includes the model-specific
normalization layer. Android therefore supplies raw RGB values in the range
0..255 after center crop and resize.

## Commands

Prepare the balanced 224 x 224 dataset:

```bash
training/image_models/prepare_dataset.sh
```

Create the persisted split:

```bash
python3 training/image_models/split_dataset.py
```

Export the Android benchmark assets from the test split:

```bash
python3 training/image_models/export_eval_assets.py
```

Train and export models when TensorFlow dependencies are available:

```bash
python3 training/image_models/train_mobilenetv3small.py
python3 training/image_models/train_efficientnet_lite0.py
```
