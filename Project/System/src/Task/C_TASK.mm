//
//  C_TASK.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin. The engine's
//  cooperative task scheduler: every task lives in one priority-sorted circular
//  list bounded by a sentinel head (DAT_00188468). Each frame the manager walks
//  the list in priority order, update()ing live tasks and reaping killed ones.
//  Base ctor FUN_00027ea8, setPriority FUN_00027f08, updateAll FUN_00027f40.
//

#include <climits>

#import "C_TASK.h"

// Ghidra: DAT_00188468 — a self-linked sentinel whose priority is the maximum so
// every real task sorts before it, and whose next/prev bound the circular list.
C_TASK &C_TASK::scheduler() {
    static C_TASK sentinel;
    static bool initialised = false;
    if (!initialised) {
        initialised = true;
        sentinel.m_priority = INT_MAX;
    }
    return sentinel;
}

// Ghidra: base ctor FUN_00027ea8 — sets the vtable, self-links the node, defaults
// the priority to 9, and clears the name + killed flag. It stays detached (its own
// prev/next) until setPriority inserts it into the scheduler list. (The scene-tree
// links are left for the owner/subclass to populate; modelled as null here.)
C_TASK::C_TASK()
    : m_prev(this), m_next(this), m_priority(9),
      m_parent(nullptr), m_link1(nullptr), m_link2(nullptr), m_link3(nullptr),
      m_name(nullptr), m_killed(false) {
}

// Ghidra: base dtor @ 0x27ec8 (mislabelled "caSourceNode_dtor") — re-install the base vtable,
// unlink the node from the scheduler list, then free the owned name buffer. The compiler's
// deleting-destructor thunk @ 0x27ef8 ("caSourceNode_delete") is this destructor followed by
// operator delete (the vtable delete slot) and is not written by hand. The reaped-task path in
// FUN_00027f40 saves ->next before invoking this.
C_TASK::~C_TASK() {
    m_next->m_prev = m_prev;
    m_prev->m_next = m_next;
    delete[] m_name;   // the node owns its name buffer (the binary frees and nulls it here)
    m_name = nullptr;
}

// Base per-frame hooks: overridden by concrete tasks (MainTask, TitleTask, ...).
void C_TASK::update(int /*deltaMs*/) {}
void C_TASK::draw() {}

// Ghidra: FUN_00027f08 — unlink, then insert before the first node whose priority
// is >= `priority` (walking from the sentinel), keeping the list sorted.
void C_TASK::setPriority(int priority) {
    // Unlink from the current slot.
    m_next->m_prev = m_prev;
    m_prev->m_next = m_next;

    C_TASK *before = &scheduler();
    C_TASK *at = before->m_next;
    while (at->m_priority < priority) {
        before = at;
        at = at->m_next;
    }

    m_next = at;
    m_prev = before;
    before->m_next = this;
    at->m_prev = this;
    m_priority = priority;
}

// Ghidra: FUN_00027f40 — the scheduler tick. Walk the list in priority order:
// update() each live task; destroy (reap) any that has been killed.
void C_TASK::updateAll(int deltaMs) {
    C_TASK &sentinel = scheduler();
    C_TASK *task = sentinel.m_next;
    while (task != &sentinel) {
        if (!task->m_killed) {
            task->update(deltaMs);   // vtable[0]
            task = task->m_next;
        } else {
            C_TASK *next = task->m_next;   // save before the dtor unlinks it
            delete task;
            task = next;
        }
    }
}
