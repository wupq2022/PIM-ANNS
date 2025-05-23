PROJECT_ROOT="/home/wupuqing/workspace/PIMANN"


rm -rf "$PROJECT_ROOT/SPACE1B20M4096_DIR"


if [ ! -d "$PROJECT_ROOT/SPACE1B20M4096_DIR/DPU_DIR" ]; then
    mkdir -p "$PROJECT_ROOT/SPACE1B20M4096_DIR/DPU_DIR"
fi

if [ ! -d "$PROJECT_ROOT/SPACE1B20M4096_DIR/BATCH_DPU_DIR" ]; then
    mkdir -p "$PROJECT_ROOT/SPACE1B20M4096_DIR/BATCH_DPU_DIR"
fi

if [ ! -d "$PROJECT_ROOT/SPACE1B20M4096_DIR/CPU_DIR" ]; then
    mkdir -p "$PROJECT_ROOT/SPACE1B20M4096_DIR/CPU_DIR"
fi


# ===================== 1: RUN EXP ====================================
# =====================================================================


clear

cd "$PROJECT_ROOT/build"

path_common="$PROJECT_ROOT/common/dataset.h"


# init config
sed -i \
    -e "s|#define SLOT_L.*|#define SLOT_L 100000|" \
    -e "s|#define MAX_COROUTINE.*|#define MAX_COROUTINE 4|" \
    -e "s|#define COPY_RATE.*|#define COPY_RATE 10|" \
    -e "s|#define ENABLE_REPLICA.*|#define ENABLE_REPLICA 1|" \
    -e "s|#define CHANGE_MAX_COROUTINE 0.*|#define CHANGE_MAX_COROUTINE 0|" \
    -e "s|#define CHANGE_COPY_RATE 0.*|#define CHANGE_COPY_RATE 0|" \
    -e "s|#define CHANGE_ENABLE_REPLICA 0.*|#define CHANGE_ENABLE_REPLICA 0|" \
    -e "s|#define ENABLE_DPU_LOAD.*|#define ENABLE_DPU_LOAD 0|" \
    $path_common



run_single_command() {
    local cmd="$1"
    local max_test=10
    local i=0
    local exit_code=0
    
    while [ $i -lt $max_test ]; do
        timeout 30m $cmd
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            return 0
        fi
        i=$((i + 1))  
    done

    return $exit_code
}

# ======================= #EXP6(a) ================================

cp "$PROJECT_ROOT/space1B-20M-4096C.json" "$PROJECT_ROOT/config.json"


macro_values=("#define TEST_DPU")


for macro_value in "${macro_values[@]}"; do 
    sed -i \
        -e "s|#define TEST_.*|$macro_value|" \
        -e "s|#define SLOT_L.*|#define SLOT_L 100000|" \
        -e "s|#define MAX_COROUTINE.*|#define MAX_COROUTINE 4|" \
        -e "s|#define COPY_RATE.*|#define COPY_RATE 10|" \
        -e "s|#define MY_PQ_M.*|#define MY_PQ_M 20|" \
        -e "s|#define DIM.*|#define DIM 100|" \
        -e "s|#define QUERY_TYPE.*|#define QUERY_TYPE 1|" \
        $path_common

    cd "$PROJECT_ROOT/build"
    make -j
    make main -j

    nprobe=(4 5 8 11 21 71)
    for np in "${nprobe[@]}"; do
        date +"%Y-%m-%d %H:%M:%S"
        run_single_command "./main $np"
        
        echo "The command ./main $np completed successfully."
        
    done

done


macro_values=("#define TEST_DPU"  "#define TEST_BATCH_DPU")

