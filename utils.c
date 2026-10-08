#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

enum { CUBIES = 7, PERMUTATIONS = 5040, ORIENTATIONS = 729, STATES = PERMUTATIONS * ORIENTATIONS, MOVES = 9 };

typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

static const uint8_t source[3][CUBIES] = {
    {1, 4, 2, 0, 3, 5, 6},
    {0, 1, 2, 4, 5, 6, 3},
    {0, 2, 5, 3, 1, 4, 6},
};
static const uint8_t twist[3][CUBIES] = {
    {1, 2, 0, 2, 1, 0, 0},
    {0, 0, 0, 1, 2, 1, 2},
    {0, 0, 0, 0, 0, 0, 0},
};

static const uint8_t o_plus_twist_mod3[5] = {0, 1, 2, 0, 1};

// The three quarter-turns preserve the fixed front-upper-left corner.
static state_t quarter_turn(state_t state, uint8_t face)
{
    state_t result;
    for (uint8_t i = 0; i < CUBIES; i++) {
        uint8_t from = source[face][i];
        result.p[i] = state.p[from];
        // state.o + twist: min 0 + 0 = 0, max 2 + 2 = 4
        result.o[i] = o_plus_twist_mod3[state.o[from] + twist[face][i]];
    }
    return result;
}

static uint32_t rank_state(const state_t *state)
{
    uint32_t p = 0, o = 0;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        uint8_t smaller = 0;
        for (uint8_t j = (uint8_t) (i + 1U); j < CUBIES; ++j)
            if (state->p[j] < state->p[i])
                ++smaller;
        p = p * (CUBIES - i) + smaller;
    }

    for (uint8_t i = 0; i < 6; ++i)
        o = o * 3U + state->o[i];
    return p * ORIENTATIONS + o;
}

static void unrank_state(uint32_t rank, state_t *state)
{
    uint8_t available[CUBIES] = {0, 1, 2, 3, 4, 5, 6};
    uint32_t p = rank / ORIENTATIONS, o = rank % ORIENTATIONS, f = 720;
    uint8_t sum = 0;
    for (uint8_t i = 0; i < CUBIES; ++i) {
        uint8_t q = (uint8_t) (p / f);
        p %= f;
        state->p[i] = available[q];
        for (uint8_t j = q; j + 1 < CUBIES - i; ++j)
            available[j] = available[j + 1U];
        if (i < 5)
            f /= 6U - i;
    }
    for (uint8_t i = 6; i-- > 0;) {
        state->o[i] = (uint8_t) (o % 3U);
        sum = (uint8_t) (sum + state->o[i]);
        o /= 3U;
    }
    state->o[6] = (uint8_t) ((3U - sum % 3U) % 3U);
}

