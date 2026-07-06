#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RAW_DIR="${ROOT_DIR}/images"
OUT_DIR="${ROOT_DIR}/data/cuelens_images_224"
SELECTED_PEOPLE="${ROOT_DIR}/training/image_models/selected_people_smoking_500.txt"
AUG_MANIFEST="${ROOT_DIR}/training/image_models/negative_augmentation_manifest.csv"
TARGET_SIZE=224
RAW_SIZE=512
TARGET_PER_CLASS=500

classes=(
  "ashtray"
  "cigarette"
  "cigarette_pack"
  "people_smoking"
  "smoke"
  "negative"
)

require_dir() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    printf 'Missing directory: %s\n' "${dir}" >&2
    exit 1
  fi
}

count_files() {
  find "$1" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l
}

require_dir "${RAW_DIR}"
for class_name in "${classes[@]}"; do
  require_dir "${RAW_DIR}/${class_name}"
done

negative_dir="${RAW_DIR}/negative"
negative_count="$(count_files "${negative_dir}")"
if (( negative_count < TARGET_PER_CLASS )); then
  mkdir -p "$(dirname "${AUG_MANIFEST}")"
  if [[ ! -f "${AUG_MANIFEST}" ]]; then
    printf 'generated_file,source_file,variant\n' > "${AUG_MANIFEST}"
  fi

  mapfile -t negative_sources < <(
    find "${negative_dir}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
  )

  if (( ${#negative_sources[@]} == 0 )); then
    printf 'No negative source images found.\n' >&2
    exit 1
  fi

  needed=$((TARGET_PER_CLASS - negative_count))
  for ((i = 0; i < needed; i++)); do
    source_index=$((i % ${#negative_sources[@]}))
    source_file="${negative_sources[$source_index]}"
    generated_file="${negative_dir}/negative_aug_$(printf '%04d' "$((negative_count + i))").png"
    variant_index=$((i % 4))

    case "${variant_index}" in
      0)
        variant="flop"
        convert "${source_file}" -auto-orient -flop -resize "${RAW_SIZE}x${RAW_SIZE}^" -gravity center -extent "${RAW_SIZE}x${RAW_SIZE}" "${generated_file}"
        ;;
      1)
        variant="zoom_crop"
        convert "${source_file}" -auto-orient -resize 600x600^ -gravity center -crop "${RAW_SIZE}x${RAW_SIZE}+0+0" +repage "${generated_file}"
        ;;
      2)
        variant="rotate_crop"
        convert "${source_file}" -auto-orient -virtual-pixel edge -distort SRT 4 -resize "${RAW_SIZE}x${RAW_SIZE}^" -gravity center -extent "${RAW_SIZE}x${RAW_SIZE}" "${generated_file}"
        ;;
      *)
        variant="contrast"
        convert "${source_file}" -auto-orient -brightness-contrast 4x6 -resize "${RAW_SIZE}x${RAW_SIZE}^" -gravity center -extent "${RAW_SIZE}x${RAW_SIZE}" "${generated_file}"
        ;;
    esac

    printf '%s,%s,%s\n' "${generated_file#${ROOT_DIR}/}" "${source_file#${ROOT_DIR}/}" "${variant}" >> "${AUG_MANIFEST}"
  done
fi

if [[ ! -f "${SELECTED_PEOPLE}" ]] || [[ "$(wc -l < "${SELECTED_PEOPLE}")" -ne "${TARGET_PER_CLASS}" ]]; then
  find "${RAW_DIR}/people_smoking" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort \
    | shuf -n "${TARGET_PER_CLASS}" \
    | sed "s#^${ROOT_DIR}/##" > "${SELECTED_PEOPLE}"
fi

mkdir -p "${OUT_DIR}"
for class_name in "${classes[@]}"; do
  mkdir -p "${OUT_DIR}/${class_name}"
done

resize_one() {
  local source_file="$1"
  local destination_file="$2"
  convert "${source_file}" -auto-orient -resize "${TARGET_SIZE}x${TARGET_SIZE}^" -gravity center -extent "${TARGET_SIZE}x${TARGET_SIZE}" "${destination_file}"
}

prepare_class() {
  local class_name="$1"
  local list_file="$2"
  local counter=0

  while IFS= read -r source_file; do
    if [[ -z "${source_file}" ]]; then
      continue
    fi
    if [[ "${source_file}" != /* ]]; then
      source_file="${ROOT_DIR}/${source_file}"
    fi
    destination_file="${OUT_DIR}/${class_name}/${class_name}_$(printf '%04d' "${counter}").png"
    resize_one "${source_file}" "${destination_file}"
    counter=$((counter + 1))
  done < "${list_file}"

  if (( counter != TARGET_PER_CLASS )); then
    printf 'Expected %d files for %s, wrote %d.\n' "${TARGET_PER_CLASS}" "${class_name}" "${counter}" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

for class_name in "ashtray" "cigarette" "cigarette_pack" "smoke" "negative"; do
  find "${RAW_DIR}/${class_name}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort \
    | head -n "${TARGET_PER_CLASS}" > "${tmp_dir}/${class_name}.txt"
  prepare_class "${class_name}" "${tmp_dir}/${class_name}.txt"
done

prepare_class "people_smoking" "${SELECTED_PEOPLE}"

for class_name in "${classes[@]}"; do
  printf '%s %s\n' "$(count_files "${OUT_DIR}/${class_name}")" "${class_name}"
done