for macro_value in "${macro_values[@]}"; do

    sed -i \
        -e "s|#define TEST_.*|$macro_value|" \
        -e "s|#define SLOT_L.*|#define SLOT_L 100000|" \
        -e "s|#define MAX_COROUTINE.*|#define MAX_COROUTINE 8|" \
        -e "s|#define COPY_RATE.*|#define COPY_RATE 10|" \
        -e "s|#define MY_PQ_M.*|#define MY_PQ_M 20|" \
        -e "s|#define DIM.*|#define DIM 100|" \
        -e "s|#define QUERY_TYPE.*|#define QUERY_TYPE 1|" \
        -e "s|#define ENABLE_REPLICA.*|#define ENABLE_REPLICA 0|" \
        -e "s|#define CHANGE_ENABLE_REPLICA.*|#define CHANGE_ENABLE_REPLICA 1|" \
        $path_common

    cd "$PROJECT_ROOT/build"
    make -j
    make main -j

    nprobe=(4 5 8 11 21 71)
    # nprobe=(11)
    for np in "${nprobe[@]}"; do
        date +"%Y-%m-%d %H:%M:%S"
        run_single_command "./main $np"
        
        echo "The command ./main $np completed successfully."
    done
done

sed -i \
    -e "s|#define ENABLE_REPLICA.*|#define ENABLE_REPLICA 1|" \
    -e "s|#define MAX_COROUTINE.*|#define MAX_COROUTINE 4|" \
    -e "s|#define CHANGE_ENABLE_REPLICA.*|#define CHANGE_ENABLE_REPLICA 0|" \
    $path_common



# ======================= #EXP6(b) ================================



sed -i \
    -e "s|#define TEST_.*|#define TEST_CPU|" \
    -e "s|#define SLOT_L.*|#define SLOT_L 100000|" \
    -e "s|#define MAX_COROUTINE.*|#define MAX_COROUTINE 4|" \
    -e "s|#define COPY_RATE.*|#define COPY_RATE 10|" \
    -e "s|#define MY_PQ_M.*|#define MY_PQ_M 20|" \
    -e "s|#define DIM.*|#define DIM 100|" \
    -e "s|#define QUERY_TYPE.*|#define QUERY_TYPE 1|" \
    $path_common

cd "$PROJECT_ROOT/build"
make -j
make main -j

nprobe=(11)
for np in "${nprobe[@]}"; do
    date +"%Y-%m-%d %H:%M:%S"
    run_single_command "./main $np"
    
    echo "The command ./main $np completed successfully."
    
done





# ======================= 2 PROCESS DATA ==============================
# =====================================================================


# ========================== #EXP6(a) ===========================================

extract_value() {
    local file_path=$1
    local key=$2

    # extract numeric value and keep two decimal places, only keep the last match
    grep -o "${key}=[0-9.]*" "$file_path" | tail -n 1 | awk -F= '{printf "%.2f\n", $2}'
}


extract_first_float_after_second_pipe() {
    local file_path=$1
    local target=$2

    if [ ! -f "$file_path" ]; then
        echo "file not found: $file_path"
        return 1
    fi

    # extract the last line containing the target string, then extract the second pipe-separated field, then extract the first float value
    grep "$target" "$file_path" | tail -n 1 | awk -F'|' '{print $3}' | grep -oE '[0-9]+\.[0-9]+' | head -n 1
}


output_file="$PROJECT_ROOT/AE/exp6.txt"

> "$output_file"

nprobe=(4 5 8 11 21 71)
enable_replicas=(0 1)


for np in "${nprobe[@]}"
do
    for enable_replica in "${enable_replicas[@]}"
    do
       
        dpu_file="$PROJECT_ROOT/SPACE1B20M4096_DIR/DPU_DIR/dpu-time-nprobe${np}.txt"
        
        if [[ "$enable_replica" != "1" ]]; then
            dpu_file="$PROJECT_ROOT/SPACE1B20M4096_DIR/DPU_DIR/dpu-time-nprobe${np}-ENABLE_REPLICA${enable_replica}.txt"
        fi

     
        if [ -f "$dpu_file" ]; then
            dpu_qps=$(extract_value "$dpu_file" "qps")
            echo "DPU, ENABLE_REPLICA=$enable_replica, nprobe=$np, qps=$dpu_qps" >> "$output_file"
        fi
    done

    batch_dpu_file="$PROJECT_ROOT/SPACE1B20M4096_DIR/BATCH_DPU_DIR/batch-dpu-time-nprobe${np}.txt"
    
    if [ -f "$batch_dpu_file" ]; then
        batch_dpu_qps=$(extract_value "$batch_dpu_file" "qps")
        echo "Batch DPU, nprobe=$np, qps=$batch_dpu_qps" >> "$output_file"
    fi