int main(void)
{
    uint16_t permutation[3][PERMUTATIONS], orientation[3][ORIENTATIONS];
    state_t state;
    for (uint16_t rank = 0; rank < PERMUTATIONS; ++rank) {
        unrank_state((uint32_t) rank * ORIENTATIONS, &state);
        for (uint8_t face = 0; face < 3; ++face) {
            state_t next = quarter_turn(state, face);
            permutation[face][rank] = (uint16_t) (rank_state(&next) / ORIENTATIONS);
        }
    }
    for (uint16_t rank = 0; rank < ORIENTATIONS; ++rank) {
        unrank_state(rank, &state);
        for (uint8_t face = 0; face < 3; ++face) {
            state_t next = quarter_turn(state, face);
            orientation[face][rank] = (uint16_t) (rank_state(&next) % ORIENTATIONS);
        }
    }

    /*
    heuristics for IDA*
    h_p[r] stores how many moves for rank_p==r to restore to rank_p==0 (solved state)
    */
    uint8_t h_p[PERMUTATIONS], h_o[ORIENTATIONS];
    memset(h_p, 0xFF, sizeof(h_p));
    memset(h_o, 0xFF, sizeof(h_o));
    h_p[0] = 0;
    h_o[0] = 0;

    uint8_t depth = 0;
    uint16_t visited_p = 1;
    while (visited_p < PERMUTATIONS) {
        // a single BFS level
        for (uint16_t rank_p = 0; rank_p < PERMUTATIONS; rank_p++) {
            if (h_p[rank_p] == depth) {
                for (uint8_t face = 0; face <= 2; face++) {
                    uint16_t next_rank_p = rank_p;

                    for (uint8_t turn = 0; turn <= 2; turn++) {
                        next_rank_p = permutation[face][next_rank_p];

                        if (h_p[next_rank_p] == 0xFF) {  // unvisited
                            h_p[next_rank_p] = depth + 1;
                            visited_p++;
                        }
                    }
                }
            }
        }
        depth++;
    }

    depth = 0;
    uint16_t visited_o = 1;
    while (visited_o < ORIENTATIONS) {
        // a single BFS level
        for (uint16_t rank_o = 0; rank_o < ORIENTATIONS; rank_o++) {
            if (h_o[rank_o] == depth) {
                for (uint8_t face = 0; face <= 2; face++) {
                    uint16_t next_rank_o = rank_o;

                    for (uint8_t turn = 0; turn <= 2; turn++) {
                        next_rank_o = orientation[face][next_rank_o];

                        if (h_o[next_rank_o] == 0xFF) {  // unvisited
                            h_o[next_rank_o] = depth + 1;
                            visited_o++;
                        }
                    }
                }
            }
        }
        depth++;
    }

    FILE *fptr = fopen("lut.h", "w");

    if (!fptr) {
        fprintf(stderr, "Failed to open file lut.h\n");
        return 1;
    }

    fprintf(fptr,
            "#ifndef LUT_H\n"
            "#define LUT_H\n"
            "#include <stdint.h>\n\n");

    fprintf(fptr, "static const uint16_t next_rank_p[3][5040] = {");
    for (size_t face = 0; face <= 2; face++) {
        fprintf(fptr, "{");
        for (size_t r = 0; r < PERMUTATIONS; r++) {
            fprintf(fptr, "%d", permutation[face][r]);
            if (r < PERMUTATIONS - 1)
                fprintf(fptr, ", ");
        }
        fprintf(fptr, "}");
        if (face < 2)
            fprintf(fptr, ", ");
    }
    fprintf(fptr, "};\n");

    fprintf(fptr, "static const uint16_t next_rank_o[3][729] = {");
    for (size_t face = 0; face <= 2; face++) {
        fprintf(fptr, "{");
        for (size_t r = 0; r < ORIENTATIONS; r++) {
            fprintf(fptr, "%d", orientation[face][r]);
            if (r < ORIENTATIONS - 1)
                fprintf(fptr, ", ");
        }
        fprintf(fptr, "}");
        if (face < 2)
            fprintf(fptr, ", ");
    }
    fprintf(fptr, "};\n");

    fprintf(fptr, "static const uint8_t h_p[5040] = {");
    for (size_t i = 0; i < PERMUTATIONS; i++) {
        fprintf(fptr, "%d", h_p[i]);

        if (i < PERMUTATIONS - 1)
            fprintf(fptr, ", ");
    }
    fprintf(fptr, "};\n");

    fprintf(fptr, "static const uint8_t h_o[729] = {");
    for (size_t i = 0; i < ORIENTATIONS; i++) {
        fprintf(fptr, "%d", h_o[i]);

        if (i < ORIENTATIONS - 1)
            fprintf(fptr, ", ");
    }
    fprintf(fptr, "};\n");

    fprintf(fptr, "\n#endif\n");
    fclose(fptr);

    fptr = fopen("lut.s", "w");

    if (!fptr) {
        fprintf(stderr, "Failed to open file lut.s\n");
    }

    fprintf(fptr, ".data\n\n");

    fprintf(fptr, ".globl next_rank_p\n");
    fprintf(fptr, ".align 2\n");
    fprintf(fptr, "next_rank_p:\n");
    for (size_t face = 0; face <= 2; face++) {
        fprintf(fptr, "next_rank_p_f%zu:\n", face);  // face sub tag
        for (size_t r = 0; r < PERMUTATIONS; r++) {
            if (r % 16 == 0)
                fprintf(fptr, "    .half ");  // uint16_t
            fprintf(fptr, "%u", permutation[face][r]);
            if (r % 16 == 15 || r == PERMUTATIONS - 1)
                fprintf(fptr, "\n");
            else
                fprintf(fptr, ", ");
        }
    }
    
    fprintf(fptr, "\n");
    fprintf(fptr, ".globl next_rank_o\n");
    fprintf(fptr, ".align 2\n");
    fprintf(fptr, "next_rank_o:\n");
    for (size_t face = 0; face <= 2; face++) {
        fprintf(fptr, "next_rank_o_f%zu:\n", face);  // face sub tag
        for (size_t r = 0; r < ORIENTATIONS; r++) {
            if (r % 16 == 0)
                fprintf(fptr, "    .half ");  // uint16_t
            fprintf(fptr, "%u", orientation[face][r]);
            if (r % 16 == 15 || r == ORIENTATIONS - 1)
                fprintf(fptr, "\n");
            else
                fprintf(fptr, ", ");
        }
    }

    fprintf(fptr, "\n");
    fprintf(fptr, ".globl h_p\n");
    fprintf(fptr, ".align 2\n");
    fprintf(fptr, "h_p:\n");
    for (size_t i = 0; i < PERMUTATIONS; i++) {
        if (i % 16 == 0)
            fprintf(fptr, "    .byte ");  // uint8_t
        fprintf(fptr, "%d", h_p[i]);
        if (i % 16 == 15 || i == PERMUTATIONS - 1)
            fprintf(fptr, "\n");
        else
            fprintf(fptr, ", ");
    }

    fprintf(fptr, "\n");
    fprintf(fptr, ".globl h_o\n");
    fprintf(fptr, ".align 2\n");
    fprintf(fptr, "h_o:\n");
    for (size_t i = 0; i < ORIENTATIONS; i++) {
        if (i % 16 == 0)
            fprintf(fptr, "    .byte ");  // uint8_t
        fprintf(fptr, "%d", h_o[i]);
        if (i % 16 == 15 || i == ORIENTATIONS - 1)
            fprintf(fptr, "\n");
        else
            fprintf(fptr, ", ");
    }

    fclose(fptr);

    return 0;
}