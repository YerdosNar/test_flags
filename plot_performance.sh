#!/usr/bin/env bash

# --- Configuration ---
C_FILE="matrix_bench_plot.c"
EXECUTABLE="matrix_bench_plot"
DATA_FILE="performance_data.csv"
GRAPH_FILE="performance_graph.png"

# Array of matrix sizes to test (X-axis)
# Starts small and increases. Add more/larger values for a more detailed graph.
declare -a SIZES=(200 400 600 800 1000 1200 1400 1600 1800 2000)

# Array of optimization flags to test (the different lines on the graph)
declare -a FLAGS=(
    "-O0"
    "-O1"
    "-O2"
    "-O3"
    "-O3 -ffast-math"
    "-Ofast"
)

# --- Script Start ---
echo "🚀 Starting performance data generation for gnuplot..."

# Clean up old files
rm -f "$EXECUTABLE" "$DATA_FILE" "$GRAPH_FILE"

# --- Create CSV Header ---
# Sanitize flags for use as column headers (e.g., "-O3 -ffast-math" -> "O3-ffast-math")
HEADER="Size"
for flag in "${FLAGS[@]}"; do
    sanitized_flag=$(echo "$flag" | sed 's/ /-/g' | sed 's/^-//')
    HEADER="$HEADER,$sanitized_flag"
done
echo "$HEADER" > "$DATA_FILE"

# --- Data Generation Loop ---
for size in "${SIZES[@]}"; do
    echo "Benchmarking matrix size: $size x $size..."
    
    # Start the CSV line with the current matrix size
    DATA_LINE="$size"

    for flag in "${FLAGS[@]}"; do
        # Compile the C code with the current flag
        gcc -o "$EXECUTABLE" "$C_FILE" -Wall $flag
        
        if [ $? -eq 0 ]; then
            # Run the compiled program and capture the time
            TIME_TAKEN=$(./"$EXECUTABLE" "$size")
            # Append the result to our CSV line
            DATA_LINE="$DATA_LINE,$TIME_TAKEN"
        else
            echo "Compilation failed for flag: $flag"
            DATA_LINE="$DATA_LINE,0" # Add 0 for failed compilations
        fi
    done
    
    # Write the completed line of data to our CSV file
    echo "$DATA_LINE" >> "$DATA_FILE"
done

echo "✅ Data generation complete. CSV file is '$DATA_FILE'."
rm -f "$EXECUTABLE" # Clean up the last compiled executable

# --- Gnuplot Graph Generation ---
echo "📈 Generating graph with gnuplot..."

gnuplot --persist <<- EOF
    set terminal pngcairo size 1024,768 enhanced font 'Verdana,10'
    set output '$GRAPH_FILE'
    
    set title "Matrix Multiplication Performance by GCC Optimization Flag"
    set xlabel "Matrix Size (N x N)"
    set ylabel "Execution Time (seconds)"
    
    set key top left
    set grid
    set datafile separator ","

    plot for [i=2:7] '$DATA_FILE' using 1:i with linespoints title columnheader(i)
EOF

if [ $? -eq 0 ]; then
    echo "🎉 Success! Graph saved as '$GRAPH_FILE'."
else
    echo "⚠️ Gnuplot error. Please ensure gnuplot is installed."
fi