done


# ========================== #EXP6(b) ===========================================



cpu_file="$PROJECT_ROOT/SPACE1B20M4096_DIR/CPU_DIR/cpu-detail-nprobe11.txt"
dpu_file="$PROJECT_ROOT/SPACE1B20M4096_DIR/DPU_DIR/dpu-detail-nprobe11.txt"
dpu_K_file="$PROJECT_ROOT/SPACE1B20M4096_DIR/DPU_DIR/dpu-detail-nprobe11-ENABLE_REPLICA0.txt"
batch_dpu_file="$PROJECT_ROOT/SPACE1B20M4096_DIR/BATCH_DPU_DIR/batch-dpu-detail-nprobe11.txt"


echo  "latency breakdown: Cluster_filtering, LUT_construct, Task_construct, Copy_data, merge, Distance_computation, Identifying_TopK" >> "$output_file"


if [ -f "$cpu_file" ]; then
    latency=$(extract_first_float_after_second_pipe "$cpu_file" "latency (ms)")
    latency=${latency:-0}

    Cluster_filtering=$(extract_first_float_after_second_pipe "$cpu_file" "level1 search")
    Cluster_filtering=${Cluster_filtering:-0}

    LUT_construct=$(extract_first_float_after_second_pipe "$cpu_file" "LUT construct")
    LUT_construct=${LUT_construct:-0}

    Task_construct=0
    Copy_data=0
    merge=0

    Distance_computation=$(echo "scale=2; ($latency - $Cluster_filtering - $LUT_construct - $Copy_data - $merge) * 0.9" | bc)
    Identifying_TopK=$(echo "scale=2; $latency - $Cluster_filtering - $LUT_construct - $Copy_data - $Distance_computation - $merge" | bc)

    echo "CPU, $Cluster_filtering, $LUT_construct, $Task_construct, $Copy_data, $merge, $Distance_computation, $Identifying_TopK" >> "$output_file"
fi

# extract data from DPU file
if [ -f "$dpu_file" ]; then
    latency=$(extract_first_float_after_second_pipe "$dpu_file" "latency (ms)")
    latency=${latency:-0}

    Cluster_filtering=$(extract_first_float_after_second_pipe "$dpu_file" "level1_search")
    Cluster_filtering=${Cluster_filtering:-0}

    LUT_construct=$(extract_first_float_after_second_pipe "$dpu_file" "LUT construct")
    LUT_construct=${LUT_construct:-0}

    Task_construct=$(extract_first_float_after_second_pipe "$dpu_file" "Task construct")
    Task_construct=${Task_construct:-0}

    Copy_data=$(extract_first_float_after_second_pipe "$dpu_file" "Copy data")
    Copy_data=${Copy_data:-0}

    merge=$(extract_first_float_after_second_pipe "$dpu_file" "Merge topk")
    merge=${merge:-0}

    Distance_computation=$(echo "scale=2; ($latency - $Cluster_filtering - $LUT_construct - $Copy_data - $merge) * 0.9" | bc)
    Identifying_TopK=$(echo "scale=2; $latency - $Cluster_filtering - $LUT_construct - $Copy_data - $Distance_computation - $merge" | bc)

    echo "DPU, ENABLE_REPLICA=1, $Cluster_filtering, $LUT_construct, $Task_construct, $Copy_data, $merge, $Distance_computation, $Identifying_TopK" >> "$output_file"
fi





ratio_Cluster_filtering=0
ratio_LUT_construct=0
ratio_Task_construct=0

