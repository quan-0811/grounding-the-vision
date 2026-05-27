#!/usr/bin/env bash
set -e

# ====== EDIT THESE 3 PATHS ======
THRONE_DIR="evaluation/THRONE"
COCO_FILE="data/coco2017/annotations/instances_val2017.json"
RESPONSE_FILE="evaluation/THRONE/responses.json"

# ====== OUTPUT FOLDER ======
OUT_DIR="evaluation/THRONE/throne_eval"
EVAL_DIR="$OUT_DIR/evaluations"
COMBINED_DIR="$EVAL_DIR/combined"

mkdir -p "$EVAL_DIR"
mkdir -p "$COMBINED_DIR"

cd "$THRONE_DIR"

# ====== STEP 2: RUN QA EVALUATORS ======
for EVALUATOR in google/flan-t5-base google/flan-t5-large google/flan-t5-xl
do
  SAFE_NAME="${EVALUATOR//\//_}"

  echo "Running evaluator: $EVALUATOR"

  torchrun --standalone --nproc_per_node 1 throne_aqa_evaluation.py \
    --coco_file "../$COCO_FILE" \
    --response_file "../$RESPONSE_FILE" \
    --evaluator_model_path "$EVALUATOR" \
    --per_device_batch_size 32 \
    --save_path "../$EVAL_DIR/evaluations.json"

  # Single-process mode does not auto-create combined/
  cp "../$EVAL_DIR/evaluations_${SAFE_NAME}.json" \
     "../$COMBINED_DIR/evaluations_${SAFE_NAME}.json"
done

# ====== STEP 3: SCORE ======
echo "Scoring micro metrics..."

python throne_score_aqa.py \
  --coco_val_ann_path "../$COCO_FILE" \
  --model_eval_path "../$COMBINED_DIR" \
  --thresholds 5 8 9 \
  --metric_strategy micro

echo "Scoring classwise metrics..."

python throne_score_aqa.py \
  --coco_val_ann_path "../$COCO_FILE" \
  --model_eval_path "../$COMBINED_DIR" \
  --thresholds 5 8 9 \
  --metric_strategy class