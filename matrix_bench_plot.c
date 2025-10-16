#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// A simple struct to hold matrix data and dimensions
typedef struct {
    double **data;
    int rows;
    int cols;
} Matrix;

// Allocates memory for a matrix
Matrix create_matrix(int rows, int cols) {
    Matrix m;
    m.rows = rows;
    m.cols = cols;
    m.data = (double **)malloc(rows * sizeof(double *));
    if (m.data == NULL) {
        perror("Failed to allocate memory for matrix rows");
        exit(EXIT_FAILURE);
    }
    for (int i = 0; i < rows; i++) {
        m.data[i] = (double *)malloc(cols * sizeof(double));
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

    Matrix c = create_matrix(a.rows, b.cols);
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

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <size>\n", argv[0]);
        return 1;
    }

    int size = atoi(argv[1]);
    srand(time(NULL));

    Matrix A = create_matrix(size, size);
    Matrix B = create_matrix(size, size);
    init_matrix_rand(A);
    init_matrix_rand(B);

    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);

    Matrix C = multiply(A, B);

    clock_gettime(CLOCK_MONOTONIC, &end);

    double time_spent = (end.tv_sec - start.tv_sec) +
                        (end.tv_nsec - start.tv_nsec) / 1e9;

    // MODIFICATION: Print only the raw time for easy script parsing
    printf("%f\n", time_spent);

    free_matrix(A);
    free_matrix(B);
    free_matrix(C);

    return 0;
}
