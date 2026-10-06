#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "data.h"

enum { CUBIES = 7, PERMUTATIONS = 5040, ORIENTATIONS = 729, STATES = PERMUTATIONS * ORIENTATIONS, MOVES = 9 };

// states for cubie 1-7, cubie 0 is fixed and not listed
typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

static const char *const move_names[MOVES] = {"R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'"};
static const uint8_t inverse_move[MOVES] = {2, 1, 0, 5, 4, 3, 8, 7, 6};
/* Each destination takes a cubie from source[face][destination]. */
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

static const uint8_t move_to_face[MOVES] = {0, 0, 0, 1, 1, 1, 2, 2, 2};
static const uint8_t move_mod3[MOVES] = {0, 1, 2, 0, 1, 2, 0, 1, 2};
static const uint8_t o_plus_twist_mod3[5] = {0, 1, 2, 0, 1};
static const uint16_t o_tenary_lut[6][3] = {{0, 243, 486}, {0, 81, 162}, {0, 27, 54}, {0, 9, 18}, {0, 3, 6}, {0, 1, 2}};
static const uint16_t p_fact_lut[7][7] = {
    {0, 720, 1440, 2160, 2880, 3600, 4320},
    {0, 120, 240, 360, 480, 600, 720},
    {0, 24, 48, 72, 96, 120, 144},
    {0, 6, 12, 18, 24, 30, 36},
    {0, 2, 4, 6, 8, 10, 12},
    {0, 1, 2, 3, 4, 5, 6},
    {0, 1, 2, 3, 4, 5, 6},
};

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

static state_t apply_move(state_t state, uint8_t move)
{
    uint8_t turns = move_mod3[move];
    for (uint8_t i = 0; i <= turns; i++)
        state = quarter_turn(state, move_to_face[move]);
    return state;
}

static uint32_t rank_state(const state_t *state)
{
    uint32_t p = 0, o = 0;
    for (uint8_t i = 0; i < CUBIES; i++) {
        uint8_t smaller = 0;  // Lehmer code
        for (uint8_t j = (uint8_t) (i + 1U); j < CUBIES; j++) {
            if (state->p[j] < state->p[i])
                ++smaller;
        }
        p += p_fact_lut[i][smaller];
    }

    // o = state->o[0] * 243 + state->o[1] * 81 + state->o[2] * 27 + state->o[3] * 9 + state->o[4] * 3 + state->o[5] * 1;
    o = o_tenary_lut[0][state->o[0]] + o_tenary_lut[1][state->o[1]] + o_tenary_lut[2][state->o[2]] + o_tenary_lut[3][state->o[3]] +
        o_tenary_lut[4][state->o[4]] + o_tenary_lut[5][state->o[5]];
    return times_729[p] + o;
}