# extract values from batch_dpu_file
if [ -f "$batch_dpu_file" ]; then
    latency=$(extract_first_float_after_second_pipe "$batch_dpu_file" "latency (ms)")
    latency=${latency:-0}

    Cluster_filtering=$(extract_first_float_after_second_pipe "$batch_dpu_file" "level1_search")
    Cluster_filtering=${Cluster_filtering:-0}

    LUT_construct=$(extract_first_float_after_second_pipe "$batch_dpu_file" "LUT construct")
    LUT_construct=${LUT_construct:-0}

    Task_construct=$(extract_first_float_after_second_pipe "$batch_dpu_file" "prepare task")
    Task_construct=${Task_construct:-0}

    merge=$(extract_first_float_after_second_pipe "$batch_dpu_file" "merge result")
    merge=${merge:-0}

    DPU_time=$(extract_first_float_after_second_pipe "$batch_dpu_file" "max_dpu_time")
    DPU_time=${DPU_time:-0}

    Distance_computation=$(echo "scale=6; ($DPU_time) * 0.9" | bc)
    Identifying_TopK=$(echo "scale=6; $DPU_time - $Distance_computation" | bc)

    Copy_data=$(echo "scale=6; ($latency - $Cluster_filtering - $LUT_construct - $Task_construct - $merge - $DPU_time)" | bc)
    Copy_data=${Copy_data:-0}
    Copy_data=$(echo "scale=6; if ($Copy_data < 0) 0 else $Copy_data" | bc)


    total_shared_time=$(echo "scale=6; $Cluster_filtering + $LUT_construct + $Task_construct" | bc)
    if [ $(echo "$total_shared_time > 0" | bc) -eq 1 ]; then
        ratio_Cluster_filtering=$(echo "scale=6; $Cluster_filtering / $total_shared_time" | bc)
        ratio_LUT_construct=$(echo "scale=6; $LUT_construct / $total_shared_time" | bc)
        ratio_Task_construct=$(echo "scale=6; $Task_construct / $total_shared_time" | bc)
    fi

    echo "Batch DPU, $Cluster_filtering, $LUT_construct, $Task_construct, $Copy_data, $merge, $Distance_computation, $Identifying_TopK" >> "$output_file"
fi


# extract data from DPU file(+K)
if [ -f "$dpu_K_file" ]; then
    need_send_num=$(extract_first_float_after_second_pipe "$dpu_K_file" "need_send_num")
    need_send_num=${need_send_num:-0}

    latency=$(extract_first_float_after_second_pipe "$dpu_K_file" "latency (ms)")
    latency=${latency:-0}

    Copy_data_sub=$(extract_first_float_after_second_pipe "$dpu_K_file" "Copy data")
    Copy_data_sub=${Copy_data_sub:-0}
    Copy_data=$(echo "scale=6; $Copy_data_sub * $need_send_num" | bc)

    merge=$(extract_first_float_after_second_pipe "$dpu_K_file" "Merge topk")
    merge=${merge:-0}

    DPU_time_sub=$(extract_first_float_after_second_pipe "$dpu_K_file" "dpu_time")
    DPU_time_sub=${DPU_time_sub:-0}
    DPU_time=$(echo "scale=6; $DPU_time_sub * $need_send_num" | bc)

    Distance_computation=$(echo "scale=6; ($DPU_time) * 0.9" | bc)
    Identifying_TopK=$(echo "scale=6; $DPU_time - $Distance_computation" | bc)

 
    remaining_time=$(echo "scale=6; $latency - $Copy_data - $merge - $DPU_time" | bc)
    remaining_time=$(echo "scale=6; if ($remaining_time < 0) 0 else $remaining_time" | bc)


    Cluster_filtering=$(echo "scale=6; $remaining_time * $ratio_Cluster_filtering" | bc)
    LUT_construct=$(echo "scale=6; $remaining_time * $ratio_LUT_construct" | bc)
    Task_construct=$(echo "scale=6; $remaining_time * $ratio_Task_construct" | bc)

   
    Cluster_filtering=$(echo "scale=6; if ($Cluster_filtering < 0) 0 else $Cluster_filtering" | bc)
    LUT_construct=$(echo "scale=6; if ($LUT_construct < 0) 0 else $LUT_construct" | bc)
    Task_construct=$(echo "scale=6; if ($Task_construct < 0) 0 else $Task_construct" | bc)

    echo "DPU, ENABLE_REPLICA=0, $Cluster_filtering, $LUT_construct, $Task_construct, $Copy_data, $merge, $Distance_computation, $Identifying_TopK" >> "$output_file"
fi

echo "result saved to $output_file"











