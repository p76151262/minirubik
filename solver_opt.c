#include <stdint.h>
#include <stdio.h>
#include "lut.h"

const char state_str[] = "21345671111111";

enum { CUBIES = 7, PERMUTATIONS = 5040, ORIENTATIONS = 729, STATES = PERMUTATIONS * ORIENTATIONS, MOVES = 9 };

// states for cubie 1-7, cubie 0 is fixed and not listed
typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

typedef struct {
    uint16_t first;
    uint16_t second;
} u16_pair_t;

static const char *const move_names[MOVES] = {"R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'"};
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

uint8_t solution_path[11] = {0};

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

static u16_pair_t rank_state(const state_t *state)
{
    uint16_t p = 0, o = 0;
    for (uint8_t i = 0; i < CUBIES; i++) {
        uint8_t smaller = 0;  // Lehmer code
        for (uint8_t j = (uint8_t) (i + 1U); j < CUBIES; j++)
            smaller += (state->p[j] < state->p[i]);
        p += p_fact_lut[i][smaller];
    }

    // o = state->o[0] * 243 + state->o[1] * 81 + state->o[2] * 27 + state->o[3] * 9 + state->o[4] * 3 + state->o[5] * 1;
    o = o_tenary_lut[0][state->o[0]] + o_tenary_lut[1][state->o[1]] + o_tenary_lut[2][state->o[2]] + o_tenary_lut[3][state->o[3]] +
        o_tenary_lut[4][state->o[4]] + o_tenary_lut[5][state->o[5]];

    u16_pair_t result = {p, o};

    return result;
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

static int dfs(uint16_t p, uint16_t o, uint8_t depth, uint8_t bound, uint8_t last_face)
{
    // h = max(h_p, h_o)
    uint8_t h = h_p[p] > h_o[o] ? h_p[p] : h_o[o];

    // pruning 1: if current steps count(depth) + estimate minimum step count(h) > depth limit
    // give up searching
    if (depth + h > bound)
        return 0;

    // terminate condition (solved)
    if (p == 0 && o == 0)
        return 1;

    // go deeper in dfs
    for (uint8_t face = 0; face <= 2; face++) {
        // pruning 2: skip consecutive same face as they belong to 1 move
        if (face == last_face)
            continue;

        uint16_t next_p = p, next_o = o;
        for (uint8_t turn = 0; turn <= 2; turn++) {
            next_p = next_rank_p[face][next_p];
            next_o = next_rank_o[face][next_o];

            if (dfs(next_p, next_o, depth + 1, bound, face)) {     // the dfs reached solved state
                solution_path[depth] = (face << 1) + face + turn;  // face * 3 + turn
                return 1;
            }
        }
    }

    return 0;  // fail
}

// iterative version, arrays act as stacks
static int iterative_dfs(uint16_t start_p, uint16_t start_o, uint8_t bound)
{
    if (start_p == 0 && start_o == 0)
        return 1;

    uint16_t p_stk[12];
    uint16_t o_stk[12];
    uint8_t face_stk[12];
    uint8_t turn_stk[12];

    p_stk[0] = start_p;
    o_stk[0] = start_o;
    int8_t depth = 0;

enter_level:;
    uint8_t face = 0;
    uint8_t last_face = ((depth > 0) ? face_stk[depth - 1] : 0xFF);

face_loop:
    if (face == last_face)  // pruning 2
        goto next_face;
    uint16_t next_p = p_stk[depth];
    uint16_t next_o = o_stk[depth];

    uint8_t turn = 0;
turn_loop:
    next_p = next_rank_p[face][next_p];
    next_o = next_rank_o[face][next_o];

    uint8_t h = h_p[next_p] > h_o[next_o] ? h_p[next_p] : h_o[next_o];
    if (depth + 1 + h <= bound) {  // pruning 1: go into next level or not
        face_stk[depth] = face;
        turn_stk[depth] = turn;

        // next_p and next_o would be updated until both reaches 0
        if (next_p == 0 && next_o == 0) {  // solution found
            for (int8_t i = 0; i <= depth; i++)
                solution_path[i] = (face_stk[i] << 1) + face_stk[i] + turn_stk[i];
            return 1;
        }

        // solution not found yet
        // the next_* values calculated at depth d is the start_* values
        // for the depth d+1, and that are stored in *_stk[d+1]
        // *_stk[d] are not toched by depth d
        depth++;
        p_stk[depth] = next_p;
        o_stk[depth] = next_o;
        goto enter_level;
    }

resume_turn:
    if (++turn <= 2)
        goto turn_loop;

next_face:
    if (++face <= 2)
        goto face_loop;

    // 3 faces are exhausted, backtrack 1 level up
    if (--depth < 0)
        return 0;  // nothing to backtrack (root node)

    // resume values from stack for backtrack
    face = face_stk[depth];
    turn = turn_stk[depth];
    next_p = p_stk[depth + 1];  // retrieve next_* from *_stk[d+1]
    next_o = o_stk[depth + 1];
    goto resume_turn;
}

static int parse_state(const char *input, state_t *state)
{
    for (int i = 0; i < 14; i++) {
        int limit = i < 7 ? 7 : 3;
        if (input[i] < '1' || input[i] > '0' + limit)
            return 0;

        int state_idx = i >= 7 ? i - 7 : i;

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

int main(void)
{
    state_t state;

    // check if input state is invalid
    if (!parse_state(state_str, &state)) {
        fprintf(stderr, "Input state %s is invalid!\n", state_str);
        return 2;
    }

    const u16_pair_t rank = rank_state(&state);
    const uint16_t start_p = rank.first;
    const uint16_t start_o = rank.second;

    fprintf(stdout, "state = %s, rank_p = %d, rank_o = %d\n", state_str, start_p, start_o);

    uint8_t start_bound = h_p[start_p] > h_o[start_o] ? h_p[start_p] : h_o[start_o];
    fprintf(stdout, "start_bound = %d, starting IDA*...\n", start_bound);

    for (uint8_t bound = start_bound; bound <= 11; bound++) {
        if (iterative_dfs(start_p, start_o, bound)) {  // solution found under bound
            fprintf(stdout, "IDA*: found solution under bound %d\n", bound);

            for (int8_t i = 0; i < bound; i++) {
                uint8_t move = solution_path[i];
                fprintf(stdout, "%s ", move_names[move]);
                state = apply_move(state, move);
            }
            break;
        }
        fprintf(stdout, "IDA*: failed to find solution under bound %d\n", bound);
    }
    putchar('\n');

    fprintf(stdout, "state after applying solution moves:\n");
    for (uint8_t i = 0; i < 14; i++) {
        fprintf(stdout, "%hhu", *((uint8_t *) (&state) + i) + 1);
    }

    putchar('\n');
    return output_failed();
}
