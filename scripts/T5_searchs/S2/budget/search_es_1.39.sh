#$DATASET: ""
seeds=(42)
prune_criterion='tra_val_cos1'
cuda_devices=(0)  # Define CUDA devices to use for each seed
master_ports=(12369 11101 11113 11114)  # Define master ports for each seed

epochs=(15 20 5 15 3 4 3)
val_epochs=(1 1 1 1 1 1 1)
prune_epochs=(2 2 1 2 1 1 1)
datasets=(cola mrpc sst2 stsb mnli qnli qqp)
budget=102600

ROOT_PATH=/data/user_name

export TRANSFORMERS_CACHE=${ROOT_PATH}/huggingface_cache/transformers
export HF_HOME=${ROOT_PATH}/huggingface_cache/transformers

for DA in "${!datasets[@]}"
do
  DATASET=${datasets[$DA]}
  epoch=${epochs[$DA]}
  val_epoch=${val_epochs[$DA]}
  prune_epoch=${prune_epochs[$DA]}
  for index in "${!seeds[@]}"
  do
      seed=${seeds[$index]}
      prune_cri=$prune_criterion
      cuda_device=${cuda_devices[$index]}
      master_port=${master_ports[$index]}
      output_dir="/data/user_name/output/NLP/moma/search_es/${DATASET}/${budget}_${seed}/"
      log_file="/data/user_name/output/NLP/moma/search_es/${budget}_${DATASET}_seed${seed}.log"
      CUDA_VISIBLE_DEVICES=$cuda_device torchrun --nproc_per_node 1  --master_port $master_port train.py \
          --model_name_or_path google-t5/t5-large \
          --task_name="${DATASET}" \
          --log_dir=/data/user_name/output/NLP/moma/search_es/logs/ \
          --train_batch_size 32 \
          --valid_batch_size 32 \
          --accum_iter 1 \
          --epochs $epoch \
          --lr 3e-4 \
          --warmup_epochs 1 \
          --val_interval $val_epoch \
          --lora_rank 8 \
          --weight_decay 0.0001 \
          --arch_learning_rate 0.01 \
          --arch_weight_decay 0.0001 \
          --output_dir "$output_dir" \
          --seed $seed \
          --use_search \
          --iter_search \
          --early_stop \
          --use_prefix \
          --use_PA \
          --use_SA \
          --budget_abs $budget \
          --prune_threshold 0.85 \
          --max_prune_step 100 \
          --prune_criterion $prune_cri \
          --prune_begin_epoch $prune_epoch \
          --split_train_data \
          &>> "$log_file" &
  done
  wait
done

epochs=(15 20 5 15 3 4 3)
val_epochs=(2 2 1 2 1 1 1)

for DA in "${!datasets[@]}"
do
  DATASET=${datasets[$DA]}
  epoch=${epochs[$DA]}
  val_epoch=${val_epochs[$DA]}
  for index in "${!seeds[@]}"
  do
      seed=${seeds[$index]}
      cuda_device=${cuda_devices[$index]}
      master_port=${master_ports[$index]}
      resume="/data/user_name/output/NLP/moma/search_es/${DATASET}/${budget}_${seed}/checkpoint.pth"
      output_dir="/data/user_name/output/NLP/moma/retrain_es/${DATASET}/${budget}_${seed}/"
      log_file="/data/user_name/output/NLP/moma/retrain_es/${budget}_${DATASET}_seed${seed}.log"
      CUDA_VISIBLE_DEVICES=$cuda_device torchrun --nproc_per_node 1  --master_port $master_port train.py \
          --model_name_or_path google-t5/t5-large \
          --task_name="${DATASET}" \
          --log_dir=/data/user_name/output/NLP/moma/retrain_es/logs/ \
          --train_batch_size 32 \
          --valid_batch_size 32 \
          --accum_iter 1 \
          --epochs $epoch \
          --lr 3e-4 \
          --min_lr 1e-5 \
          --warmup_epochs 1 \
          --val_interval $val_epoch \
          --lora_rank 8 \
          --weight_decay 0.0001 \
          --output_dir "$output_dir" \
          --seed $seed \
          --use_search \
          --retrain \
          --retrain_all \
          --iter_search \
          --use_PA \
          --use_SA \
          --use_prefix \
          --resume=$resume \
          --early_stop \
          &>> "$log_file" &
  done
  wait
done