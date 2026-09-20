#!/usr/bin/env bash

root=$(cd -- "$(dirname -- "$0")" && pwd)
src="$root/../cuelens/app/src/main/res/drawable"
dst="$root/cue-composites"
# App-Layout: 24 + 140 + 64 + 140 + 24 dp Referenzbreite.
width_dp=392
scale=100%

order=({0..49})
for ((n=49; n>0; n--)); do
    j=$((RANDOM % (n + 1)))
    tmp=${order[n]}
    order[n]=${order[j]}
    order[j]=$tmp
done

mkdir -p "$dst"
for ((n=0; n<50; n++)); do
    printf -v id '%03d' "$n"
    printf -v out '%03d' "${order[n]}"
    sides=(a b)
    if ((RANDOM % 2)); then sides=(b a); fi
    w=$(magick identify -ping -format '%w' "$src/cue_$id.png")
    box_w=$((w * 140 / width_dp))
    box_h=$((w * 120 / width_dp))
    gap=$((w * 64 / width_dp))
    edge=$(((w - 2 * box_w - gap) / 2))
    bottom=$((w * 32 / width_dp))

    magick "$src/cue_$id.png" \
        \( "$src/match_${sides[0]}_$id.png" -resize "${box_w}x${box_h}" \
           -background none -gravity center -extent "${box_w}x${box_h}" \) \
        -gravity southwest -geometry "+${edge}+${bottom}" -composite \
        \( "$src/match_${sides[1]}_$id.png" -resize "${box_w}x${box_h}" \
           -background none -gravity center -extent "${box_w}x${box_h}" \) \
        -gravity southeast -geometry "+${edge}+${bottom}" -composite \
        -resize "$scale" "$dst/cue_$out.png"
done
