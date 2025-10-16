#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define ROWS 100
#define COLS 100

// A simple struct to hold matrix data and dimensions
typedef struct {
    double **data;
    int rows;
    int cols;
} Matrix;

// Allocates memory for a matrix
Matrix create_matrix() {
    Matrix m;
    m.rows = ROWS;
    m.cols = COLS;
    m.data = (double **)malloc(ROWS * sizeof(double *));
    if (m.data == NULL) {
        perror("Failed to allocate memory for matrix rows");
        exit(EXIT_FAILURE);
    }
    for (int i = 0; i < ROWS; i++) {
        m.data[i] = (double *)malloc(COLS * sizeof(double));
        if (m.data[i] == NULL) {
            perror("Failed to allocate memory for matrix columns");
            exit(EXIT_FAILURE);
        }
    }
    return m;
}

// Frees the memory used by a matrix
void free_matrix(Matrix m) {
    if (m.data == NULL) return;
    for (int i = 0; i < m.rows; i++) {
        free(m.data[i]);
    }
    free(m.data);
}

// Fills a matrix with random double values between 0.0 and 1.0
void init_matrix_rand(Matrix m) {
    for (int i = 0; i < m.rows; i++) {
        for (int j = 0; j < m.cols; j++) {
            m.data[i][j] = (double)rand() / (double)RAND_MAX;
        }
    }
}

// The core function to be benchmarked
Matrix multiply(Matrix a, Matrix b) {
    if (a.cols != b.rows) {
        fprintf(stderr, "Matrix dimension mismatch for multiplication.\n");
        exit(EXIT_FAILURE);
    }

    Matrix c = create_matrix();
    for (int i = 0; i < a.rows; i++) {
        for (int j = 0; j < b.cols; j++) {
            c.data[i][j] = 0.0; // Initialize element to zero
            for (int k = 0; k < a.cols; k++) {
                c.data[i][j] += a.data[i][k] * b.data[k][j];
            }
        }
    }
    return c;
}

int main() {
    srand(time(NULL));

    // Create and initialize matrices
    Matrix A = create_matrix();
    Matrix B = create_matrix();
    init_matrix_rand(A);
    init_matrix_rand(B);

    // --- Timing Start ---
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    Matrix C = multiply(A, B);

    clock_gettime(CLOCK_MONOTONIC, &end);
    // --- Timing End ---

    // Calculate elapsed time in seconds
    double time_spent = (end.tv_sec - start.tv_sec) +
                        (end.tv_nsec - start.tv_nsec) / 1e9;

    printf("Execution time: %-4.5f seconds\n", time_spent);

    // Cleanup
    free_matrix(A);
    free_matrix(B);
    free_matrix(C);

    return 0;
}