/*@ requires \valid(state); requires rank < STATES; assigns *state; */
static void unrank_state(uint32_t rank, state_t *state)
{
    uint8_t available[CUBIES] = {0, 1, 2, 3, 4, 5, 6};
    uint32_t p = rank / ORIENTATIONS, o = rank % ORIENTATIONS, f = 720;
    uint8_t sum = 0;
    for (uint8_t i = 0; i < CUBIES; i++) {
        uint8_t q = (uint8_t) (p / f);
        p %= f;
        state->p[i] = available[q];
        for (uint8_t j = q; j + 1 < CUBIES - i; j++)
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

static int valid(const state_t *state)
{
    uint8_t sum = 0;
    for (uint8_t i = 0; i < CUBIES; i++) {
        if (state->p[i] >= CUBIES || state->o[i] >= 3)
            return 0;
        for (uint8_t j = 0; j < i; j++) {
            if (state->p[j] == state->p[i])
                return 0;
        }
        sum = (uint8_t) (sum + state->o[i]);
    }

    // sum % 3 == 0
    while (sum >= 3) {
        sum -= 3;
    }

    return sum == 0;
}

static int build_table(uint8_t toward_solved[], uint8_t *diameter)
{
    // original impl: saves moves that towards solved state.
    // our impl: for each entry, lower 4 bits store the move towards solved state
    // while higher 4 bits store depth value for BFS

    // for 3 faces R, B, D
    // quarter turns are factored into 2 tables
    // next_rank_p[f][r] stores the new rank after
    // face f @ rank r performs a rotation

    // BFS starts

    // mark unvisited entry as 0xFF
    for (uint32_t i = 0; i < STATES; i++) {
        toward_solved[i] = 0xFF;
    }

    // rank 0 is the solved state
    toward_solved[0] = 0;
    uint32_t visited_count = 1;
    *diameter = 0;

    for (uint8_t depth = 0; depth <= 11; depth++) {
        uint8_t next_depth_mask = (uint8_t) ((depth + 1) << 4);

        uint16_t p = 0, o = 0;
        for (uint32_t rank = 0; rank < STATES; rank++) {
            if ((uint8_t) (toward_solved[rank] >> 4) == depth) {  // if the entry is at correct level for the current BFS depth
                for (uint8_t face = 0; face <= 2; face++) {
                    uint16_t next_p = p, next_o = o;

                    for (uint8_t turn = 0; turn <= 2; turn++) {
                        next_p = next_rank_p[face][next_p];
                        next_o = next_rank_o[face][next_o];
                        uint32_t next_rank = times_729[next_p] + next_o;

                        if (toward_solved[next_rank] == 0xFF) {  // unvisited
                            uint8_t move = (uint8_t) ((face << 1) + face + turn);
                            toward_solved[next_rank] = next_depth_mask | inverse_move[move];  // save the solution step
                            visited_count++;
                        }
                    }
                }
            }

            if (++o == ORIENTATIONS) {
                o = 0;
                p++;
            }
        }

        *diameter = depth;
    }

    // BFS ends

    // check if all possible states are visited
    if (visited_count != STATES) {
        printf("visited_count: %d\n", visited_count);
        return 0;  // fail
    }

    return 1;  // success
}

static int parse_state(const char *input, state_t *state)
{
    for (int i = 0; i < 14; i++) {
        int limit = i < 7 ? 7 : 3;
        if (input[i] < '1' || input[i] > '0' + limit)
            return 0;

        int state_idx = i;
        if (state_idx >= 7) {
            state_idx -= 7;
        }

        (i < 7 ? state->p : state->o)[state_idx] = (uint8_t) (input[i] - '1');
    }
    return input[14] == '\0' && valid(state);
}

/* stdout is fully buffered off a terminal, so a write error surfaces at the
 * flush, not at the printf that queued the bytes. Every exit path that has
 * produced output goes through here.
 */
static int output_failed(void)
{
    return fflush(stdout) != 0 || ferror(stdout);
}

static int self_test(void)
{
    const state_t solved = {{0, 1, 2, 3, 4, 5, 6}, {0}};
    state_t state;
    for (uint8_t move = 0; move < MOVES; move++) {
        state = solved;
        state = apply_move(state, move);
        state = apply_move(state, inverse_move[move]);
        if (memcmp(&solved, &state, sizeof(solved)))
            return 0;
    }
    for (uint32_t rank = 0; rank < STATES; rank++) {
        unrank_state(rank, &state);
        if (!valid(&state) || rank_state(&state) != rank)
            return 0;
    }
    return 1;
}

int main(int argc, char **argv)
{
    const char state_str[] = "21345671111111";
    const uint8_t is_self_test = 0;

    state_t state;
    uint8_t diameter;
    uint8_t toward_solved[STATES];

    // self-test routine
    if (is_self_test) {
        if (!self_test()) {
            fputs("self-test failed\n", stderr);
            return 1;
        }
        int status = build_table(toward_solved, &diameter);
        if (!status) {
            fputs("could not build complete state table\n", stderr);
            return 1;
        }
        if (diameter != 11) {
            fputs("BFS check failed\n", stderr);
            return 1;
        }
        puts("3674160 states; diameter 11");
        return output_failed();
    }

    // invalid input state
    if (!parse_state(state_str, &state)) {
        /* C99 5.1.2.2.1 lets argv[0] be null when argc is 0. */
        fprintf(stderr, "usage: %s PPPPPPPOOOOOOO\n", argc > 0 && argv[0] ? argv[0] : "solver");
        return 2;
    }

    // normal routine
    int status = build_table(toward_solved, &diameter);
    if (!status) {
        fputs("could not build complete state table\n", stderr);
        return 1;
    }
    const char *separator = "";
    for (uint32_t rank = rank_state(&state); rank; rank = rank_state(&state)) {
        uint8_t move = toward_solved[rank] & 0xF;  // the lower 4 bits is the real move
        printf("%s%s", separator, move_names[move]);
        separator = " ";
        state = apply_move(state, move);
    }
    putchar('\n');
    return output_failed();
}
